import 'package:financeapp/src/application/post_journal_entry.dart';
import 'package:financeapp/src/domain/accounting/account.dart';
import 'package:financeapp/src/domain/accounting/account_type.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_unit_of_work.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';

const npr = 'NPR';

Money rs(int majorUnits) => Money.minor(majorUnits * 100, npr);

const bank = Account(
    id: 'acct-bank', code: '1010', name: 'Bank', type: AccountType.asset);
const rent = Account(
    id: 'acct-rent',
    code: '5010',
    name: 'Office Rent',
    type: AccountType.expense);

/// Nepal's fiscal year 2082/83.
final fiscalYear = const NepaliFiscalCalendar().forBsYear(2082);

JournalEntry entryOn(DateTime date, {String id = 'JE-1'}) => JournalEntry(
      id: id,
      date: date,
      description: 'Office rent',
      lines: [
        JournalLine.debit(account: rent, amount: rs(500)),
        JournalLine.credit(account: bank, amount: rs(500)),
      ],
    );

void main() {
  late PostJournalEntry useCase;

  test('the fixture describes the expected fiscal year', () {
    // Guards the tests themselves. If the calendar anchor ever shifts, these
    // tests should fail loudly rather than silently testing a different period.
    expect(fiscalYear.label, 'FY 2082/83');
    expect(fiscalYear.startDate, DateTime(2025, 7, 17));
    expect(fiscalYear.endDate, DateTime(2026, 7, 16));
  });

  group('accepted postings', () {
    test('an entry dated mid-year is posted and readable', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      useCase = PostJournalEntry(
        fiscalYear: fiscalYear,
        journal: DriftJournalRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      );
      await DriftAccountRepository(db).saveAll([bank, rent]);

      final outcome = await useCase(entryOn(DateTime(2026, 1, 15)));

      expect(outcome, isA<JournalEntryPosted>());
      expect(
        await DriftJournalRepository(db).byId('JE-1'),
        isNotNull,
        reason: 'an accepted posting must actually be written',
      );
    });

    test('the first day of the fiscal year is accepted', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      useCase = PostJournalEntry(
        fiscalYear: fiscalYear,
        journal: DriftJournalRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      );
      await DriftAccountRepository(db).saveAll([bank, rent]);

      final outcome = await useCase(entryOn(fiscalYear.startDate));

      expect(outcome, isA<JournalEntryPosted>());
      expect(await DriftJournalRepository(db).byId('JE-1'), isNotNull);
    });

    test('the last day of the fiscal year is accepted', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      useCase = PostJournalEntry(
        fiscalYear: fiscalYear,
        journal: DriftJournalRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      );
      await DriftAccountRepository(db).saveAll([bank, rent]);

      final outcome = await useCase(entryOn(fiscalYear.endDate));

      expect(outcome, isA<JournalEntryPosted>());
      expect(await DriftJournalRepository(db).byId('JE-1'), isNotNull);
    });

    test('an afternoon on the last day is accepted', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      useCase = PostJournalEntry(
        fiscalYear: fiscalYear,
        journal: DriftJournalRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      );
      await DriftAccountRepository(db).saveAll([bank, rent]);

      final afternoon = DateTime(
        fiscalYear.endDate.year,
        fiscalYear.endDate.month,
        fiscalYear.endDate.day,
        15,
        45,
      );
      final outcome = await useCase(entryOn(afternoon));

      expect(outcome, isA<JournalEntryPosted>(),
          reason: 'a time stamp on the final day must not be treated as '
              'after the period');
    });
  });

  group('refused postings', () {
    test('the day before the fiscal year starts is refused', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      useCase = PostJournalEntry(
        fiscalYear: fiscalYear,
        journal: DriftJournalRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      );
      await DriftAccountRepository(db).saveAll([bank, rent]);

      final tooEarly = fiscalYear.startDate.subtract(const Duration(days: 1));
      final outcome = await useCase(entryOn(tooEarly));

      expect(outcome, isA<JournalEntryRejected>());
      expect(
        (outcome as JournalEntryRejected).reason,
        PostRejectionReason.outsideFiscalYear,
      );
    });

    test('the day after the fiscal year ends is refused', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      useCase = PostJournalEntry(
        fiscalYear: fiscalYear,
        journal: DriftJournalRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      );
      await DriftAccountRepository(db).saveAll([bank, rent]);

      final tooLate = fiscalYear.endDate.add(const Duration(days: 1));
      final outcome = await useCase(entryOn(tooLate));

      expect(outcome, isA<JournalEntryRejected>());
    });

    test('a refusal writes nothing at all', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      useCase = PostJournalEntry(
        fiscalYear: fiscalYear,
        journal: DriftJournalRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      );
      await DriftAccountRepository(db).saveAll([bank, rent]);

      await useCase(
        entryOn(fiscalYear.endDate.add(const Duration(days: 1))),
      );

      expect(await DriftJournalRepository(db).byId('JE-1'), isNull);
      expect(await db.select(db.journalEntries).get(), isEmpty);
      expect(await db.select(db.journalLines).get(), isEmpty,
          reason: 'a refused posting must not leave orphaned lines');
    });

    test('a refusal is a result, not an exception', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      useCase = PostJournalEntry(
        fiscalYear: fiscalYear,
        journal: DriftJournalRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      );
      await DriftAccountRepository(db).saveAll([bank, rent]);

      // Expected user input must not be signalled with an exception, or callers
      // end up catching it to show a message, which hides real failures.
      await expectLater(
        useCase(
            entryOn(fiscalYear.startDate.subtract(const Duration(days: 1)))),
        completes,
      );
    });

    test('the refusal names the fiscal year for the user', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      useCase = PostJournalEntry(
        fiscalYear: fiscalYear,
        journal: DriftJournalRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      );
      await DriftAccountRepository(db).saveAll([bank, rent]);

      final outcome = await useCase(
        entryOn(fiscalYear.endDate.add(const Duration(days: 1))),
      ) as JournalEntryRejected;

      expect(outcome.message, contains('FY 2082/83'));
      expect(outcome.fiscalYear, fiscalYear);
    });

    test('a refusal leaves earlier committed entries untouched', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final journal = DriftJournalRepository(db);
      useCase = PostJournalEntry(
        fiscalYear: fiscalYear,
        journal: journal,
        unitOfWork: DriftUnitOfWork(db),
      );
      await DriftAccountRepository(db).saveAll([bank, rent]);

      await useCase(entryOn(DateTime(2026, 1, 15), id: 'JE-GOOD'));

      final refused = await useCase(
        entryOn(
          fiscalYear.endDate.add(const Duration(days: 1)),
          id: 'JE-BAD',
        ),
      );

      expect(refused, isA<JournalEntryRejected>());
      expect(await journal.byId('JE-GOOD'), isNotNull,
          reason: 'the refusal must not roll back or damage prior work');
      expect(await journal.byId('JE-BAD'), isNull);
      expect((await journal.all()).length, 1);
    });
  });

  group('the posting guard is not bypassable', () {
    test('every refusal path leaves the journal unchanged', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final journal = DriftJournalRepository(db);
      useCase = PostJournalEntry(
        fiscalYear: fiscalYear,
        journal: journal,
        unitOfWork: DriftUnitOfWork(db),
      );
      await DriftAccountRepository(db).saveAll([bank, rent]);

      for (final date in [
        fiscalYear.startDate.subtract(const Duration(days: 400)),
        fiscalYear.startDate.subtract(const Duration(days: 1)),
        fiscalYear.endDate.add(const Duration(days: 1)),
        fiscalYear.endDate.add(const Duration(days: 400)),
      ]) {
        final outcome = await useCase(entryOn(date));
        expect(outcome, isA<JournalEntryRejected>(),
            reason: '$date should have been refused');
      }

      expect(await journal.all(), isEmpty);
    });
  });
}
