import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:financeapp/src/domain/shared/book_backup.dart';
import 'package:financeapp/src/domain/shared/book_upload.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/sync/http_backup_uploader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Tests for sending a verified snapshot to the server.
///
/// The feature is only worth having if it can **say no**. So most of these are
/// about what happens when the server refuses, is unreachable, or reports a
/// conflict — and, above all, about the one invariant that must hold in every
/// single case: **the local backup is never touched.**
///
/// That invariant is the whole point. A local snapshot is the only copy the
/// business has until the server confirms otherwise, so an upload that lost or
/// altered it would turn a good backup into no backup. Each refusal test asserts
/// the file's bytes are unchanged.
void main() {
  late Directory temp;
  late Directory backupDir;
  late File logFile;
  late File snapshot;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('financeapp_upload');
    backupDir = Directory(p.join(temp.path, 'backups'))..createSync();
    logFile = File(p.join(backupDir.path, 'uploads.json'));
    snapshot = File(p.join(backupDir.path, 'accounting-FY-2082-83-20260930.db'))
      ..writeAsBytesSync(List<int>.generate(2048, (i) => i % 251));
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// A snapshot as the backup service would describe it: the recorded checksum is
  /// the file's own, which is what makes it the *verified* artifact.
  ///
  /// [recordedChecksum] and [recordedSize] exist so a test can describe a file
  /// that no longer matches what was recorded, which is the case the uploader
  /// must refuse.
  BookBackup backupOf(
    File file, {
    String label = 'FY 2082/83',
    String? recordedChecksum,
    int? recordedSize,
  }) =>
      BookBackup(
        fileName: p.basename(file.path),
        filePath: file.path,
        fiscalYearLabel: label,
        takenAt: DateTime(2026, 9, 30, 10, 0),
        fileSizeBytes: recordedSize ?? file.lengthSync(),
        checksum: recordedChecksum ?? sha256Of(file),
      );

  BackendSession sessionFor({
    String token = 'a-token',
    String bookId = '7',
    String base = 'http://127.0.0.1:8123',
  }) =>
      BackendSession(
        serverBaseUrl: Uri.parse(base),
        token: token,
        bookId: bookId,
        accountLabel: 'sita@example.com',
      );

  HttpBackupUploader uploaderWith(
    HttpTransport transport, {
    BackendSession? session,
  }) =>
      HttpBackupUploader(
        transport: transport,
        session: session ?? sessionFor(),
        uploadLogFile: logFile,
      );

  group('the request carries the truth about the file', () {
    test('declares the checksum and size of the bytes being sent', () async {
      final transport = FakeTransport.success(revision: 1);
      await uploaderWith(transport).upload(backupOf(snapshot));

      final body = transport.lastRequest.bodyAsText();
      expect(body, contains(sha256Of(snapshot)));
      expect(declaredFieldIn(body, 'checksum'), sha256Of(snapshot));
      expect(declaredFieldIn(body, 'file_size'), '${snapshot.lengthSync()}');
      expect(declaredFieldIn(body, 'fiscal_year_label'), 'FY 2082/83');
    });

    test('declares the schema version the application writes', () async {
      final transport = FakeTransport.success(revision: 1);
      await uploaderWith(transport).upload(backupOf(snapshot));

      // Read back out of the request and compared to the **constant**, not to a
      // literal. The old assertion was `contains('9')`, which the snapshot's own
      // bytes already satisfied, so it could never fail.
      expect(
        declaredFieldIn(transport.lastRequest.bodyAsText(), 'database_version'),
        '$currentSchemaVersion',
      );
    });

    test('posts to the book\'s revisions endpoint on the configured server',
        () async {
      final transport = FakeTransport.success(revision: 1);
      await uploaderWith(
        transport,
        session: sessionFor(bookId: '42', base: 'https://books.example.com'),
      ).upload(backupOf(snapshot));

      expect(
        transport.lastRequest.url.toString(),
        'https://books.example.com/api/books/42/backup-revisions',
      );
      expect(transport.lastRequest.method, 'POST');
    });

    test('sends the token as a bearer credential', () async {
      final transport = FakeTransport.success(revision: 1);
      await uploaderWith(transport, session: sessionFor(token: 'secret-token'))
          .upload(backupOf(snapshot));

      expect(
        transport.lastRequest.headers['Authorization'],
        'Bearer secret-token',
      );
    });

    test('sends the snapshot bytes themselves, not a placeholder', () async {
      final transport = FakeTransport.success(revision: 1);
      await uploaderWith(transport).upload(backupOf(snapshot));

      // The multipart body must contain the actual file content, and the file
      // must be passed by reference as its own segment rather than copied into a
      // concatenated buffer.
      final parts = transport.lastRequest.bodyParts;
      expect(
        parts.any((part) =>
            part.length == snapshot.lengthSync() &&
            String.fromCharCodes(part.take(64)) ==
                String.fromCharCodes(snapshot.readAsBytesSync().take(64))),
        isTrue,
        reason: 'the snapshot must be one whole, uncopied segment',
      );
    });
  });

  /// The snapshot must still be the artifact that was verified.
  ///
  /// The server's checksum check only proves the bytes survived the trip, so
  /// without a local comparison a file that changed since it was taken would be
  /// uploaded, accepted, and reported as a safe off-machine backup.
  group('a snapshot that is no longer the verified one is not sent', () {
    test('refuses when the file no longer matches its recorded checksum',
        () async {
      final before = snapshot.readAsBytesSync();
      final transport = FakeTransport.success(revision: 1);

      final result = await uploaderWith(transport).upload(
        backupOf(snapshot, recordedChecksum: 'f' * 64),
      );

      expect(result.status, UploadStatus.unverified);
      expect(result.isSuccess, isFalse);
      expect(
        transport.requests,
        isEmpty,
        reason: 'nothing should leave the machine for an unverified snapshot',
      );
      expect(snapshot.readAsBytesSync(), before);
    });

    test('refuses when the file is not the size it was when taken', () async {
      final transport = FakeTransport.success(revision: 1);

      final result = await uploaderWith(transport).upload(
        backupOf(snapshot, recordedSize: snapshot.lengthSync() + 1),
      );

      expect(result.status, UploadStatus.unverified);
      expect(transport.requests, isEmpty);
      expect(snapshot.existsSync(), isTrue);
    });

    test('an unverified snapshot is not recorded as an upload', () async {
      await uploaderWith(FakeTransport.success(revision: 1)).upload(
        backupOf(snapshot, recordedChecksum: 'f' * 64),
      );

      expect(
          await uploaderWith(FakeTransport.success(revision: 1))
              .uploadsFor('FY 2082/83'),
          isEmpty);
    });

    test('a snapshot that matches its record is sent as normal', () async {
      // The guard must not block the ordinary case.
      final result = await uploaderWith(FakeTransport.success(revision: 1))
          .upload(backupOf(snapshot));

      expect(result.status, UploadStatus.uploaded, reason: result.message);
    });
  });

  group('the revision continues the sequence the server expects', () {
    test('asks the server what is already stored, and sends one more',
        () async {
      final transport = FakeTransport.sequence([
        FakeTransport.indexWith(revisions: [1, 2, 3]),
        FakeTransport.stored(revision: 4),
      ]);

      final result = await uploaderWith(transport).upload(backupOf(snapshot));

      expect(result.status, UploadStatus.uploaded);
      expect(transport.requests.first.method, 'GET');
      // Asserted on the **declared** revision, not on the server's echo. The
      // fake replies with whatever a test scripts, so checking only
      // `result.remoteRevision` would assert the script and not the uploader.
      expect(declaredRevisionIn(transport.lastRequest.bodyAsText()), 4);
    });

    test('sends revision 1 when the server holds nothing for this year',
        () async {
      final transport = FakeTransport.sequence([
        FakeTransport.indexWith(revisions: const []),
        FakeTransport.stored(revision: 1),
      ]);

      final result = await uploaderWith(transport).upload(backupOf(snapshot));

      expect(result.status, UploadStatus.uploaded);
      expect(declaredRevisionIn(transport.lastRequest.bodyAsText()), 1);
    });

    test('ignores revisions belonging to a different fiscal year', () async {
      final transport = FakeTransport.sequence([
        // The index lists another year's revisions at higher numbers.
        FakeTransport.indexWith(revisions: [5, 6], label: 'FY 2081/82'),
        FakeTransport.stored(revision: 1),
      ]);

      await uploaderWith(transport).upload(backupOf(snapshot));

      expect(
        declaredRevisionIn(transport.lastRequest.bodyAsText()),
        1,
        reason:
            'another year\'s revisions must not advance this year\'s number, '
            'or the first upload after that year would conflict',
      );
    });
  });

  group('a refusal is reported and the local backup is untouched', () {
    test('a checksum refusal becomes a rejected result', () async {
      final before = snapshot.readAsBytesSync();
      final transport = FakeTransport.sequence([
        FakeTransport.indexWith(revisions: const []),
        FakeTransport.refused(
          422,
          '{"message":"The upload was not accepted as a valid backup.",'
          '"reason":"The checksum does not match."}',
        ),
      ]);

      final result = await uploaderWith(transport).upload(backupOf(snapshot));

      expect(result.status, UploadStatus.rejected);
      expect(result.isSuccess, isFalse);
      expect(result.message, contains('checksum'));
      expect(snapshot.readAsBytesSync(), before,
          reason: 'the local copy is the '
              'fallback and must survive a refusal byte for byte');
      expect(snapshot.existsSync(), isTrue);
    });

    test('a conflict is reported as a conflict, not as a failure or a success',
        () async {
      final transport = FakeTransport.sequence([
        FakeTransport.indexWith(revisions: [1]),
        FakeTransport.refused(
          409,
          '{"message":"The revision does not follow the latest stored one.",'
          '"reason":"Expected revision 2, but the desktop sent 1."}',
        ),
      ]);

      final result = await uploaderWith(transport).upload(backupOf(snapshot));

      expect(result.status, UploadStatus.conflict);
      expect(result.message, contains('revision'));
    });

    test('a conflict is not retried blindly', () async {
      final transport = FakeTransport.sequence([
        FakeTransport.indexWith(revisions: [1]),
        FakeTransport.refused(409, '{"message":"stale"}'),
      ]);

      await uploaderWith(transport).upload(backupOf(snapshot));

      final posts = transport.requests.where((r) => r.method == 'POST');
      expect(
        posts.length,
        1,
        reason: 'retrying would either fail again or overwrite another '
            'installation\'s snapshot',
      );
    });

    test('a non-database refusal never claims success', () async {
      final transport = FakeTransport.sequence([
        FakeTransport.indexWith(revisions: const []),
        FakeTransport.refused(422, '{"reason":"Not a SQLite database."}'),
      ]);

      final result = await uploaderWith(transport).upload(backupOf(snapshot));

      expect(result.isSuccess, isFalse);
      expect(result.status, UploadStatus.rejected);
    });
  });

  group('an unreachable server does not stop the business', () {
    test('a connection failure becomes an unreachable result', () async {
      final before = snapshot.readAsBytesSync();
      final transport = FakeTransport.offline();

      final result = await uploaderWith(transport).upload(backupOf(snapshot));

      expect(result.status, UploadStatus.unreachable);
      expect(result.isSuccess, isFalse);
      expect(snapshot.readAsBytesSync(), before);
    });

    test('a server error status is not treated as a successful upload',
        () async {
      final transport = FakeTransport.sequence([
        FakeTransport.indexWith(revisions: const []),
        FakeTransport.refused(500, 'Internal Server Error'),
      ]);

      final result = await uploaderWith(transport).upload(backupOf(snapshot));

      expect(result.isSuccess, isFalse);
      expect(result.status, UploadStatus.unreachable);
    });

    test('an unparseable response is not treated as success', () async {
      final transport = FakeTransport.sequence([
        FakeTransport.indexWith(revisions: const []),
        const TransportResponse(statusCode: 201, body: 'not json at all'),
      ]);

      final result = await uploaderWith(transport).upload(backupOf(snapshot));

      // 201 with no revision means the server did not confirm what it stored.
      expect(result.isSuccess, isFalse);
    });

    test('the local backup survives every failure mode byte for byte',
        () async {
      final before = snapshot.readAsBytesSync();

      for (final transport in <FakeTransport>[
        FakeTransport.offline(),
        FakeTransport.sequence([
          FakeTransport.indexWith(revisions: const []),
          FakeTransport.refused(422, '{"reason":"no"}'),
        ]),
        FakeTransport.sequence([
          FakeTransport.indexWith(revisions: [9]),
          FakeTransport.refused(409, '{"message":"stale"}'),
        ]),
      ]) {
        if (logFile.existsSync()) logFile.deleteSync();
        await uploaderWith(transport).upload(backupOf(snapshot));
        expect(snapshot.readAsBytesSync(), before);
        expect(snapshot.existsSync(), isTrue);
      }
    });
  });

  group('the last successful upload is remembered', () {
    test('a successful upload is recorded with its year and revision',
        () async {
      final transport = FakeTransport.sequence([
        FakeTransport.indexWith(revisions: const []),
        FakeTransport.stored(revision: 1),
      ]);

      await uploaderWith(transport).upload(backupOf(snapshot));

      final records = await uploaderWith(transport).uploadsFor('FY 2082/83');
      expect(records, hasLength(1));
      expect(records.single.remoteRevision, 1);
      expect(records.single.fiscalYearLabel, 'FY 2082/83');
    });

    test('a failed upload is not recorded as a success', () async {
      final transport = FakeTransport.sequence([
        FakeTransport.indexWith(revisions: const []),
        FakeTransport.refused(422, '{"reason":"no"}'),
      ]);

      await uploaderWith(transport).upload(backupOf(snapshot));

      expect(await uploaderWith(transport).uploadsFor('FY 2082/83'), isEmpty);
    });

    test('an unreachable server records nothing', () async {
      await uploaderWith(FakeTransport.offline()).upload(backupOf(snapshot));

      expect(
          await uploaderWith(FakeTransport.offline()).uploadsFor('FY 2082/83'),
          isEmpty);
    });

    test('records survive a new uploader, so a restart does not forget',
        () async {
      final transport = FakeTransport.sequence([
        FakeTransport.indexWith(revisions: const []),
        FakeTransport.stored(revision: 1),
      ]);
      await uploaderWith(transport).upload(backupOf(snapshot));

      // A fresh instance, as if the application had been restarted.
      final reopened = HttpBackupUploader(
        transport: transport,
        session: sessionFor(),
        uploadLogFile: logFile,
      );

      expect(await reopened.uploadsFor('FY 2082/83'), hasLength(1));
    });

    test('uploads are listed newest first and only for the asked year',
        () async {
      final log = <String, Object?>{
        'uploads': [
          {
            'fiscalYearLabel': 'FY 2081/82',
            'fileName': 'a.db',
            'uploadedAt': '2026-01-01T00:00:00.000',
            'remoteRevision': 1,
            'checksum': 'x',
          },
          {
            'fiscalYearLabel': 'FY 2082/83',
            'fileName': 'b.db',
            'uploadedAt': '2026-09-01T00:00:00.000',
            'remoteRevision': 1,
            'checksum': 'y',
          },
          {
            'fiscalYearLabel': 'FY 2082/83',
            'fileName': 'c.db',
            'uploadedAt': '2026-09-30T00:00:00.000',
            'remoteRevision': 2,
            'checksum': 'z',
          },
        ],
      };
      logFile.writeAsStringSync(jsonEncode(log));

      final records =
          await uploaderWith(FakeTransport.offline()).uploadsFor('FY 2082/83');

      expect(records.map((r) => r.fileName), ['c.db', 'b.db']);
    });
  });

  group('whether an upload is possible at all', () {
    test('is false with no session', () {
      final uploader = HttpBackupUploader(
        transport: FakeTransport.success(revision: 1),
        session: null,
        uploadLogFile: logFile,
      );
      expect(uploader.canUpload, isFalse);
      expect(uploader.session, isNull);
    });

    test('is false when the token is empty', () {
      expect(
          uploaderWith(
            FakeTransport.success(revision: 1),
            session: sessionFor(token: '   '),
          ).canUpload,
          isFalse);
    });

    test('is false when the book id is empty', () {
      expect(
          uploaderWith(
            FakeTransport.success(revision: 1),
            session: sessionFor(bookId: ''),
          ).canUpload,
          isFalse);
    });

    test('is true for a usable session', () {
      expect(
          uploaderWith(FakeTransport.success(revision: 1)).canUpload, isTrue);
    });

    test('refuses to attempt an upload with no session, rather than guessing',
        () async {
      final uploader = HttpBackupUploader(
        transport: FakeTransport.success(revision: 1),
        session: null,
        uploadLogFile: logFile,
      );

      expect(
        () => uploader.upload(backupOf(snapshot)),
        throwsA(isA<UploadException>()),
      );
    });
  });
}

