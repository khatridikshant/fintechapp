import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../../domain/shared/book_backup.dart';
import '../../domain/shared/book_backup_service.dart';
import '../../domain/shared/book_year.dart';
import '../database/app_database.dart';

/// Takes, verifies, and restores snapshots of **every** fiscal year's books.
///
/// ADR 002 gives each fiscal year its own SQLite file. A business that has traded
/// for three years has three sets of books, and all three must be kept. So a
/// backup run covers **every `accounting-FY-*.db` file in the books folder**, not
/// just the current one. A year that cannot be backed up is reported as a
/// failure rather than skipped, because a year silently missing from a run is the
/// exact problem this feature exists to prevent.
///
/// Two things here are load-bearing and easy to get wrong:
///
/// 1. **Each snapshot is produced by SQLite**, with `VACUUM INTO`, not by copying
///    the file. Copying a live database can capture it mid-write and produce a
///    file that is quietly corrupt: plausible size, plausible name, unusable.
/// 2. **Every snapshot is verified before it is accepted.** A checksum proves the
///    bytes have not changed; SQLite's own integrity check proves the file is a
///    database at all. A backup that is not proved is not reported as one.
class FileBookBackupService implements BookBackupService {
  FileBookBackupService({
    required this.currentDatabase,
    required this.booksDirectory,
    required this.backupDirectory,
    required this.currentFiscalYearLabel,
  });

  /// The open, writable books. Closed years are opened on demand instead.
  final AppDatabase currentDatabase;

  /// The folder holding one database file per fiscal year.
  final Directory booksDirectory;

  /// Where snapshots are kept. Never rotated: a backup is never overwritten.
  final Directory backupDirectory;

  /// The year [currentDatabase] holds, so it is not opened a second time.
  final String currentFiscalYearLabel;

  static const String _extension = '.db';

  /// Matches `accounting-FY-2082-83.db` and captures `FY-2082-83`.
  static final RegExp _booksFile = RegExp(r'^accounting-(FY-\d{4}-\d{2})\.db$');

  @override
  Future<List<BookYear>> knownYears() async {
    if (!await booksDirectory.exists()) return const [];

    final years = <BookYear>[];
    for (final entity in await booksDirectory.list().toList()) {
      if (entity is! File) continue;
      final match = _booksFile.firstMatch(p.basename(entity.path));
      if (match == null) continue;
      years.add(
        BookYear(
          fiscalYearLabel: _labelFrom(match.group(1)!),
          filePath: entity.path,
        ),
      );
    }

    // Newest year first, so a screen opens on the year in use.
    years.sort((a, b) => b.fiscalYearLabel.compareTo(a.fiscalYearLabel));
    return years;
  }

  @override
  Future<BackupRun> takeBackup() async {
    await backupDirectory.create(recursive: true);

    final years = await knownYears();
    final backups = <BookBackup>[];
    final failures = <BackupFailure>[];

    for (final year in years) {
      try {
        backups.add(await _backupOneYear(year));
      } catch (error) {
        // Reported, not skipped. A run that quietly omits a year would look
        // successful while leaving that year unprotected.
        failures.add(
          BackupFailure(
            fiscalYearLabel: year.fiscalYearLabel,
            reason: error is BackupException ? error.message : '$error',
          ),
        );
      }
    }

    return BackupRun(backups: backups, failures: failures);
  }

