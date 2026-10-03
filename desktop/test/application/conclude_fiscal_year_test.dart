import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:financeapp/src/application/conclude_fiscal_year.dart';
import 'package:financeapp/src/domain/accounting/account.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/fiscal/fiscal_year.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_unit_of_work.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Closing a fiscal year.
///
/// **The rule under test is the ordering**, because the specification makes it one:
///
/// > *"Only after server confirmation may the local application create and
/// activate the next fiscal-year SQLite database."*
///
/// A close that creates the next year before the archive is confirmed loses the
/// old year with no record of it on the server — which is the one failure this
/// feature exists to prevent.
void main() {
  /// The year under test, **taken from the calendar** rather than hand-written.
  ///
  /// It was `FiscalYear(label: 'FY 2082/83', start: DateTime(2026, 7), end:
  /// DateTime(2027, 7))`, which is wrong: the real FY 2082/83 runs 17 Jul 2025 to
  /// 16 Jul 2026. A fictional fiscal year made the whole suite validate a world
  /// that does not exist, and is precisely why neither the wrong year handed to
  /// the transition nor the two-day successor could be seen — the assertions
  /// lined up with the stub rather than with the application.
  final year = const NepaliFiscalCalendar().forBsYear(2082);

  late AppDatabase db;
  late DriftJournalRepository journal;
  late _Archive archive;
  late _Transition transition;
  late File dbFile;
  late Directory tempDir;

  setUp(() async {
    db = openInMemoryDatabase();
    await DriftAccountRepository(db).saveAll(const ChartOfAccounts().all);
    journal = DriftJournalRepository(db);
    archive = _Archive();
    transition = _Transition();
    // The archive is handed a real path and never reads it back, but the file
    // has to exist so handing it over cannot throw for the wrong reason.
    tempDir = Directory.systemTemp.createTempSync('close');
    dbFile = File(p.join(tempDir.path, 'books.db'))..writeAsBytesSync(<int>[0]);

    // A year with sales, a cost, and a cash balance, so the closing has work.
    await journal.append(JournalEntry(
      id: 'JE-1',
      date: DateTime(2026, 3, 1),
      description: 'Sale',
      lines: <JournalLine>[
        JournalLine.debit(
          account: ChartOfAccounts.receivable,
          amount: Money.fromMajorUnits(100000, 'NPR'),
        ),
        JournalLine.credit(
          account: ChartOfAccounts.salesRevenue,
          amount: Money.fromMajorUnits(100000, 'NPR'),
        ),
      ],
    ));
    await journal.append(JournalEntry(
      id: 'JE-2',
      date: DateTime(2026, 3, 2),
      description: 'Stock cost',
      lines: <JournalLine>[
        JournalLine.debit(
          account: ChartOfAccounts.costOfGoodsSold,
          amount: Money.fromMajorUnits(60000, 'NPR'),
        ),
        JournalLine.credit(
          account: ChartOfAccounts.bank,
          amount: Money.fromMajorUnits(60000, 'NPR'),
        ),
      ],
    ));
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  ConcludeFiscalYear useCase() => ConcludeFiscalYear(
        fiscalYear: year,
        databaseFile: dbFile,
        journal: journal,
        unitOfWork: DriftUnitOfWork(db),
        archive: archive,
        transition: transition,
        accounts: const ChartOfAccounts().all,
      );

  group('the happy path', () {
    test('closes the books, archives, then opens the next year', () async {
      final outcome = await useCase()();

      expect(outcome, isA<FiscalYearConcluded>(), reason: '$outcome');
      final concluded = outcome as FiscalYearConcluded;

      // The year's result is revenue closed less expenses closed.
      expect(concluded.closed.result.minorUnits, 4000000,
          reason: '100,000 sales less 60,000 cost is a 40,000 profit');

      // Only balance-sheet accounts carry forward.
      expect(
        concluded.openingBalances.keys.map((Account a) => a.code).toSet(),
        <String>{ChartOfAccounts.receivable.code, ChartOfAccounts.bank.code},
      );
      expect(transition.calls, 1, reason: 'the next year was created once');
      expect(archive.calls, 1);
    });

    test('posts closing entries that zero the nominal accounts', () async {
      await useCase()();

      final all = await journal.all();
      final closing =
          all.firstWhere((JournalEntry e) => e.id.startsWith('CLOSE-'));

      // Every nominal account is zeroed, and the entry balances.
      final revenue = closing.lines.firstWhere(
          (JournalLine l) => l.account.id == ChartOfAccounts.salesRevenue.id);
      expect(revenue.amount.minorUnits, 10000000,
          reason: 'sales are credited closed by the same amount');

      final cost = closing.lines.firstWhere((JournalLine l) =>
          l.account.id == ChartOfAccounts.costOfGoodsSold.id);
      expect(cost.isDebit, isTrue,
          reason: 'an expense is closed by debiting it');

      expect(closing.isBalanced, isTrue);
    });

    test('the next year is derived from this one, not from the clock',
        () async {
      final outcome = await useCase()() as FiscalYearConcluded;

      expect(outcome.nextYear.label, 'FY 2083/84');
    });

    test('the next year is a real calendar year, not two days of arithmetic',
        () async {
      // FY 2082/83 runs 17 Jul 2025 to 16 Jul 2026. FY 2083/84 therefore **starts
      // the day after 2082/83 ends**, not on the same day, and lasts a year.
      final outcome = await useCase()() as FiscalYearConcluded;

      expect(outcome.nextYear.startDate, DateTime(2026, 7, 17),
          reason: 'must begin the day after the closed year ends');
      expect(outcome.nextYear.endDate, DateTime(2027, 7, 16));
      expect(
        outcome.nextYear.endDate.difference(outcome.nextYear.startDate).inDays,
        anyOf(364, 365),
        reason:
            'a fiscal year spans 365 or 366 days inclusive, so 364 or 365 days '
            'between the bounds. A two-day year would file every document after '
            'Shrawan into the wrong year.',
      );
    });
  });

  group('which year the transition is asked to create', () {
    test('it is given the NEXT year, never the one being closed', () async {
      // **The defect this pins.** `beginNextYear` creates the database named by
      // the year it is handed. Handing it the year being closed therefore reopens
      // that concluded year's file read-write and appends the next year's opening
      // entry into it -- so the archived year holds both the closing entries and an
      // opening entry, assets are posted twice, `BalanceSheet.assertBalanced()`
      // throws on every later read of that year, and the next year is never
      // created at all.
      await useCase()();

      expect(transition.years, hasLength(1));
      expect(
        transition.years.single.label,
        'FY 2083/84',
        reason: 'the transition must create the NEXT year',
      );
      expect(
        transition.years.single.label,
        isNot(year.label),
        reason: 'creating the year being concluded is what corrupts it',
      );
    });

    test('the year created starts when the closed year stops', () async {
      // The dates must be contiguous. A gap loses transactions; an overlap files
      // them into two years.
      await useCase()();

      final created = transition.years.single;
      expect(created.startDate, DateTime(2026, 7, 17));
      expect(
        created.startDate.difference(year.endDate).inDays,
        1,
        reason: 'the new year must begin the day after the old one ends',
      );
    });
  });

  group('the ordering, which is the point', () {
    test('an unreachable archive stops the close before anything is written',
        () async {
      archive.available = false;

      final outcome = await useCase()();

      expect(outcome, isA<FiscalYearNotConcluded>());
      expect((outcome as FiscalYearNotConcluded).reason,
          contains('cannot be reached'));
      expect(transition.calls, 0,
          reason: 'the next year must not be created without an archive');
      expect(
          (await journal.all())
              .where((JournalEntry e) => e.id.startsWith('CLOSE-')),
          isEmpty,
          reason: 'nothing is closed when the year cannot be archived');
    });

    test('a failed archive leaves the year open and creates no next year',
        () async {
      archive.failWith = 'the server refused';

      final outcome = await useCase()();

      expect(outcome, isA<FiscalYearNotConcluded>());
      expect(transition.calls, 0,
          reason:
              'this is the failure the specification is most explicit about');
    });

    test('the archive happens before the next year is created', () async {
      // Recorded as a sequence, so ordering is asserted rather than assumed.
      final order = <String>[];

      await ConcludeFiscalYear(
        fiscalYear: year,
        databaseFile: dbFile,
        journal: journal,
        unitOfWork: DriftUnitOfWork(db),
        archive: _OrderRecordingArchive(order),
        transition: _OrderRecordingTransition(order),
        accounts: const ChartOfAccounts().all,
      )();

      expect(order, <String>['archive', 'transition', 'conclude']);
    });

    test('the server is told last, so a failure cannot strand a closed year',
        () async {
      // The ordering is the safety property, and it is the reverse of the obvious
      // one. Telling the server a year is concluded **before** the transition
      // means a failure in between leaves the server holding a year as final while
      // this computer can still open, edit and upload it. The consequence is a
      // year that is simultaneously read-only and editable.
      final order = <String>[];

      await ConcludeFiscalYear(
        fiscalYear: year,
        databaseFile: dbFile,
        journal: journal,
        unitOfWork: DriftUnitOfWork(db),
        archive: _OrderRecordingArchive(order),
        transition: _OrderRecordingTransition(order),
        accounts: const ChartOfAccounts().all,
      )();

      expect(
        order.indexOf('conclude'),
        greaterThan(order.indexOf('transition')),
        reason:
            'the server must not be told until the next year exists locally',
      );
    });

    test('a server that cannot be reached does not fail the close', () async {
      // The archive is already confirmed by this point, so the record is safe.
      // The duplicates that remain cost disk and nothing else, and turning a
      // successful close into a failure over housekeeping would be the worse
      // outcome for the user.
      final order = <String>[];
      final journal = DriftJournalRepository(db);

      final result = await ConcludeFiscalYear(
        fiscalYear: year,
        databaseFile: dbFile,
        journal: journal,
        unitOfWork: DriftUnitOfWork(db),
        archive: _UnreachableConcludeArchive(),
        transition: _OrderRecordingTransition(order),
        accounts: const ChartOfAccounts().all,
      )();

      expect(result, isA<FiscalYearConcluded>());
      expect(
        (result as FiscalYearConcluded).serverOutcome,
        ConcludeOutcome.unreachable,
      );
      expect(order, contains('transition'),
          reason: 'the year must still close');
    });
  });

  group('blocking conditions', () {
    test('an entry dated outside the year stops the close', () async {
      await journal.append(JournalEntry(
        id: 'JE-3',
        date: DateTime(2027, 9, 1),
        description: 'Next year, wrongly filed here',
        lines: <JournalLine>[
          JournalLine.debit(
            account: ChartOfAccounts.cash,
            amount: Money.fromMajorUnits(1, 'NPR'),
          ),
          JournalLine.credit(
            account: ChartOfAccounts.otherIncome,
            amount: Money.fromMajorUnits(1, 'NPR'),
          ),
        ],
      ));

      final outcome = await useCase()();

      expect(outcome, isA<FiscalYearNotConcluded>());
      expect((outcome as FiscalYearNotConcluded).reason,
          contains('outside the year'));
      expect(transition.calls, 0);
    });

    test('a year with nothing in it still closes, with no entries', () async {
      // A fresh database with only the chart has no entries to close.
      final empty = openInMemoryDatabase();
      await DriftAccountRepository(empty).saveAll(const ChartOfAccounts().all);

      final outcome = await ConcludeFiscalYear(
        fiscalYear: year,
        databaseFile: dbFile,
        journal: DriftJournalRepository(empty),
        unitOfWork: DriftUnitOfWork(empty),
        archive: archive,
        transition: transition,
        accounts: const ChartOfAccounts().all,
      )();

      expect(outcome, isA<FiscalYearConcluded>());
      expect((outcome as FiscalYearConcluded).closed.hasWork, isFalse);
      await empty.close();
    });
  });
}

/// A [FiscalYearArchive] that records calls and can refuse.
class _Archive implements FiscalYearArchive {
  bool available = true;
  String? failWith;
  int calls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ConcludeOutcome> conclude(FiscalYear fiscalYear) async =>
      ConcludeOutcome.concluded;

  @override
  Future<void> archive(FiscalYear fiscalYear, File databaseFile) async {
    calls++;
    final failure = failWith;
    if (failure != null) throw StateError(failure);
  }
}

/// A [FiscalYearTransition] that records how many times it ran.
class _Transition implements FiscalYearTransition {
  int calls = 0;

  /// Every year this was asked to create.
  ///
  /// **Recorded, not merely counted.** Counting was exactly the gap that let the
  /// real defect through: the count was right while the year handed over was
  /// wrong, and counting cannot tell those apart.
  final List<FiscalYear> years = <FiscalYear>[];

  @override
  Future<void> beginNextYear({
    required FiscalYear nextYear,
    required Map<Account, Money> openingBalances,
  }) async {
    calls++;
    years.add(nextYear);
  }
}

class _OrderRecordingArchive implements FiscalYearArchive {
  _OrderRecordingArchive(this.order);
  final List<String> order;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> archive(FiscalYear fiscalYear, File databaseFile) async =>
      order.add('archive');

  /// Recorded so the ordering test can see it.
  ///
  /// **It comes after the transition, deliberately.** Telling the server a year is
  /// final before the next year's books exist locally would let a failure in
  /// between leave the server holding a closed year that this computer can still
  /// edit.
  @override
  Future<ConcludeOutcome> conclude(FiscalYear fiscalYear) async {
    order.add('conclude');
    return ConcludeOutcome.concluded;
  }
}

/// An archive that stores the snapshot but cannot reach the server afterwards.
///
/// Stands for the ordinary offline case: the close works, and only the
/// housekeeping on the server is skipped.
class _UnreachableConcludeArchive implements FiscalYearArchive {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> archive(FiscalYear fiscalYear, File databaseFile) async {}

  @override
  Future<ConcludeOutcome> conclude(FiscalYear fiscalYear) async =>
      ConcludeOutcome.unreachable;
}

class _OrderRecordingTransition implements FiscalYearTransition {
  _OrderRecordingTransition(this.order);
  final List<String> order;

  @override
  Future<void> beginNextYear({
    required FiscalYear nextYear,
    required Map<Account, Money> openingBalances,
  }) async =>
      order.add('transition');
}
