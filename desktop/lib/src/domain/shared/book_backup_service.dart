import 'book_backup.dart';
import 'book_year.dart';

/// What a caller may ask about backups without being able to restore one.
///
/// A narrow interface, deliberately. Restoring replaces the books, which is
/// destructive enough to deserve its own considered flow rather than a button on
/// a list. A screen is given this; it never sees [BookBackupService.restore].
///
/// **Every operation here spans every fiscal year on disk**, not just the current
/// one. ADR 002 gives each year its own file, so a business with three years of
/// trading has three sets of books, and each one must be kept. A backup that
/// covered only the current year would leave the older ones, which are closest to
/// the retention clock, unprotected while still appearing to be a safety net.
abstract interface class BackupActions {
  /// The fiscal years present in the books folder, newest first.
  ///
  /// Used so a screen can show which years exist and, crucially, which of them
  /// have **no** backup.
  Future<List<BookYear>> knownYears();

  /// Backs up every fiscal year that exists.
  ///
  /// Returns a [BackupRun] listing what was covered and what was not. A year that
  /// cannot be backed up is reported as a failure, never skipped silently.
  Future<BackupRun> takeBackup();

  /// Every backup that exists, newest first.
  Future<List<BookBackup>> listBackups();

  /// Re-checks a backup's checksum and asks SQLite whether it is a valid
  /// database.
  Future<BackupVerification> verify(BookBackup backup);
}

/// Port for taking, listing, verifying, and restoring backups of the books.
///
/// This is an interface owned by the domain. The implementation lives in
/// `infrastructure/`, because it deals with files and checksums.
///
/// **Why this is not optional plumbing.** Nepali law requires a business to keep
/// its books for years. A single file on one computer is therefore a compliance
/// risk, not merely a data risk. See `docs/BACKUP_AND_RETENTION.md`.
abstract interface class BookBackupService implements BackupActions {
  /// The most recent backup of any year, or null when there is none.
  Future<BookBackup?> latestBackup();

  /// Replaces the current books with [backup].
  ///
  /// Verifies the backup **first** and takes an emergency copy of the current
  /// books before replacing them, so a wrong choice is recoverable. Throws
  /// [BackupException] rather than touching anything if the backup is unusable.
  Future<void> restore(BookBackup backup);
}
