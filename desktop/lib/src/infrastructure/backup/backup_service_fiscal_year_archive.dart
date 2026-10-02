import 'dart:io';

import '../../application/conclude_fiscal_year.dart';
import '../../domain/fiscal/fiscal_year.dart';
import '../../domain/shared/book_backup.dart';
import '../../domain/shared/book_backup_service.dart';
import '../../domain/shared/book_upload.dart';
import '../../domain/shared/book_upload_service.dart';

/// Archives a closed fiscal year by **snapshotting it and uploading the
/// snapshot**, reusing the backup and upload services rather than a second copy of
/// either.
///
/// ## Why it goes through those services
///
/// The upload path already does the three things an archive must not skip:
///
/// - `VACUUM INTO` to produce a self-consistent copy while the books are open;
/// - verifies the snapshot before filing it, so a corrupt archive is never stored;
/// - **verifies the server's copy** and refuses anything but a confirmed store.
///
/// Duplicating that would give the archive weaker guarantees than the ordinary
/// backup, which is the opposite of what an archive is for. Reusing it means a
/// year is archived exactly as well as any other backup.
class BackupServiceFiscalYearArchive implements FiscalYearArchive {
  BackupServiceFiscalYearArchive({
    required this.backups,
    required this.uploads,
    FiscalYearConcluder? concluder,
  }) : _concluder = concluder;

  final BackupActions backups;
  final UploadActions uploads;

  /// Tells the server to keep only one snapshot of a concluded year.
  ///
  /// Optional, and **defaults to reporting the server as unreachable**. A caller
  /// that supplies none gets a close that still works and reports that the
  /// duplicates were not dropped, rather than an error.
  final FiscalYearConcluder? _concluder;

  @override
  Future<ConcludeOutcome> conclude(FiscalYear fiscalYear) async =>
      _concluder?.conclude(fiscalYear) ??
      // **Not an exception.** Without a concluder the close has still happened
      // and the archive is still safe; only the housekeeping was skipped.
      Future<ConcludeOutcome>.value(ConcludeOutcome.unreachable);

  @override
  Future<bool> isAvailable() async => uploads.canUpload;

  @override
  Future<void> archive(FiscalYear fiscalYear, File databaseFile) async {
    if (!uploads.canUpload) {
      throw StateError('No signed-in session, so the year cannot be archived.');
    }

    // The snapshot of the year's books. `takeBackup` covers every year and
    // verifies each, which is why it is preferred over vacuuming here: a second
    // snapshot path would be a second set of guarantees to keep in step.
    final run = await backups.takeBackup();

    if (!run.isComplete) {
      final failed = run.failures.map((Object f) => '$f').join('; ');
      throw StateError('The year could not be snapshotted: $failed');
    }

    // The one snapshot belonging to the year being closed.
    final BookBackup? snapshot = run.backups
        .where((BookBackup b) => b.fiscalYearLabel == fiscalYear.label)
        .cast<BookBackup?>()
        .firstWhere((BookBackup? b) => b != null, orElse: () => null);

    if (snapshot == null) {
      throw StateError(
        'No snapshot of ${fiscalYear.label} was taken, so it was not archived.',
      );
    }

    final result = await uploads.upload(snapshot);

    // Only a confirmed store counts. Every other outcome throws, which leaves
    // the current year open -- the behaviour the specification requires.
    switch (result.status) {
      case UploadStatus.uploaded:
        return;
      case UploadStatus.rejected:
        throw StateError('The server refused the archive: ${result.message}');
      case UploadStatus.unverified:
        throw StateError('The archive was not stored: ${result.message}');
      case UploadStatus.conflict:
        throw StateError(
            'A newer archive of this year exists: ${result.message}');
      case UploadStatus.unauthenticated:
        throw StateError(
          'The session expired while archiving, so nothing was stored. '
          'Sign in again and retry. ${result.message}',
        );
      case UploadStatus.unreachable:
        throw StateError(
          'The archive could not be stored, so the year was not closed. '
          '${result.message}',
        );
    }
  }
}
