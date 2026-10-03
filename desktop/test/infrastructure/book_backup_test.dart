import 'dart:io';

import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/shared/book_backup.dart';
import 'package:financeapp/src/domain/shared/book_year.dart';
import 'package:financeapp/src/domain/shared/currency.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/backup/file_book_backup_service.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Tests for backup across **every** fiscal year.
///
/// ADR 002 gives each fiscal year its own SQLite file. A business that has traded
/// for three years has three sets of books, and all three must be kept. So the
/// thing these tests care about most is not "does one snapshot verify" but **"are
/// all the years covered, and is an uncovered year reported rather than
/// skipped"**.
///
/// The test that proves the feature is the restore: a backup that has never been
/// restored has only been assumed to work.
void main() {
  late Directory booksDir;
  late Directory backupDir;

  setUp(() {
    booksDir = Directory.systemTemp.createTempSync('financeapp_books');
    backupDir = Directory(p.join(booksDir.path, 'backups'))..createSync();
  });

  tearDown(() {
    if (booksDir.existsSync()) booksDir.deleteSync(recursive: true);
  });

  Money rs(int majorUnits) => Money.minor(majorUnits * 100, bookCurrency);

  JournalEntry rentEntry(int majorUnits,
          {required DateTime date, String id = 'JE-1'}) =>
      JournalEntry(
        id: id,
        date: date,
        description: 'Office rent',
        lines: [
          JournalLine.debit(
            account: ChartOfAccounts.officeRent,
            amount: rs(majorUnits),
          ),
          JournalLine.credit(
            account: ChartOfAccounts.bank,
            amount: rs(majorUnits),
          ),
        ],
      );

  File booksFileFor(String label) => File(
        p.join(booksDir.path,
            'accounting-${label.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}.db'),
      );

  /// Creates a real fiscal-year database on disk, the way the application does.
  Future<void> createYear(
    String label, {
    required DateTime date,
    int rent = 500,
  }) async {
    final db = openFileDatabase(booksFileFor(label));
    await DriftAccountRepository(db).saveAll(const ChartOfAccounts().all);
    await DriftJournalRepository(db).append(rentEntry(rent, date: date));
    await db.close();
  }

  /// The current, writable year.
  Future<AppDatabase> openCurrentYear(String label) async {
    final db = openFileDatabase(booksFileFor(label));
    await DriftAccountRepository(db).saveAll(const ChartOfAccounts().all);
    await DriftJournalRepository(db).append(
      rentEntry(500, date: DateTime(2026, 9, 1)),
    );
    return db;
  }

  /// The SHA-256 of a file's bytes, matching how backups record theirs.
  Future<String> sha256Of(File file) async =>
      sha256.convert(await file.readAsBytes()).toString();

  /// Reads `PRAGMA user_version` with a **raw** connection.
  ///
  /// Raw rather than drift, because the whole point is to inspect the file without
  /// opening it in a way that might itself change it.
  Future<int> schemaVersionOf(File file) async {
    final db = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
    try {
      return db.select('PRAGMA user_version').first.values.first as int;
    } finally {
      db.dispose();
    }
  }

  /// Sets `PRAGMA user_version`, which is how a file is made to look like it was
  /// written by an older build.
  Future<void> setSchemaVersion(File file, int version) async {
    final db = sqlite.sqlite3.open(file.path);
    try {
      db.execute('PRAGMA user_version = $version');
    } finally {
      db.dispose();
    }
  }

  FileBookBackupService serviceFor(
    AppDatabase current, {
    String label = 'FY 2083/84',
  }) =>
      FileBookBackupService(
        currentDatabase: current,
        booksDirectory: booksDir,
        backupDirectory: backupDir,
        currentFiscalYearLabel: label,
      );

  Future<int> totalDebitsIn(AppDatabase db) async {
    final entries = await DriftJournalRepository(db).all();
    return entries.fold<int>(0, (sum, e) => sum + e.totalDebits.minorUnits);
  }

  group('Every fiscal year is backed up, not only the current one', () {
    test('a run covers all years found on disk', () async {
      // Three years of trading, which is three sets of books. Backing up only
      // the current one would leave two unprotected.
      await createYear('FY 2081/82', date: DateTime(2024, 9, 1), rent: 100);
      await createYear('FY 2082/83', date: DateTime(2025, 9, 1), rent: 200);
      final current = await openCurrentYear('FY 2083/84');
      addTearDown(current.close);

      final run = await serviceFor(current).takeBackup();

      expect(run.isComplete, isTrue, reason: 'no year should have failed');
      expect(run.yearCount, 3);
      expect(
        run.backups.map((b) => b.fiscalYearLabel).toSet(),
        {'FY 2081/82', 'FY 2082/83', 'FY 2083/84'},
        reason: 'the concluded years are the ones closest to the retention '
            'clock and must be covered',
      );
    });

    test('each year keeps its own figures', () async {
      await createYear('FY 2081/82', date: DateTime(2024, 9, 1), rent: 100);
      await createYear('FY 2082/83', date: DateTime(2025, 9, 1), rent: 200);
      final current = await openCurrentYear('FY 2083/84');
      addTearDown(current.close);

      final run = await serviceFor(current).takeBackup();
      final byYear = {for (final b in run.backups) b.fiscalYearLabel: b};

      for (final entry in <String, int>{
        'FY 2081/82': 100,
        'FY 2082/83': 200,
        'FY 2083/84': 500,
      }.entries) {
        final snapshot = openFileDatabase(File(byYear[entry.key]!.filePath));
        final debits = await totalDebitsIn(snapshot);
        await snapshot.close();
        expect(debits, rs(entry.value).minorUnits,
            reason: '${entry.key} snapshot holds the wrong figures');
      }
    });

    test('the years are discovered from the books folder', () async {
      await createYear('FY 2081/82', date: DateTime(2024, 9, 1));
      final current = await openCurrentYear('FY 2083/84');
      addTearDown(current.close);

      final years = await serviceFor(current).knownYears();

      expect(years.map((y) => y.fiscalYearLabel),
          containsAll(<String>['FY 2081/82', 'FY 2083/84']));
    });

    test('a file that is not a books file is ignored', () async {
      await File(p.join(booksDir.path, 'notes.txt')).writeAsString('not books');
      await File(p.join(booksDir.path, 'random.db')).writeAsString('not books');
      final current = await openCurrentYear('FY 2083/84');
      addTearDown(current.close);

      final years = await serviceFor(current).knownYears();

      expect(years, hasLength(1));
      expect(years.single.fiscalYearLabel, 'FY 2083/84');
    });

    test('a year that cannot be backed up is reported, not skipped', () async {
      // A closed year whose file is not a database at all. The run must say so
      // rather than quietly covering the other years and looking successful.
      await File(p.join(booksDir.path, 'accounting-FY-2081-82.db'))
          .writeAsString('this is not a database');
      final current = await openCurrentYear('FY 2083/84');
      addTearDown(current.close);

      final run = await serviceFor(current).takeBackup();

      expect(run.isComplete, isFalse);
      expect(run.failures, hasLength(1));
      expect(run.failures.single.fiscalYearLabel, 'FY 2081/82');
      expect(run.backups, hasLength(1),
          reason: 'the years that could be backed up still were');
    });

    test('no books at all is an empty run, not an error', () async {
      final current = await openCurrentYear('FY 2083/84');
      await current.close();
      booksFileFor('FY 2083/84').deleteSync();

      // A fresh service with an open in-memory database, and an empty folder.
      final inMemory = openInMemoryDatabase();
      addTearDown(inMemory.close);

      final run = await serviceFor(inMemory).takeBackup();

      expect(run.isEmpty, isTrue);
      expect(run.isComplete, isTrue);
    });
  });

  group('Taking a backup', () {
    test('produces a verified snapshot with a checksum', () async {
      final current = await openCurrentYear('FY 2083/84');
      addTearDown(current.close);

      final run = await serviceFor(current).takeBackup();
      final backup = run.backups.single;

      expect(backup.fileSizeBytes, greaterThan(0));
      expect(backup.checksum, hasLength(64));
      expect(backup.fiscalYearLabel, 'FY 2083/84');
      expect(File(backup.filePath).existsSync(), isTrue);
    });

    test('a snapshot is a usable database, not just a file', () async {
      final current = await openCurrentYear('FY 2083/84');
      addTearDown(current.close);
      final service = serviceFor(current);

      final backup = (await service.takeBackup()).backups.single;
      final verification = await service.verify(backup);

      expect(verification.checksumMatches, isTrue);
      expect(verification.integrityPassed, isTrue);
      expect(verification.isUsable, isTrue);
    });

    test('several runs accumulate and never overwrite', () async {
      final current = await openCurrentYear('FY 2083/84');
      addTearDown(current.close);
      final service = serviceFor(current);

      final first = (await service.takeBackup()).backups.single;
      // The timestamp has millisecond resolution; a collision suffix guards the
      // rest, but space them out so the test is about accumulation.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = (await service.takeBackup()).backups.single;

      expect(first.fileName, isNot(second.fileName));
      expect(File(first.filePath).existsSync(), isTrue,
          reason: 'a new backup must never destroy an older one');
      expect(await service.listBackups(), hasLength(2));
    });
  });

  group('Verifying a backup', () {
    test('a corrupted backup is detected and refused', () async {
      final current = await openCurrentYear('FY 2083/84');
      addTearDown(current.close);
      final service = serviceFor(current);

      final backup = (await service.takeBackup()).backups.single;
      final file = File(backup.filePath);
      final bytes = await file.readAsBytes();
      bytes[bytes.length ~/ 2] = bytes[bytes.length ~/ 2] ^ 0xFF;
      await file.writeAsBytes(bytes);

      final verification = await service.verify(backup);

      expect(verification.checksumMatches, isFalse);
      expect(verification.isUsable, isFalse);
      expect(verification.summary, contains('changed since it was taken'));
    });

    test('a missing backup is detected', () async {
      final current = await openCurrentYear('FY 2083/84');
      addTearDown(current.close);
      final service = serviceFor(current);

      final backup = (await service.takeBackup()).backups.single;
      File(backup.filePath).deleteSync();

      final verification = await service.verify(backup);

      expect(verification.isUsable, isFalse);
      expect(verification.detail, contains('missing'));
    });

    test('a file that is not a database is detected', () async {
      final current = await openCurrentYear('FY 2083/84');
      addTearDown(current.close);
      final service = serviceFor(current);

      final fake = File(
        p.join(backupDir.path, 'accounting-FY-2083-84-20260101120000000.db'),
      );
      await fake.writeAsString('named like a database, is not one');

      final listed = await service.listBackups();
      final verification = await service.verify(listed.single);

      expect(verification.integrityPassed, isFalse);
      expect(verification.isUsable, isFalse);
    });
  });

  group('Restoring a backup', () {
    test('brings the figures back', () async {
      // The test that proves the whole feature.
      var current = await openCurrentYear('FY 2083/84');
      final service = serviceFor(current);

      final backup = (await service.takeBackup()).backups.single;
      expect(await totalDebitsIn(current), rs(500).minorUnits);

      await DriftJournalRepository(current).append(
        rentEntry(150, date: DateTime(2026, 9, 2), id: 'JE-2'),
      );
      expect(await totalDebitsIn(current), rs(650).minorUnits);

      await service.restore(backup);
      current = service.reopen();
      addTearDown(current.close);

      expect(await totalDebitsIn(current), rs(500).minorUnits,
          reason: 'the restored books must hold the figures as at the backup');
    });

    test('takes an emergency backup of the current books first', () async {
      var current = await openCurrentYear('FY 2083/84');
      final service = serviceFor(current);
      final chosen = (await service.takeBackup()).backups.single;

      await DriftJournalRepository(current).append(
        rentEntry(150, date: DateTime(2026, 9, 2), id: 'JE-2'),
      );

      await service.restore(chosen);

      final all = await service.listBackups();
      expect(all.length, greaterThanOrEqualTo(2),
          reason: 'the books being replaced must be captured before they are '
              'overwritten, so the restore itself is reversible');

      // The newest is the emergency copy, holding the pre-restore figures.
      final emergencyDb = openFileDatabase(File(all.first.filePath));
      final emergencyDebits = await totalDebitsIn(emergencyDb);
      await emergencyDb.close();
      expect(emergencyDebits, rs(650).minorUnits);

      current = service.reopen();
      addTearDown(current.close);
      expect(await totalDebitsIn(current), rs(500).minorUnits);
    });

    test('refuses an unusable backup and touches nothing', () async {
      final current = await openCurrentYear('FY 2083/84');
      addTearDown(current.close);
      final service = serviceFor(current);

      final backup = (await service.takeBackup()).backups.single;
      final file = File(backup.filePath);
      final bytes = await file.readAsBytes();
      bytes[bytes.length ~/ 2] = bytes[bytes.length ~/ 2] ^ 0xFF;
      await file.writeAsBytes(bytes);

      await expectLater(
        service.restore(backup),
        throwsA(isA<BackupException>()),
      );

      expect(await totalDebitsIn(current), rs(500).minorUnits,
          reason: 'a refused restore must not have modified the books');
    });
  });

  group('A backup reports what it is', () {
    BookBackup sized(int bytes) => BookBackup(
          fileName: 'accounting-FY-2082-83-20260101120000000.db',
          filePath: '/backups/x.db',
          fiscalYearLabel: 'FY 2082/83',
          takenAt: DateTime(2026, 1, 1, 12),
          fileSizeBytes: bytes,
          checksum: 'a' * 64,
        );

    test('a readable size a person can understand', () {
      expect(sized(512).readableSize, '512 bytes');
      expect(sized(2048).readableSize, '2 KB');
      expect(sized(3 * 1024 * 1024).readableSize, '3.0 MB');
    });

    test('a run summarises its coverage', () {
      const complete = BackupRun(backups: [], failures: []);
      expect(complete.isEmpty, isTrue);
      expect(complete.isComplete, isTrue);

      const partial = BackupRun(
        backups: [],
        failures: [
          BackupFailure(fiscalYearLabel: 'FY 2081/82', reason: 'unreadable'),
        ],
      );
      expect(partial.isComplete, isFalse);
      expect(partial.failures.single.fiscalYearLabel, 'FY 2081/82');
    });
  });

  group('Verifying must not change what is verified', () {
    // ## The defect
    //
    // `PRAGMA integrity_check` is a read-only question, but it was asked through a
    // drift `AppDatabase`. Drift runs `onUpgrade` when a connection opens a file
    // whose `user_version` is behind, so **asking the question wrote tables**. Every
    // call to `verify()` therefore mutated the file it was checking, and taking a
    // backup migrated each concluded year's database in place — contradicting ADR
    // 002, which says a concluded year opens read-only and is never silently
    // modified.
    //
    // ## Why the existing tests could not see it
    //
    // After the mutation `user_version` is current, so drift does not migrate again
    // and nothing throws. A test asserting "the backup is a usable database"
    // therefore **passes on a file the check just modified**.

    test('verifying a backup leaves the file byte-for-byte identical',
        () async {
      await createYear('FY 2082/83', date: DateTime(2026, 3, 1));
      final current = await openCurrentYear('FY 2083/84');
      addTearDown(current.close);

      final service = serviceFor(current);
      final run = await service.takeBackup();
      expect(run.isComplete, isTrue, reason: 'the run must succeed first');

      final backup = run.backups.first;
      final file = File(backup.filePath);

      // **Bytes, not just a checksum of the logical content.** A migration adds
      // tables and bumps `user_version`, which changes the bytes even where the
      // accounting rows are identical.
      final before = file.readAsBytesSync();

      final verification = await service.verify(backup);

      expect(verification.integrityPassed, isTrue,
          reason: 'a snapshot we just took is intact');
      expect(
        file.readAsBytesSync(),
        before,
        reason: 'asking whether a file is damaged must not alter it',
      );
    });

    test('a concluded year at an older schema version is not migrated',
        () async {
      // **The reproduction that matters.** A snapshot written by an earlier build
      // has an older `user_version`. Backing it up used to open it through drift,
      // which migrates on open -- so taking a backup silently rewrote the archived
      // year, contradicting ADR 002 ("concluded years open read-only and are never
      // silently modified") and destroying the evidence of what that file actually
      // contained when it was archived.
      await createYear('FY 2081/82', date: DateTime(2026, 3, 1));
      await createYear('FY 2082/83', date: DateTime(2026, 3, 1));
      final current = await openCurrentYear('FY 2083/84');
      addTearDown(current.close);

      // Downgrade **before** the run, so the file really is an older snapshot.
      await setSchemaVersion(booksFileFor('FY 2081/82'), 1);

      final run = await serviceFor(current).takeBackup();
      expect(run.isComplete, isTrue);

      expect(
        await schemaVersionOf(booksFileFor('FY 2081/82')),
        1,
        reason:
            'backing up must not migrate an archived year: it is a historical '
            'record, not something the application may bring up to date',
      );
    });

    test('verifying an older snapshot succeeds and does not migrate it',
        () async {
      // The same condition, checked through `verify` rather than through a run.
      //
      // The checksum is recorded **after** the downgrade, so `verify` is comparing
      // like with like. Editing the file after it was recorded would make
      // `checksumMatches` false and the integrity check would never run -- a real
      // outcome, but not the one under test here.
      await createYear('FY 2082/83', date: DateTime(2026, 3, 1));
      final current = await openCurrentYear('FY 2083/84');
      addTearDown(current.close);

      final service = serviceFor(current);
      final backup = (await service.takeBackup()).backups.first;
      final file = File(backup.filePath);
      await setSchemaVersion(file, 1);

      // Re-record the checksum so the verification reaches the integrity check.
      final reRecorded = BookBackup(
        filePath: backup.filePath,
        fileName: backup.fileName,
        fiscalYearLabel: backup.fiscalYearLabel,
        fileSizeBytes: backup.fileSizeBytes,
        checksum: await sha256Of(file),
        takenAt: backup.takenAt,
      );

      final verification = await service.verify(reRecorded);

      expect(verification.checksumMatches, isTrue);
      expect(verification.integrityPassed, isTrue,
          reason:
              'an older snapshot is still a valid database; calling it damaged '
              'would prevent recovering a backup taken by an earlier build');
      expect(await schemaVersionOf(file), 1,
          reason: 'verifying must not migrate the file it checked');
    });

    test('verifying twice is idempotent', () async {
      // A check that mutates on the first call and not the second is the
      // signature of a hidden migration: the second call sees a current schema and
      // has nothing left to do.
      await createYear('FY 2082/83', date: DateTime(2026, 3, 1));
      final current = await openCurrentYear('FY 2083/84');
      addTearDown(current.close);

      final service = serviceFor(current);
      final backup = (await service.takeBackup()).backups.first;
      final file = File(backup.filePath);

      await service.verify(backup);
      final afterFirst = file.readAsBytesSync();
      await service.verify(backup);

      expect(file.readAsBytesSync(), afterFirst);
    });

    test('a concluded year is not migrated by taking a backup', () async {
      // The consequence that matters: a concluded year must be byte-identical after
      // a backup run, because it is the archived record of that year and ADR 002
      // forbids silently modifying it.
      await createYear('FY 2081/82', date: DateTime(2026, 3, 1));
      await createYear('FY 2082/83', date: DateTime(2026, 3, 1));
      final current = await openCurrentYear('FY 2083/84');
      addTearDown(current.close);

      final concluded = booksFileFor('FY 2081/82');
      final before = concluded.readAsBytesSync();

      final run = await serviceFor(current).takeBackup();
      expect(run.isComplete, isTrue);

      expect(concluded.readAsBytesSync(), before,
          reason: 'backing up must not touch the archived year at all');
    });
  });
}