/// The SHA-256 the uploader must declare, computed independently of the
/// implementation under test so the assertion is not circular.
String sha256Of(File file) => sha256.convert(file.readAsBytesSync()).toString();

/// The `revision` field the uploader actually put in the multipart body.
///
/// Read out of the request rather than taken from the response, because a fake
/// transport replies with whatever a test scripted. Asserting the echo would
/// test the fake instead of the uploader.
int declaredRevisionIn(String multipartBody) {
  final match =
      RegExp(r'name="revision"\r\n\r\n(\d+)\r\n').firstMatch(multipartBody);
  if (match == null) {
    fail('no revision field found in the multipart body:\n$multipartBody');
  }
  return int.parse(match.group(1)!);
}

/// A single named field's value, read out of the multipart body.
///
/// Asserting on the **request** rather than on a fake's echoed response is what
/// keeps these tests about the uploader. A fake replies with whatever a test
/// scripted, so comparing the echo would test the fake.
String declaredFieldIn(String multipartBody, String name) {
  final match =
      RegExp('name="$name"\r\n\r\n(.*?)\r\n').firstMatch(multipartBody);
  if (match == null) {
    fail('no "$name" field found in the multipart body:\n$multipartBody');
  }
  return match.group(1)!;
}

/// One request the uploader made, kept so a test can inspect it.
class TestRequest {
  TestRequest({
    required this.method,
    required this.url,
    required this.headers,
    required this.bodyParts,
  });

