import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../domain/shared/book_backup.dart';
import '../../domain/shared/book_upload.dart';
import '../../domain/shared/book_upload_service.dart';
import '../database/app_database.dart';

/// The answer to one HTTP request, reduced to what this feature needs.
class TransportResponse {
  const TransportResponse({required this.statusCode, this.body = ''});

  final int statusCode;
  final String body;
}

/// Where a request is sent.
///
/// A seam, so the uploader's real behaviour — URL building, headers, multipart
/// encoding, status mapping — is exercised by tests without a server. Replacing
/// the transport rather than the HTTP client means nothing above it is faked.
abstract interface class HttpTransport {
  /// Sends one request.
  ///
  /// [body] is an **ordered list of byte segments**, not one buffer. A snapshot
  /// can be tens of megabytes, and concatenating every part into a single
  /// `Uint8List` would hold a second full-size copy of the file in memory for no
  /// benefit. The segments are written in order instead.
  Future<TransportResponse> send({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    List<List<int>> body = const <List<int>>[],
  });
}

/// The real transport, over `dart:io`.
///
/// `dart:io` rather than a package on purpose: it is part of the SDK, so the
/// upload gains no dependency at all. `docs/AI_RULES.md` requires every
/// dependency to be a deliberate, recorded choice, and the standard library is
/// the cheapest choice available.
class IoHttpTransport implements HttpTransport {
  IoHttpTransport({this.timeout = const Duration(seconds: 30)});

  /// A request that hangs must not hang the application.
  final Duration timeout;

  /// **One client for the whole transport, not one per request.**
  ///
  /// `HttpClient` owns the connection pool, so building one per request throws
  /// keep-alive away and forces a fresh TCP (and, over HTTPS, TLS) handshake for
  /// every call — and sending several fiscal years is two calls per year. The
  /// transport is built once in the composition root and lives as long as the
  /// application, so the pool is reused throughout.
  late final HttpClient _client = HttpClient()..connectionTimeout = timeout;

  @override
  Future<TransportResponse> send({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    List<List<int>> body = const <List<int>>[],
  }) async {
    final request = await _client.openUrl(method, url).timeout(timeout);
    headers.forEach(request.headers.set);

    if (body.isNotEmpty) {
      // Declared up front so the request is a normal length-delimited body
      // rather than chunked, which keeps the wire format the multipart parser on
      // the server already handles.
      request.contentLength =
          body.fold<int>(0, (total, part) => total + part.length);
      for (final part in body) {
        request.add(part);
      }
    }

    final response = await request.close().timeout(timeout);
    final text = await response.transform(utf8.decoder).join().timeout(timeout);
    return TransportResponse(statusCode: response.statusCode, body: text);
  }
}

/// Sends a verified snapshot to the server.
///
/// ## What this guarantees
///
/// **The local snapshot is never modified.** Not on success, not on refusal, not
/// on a conflict, not when the server cannot be reached. It is opened for
/// reading and its bytes are sent; nothing writes to it. That is what makes it
/// safe to keep using the offline backup exactly as before, with uploading as a
/// strictly additional copy.
///
/// **A result is only a success when the server said so.** The upload reports
/// [UploadStatus.uploaded] only after a `201` carrying a revision number. A
/// `201` whose body cannot be read is *not* a success: the point of the answer is
/// to confirm what the server stored, and an answer that does not do that has not
/// confirmed anything.
///
/// **The declared checksum and size come from the file, not from the
/// [BookBackup].** They are recomputed at upload time, because the server checks
/// them against the bytes it receives. Sending a checksum recorded when the
/// backup was taken would turn a harmless later change into a confusing refusal.
class HttpBackupUploader implements UploadActions {
  HttpBackupUploader({
    required HttpTransport transport,
    required BackendSession? session,
    required File uploadLogFile,
  })  : _transport = transport,
        _session = session,
        _uploadLogFile = uploadLogFile;

  final HttpTransport _transport;
  final BackendSession? _session;
  final File _uploadLogFile;

  /// The multipart boundary is long and drawn from a random source so it cannot
  /// collide with the file's contents.
  final Random _random = Random.secure();

  @override
  BackendSession? get session => _session;