  /// Snapshots one fiscal year.
  ///
  /// The current year uses the connection already open; a closed year is opened
  /// read-only for the duration and closed again. Both go through the same
  /// snapshot and verification path, so a closed year is not treated as a lesser
  /// case.
  Future<BookBackup> _backupOneYear(BookYear year) async {
    final isCurrent = year.fiscalYearLabel == currentFiscalYearLabel;

    final target = _freeFileFor(year.fiscalYearLabel, DateTime.now());
    final staging = File('${target.path}.staging');

    AppDatabase? opened;
    try {
      if (await staging.exists()) await staging.delete();

      final source = isCurrent
          ? currentDatabase
          : opened = AppDatabase(NativeDatabase(File(year.filePath)));

      await source.customStatement("VACUUM INTO '${_escape(staging.path)}'");
    } catch (error) {
      if (await staging.exists()) await staging.delete();
      throw BackupException(
        'The snapshot of ${year.fiscalYearLabel} could not be taken.',
        cause: error,
      );
    } finally {
      await opened?.close();
    }

    // Prove it before filing it. A snapshot that is not a database is worse than
    // no snapshot, because it would be trusted.
    final verification = await _verifyFile(staging);
    if (!verification.isUsable) {
      if (await staging.exists()) await staging.delete();
      throw BackupException(
        'The snapshot of ${year.fiscalYearLabel} failed verification and was '
                'discarded. ${verification.detail ?? ''}'
            .trim(),
      );
    }

    await staging.rename(target.path);

    final stat = await target.stat();
    return BookBackup(
      fileName: p.basename(target.path),
      filePath: target.path,
      fiscalYearLabel: year.fiscalYearLabel,
      takenAt: DateTime.now(),
      fileSizeBytes: stat.size,
      checksum: await _checksumOf(target),
    );
  }

  @override
  Future<List<BookBackup>> listBackups() async {
    if (!await backupDirectory.exists()) return const [];

    final files = await backupDirectory
        .list()
        .where((entity) => entity is File && entity.path.endsWith(_extension))
        .cast<File>()
        .toList();

    final backups = <BookBackup>[];
    for (final file in files) {
      backups.add(await _describe(file));
    }

    // Newest first. Ordered by the timestamp in the name rather than by file
    // modification time, because a file's mtime can be changed by a copy and the
    // name cannot be wrong about when the snapshot was taken.
    backups.sort((a, b) => b.fileName.compareTo(a.fileName));
    return backups;
  }

  @override
  Future<BookBackup?> latestBackup() async {
    final backups = await listBackups();
    return backups.isEmpty ? null : backups.first;
  }

  @override
  Future<BackupVerification> verify(BookBackup backup) =>
      _verifyFile(File(backup.filePath), recordedChecksum: backup.checksum);

  @override
  Future<void> restore(BookBackup backup) async {
    // Verify first, so an unusable backup is refused before anything is touched.
    final verification = await verify(backup);
    if (!verification.isUsable) {
      throw BackupException(
        'This backup was not restored because it failed verification. '
        '${verification.summary}',
      );
    }

    // A restore replaces that fiscal year's own books file, which is NOT the
    // snapshot's file name. Using the snapshot name here would write a new file
    // beside the books and leave the real ones untouched.
    final target = File(
      p.join(booksDirectory.path, _booksFileNameFor(backup.fiscalYearLabel)),
    );
    final isCurrentYear = backup.fiscalYearLabel == currentFiscalYearLabel;

    // Capture what is about to be replaced. Choosing the wrong backup must not be
    // the end of the story.
    if (await target.exists()) {
      await takeBackup();
    }

    try {
      // Close the connection so the current file can be replaced.
      if (isCurrentYear) await currentDatabase.close();

      await File(backup.filePath).copy(target.path);

      // Confirm the restored file is usable before telling anyone it worked.
      final restored = await _verifyFile(target);
      if (!restored.isUsable) {
        throw BackupException(
          'The restored file failed verification. The emergency backup taken '
                  'just before restoring is intact and can be restored instead. '
                  '${restored.detail ?? ''}'
              .trim(),
        );
      }
    } catch (error) {
      if (error is BackupException) rethrow;
      throw BackupException('The restore did not complete.', cause: error);
    }
  }

  /// Re-opens the current books after a restore.
  ///
  /// Separate from [restore] so a caller decides when to come back up, and so a
  /// failed restore does not attempt it.
  AppDatabase reopen() => AppDatabase(
      NativeDatabase(File(p.join(booksDirectory.path, _currentFileName()))));

  String _currentFileName() => _booksFileNameFor(currentFiscalYearLabel);

  /// `FY 2082/83` becomes `accounting-FY-2082-83.db`.
  ///
  /// The inverse of [_labelFrom]. Restoring needs this: the file to replace is
  /// this year's books file, **not** the snapshot's own file name.
  String _booksFileNameFor(String fiscalYearLabel) =>
      'accounting-${fiscalYearLabel.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}'
      '$_extension';