  final String method;
  final Uri url;
  final Map<String, String> headers;

  /// The body as the ordered segments the uploader produced. The file is one
  /// whole segment rather than being concatenated into a single buffer.
  final List<List<int>> bodyParts;

  /// The body as text. `latin1` so no byte is lost or re-encoded; multipart
  /// bodies are ASCII apart from the file content.
  String bodyAsText() => latin1
      .decode(bodyParts.expand((part) => part).toList(), allowInvalid: true);
}

/// A transport that answers from a script instead of a network.
///
/// The seam is the transport rather than the HTTP client, so the uploader's
/// URL building, header handling, multipart encoding, and status mapping are all
/// exercised for real, and only the socket is replaced.
class FakeTransport implements HttpTransport {
  FakeTransport._(this._script, {this.alwaysOffline = false});

  /// Answers any request with the next scripted response, in order.
  factory FakeTransport.sequence(List<TransportResponse> responses) =>
      FakeTransport._(List<TransportResponse>.of(responses));

  /// Answers an index lookup and then a successful store.
  factory FakeTransport.success({required int revision}) =>
      FakeTransport.sequence([
        FakeTransport.indexWith(revisions: const []),
        FakeTransport.stored(revision: revision),
      ]);

  /// Never connects, as if the machine were offline.
  factory FakeTransport.offline() =>
      FakeTransport._(const [], alwaysOffline: true);