  @override
  bool get canUpload => _session?.isUsable ?? false;

  @override
  Future<UploadResult> upload(BookBackup backup) async {
    final session = _session;
    if (session == null || !session.isUsable) {
      throw UploadException(
        'This application is not signed in, so the backup has not been sent.',
      );
    }

    final file = File(backup.filePath);
    if (!await file.exists()) {
      throw UploadException(
        'The backup ${backup.fileName} is no longer on disk, so it could not be '
        'sent.',
      );
    }

    // **Prove the file is still the snapshot that was verified, before sending
    // it.** The recorded checksum is what makes it that snapshot: without this
    // check, a file that was corrupted or edited since it was taken would be
    // uploaded, accepted by the server (whose checksum check only proves the
    // bytes survived the trip), and reported to the user as a safe off-machine
    // backup. Verifying here is far cheaper than discovering it at restore time.
    final size = await file.length();
    final checksum = await _checksumOffIsolate(file.path);

    if (backup.checksum.isNotEmpty && checksum != backup.checksum) {
      return UploadResult(
        backup: backup,
        status: UploadStatus.unverified,
        message: 'This snapshot is no longer the one that was verified, so it '
            'was not sent. Take a fresh backup of ${backup.fiscalYearLabel} and '
            'send that. Nothing was uploaded and your files are unchanged.',
      );
    }
    if (backup.fileSizeBytes > 0 && size != backup.fileSizeBytes) {
      return UploadResult(
        backup: backup,
        status: UploadStatus.unverified,
        message:
            'This snapshot is not the size it was when it was taken, so it '
            'was not sent. Take a fresh backup of ${backup.fiscalYearLabel} and '
            'send that. Nothing was uploaded and your files are unchanged.',
      );
    }

    // Read the bytes once for the body. The checksum above is computed by
    // streaming in a separate isolate, so a large snapshot neither blocks the
    // interface nor exists twice in memory at once.
    final bytes = await file.readAsBytes();

    // Ask what is already stored, so the revision continues the sequence. The
    // server refuses a revision that does not follow the latest, so guessing
    // would produce a conflict on the very first upload after a reinstall.
    final nextRevision = await _nextRevisionFor(session, backup);
    if (nextRevision == null) {
      return UploadResult(
        backup: backup,
        status: UploadStatus.unreachable,
        message: 'The cloud copy was not updated: the server could not be '
            'reached. Your books and your local backup are unchanged.',
      );
    }

    final boundary = _newBoundary();
    final body = _multipartParts(
      boundary: boundary,
      fields: <String, String>{
        'fiscal_year_label': backup.fiscalYearLabel,
        'checksum': checksum,
        'file_size': '$size',
        'database_version': '$currentSchemaVersion',
        'revision': '$nextRevision',
      },
      fileField: 'file',
      fileName: backup.fileName,
      fileBytes: bytes,
    );

    final TransportResponse response;
    try {
      response = await _transport.send(
        method: 'POST',
        url: _revisionsUri(session),
        headers: <String, String>{
          'Authorization': 'Bearer ${session.token}',
          'Accept': 'application/json',
          'Content-Type': 'multipart/form-data; boundary=$boundary',
        },
        body: body,
      );
    } catch (error) {
      // Offline is a normal condition for this product, not a failure of the
      // business. Nothing was stored, and nothing local changed.
      return UploadResult(
        backup: backup,
        status: UploadStatus.unreachable,
        message: 'The cloud copy was not updated: the server could not be '
            'reached. Your books and your local backup are unchanged.',
      );
    }

    return _interpret(response, backup, nextRevision, checksum);
  }

