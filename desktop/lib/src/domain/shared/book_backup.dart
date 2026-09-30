/// A verified snapshot of one fiscal year's books.
///
/// A backup is only a backup if it has been **proved** to be a valid database at
/// the moment it was taken. A file with a plausible name and size that cannot be
/// opened is worse than no backup at all, because it is trusted.
class BookBackup {
  const BookBackup({
    required this.fileName,
    required this.filePath,
    required this.fiscalYearLabel,
    required this.takenAt,
    required this.fileSizeBytes,
    required this.checksum,
  });

  /// The file's name, which doubles as its identity.
  final String fileName;

  final String filePath;

  /// The fiscal year this snapshot covers, for example `FY 2082/83`.
  final String fiscalYearLabel;

  final DateTime takenAt;

  final int fileSizeBytes;

  /// SHA-256 of the snapshot, in lower-case hex.
  ///
  /// Recorded so that later corruption or tampering is detectable. Two files with
  /// the same checksum are the same file for practical purposes.
  final String checksum;

  /// A human-readable size, for a screen that has to show it.
  String get readableSize {
    const kb = 1024;
    const mb = kb * 1024;
    if (fileSizeBytes >= mb) {
      return '${(fileSizeBytes / mb).toStringAsFixed(1)} MB';
    }
    if (fileSizeBytes >= kb) {
      return '${(fileSizeBytes / kb).toStringAsFixed(0)} KB';
    }
    return '$fileSizeBytes bytes';
  }

  @override
  String toString() => 'BookBackup($fileName, $readableSize)';
}

/// The result of checking a backup.
///
/// Separates "the bytes are unchanged" from "the file is a usable database",
/// because those are different failures and a user needs to know which happened.
class BackupVerification {
  const BackupVerification({
    required this.backup,
    required this.checksumMatches,
    required this.integrityPassed,
    this.detail,
  });

  final BookBackup backup;

  /// True when the file's checksum still equals the one recorded when it was
  /// taken.
  final bool checksumMatches;

  /// True when SQLite reports the file as a valid, undamaged database.
  final bool integrityPassed;

  /// What SQLite said, or why the check could not run.
  final String? detail;

  /// True when the backup can be trusted and restored.
  bool get isUsable => checksumMatches && integrityPassed;

  /// A message suitable for showing to a user.
  String get summary {
    if (isUsable) return 'This backup is intact and can be restored.';
    if (!checksumMatches) {
      return 'This backup has changed since it was taken and cannot be trusted. '
              '${detail ?? ''}'
          .trim();
    }
    return 'This backup is not a usable database. ${detail ?? ''}'.trim();
  }
}

/// Raised when a backup cannot be taken or cannot be trusted.
///
/// Deliberately fatal for the operation. A backup that silently did not happen is
/// the failure mode this whole feature exists to prevent.
class BackupException implements Exception {
  BackupException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'BackupException: $message'
      : 'BackupException: $message (cause: $cause)';
}
