import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/shared/book_backup.dart';
import 'package:financeapp/src/domain/shared/book_year.dart';
import 'package:financeapp/src/infrastructure/backup/file_book_backup_service.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/business_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/open_business_database.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Opens a snapshot file as a business database, for checking its contents.
BusinessDatabase _asBusiness(File file) => BusinessDatabase(openExecutor(file));

/// The business details must be covered by a backup run.
///
/// **They are not a fiscal year, but losing them is just as serious:** a restored
/// machine with no business name or PAN cannot produce a valid tax bill, because
/// an invoice without the seller's PAN is not a valid tax bill.
///
/// Two things could go wrong and both are checked here: the file being *skipped*
/// by the sweep, and -- far worse -- being *opened with the wrong schema*, which
/// would run the year migrations against it and corrupt it.
void main() {
  late Directory booksDir;
  late Directory backupDir;
  late AppDatabase current;
  late FileBookBackupService service;

  const label = 'FY 2082/83';
  const olderLabel = 'FY 2081/82';

  /// The on-disk name for a fiscal year, the way the application writes it: the
  /// label with its separators flattened. Using the label raw would put a space
  /// and a slash into the path.
  File booksFileFor(String yearLabel) => File(
        p.join(
          booksDir.path,
          'accounting-${yearLabel.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}.db',
        ),
      );

  setUp(() async {
    booksDir = Directory.systemTemp.createTempSync('biz_books');
    backupDir = Directory(p.join(booksDir.path, 'backups'))..createSync();

    // Two year files. Both must be **real** databases: a file of junk bytes would
    // fail its integrity check and make the run incomplete, which would mask the
    // thing under test.
    final closed = openFileDatabase(booksFileFor(olderLabel));
    await DriftAccountRepository(closed).saveAll(const ChartOfAccounts().all);
    await closed.close();

    current = openFileDatabase(booksFileFor(label));
    // Drift creates the file on the first real table write, and the sweep reads
    // the folder, so it has to exist before the sweep runs.
    await DriftAccountRepository(current).saveAll(const ChartOfAccounts().all);

    service = FileBookBackupService(
      currentDatabase: current,
      booksDirectory: booksDir,
      backupDirectory: backupDir,
      currentFiscalYearLabel: label,
    );
  });

  tearDown(() async {
    await current.close();
    booksDir.deleteSync(recursive: true);
  });

  /// A real business database with a profile in it.
  Future<File> writeBusinessDetails() async {
    final db = openBusinessDatabase(booksDir);
    await db.into(db.businessProfiles).insert(
          BusinessProfilesCompanion.insert(
            id: 'primary',
            name: 'Sharma Electronics Pvt. Ltd.',
            pan: const Value('301234567'),
            isVatRegistered: const Value(true),
          ),
        );
    await db.close();
    return File(p.join(booksDir.path, businessDatabaseName));
  }

  BookBackup businessSnapshotOf(BackupRun run) => run.backups.firstWhere(
        (BookBackup b) => b.fiscalYearLabel == BookYear.businessDetailsLabel,
      );

  group('the sweep finds it', () {
    test('business details appear alongside the years, not as one', () async {
      await writeBusinessDetails();

      final years = await service.knownYears();

      expect(
        years.map((BookYear y) => y.fiscalYearLabel),
        containsAll(<String>[
          label,
          olderLabel,
          BookYear.businessDetailsLabel,
        ]),
      );
      expect(years.where((BookYear y) => y.isBusinessDetails), hasLength(1));
    });

    test('they are not sorted among the years', () async {
      // The screen opens on the year in use. A list sorted with "Business details"
      // among fiscal-year labels would be nonsense, because it has no year.
      await writeBusinessDetails();

      final years = await service.knownYears();

      expect(years.first.fiscalYearLabel, label,
          reason: 'the year in use must still open first');
      expect(years.last.fiscalYearLabel, BookYear.businessDetailsLabel);
    });

    test('a books folder with no business database is unaffected', () async {
      // The file is created on first use, so it is often absent.
      final years = await service.knownYears();
      expect(years.where((BookYear y) => y.isBusinessDetails), isEmpty);
    });
  });

  group('a run covers it', () {
    test('the snapshot is taken, verified, and listed', () async {
      await writeBusinessDetails();

      final run = await service.takeBackup();

      expect(run.isComplete, isTrue,
          reason: 'a run that skipped the business details is not complete');
      final snapshot = businessSnapshotOf(run);

      expect(snapshot.fileName, startsWith('business-'));
      // Verified, not merely written. An unverified snapshot would be trusted.
      expect((await service.verify(snapshot)).isUsable, isTrue);
      expect(
        await service.listBackups(),
        contains(predicate<BookBackup>(
          (BookBackup b) => b.fiscalYearLabel == BookYear.businessDetailsLabel,
        )),
      );
    });

    test('the snapshot is readable and still says who the business is',
        () async {
      await writeBusinessDetails();

      final snapshot = businessSnapshotOf(await service.takeBackup());

      // Open it the way the application would, and check the data survived.
      final restored = _asBusiness(File(snapshot.filePath));
      final row = await restored.select(restored.businessProfiles).getSingle();
      expect(row.name, 'Sharma Electronics Pvt. Ltd.');
      expect(row.pan, '301234567');
      expect(row.isVatRegistered, isTrue);
      await restored.close();
    });

    test('taking the snapshot does not migrate or alter the business file',
        () async {
      // **The dangerous case.** Opening `business.db` as an `AppDatabase` would
      // run the year migrations against it -- version 1 where the app expects 11
      // -- writing year tables into the business file. The test above catches it:
      // if the schema had been migrated, the snapshot would no longer open as a
      // business database with one profile row.
      await writeBusinessDetails();

      await service.takeBackup();

      // Still readable as business data, and still exactly one row.
      final after = openBusinessDatabase(booksDir);
      expect(await after.select(after.businessProfiles).get(), hasLength(1));
      await after.close();
    });
  });

  group('restoring', () {
    test('puts the business details back where they belong', () async {
      await writeBusinessDetails();
      final snapshot = businessSnapshotOf(await service.takeBackup());

      // Lose them.
      File(p.join(booksDir.path, businessDatabaseName)).deleteSync();

      await service.restore(snapshot);

      // Restored under the real name, not the snapshot's.
      final restored = openBusinessDatabase(booksDir);
      final row = await restored.select(restored.businessProfiles).getSingle();
      expect(row.name, 'Sharma Electronics Pvt. Ltd.');
      expect(row.pan, '301234567');
      await restored.close();
    });

    test('does not overwrite a year when a business snapshot is restored',
        () async {
      await writeBusinessDetails();
      final snapshot = businessSnapshotOf(await service.takeBackup());

      final yearFile = booksFileFor(label);
      final yearBefore = yearFile.readAsBytesSync();

      await service.restore(snapshot);

      expect(yearFile.readAsBytesSync(), yearBefore,
          reason: 'restoring business details must not touch the books');
    });
  });
}
