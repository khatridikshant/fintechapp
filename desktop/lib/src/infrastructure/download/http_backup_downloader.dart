import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;

import '../../domain/shared/backup_download.dart';

import '../../domain/shared/book_upload.dart';
import '../http/http_transport.dart';

/// Fetches a stored snapshot from the server.
///
/// ## The checksum the server sent is the one that matters
///
/// The bytes are hashed locally and compared with the checksum in
/// `X-Backup-Checksum`. That is the same discipline the upload applies in reverse,
/// and it is what makes a restore trustworthy: a file that changed on the server
/// after it was verified is refused rather than becoming the books.
class HttpBackupDownloader implements BackupDownloader {
  HttpBackupDownloader({required this.transport, required this.session});

  final HttpTransport transport;
  final BackendSession session;

  @override
  Future<bool> isAvailable() async {
    try {
      // Any answer, even a refusal, means the service is reachable.
      await transport.send(
        method: 'GET',
        url: _revisionsUrl,
        headers: _headers,
      );
      return true;
    } catch (error) {
      return false;
    }
  }

  @override
  Future<DownloadAttempt> download({
    required int revision,
    required String fiscalYearLabel,
  }) async {
    final TransportResponse response;
    try {
      response = await transport.send(
        method: 'GET',
        url: _api('/api/backup-revisions/$revision/download'),
        headers: _headers,
      );
    } catch (error) {
      return const DownloadFailed(DownloadRefusal.notAvailable);
    }

    if (response.statusCode == 404 || response.statusCode == 410) {
      return DownloadFailed(
        DownloadRefusal.refused,
        'The server no longer holds that revision.',
      );
    }
    if (response.statusCode != 200) {
      return DownloadFailed(
        DownloadRefusal.refused,
        'The server answered ${response.statusCode}.',
      );
    }

    final bytes = response.binaryBody;
    if (bytes == null) {
      return const DownloadFailed(DownloadRefusal.unreadable);
    }

    // The declared length and size, so a truncated transfer is visible rather
    // than restored.
    if (bytes.isEmpty) {
      return const DownloadFailed(DownloadRefusal.incomplete);
    }

    final declared = _checksumOf(response.headers['x-backup-checksum']);
    if (declared == null) {
      return const DownloadFailed(
        DownloadRefusal.unreadable,
      );
    }

    final actual = _sha256Hex(bytes);
    if (actual != declared) {
      return DownloadFailed(
        DownloadRefusal.checksumMismatch,
        'The server recorded $declared but sent a file that hashes to $actual.',
      );
    }

    return DownloadSucceeded(
      DownloadedBackup(
        bytes: bytes,
        declaredChecksum: declared,
        fileSize: bytes.length,
      ),
    );
  }

  Map<String, String> get _headers => <String, String>{
        'Authorization': 'Bearer ${session.token}',
        'Accept': 'application/octet-stream',
      };

  Uri get _revisionsUrl =>
      _api('/api/books/${session.bookId}/backup-revisions');

  Uri _api(String path) => Uri.parse(
        '${session.serverBaseUrl.toString().replaceAll(RegExp(r'/+$'), '')}$path',
      );

  static String? _checksumOf(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return RegExp(r'^[0-9a-f]{64}$').hasMatch(trimmed) ? trimmed : null;
  }

  /// SHA-256 of the received bytes, in the same lower-case hex the server uses.
  static String _sha256Hex(Uint8List bytes) => sha256.convert(bytes).toString();
}
