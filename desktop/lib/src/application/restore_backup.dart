import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/shared/backup_download.dart';
import '../domain/shared/book_backup.dart';
import '../domain/shared/book_backup_service.dart';

/// Restores a snapshot fetched from the server, putting a fiscal year's books back.
///
/// ## Why the download is verified twice, and why it matters
///
/// The checksum is checked when the bytes arrive, and then **again through the
/// ordinary [BackupActions.verify]**, which runs `PRAGMA integrity_check` on a real
/// SQLite connection. The first check proves the bytes are what the server recorded;
/// the second proves they are a usable database. Either alone would let something
/// through: a matching checksum on a corrupt file, or a valid database the server
/// never verified.
///
/// **A restore overwrites the live books**, so this is the one operation in the
/// application where untrusted bytes would become accounting data. Nothing is
/// written to the books directory until both checks have passed.
class RestoreBackup {
  RestoreBackup({
    required this.backups,
    required this.downloads,
    required this.booksDirectory,
  });

  /// The ordinary backup service, reused for its verification and its recovery
  /// copy. Restoring through a second path would mean a second set of guarantees.
  ///
  /// [BookBackupService] rather than [BackupActions], because only the service
  /// offers `restore` -- and reusing *its* restore is the point, so the recovery
  /// copy and the re-verification are exactly the ones an ordinary restore does.
  final BookBackupService backups;

  final BackupDownloader downloads;

  final Directory booksDirectory;

  Future<RestoreOutcome> call({
    required int remoteRevision,
    required String fiscalYearLabel,
  }) async {
    // Checked first, so an offline machine never starts a restore it cannot finish.
    if (!await downloads.isAvailable()) {
      return const RestoreRefused(
        'The server could not be reached, so nothing was restored.',
      );
    }

    final attempt = await downloads.download(
      revision: remoteRevision,
      fiscalYearLabel: fiscalYearLabel,
    );

    final failure = switch (attempt) {
      DownloadFailed(:final message) => message,
      DownloadSucceeded() => null,
    };
    if (failure != null) return RestoreRefused(failure);

    final downloaded = (attempt as DownloadSucceeded).backup;

    // **Staged outside the books folder**, so a failure mid-verification cannot
    // leave a partial file where a year database belongs.
    //
    // The label is slugged because it contains a slash: `FY 2082/83` would
    // otherwise name a *directory*, and a label with a path separator in it could
    // reach outside the books folder entirely.
    final safeLabel = fiscalYearLabel.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');
    final staging = File(
      p.join(booksDirectory.path, 'restore-$safeLabel-$remoteRevision.db'),
    );
    await staging.writeAsBytes(downloaded.bytes, flush: true);

    try {
      final verification = await backups.verify(
        BookBackup(
          fileName: p.basename(staging.path),
          filePath: staging.path,
          fiscalYearLabel: fiscalYearLabel,
          takenAt: DateTime.now(),
          fileSizeBytes: downloaded.actualSize,
          checksum: downloaded.declaredChecksum,
        ),
      );

      if (!verification.isUsable) {
        return RestoreRefused(
          'The downloaded file is not a usable database, so nothing was '
          'restored. ${verification.summary}',
        );
      }

      // Only now is the books folder touched. From here the ordinary backup
      // service takes over: it verifies again, keeps a recovery copy of what it
      // is about to replace, and writes the file.
      await backups.restore(
        BookBackup(
          fileName: p.basename(staging.path),
          filePath: staging.path,
          fiscalYearLabel: fiscalYearLabel,
          takenAt: DateTime.now(),
          fileSizeBytes: downloaded.actualSize,
          checksum: downloaded.declaredChecksum,
        ),
      );

      return RestoreCompleted(fiscalYearLabel, remoteRevision);
    } finally {
      // The staged copy is not needed once the books hold the file, and leaving
      // stray databases beside the years would let them be discovered as one.
      if (await staging.exists()) await staging.delete();
    }
  }
}

/// The outcome of restoring a snapshot.
sealed class RestoreOutcome {
  const RestoreOutcome();
}

/// The books were replaced.
class RestoreCompleted extends RestoreOutcome {
  const RestoreCompleted(this.fiscalYearLabel, this.remoteRevision);

  final String fiscalYearLabel;
  final int remoteRevision;
}

/// Nothing was restored, and the books are untouched.
class RestoreRefused extends RestoreOutcome {
  const RestoreRefused(this.reason);

  /// A sentence to show the user.
  final String reason;
}