  /// Turns a server answer into a result, without ever inventing a success.
  UploadResult _interpret(
    TransportResponse response,
    BookBackup backup,
    int sentRevision,
    String checksum,
  ) {
    switch (response.statusCode) {
      case 201:
      case 200:
        final revision = _revisionFrom(response.body);
        if (revision == null) {
          // The server stored something but did not say what. Reporting success
          // would be claiming a confirmation that never happened.
          return UploadResult(
            backup: backup,
            status: UploadStatus.unreachable,
            message: 'The server answered but did not confirm what it stored, '
                'so this is not being reported as a successful upload. Your '
                'local backup is unchanged.',
          );
        }
        // Recorded only now, after the server has confirmed. A local note must
        // never run ahead of the remote fact it describes.
        _remember(
          UploadRecord(
            fiscalYearLabel: backup.fiscalYearLabel,
            fileName: backup.fileName,
            uploadedAt: DateTime.now(),
            remoteRevision: revision,
            checksum: checksum,
          ),
        );
        return UploadResult(
          backup: backup,
          status: UploadStatus.uploaded,
          remoteRevision: revision,
          message: 'Stored on the server as revision $revision. Your books '
              'remain on this computer as well.',
        );

      case 409:
        return UploadResult(
          backup: backup,
          status: UploadStatus.conflict,
          message: 'The server already holds a newer revision of this year, so '
              'this snapshot was not stored. ${_reasonFrom(response.body)} '
              'Another copy of these books has been uploaded. Your local backup '
              'is unchanged; nothing was overwritten on either side.',
        );

      case 422:
        return UploadResult(
          backup: backup,
          status: UploadStatus.rejected,
          message:
              'The server refused this snapshot. ${_reasonFrom(response.body)}'
              ' Your local backup is unchanged and can still be restored.',
        );

      default:
        // 401 and 403 land here too: a rejected credential is not a statement
        // about the books, so it is not `rejected`. It is simply "not uploaded".
        return UploadResult(
          backup: backup,
          status: UploadStatus.unreachable,
          message: 'The cloud copy was not updated: the server answered with '
              '${response.statusCode}. Your books and your local backup are '
              'unchanged.',
        );
    }
  }

  /// The revision this upload should claim, or null when the server did not
  /// answer.
  Future<int?> _nextRevisionFor(
    BackendSession session,
    BookBackup backup,
  ) async {
    final TransportResponse response;
    try {
      response = await _transport.send(
        method: 'GET',
        url: _revisionsUri(session),
        headers: <String, String>{
          'Authorization': 'Bearer ${session.token}',
          'Accept': 'application/json',
        },
      );
    } catch (error) {
      return null;
    }

    if (response.statusCode != 200) return null;

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, Object?>) return null;
      final data = decoded['data'];
      if (data is! List) return null;

