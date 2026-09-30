import 'package:financeapp/src/application/build_general_ledger.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/reporting/general_ledger.dart';
import 'package:financeapp/src/domain/reporting/trial_balance.dart';
import 'package:financeapp/src/domain/shared/currency.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A running ledger for one account, with three postings.
///
/// Hand-computed for Bank:
///   4 Jan  opening              100,000
///   4 Jan  Dr 100,000  Cr   0    running  100,000
///  10 Jan  Dr  20,000  Cr   0    running  120,000
///  20 Jan  Dr   0      Cr  5,000 running  115,000
///
/// A range starting on 10 Jan must bring forward **100,000** as its opening
/// balance, and its closing balance is still 115,000, the same as the trial
/// balance. That equality is the property being tested.
List<JournalEntry> bankEntries() => [
      JournalEntry(
        id: 'OB-1',
        date: DateTime(2026, 1, 4),
        description: 'Opening balance',
        lines: [
          JournalLine.debit(
            account: ChartOfAccounts.bank,
            amount: Money.minor(10000000, bookCurrency),
          ),
          JournalLine.credit(
            account: ChartOfAccounts.ownersEquity,
            amount: Money.minor(10000000, bookCurrency),
          ),
        ],
      ),
      JournalEntry(
        id: 'SA-1',
        date: DateTime(2026, 1, 10),
        description: 'Sale',
        lines: [
          JournalLine.debit(
            account: ChartOfAccounts.bank,
            amount: Money.minor(2000000, bookCurrency),
          ),
          JournalLine.credit(
            account: ChartOfAccounts.salesRevenue,
            amount: Money.minor(2000000, bookCurrency),
          ),
        ],
      ),
      JournalEntry(
        id: 'EX-1',
        date: DateTime(2026, 1, 20),
        description: 'Office rent',
        lines: [
          JournalLine.debit(
            account: ChartOfAccounts.officeRent,
            amount: Money.minor(500000, bookCurrency),
          ),
          JournalLine.credit(
            account: ChartOfAccounts.bank,
            amount: Money.minor(500000, bookCurrency),
          ),
        ],
      ),
    ];

