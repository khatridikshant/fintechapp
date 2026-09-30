import 'dart:io';

import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/shared/currency.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/file_books_session.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Tests for opening a concluded fiscal year.
///
/// The specification is explicit and repeats it three times: historical years
/// **open read-only** and are never silently modified. Section 21, section 26,
/// the restore rules, and the acceptance test list all say so.
///
/// So these tests are not about whether a screen offers a save button. They are
/// about whether the **database itself refuses a write**, because a rule that
/// lives only in the UI is one that any future caller can walk past.
void main() {
  late Directory booksDir;

  setUp(() {
    booksDir = Directory.systemTemp.createTempSync('financeapp_session');
  });

  tearDown(() {
    if (booksDir.existsSync()) booksDir.deleteSync(recursive: true);
  });

  final calendar = const NepaliFiscalCalendar();

  Money rs(int majorUnits) => Money.minor(majorUnits * 100, bookCurrency);

  /// A rent entry dated inside [label]'s fiscal year.
  JournalEntry rentEntry(String label, int majorUnits, {String id = 'JE-1'}) {
    final startYear = int.parse(RegExp(r'\d{4}').firstMatch(label)!.group(0)!);
    final year = calendar.forBsYear(startYear);
    return JournalEntry(
      id: id,
      date: year.startDate.add(const Duration(days: 30)),
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
  }

  File fileFor(String label) => File(
        p.join(
          booksDir.path,
          'accounting-${label.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}.db',
        ),
      );

  /// Creates a fiscal year's books with one posting in it.
  ///
  /// The chart is seeded first: a journal line references an account by foreign
  /// key, so an accountless database cannot hold a posting at all.
  Future<void> createYear(String label, int rent) async {
    final db = openFileDatabase(fileFor(label));
    await DriftAccountRepository(db).saveAll(const ChartOfAccounts().all);
    await DriftJournalRepository(db).append(rentEntry(label, rent));
    await db.close();
  }

  Future<int> debitsIn(String label) async {
    final db = openFileDatabase(fileFor(label));
    final entries = await DriftJournalRepository(db).all();
    final total =
        entries.fold<int>(0, (sum, e) => sum + e.totalDebits.minorUnits);
    await db.close();
    return total;
  }

  group('Every fiscal year is found', () {
    test('the session lists all the years in the folder', () async {
      await createYear('FY 2081/82', 100);
      await createYear('FY 2082/83', 200);

      final session = await FileBooksSession.openOn(
        booksDirectory: booksDir,
        startYear: calendar.forBsYear(2083),
      );
      addTearDown(session.close);

      expect(
        session.years.map((y) => y.fiscalYear.label).toSet(),
        {'FY 2081/82', 'FY 2082/83', 'FY 2083/84'},
        reason: 'the trading year is created if it does not exist yet',
      );
    });

    test('the trading year is writable and concluded years are not', () async {
      await createYear('FY 2082/83', 200);

      final session = await FileBooksSession.openOn(
        booksDirectory: booksDir,
        startYear: calendar.forBsYear(2083),
      );
      addTearDown(session.close);

      final byLabel = {for (final y in session.years) y.fiscalYear.label: y};

      expect(byLabel['FY 2083/84']!.isReadOnly, isFalse,
          reason: 'the year being traded in must be writable');
      expect(byLabel['FY 2082/83']!.isReadOnly, isTrue,
          reason: 'a concluded year must be read-only');
    });
  });

  group('A concluded year is opened read-only', () {
    test('the database refuses a write', () async {
      // The requirement, enforced at the database rather than in a screen.
      await createYear('FY 2082/83', 200);

      final session = await FileBooksSession.openOn(
        booksDirectory: booksDir,
        startYear: calendar.forBsYear(2083),
      );
      addTearDown(session.close);

      await session.open(calendar.forBsYear(2082));
      expect(session.openYear.isReadOnly, isTrue);

      // A direct write must fail. If this succeeds, "read-only" is a lie.
      await expectLater(
        session.database.customStatement(
          'INSERT INTO journal_entries (id, date, description, currency) '
          'VALUES (?, ?, ?, ?)',
          ['JE-INTRUDER', 1, 'should not be written', bookCurrency],
        ),
        throwsA(anything),
      );
    });

    test('the concluded year still reads', () async {
      await createYear('FY 2082/83', 200);

      final session = await FileBooksSession.openOn(
        booksDirectory: booksDir,
        startYear: calendar.forBsYear(2083),
      );
      addTearDown(session.close);

      await session.open(calendar.forBsYear(2082));

      // Read-only must not mean unreadable. The whole point of opening a
      // concluded year is to look at it.
      final entries = await DriftJournalRepository(session.database).all();
      expect(entries, hasLength(1));
      expect(
        entries.single.totalDebits.minorUnits,
        rs(200).minorUnits,
      );
    });

    test('writing nothing leaves the concluded year untouched on disk',
        () async {
      await createYear('FY 2082/83', 200);
      final before = await debitsIn('FY 2082/83');

      final session = await FileBooksSession.openOn(
        booksDirectory: booksDir,
        startYear: calendar.forBsYear(2083),
      );
      addTearDown(session.close);

      await session.open(calendar.forBsYear(2082));
      try {
        await session.database.customStatement(
          'INSERT INTO journal_entries (id, date, description, currency) '
          'VALUES (?, ?, ?, ?)',
          ['JE-INTRUDER', 1, 'nope', bookCurrency],
        );
      } catch (_) {
        // Expected. What matters is what is on disk afterwards.
      }

      expect(await debitsIn('FY 2082/83'), before,
          reason: 'a refused write must leave the file exactly as it was');
    });

    test('the trading year is not read-only', () async {
      // The guard must not be so broad that it stops the business trading.
      final session = await FileBooksSession.openOn(
        booksDirectory: booksDir,
        startYear: calendar.forBsYear(2083),
      );
      addTearDown(session.close);

      expect(session.openYear.isReadOnly, isFalse);

      await DriftJournalRepository(session.database).append(
        rentEntry('FY 2083/84', 500, id: 'JE-OK'),
      );

      final entries = await DriftJournalRepository(session.database).all();
      expect(entries, hasLength(1));
    });
  });

  group('Switching year', () {
    test('changes which books the use cases read', () async {
      await createYear('FY 2082/83', 200);

      final session = await FileBooksSession.openOn(
        booksDirectory: booksDir,
        startYear: calendar.forBsYear(2083),
      );
      addTearDown(session.close);

      await DriftJournalRepository(session.database).append(
        rentEntry('FY 2083/84', 500, id: 'JE-NOW'),
      );

      // The trading year.
      var report = await session.trialBalance.load();
      expect(report.fiscalYear.label, 'FY 2083/84');
      expect(report.trialBalance.totalDebits.minorUnits, rs(500).minorUnits);

      // The concluded year, through the same session.
      await session.open(calendar.forBsYear(2082));
      report = await session.trialBalance.load();
      expect(report.fiscalYear.label, 'FY 2082/83');
      expect(report.trialBalance.totalDebits.minorUnits, rs(200).minorUnits);
    });

    test('switching back to the same year does nothing', () async {
      final session = await FileBooksSession.openOn(
        booksDirectory: booksDir,
        startYear: calendar.forBsYear(2083),
      );
      addTearDown(session.close);

      final before = session.database;
      await session.open(calendar.forBsYear(2083));

      expect(identical(session.database, before), isTrue,
          reason: 're-selecting the open year must not reopen it');
    });

    test('a year with no books is refused', () async {
      final session = await FileBooksSession.openOn(
        booksDirectory: booksDir,
        startYear: calendar.forBsYear(2083),
      );
      addTearDown(session.close);

      await expectLater(
        session.open(calendar.forBsYear(2070)),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('The session starts somewhere sensible', () {
    test('on a first run it creates the trading year and seeds the chart',
        () async {
      final session = await FileBooksSession.openOn(
        booksDirectory: booksDir,
        startYear: calendar.forBsYear(2083),
      );
      addTearDown(session.close);

      expect(session.years, hasLength(1));
      expect(session.openYear.fiscalYear.label, 'FY 2083/84');
      expect(session.openYear.isReadOnly, isFalse);

      final accounts =
          await session.database.select(session.database.accounts).get();
      expect(accounts, hasLength(const ChartOfAccounts().all.length),
          reason: 'the chart must be seeded on first run or nothing can post');
    });

    test('a second launch reuses the existing year', () async {
      final first = await FileBooksSession.openOn(
        booksDirectory: booksDir,
        startYear: calendar.forBsYear(2083),
      );
      await first.close();

      final second = await FileBooksSession.openOn(
        booksDirectory: booksDir,
        startYear: calendar.forBsYear(2083),
      );
      addTearDown(second.close);

      expect(second.years, hasLength(1));
      final accounts =
          await second.database.select(second.database.accounts).get();
      expect(accounts, hasLength(const ChartOfAccounts().all.length),
          reason:
              'seeding is idempotent, so a second launch must not duplicate '
              'the chart');
    });
  });
}
