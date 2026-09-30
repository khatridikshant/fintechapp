import 'book_backup.dart';

/// A fiscal year's books found in the books folder.
///
/// ADR 002 gives each fiscal year its own SQLite file, so a business that has
/// traded for three years has three files and must keep all of them. A backup
/// that covers only the current year leaves the older ones, which are the ones
/// closest to the retention clock, entirely unprotected.
class BookYear {
  const BookYear({required this.fiscalYearLabel, required this.filePath});

  /// For example `FY 2082/83`.
  final String fiscalYearLabel;

  final String filePath;

  /// The file name, without its folder.
  String get fileName => filePath.split(RegExp(r'[\\/]')).last;

  @override
  String toString() => 'BookYear($fiscalYearLabel)';
}

/// A fiscal year that could not be backed up, and why.
///
/// Reported rather than skipped. A year silently missing from a backup run is
/// the problem this whole feature exists to prevent.
class BackupFailure {
  const BackupFailure({required this.fiscalYearLabel, required this.reason});

  final String fiscalYearLabel;
  final String reason;

  @override
  String toString() => '$fiscalYearLabel: $reason';
}

/// The outcome of backing up every fiscal year that exists.
class BackupRun {
  const BackupRun({required this.backups, required this.failures});

  /// The snapshots that were taken and verified, newest year first.
  final List<BookBackup> backups;

  /// The years that could not be backed up. **Empty means every year was
  /// covered**; a run with any failure is not a successful backup.
  final List<BackupFailure> failures;

  /// True when every fiscal year on disk was backed up.
  bool get isComplete => failures.isEmpty;

  /// True when there was nothing to back up at all.
  bool get isEmpty => backups.isEmpty && failures.isEmpty;

  /// The number of distinct fiscal years covered.
  int get yearCount => backups.length;

  @override
  String toString() =>
      'BackupRun(${backups.length} year(s), ${failures.length} failure(s))';
}