      var highest = 0;
      for (final entry in data) {
        if (entry is! Map) continue;
        // **Only this fiscal year counts.** A revision belonging to another
        // year is a different sequence, and letting one advance this year's
        // number would produce a conflict.
        if (entry['fiscal_year_label'] != backup.fiscalYearLabel) continue;
        final revision = entry['revision'];
        if (revision is int && revision > highest) highest = revision;
      }
      return highest + 1;
    } catch (error) {
      return null;
    }
  }

  Uri _revisionsUri(BackendSession session) => Uri.parse(
        '${session.serverBaseUrl.toString().replaceAll(RegExp(r'/+$'), '')}'
        '/api/books/${session.bookId}/backup-revisions',
      );

  /// Reads the revision out of a store response, or null if it is not there.
  int? _revisionFrom(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final revision = decoded['revision'];
      return revision is int ? revision : null;
    } catch (error) {
      return null;
    }
  }

  /// The server's explanation, if it gave one, as a sentence.
  String _reasonFrom(String body) {
    if (body.trim().isEmpty) return '';

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final reason = decoded['reason'] ?? decoded['message'];
        if (reason is String && reason.trim().isNotEmpty) {
          final trimmed = reason.trim();
          return trimmed.endsWith('.') ? trimmed : '$trimmed.';
        }
      }
    } catch (error) {
      // A refusal with a body we cannot read is still a refusal. The status
      // code is the part that decides, and it has already decided.
    }
    return '';
  }

  @override
  Future<List<UploadRecord>> uploadsFor(String fiscalYearLabel) async {
    final all = await _readLog();
    final matching = all
        .where((record) => record.fiscalYearLabel == fiscalYearLabel)
        .toList()
      // Newest first.
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return matching;
  }

  Future<List<UploadRecord>> _readLog() async {
    if (!await _uploadLogFile.exists()) return const [];

    try {
      final decoded = jsonDecode(await _uploadLogFile.readAsString());
      if (decoded is! Map) return const [];
      final entries = decoded['uploads'];
      if (entries is! List) return const [];

      final records = <UploadRecord>[];
      for (final entry in entries) {
        if (entry is! Map) continue;
        final label = entry['fiscalYearLabel'];
        final name = entry['fileName'];
        final at = entry['uploadedAt'];
        final revision = entry['remoteRevision'];
        final checksum = entry['checksum'];
        if (label is! String || name is! String || at is! String) continue;
        final parsed = DateTime.tryParse(at);
        if (parsed == null) continue;

        records.add(
          UploadRecord(
            fiscalYearLabel: label,
            fileName: name,
            uploadedAt: parsed,
            remoteRevision: revision is int ? revision : 0,
            checksum: checksum is String ? checksum : '',
          ),
        );
      }
      return records;
    } catch (error) {
      // A log we cannot read must not stop the application. The server is the
      // authority on what has been uploaded; this file is only a local note.
      return const [];
    }
  }

  /// Appends a confirmed upload to the local log.
  ///
  /// A failure to write is **deliberately swallowed**. The upload already
  /// succeeded on the server, and turning that into a reported failure would
  /// tell the user their backup did not happen when it did. The cost is that the
  /// screen may under-report the last upload time, which is the lesser error.
  void _remember(UploadRecord record) {
    try {
      final existing = _uploadLogFile.existsSync()
          ? jsonDecode(_uploadLogFile.readAsStringSync())
          : null;
      final uploads = <Object?>[
        if (existing is Map && existing['uploads'] is List)
          ...(existing['uploads'] as List),
      ];

      uploads.add(<String, Object?>{
        'fiscalYearLabel': record.fiscalYearLabel,
        'fileName': record.fileName,
        'uploadedAt': record.uploadedAt.toIso8601String(),
        'remoteRevision': record.remoteRevision,
        'checksum': record.checksum,
      });

      _uploadLogFile.parent.createSync(recursive: true);
      _uploadLogFile.writeAsStringSync(
        jsonEncode(<String, Object?>{'uploads': uploads}),
      );
    } catch (error) {
      // See the doc comment. Never fatal.
    }
  }

  String _newBoundary() {
    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    return '----financeapp${base64Url.encode(bytes)}';
  }

  /// Encodes a `multipart/form-data` body as **ordered segments**.
  ///
  /// Built by hand because the SDK has no multipart encoder and the one in
  /// `package:http` would add a dependency for twenty lines of work.
  ///
  /// Returns segments rather than one buffer so the snapshot's bytes are passed
  /// by reference into the request instead of being copied into a second
  /// full-size array. At snapshot sizes that copy is the difference between
  /// holding the file once and holding it several times over.
  List<List<int>> _multipartParts({
    required String boundary,
    required Map<String, String> fields,
    required String fileField,
    required String fileName,
    required List<int> fileBytes,
  }) {
    final parts = <List<int>>[];

    void writeLine(String line) => parts.add(utf8.encode('$line\r\n'));

    fields.forEach((name, value) {
      writeLine('--$boundary');
      writeLine('Content-Disposition: form-data; name="$name"');
      writeLine('');
      writeLine(value);
    });

    writeLine('--$boundary');
    writeLine('Content-Disposition: form-data; name="$fileField"; '
        'filename="$fileName"');
    writeLine('Content-Type: application/octet-stream');
    writeLine('');
    parts.add(fileBytes);
    writeLine('');
    writeLine('--$boundary--');

    return parts;
  }

  /// SHA-256 of a file, computed by streaming it in a **separate isolate**.
  ///
  /// Two reasons this is not a one-liner on the calling isolate. Hashing a
  /// snapshot of tens of megabytes is real CPU work, and the upload is started
  /// from a button handler, so doing it inline would freeze the interface —
  /// including the progress indicator that is meant to show the work happening.
  /// And streaming the file means the bytes are never held in memory just to be
  /// hashed: only the digest crosses back.
  ///
  /// Returns the digest in lower-case hex, the form the server compares against.
  Future<String> _checksumOffIsolate(String path) => Isolate.run(() async {
        final digest = await sha256.bind(File(path).openRead()).first;
        return digest.toString();
      });
}