void main() {
  final fiscalYear = const NepaliFiscalCalendar().forBsYear(2082);

  Future<(AppDatabase, BuildGeneralLedger)> seeded() async {
    final db = openInMemoryDatabase();
    await DriftAccountRepository(db).saveAll(const ChartOfAccounts().all);
    final journal = DriftJournalRepository(db);
    for (final entry in bankEntries()) {
      await journal.append(entry);
    }
    return (
      db,
      BuildGeneralLedger(
        fiscalYear: fiscalYear,
        journal: journal,
        chart: const ChartOfAccounts(),
      ),
    );
  }

  group('BuildGeneralLedger', () {
    test('returns postings in date order with a running balance', () async {
      final (db, useCase) = await seeded();
      addTearDown(db.close);

      final report = await useCase.load(account: ChartOfAccounts.bank);

      expect(report.lines.map((l) => l.entry.id), ['OB-1', 'SA-1', 'EX-1']);
      expect(
        report.lines.map((l) => l.runningBalance.minorUnits),
        [10000000, 12000000, 11500000],
      );
      expect(report.closingBalance.minorUnits, 11500000);
    });

    test('agrees with the general ledger computed in memory', () async {
      // Two derivations of the same figures must match.
      final (db, useCase) = await seeded();
      addTearDown(db.close);

      final report = await useCase.load(account: ChartOfAccounts.bank);
      final inMemory = GeneralLedger.forAccount(
        account: ChartOfAccounts.bank,
        entries: bankEntries(),
        currency: bookCurrency,
      );

      expect(report.openingBalance, inMemory.openingBalance);
      expect(report.closingBalance, inMemory.closingBalance);
      expect(report.lines.length, inMemory.lines.length);
    });

    test('a range starting mid-history brings the opening balance forward',
        () async {
      final (db, useCase) = await seeded();
      addTearDown(db.close);

      final report = await useCase.load(
        account: ChartOfAccounts.bank,
        from: DateTime(2026, 1, 10),
      );

      // The 4 Jan opening posting is outside the range but its effect must be
      // brought forward, or the running balance would look as though the account
      // had started at zero and the closing figure would not tie back.
      expect(report.openingBalance.minorUnits, 10000000);
      expect(report.hasOpeningBalance, isTrue);
      expect(report.lines.map((l) => l.entry.id), ['SA-1', 'EX-1']);
      expect(
        report.lines.first.runningBalance.minorUnits,
        12000000,
        reason: 'the first listed running balance continues from the opening',
      );
      expect(report.closingBalance.minorUnits, 11500000);
    });

    test('a range with no postings still shows the opening balance', () async {
      final (db, useCase) = await seeded();
      addTearDown(db.close);

      final report = await useCase.load(
        account: ChartOfAccounts.bank,
        from: DateTime(2027, 1, 1),
        to: DateTime(2027, 3, 31),
      );

      // Nothing moved in the range, but money was there before it. Showing an
      // empty ledger with no opening figure would read as "this account was
      // always empty", which is false.
      expect(report.isEmpty, isTrue);
      expect(report.hasOpeningBalance, isTrue);
      expect(report.openingBalance.minorUnits, 11500000);
      expect(report.closingBalance.minorUnits, 11500000);
    });

    test('an untouched account is empty with no opening balance', () async {
      final (db, useCase) = await seeded();
      addTearDown(db.close);

      final report = await useCase.load(account: ChartOfAccounts.cash);

      expect(report.isEmpty, isTrue);
      expect(report.hasOpeningBalance, isFalse);
      expect(report.openingBalance.isZero, isTrue);
      expect(report.closingBalance.isZero, isTrue);
    });

    test('the closing balance equals the same account on the trial balance',
        () async {
      // The cross-check that matters most: two reports, one book, one answer.
      final (db, useCase) = await seeded();
      addTearDown(db.close);

      final report = await useCase.load(account: ChartOfAccounts.bank);
      final trial = TrialBalance.from(
        entries: bankEntries(),
        currency: bookCurrency,
      );
      final bankRow =
          trial.rows.firstWhere((r) => r.account.id == ChartOfAccounts.bank.id);

      expect(report.closingBalance, bankRow.balance,
          reason: 'the ledger and the trial balance must agree for the same '
              'account, or one of them is wrong');
      expect(trial.isBalanced, isTrue);
    });

    test('a credit-normal account reports its balance in that direction',
        () async {
      final (db, useCase) = await seeded();
      addTearDown(db.close);

      // Sales Revenue is credit-normal: the credit side increases it.
      final report = await useCase.load(account: ChartOfAccounts.salesRevenue);

      expect(report.closingBalance.minorUnits, 2000000);
      expect(report.closingBalance.isPositive, isTrue,
          reason: 'revenue must read as a positive figure, not a negative one');
    });

    test('offers the chart accounts to choose from, in code order', () async {
      final (db, useCase) = await seeded();
      addTearDown(db.close);

      final accounts = useCase.selectableAccounts();
      final codes = accounts.map((a) => a.code).toList();

      expect(codes.first, '1010');
      expect(codes, contains('1040'));
      expect(codes, contains('4010'));
      expect(
        codes,
        equals([...codes]..sort()),
        reason: 'accounts should be offered in chart order',
      );
    });

    test('names the account and fiscal year in the heading', () async {
      final (db, useCase) = await seeded();
      addTearDown(db.close);

      final report = await useCase.load(account: ChartOfAccounts.bank);

      expect(report.periodLabel, 'Bank — FY 2082/83');
      expect(report.fiscalYear.label, 'FY 2082/83');
    });

    test('a ranged heading carries the dates', () async {
      final (db, useCase) = await seeded();
      addTearDown(db.close);

      final report = await useCase.load(
        account: ChartOfAccounts.bank,
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 3, 31),
      );

      expect(
          report.periodLabel, 'Bank — FY 2082/83, 1 Jan 2026 to 31 Mar 2026');
    });
  });
}