  final List<TransportResponse> _script;
  final bool alwaysOffline;

  /// Every request made, in order.
  final List<TestRequest> requests = <TestRequest>[];

  TestRequest get lastRequest => requests.last;

  @override
  Future<TransportResponse> send({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    List<List<int>> body = const <List<int>>[],
  }) async {
    requests.add(
      TestRequest(
        method: method,
        url: url,
        headers: headers,
        bodyParts: body,
      ),
    );

    if (alwaysOffline) {
      throw const SocketException('No route to host (test)');
    }
    if (_script.isEmpty) {
      throw StateError('FakeTransport ran out of scripted responses');
    }
    return _script.removeAt(0);
  }

  /// A `200` listing what the server already holds.
  static TransportResponse indexWith({
    required List<int> revisions,
    String label = 'FY 2082/83',
  }) =>
      TransportResponse(
        statusCode: 200,
        body: jsonEncode(<String, Object?>{
          'data': <Object?>[
            for (final revision in revisions)
              <String, Object?>{
                'id': revision,
                'fiscal_year_label': label,
                'revision': revision,
                'checksum': 'x',
                'file_size': 2048,
                // The same constant the uploader declares, so a test cannot pass
                // by both sides hardcoding the same wrong number.
                'database_version': currentSchemaVersion,
                'archive_status': 'active',
              },
          ],
        }),
      );

  /// A `201` confirming the server stored a revision.
  static TransportResponse stored({required int revision}) => TransportResponse(
        statusCode: 201,
        body: jsonEncode(<String, Object?>{
          'message': 'The snapshot was verified and stored.',
          'revision': revision,
          'fiscal_year_label': 'FY 2082/83',
          'checksum': 'x',
          'file_size': 2048,
        }),
      );

  /// A refusal with an explicit status and body.
  static TransportResponse refused(int status, String body) =>
      TransportResponse(statusCode: status, body: body);
}
