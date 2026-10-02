import 'dart:typed_data';

/// A snapshot fetched from the server, as bytes plus what the server claimed.
class DownloadedBackup {
  const DownloadedBackup({
    required this.bytes,
    required this.declaredChecksum,
    required this.fileSize,
  });

  final Uint8List bytes;

  /// The SHA-256 the server recorded when it stored the file, sent as a header.
  ///
  /// **The local hash of [bytes] is compared against this**, so a file that
  /// changed on the server after it was verified is caught before it is written
  /// anywhere.
  final String declaredChecksum;

  final int fileSize;

  /// What was received, so a truncated transfer is visible.
  int get actualSize => bytes.length;
}

/// Why a download did not happen.
enum DownloadRefusal {
  /// No usable answer: the server is down, or unreachable, or said no.
  /// **Nothing is written.**
  notAvailable,

  /// The server refused to send this revision.
  refused,

  /// The transfer arrived, but the bytes do not match what the server recorded.
  ///
  /// The single most important refusal: these bytes would become the books.
  checksumMismatch,

  /// Nothing came back, or less than the server promised.
  incomplete,

  /// The server's response could not be understood.
  unreadable,
}

/// Port for fetching a stored snapshot back.
///
/// The mirror image of the upload port, and subject to the same rule in reverse:
/// **a download is not a restore until it has been verified.** The
/// implementation lives in `infrastructure/`, because it deals with HTTP.
abstract interface class BackupDownloader {
  /// Whether the service can be reached at all.
  ///
  /// Checked before anything is written, so an offline machine leaves its books
  /// untouched rather than half-replaced.
  Future<bool> isAvailable();

  /// Fetches one revision, or explains why it could not.
  Future<DownloadAttempt> download({
    required int revision,
    required String fiscalYearLabel,
  });
}

/// The outcome of a download: the file, or a reason it did not arrive.
sealed class DownloadAttempt {
  const DownloadAttempt();
}

/// The snapshot arrived and still matches what the server recorded.
class DownloadSucceeded extends DownloadAttempt {
  const DownloadSucceeded(this.backup);

  final DownloadedBackup backup;
}

/// The snapshot did not arrive, and nothing was written.
class DownloadFailed extends DownloadAttempt {
  const DownloadFailed(this.reason, [this.detail]);

  final DownloadRefusal reason;

  /// The server's own explanation, where it gave one.
  final String? detail;

  String get message => switch (reason) {
        DownloadRefusal.notAvailable =>
          'The server could not be reached, so nothing was restored.',
        DownloadRefusal.refused =>
          'The server refused to send this snapshot. ${detail ?? ''}'.trim(),
        DownloadRefusal.checksumMismatch =>
          'What arrived does not match the checksum the server recorded, so it '
                  'was not used. ${detail ?? ''}'
              .trim(),
        DownloadRefusal.incomplete =>
          'What arrived was smaller than the server said, so it was not used.',
        DownloadRefusal.unreadable =>
          'The server sent something this application could not read.',
      };
}