  /// `FY-2082-83` becomes `FY 2082/83`.
  String _labelFrom(String fileToken) {
    final parts = fileToken.split('-');
    return 'FY ${parts[1]}/${parts[2]}';
  }

  /// A path that is not already taken.
  ///
  /// Uniqueness is **guaranteed rather than assumed**. A timestamp can repeat,
  /// and two backups in the same millisecond would otherwise collide. Refusing to
  /// overwrite is the right behaviour, because an old backup may be a record the
  /// law requires be kept, so the name gives way rather than the guard.
  File _freeFileFor(String fiscalYearLabel, DateTime takenAt) {
    final stamp = takenAt
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9]'), '')
        .padRight(17, '0')
        .substring(0, 17);
    final safeYear = fiscalYearLabel.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');
    final base = 'accounting-$safeYear-$stamp';

    var candidate = File(p.join(backupDirectory.path, '$base$_extension'));
    var suffix = 2;
    while (candidate.existsSync() && suffix < 1000) {
      candidate = File(
        p.join(backupDirectory.path, '$base-$suffix$_extension'),
      );
      suffix++;
    }
    return candidate;
  }

  Future<BookBackup> _describe(File file) async {
    final stat = await file.stat();
    final name = p.basename(file.path);
    // `accounting-FY-2082-83-20260930101032123.db` carries both the year and the
    // moment, so a listed backup can say which year it belongs to.
    final match =
        RegExp(r'^accounting-(FY-\d{4}-\d{2})-(\d+)').firstMatch(name);
    final label =
        match == null ? currentFiscalYearLabel : _labelFrom(match.group(1)!);

    return BookBackup(
      fileName: name,
      filePath: file.path,
      fiscalYearLabel: label,
      takenAt: stat.modified,
      fileSizeBytes: stat.size,
      checksum: await _checksumOf(file),
    );
  }

  Future<BackupVerification> _verifyFile(
    File file, {
    String? recordedChecksum,
  }) async {
    if (!await file.exists()) {
      return BackupVerification(
        backup: _placeholderFor(file),
        checksumMatches: false,
        integrityPassed: false,
        detail: 'The file is missing.',
      );
    }

    var checksumMatches = true;
    if (recordedChecksum != null) {
      checksumMatches = await _checksumOf(file) == recordedChecksum;
    }

    var integrityPassed = false;
    String? detail;
    if (checksumMatches) {
      try {
        integrityPassed = await _integrityCheck(file);
        if (!integrityPassed) {
          detail = 'SQLite reports the file as damaged.';
        }
      } catch (error) {
        detail = 'The file could not be opened as a database: $error';
      }
    } else {
      detail = 'Its contents have changed since it was taken.';
    }

    return BackupVerification(
      backup: _placeholderFor(file),
      checksumMatches: checksumMatches,
      integrityPassed: integrityPassed,
      detail: detail,
    );
  }

  /// Asks SQLite whether the file is a valid, undamaged database.
  ///
  /// Opens it with a real connection rather than trusting the header, because a
  /// truncated or half-written file can still begin with the SQLite magic bytes.
  Future<bool> _integrityCheck(File file) async {
    final probe = AppDatabase(NativeDatabase(file));
    try {
      final result =
          await probe.customSelect('PRAGMA integrity_check').getSingle();
      return result.data.values.first == 'ok';
    } finally {
      await probe.close();
    }
  }

  Future<String> _checksumOf(File file) async {
    final digest = sha256.convert(await file.readAsBytes());
    return digest.toString();
  }

  /// A backup stand-in for a file that could not be described.
  BookBackup _placeholderFor(File file) => BookBackup(
        fileName: p.basename(file.path),
        filePath: file.path,
        fiscalYearLabel: currentFiscalYearLabel,
        takenAt: DateTime.fromMillisecondsSinceEpoch(0),
        fileSizeBytes: 0,
        checksum: '',
      );

  /// Escapes a path for use inside a SQL string literal.
  static String _escape(String path) => path.replaceAll("'", "''");
}

/// The checksum of a byte sequence, so a caller can compare two backups.
String checksumOfBytes(List<int> bytes) => sha256.convert(bytes).toString();

/// The checksum of a string, for tests that need a deterministic value.
String checksumOfString(String value) =>
    sha256.convert(utf8.encode(value)).toString();
