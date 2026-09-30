import 'dart:io';

import 'package:financeapp/src/domain/accounting/account.dart';
import 'package:financeapp/src/domain/accounting/account_type.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/reporting/balance_sheet.dart';
import 'package:financeapp/src/domain/reporting/general_ledger.dart';
import 'package:financeapp/src/domain/reporting/profit_and_loss.dart';
import 'package:financeapp/src/domain/reporting/trial_balance.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_unit_of_work.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const npr = 'NPR';

Money rs(int majorUnits) => Money.minor(majorUnits * 100, npr);

DateTime day(int d) => DateTime(2026, 9, d);

const bank = Account(
    id: 'acct-bank', code: '1010', name: 'Bank', type: AccountType.asset);
const inventory = Account(
    id: 'acct-inv', code: '1040', name: 'Inventory', type: AccountType.asset);
const payable = Account(
    id: 'acct-ap',
    code: '2010',
    name: 'Accounts Payable',
    type: AccountType.liability);
const equity = Account(
    id: 'acct-equity',
    code: '3010',
    name: "Owner's Equity",
    type: AccountType.equity);
const sales = Account(
    id: 'acct-sales',
    code: '4010',
    name: 'Sales Revenue',
    type: AccountType.income);
const rent = Account(
    id: 'acct-rent',
    code: '5010',
    name: 'Office Rent',
    type: AccountType.expense);
const cogs = Account(
    id: 'acct-cogs',
    code: '5020',
    name: 'Cost of Goods Sold',
    type: AccountType.expense);

const chart = [bank, inventory, payable, equity, sales, rent, cogs];

List<JournalEntry> workedExample() => [
      JournalEntry(
        id: 'OB-1',
        date: day(1),
        description: 'Opening balance',
        lines: [
          JournalLine.debit(account: bank, amount: rs(100000)),
          JournalLine.credit(account: equity, amount: rs(100000)),
        ],
      ),
      JournalEntry(
        id: 'PU-1',
        date: day(2),
        description: 'Purchased goods on credit',
        lines: [
          JournalLine.debit(account: inventory, amount: rs(30000)),
          JournalLine.credit(account: payable, amount: rs(30000)),
        ],
      ),
      JournalEntry(
        id: 'SA-1',
        date: day(3),
        description: 'Sale with cost of goods sold',
        lines: [
          JournalLine.debit(account: bank, amount: rs(20000)),
          JournalLine.credit(account: sales, amount: rs(20000)),
          JournalLine.debit(account: cogs, amount: rs(12000)),
          JournalLine.credit(account: inventory, amount: rs(12000)),
        ],
      ),
      JournalEntry(
        id: 'EX-1',
        date: day(4),
        description: 'Office rent',
        lines: [
          JournalLine.debit(account: rent, amount: rs(5000)),
          JournalLine.credit(account: bank, amount: rs(5000)),
        ],
      ),
    ];

Future<void> seed(AppDatabase db) async {
  final accounts = DriftAccountRepository(db);
  final journal = DriftJournalRepository(db);
  final unitOfWork = DriftUnitOfWork(db);

  await accounts.saveAll(chart);
  // One unit of work for the whole scenario, so a failure partway through
  // leaves no half-posted example behind.
  await unitOfWork.run(() async {
    for (final entry in workedExample()) {
      await journal.append(entry);
    }
  });
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('financeapp_report_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('Reports over persisted data', () {
    test('produce the same numbers as the in-memory worked example', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final journal = DriftJournalRepository(db);

      await seed(db);

      final entries = await journal.all();
      final report = TrialBalance.from(entries: entries, currency: npr);
      final byCode = {for (final row in report.rows) row.account.code: row};

      expect(report.isBalanced, isTrue);
      expect(report.totalDebits.minorUnits, 16700000);
      expect(report.totalCredits.minorUnits, 16700000);

      expect(byCode['1010']!.balance.minorUnits, 11500000);
      expect(byCode['1040']!.balance.minorUnits, 1800000);
      expect(byCode['2010']!.balance.minorUnits, 3000000);
      expect(byCode['3010']!.balance.minorUnits, 10000000);
      expect(byCode['4010']!.balance.minorUnits, 2000000);
      expect(byCode['5010']!.balance.minorUnits, 500000);
      expect(byCode['5020']!.balance.minorUnits, 1200000);
    });

    test('the two reports agree when read back from storage', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final journal = DriftJournalRepository(db);

      await seed(db);
      final entries = await journal.all();

      final trial = TrialBalance.from(entries: entries, currency: npr);
      for (final row in trial.rows) {
        final ledger = GeneralLedger.forAccount(
          account: row.account,
          entries: entries,
          currency: npr,
        );
        expect(ledger.closingBalance, row.balance,
            reason: '${row.account.name} disagrees between the two reports '
                'after a round trip through SQLite');
      }
    });

    test('the general ledger running balance survives persistence', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final journal = DriftJournalRepository(db);

      await seed(db);

      final bankLedger = GeneralLedger.forAccount(
        account: bank,
        entries: await journal.all(),
        currency: npr,
      );

      expect(
        bankLedger.lines.map((l) => l.runningBalance.minorUnits),
        [10000000, 12000000, 11500000],
      );
      expect(bankLedger.closingBalance.minorUnits, 11500000);
    });
  });

  group('Reports survive a restart', () {
    test('numbers are identical after closing and reopening the database',
        () async {
      final file = File(p.join(tempDir.path, 'accounting-FY-2082-83.db'));

      final db = openFileDatabase(file);
      await seed(db);
      final beforeReport = TrialBalance.from(
          entries: await DriftJournalRepository(db).all(), currency: npr);
      await db.close();

      final reopened = openFileDatabase(file);
      final afterReport = TrialBalance.from(
          entries: await DriftJournalRepository(reopened).all(), currency: npr);
      final afterLedger = GeneralLedger.forAccount(
        account: bank,
        entries: await DriftJournalRepository(reopened).all(),
        currency: npr,
      );
      await reopened.close();

      expect(afterReport.isBalanced, isTrue);
      expect(afterReport.totalDebits, beforeReport.totalDebits);
      expect(afterReport.totalCredits, beforeReport.totalCredits);
      expect(afterReport.rows.length, beforeReport.rows.length);
      for (var i = 0; i < beforeReport.rows.length; i++) {
        expect(afterReport.rows[i].account.id, beforeReport.rows[i].account.id);
        expect(afterReport.rows[i].balance, beforeReport.rows[i].balance);
      }

      expect(afterLedger.closingBalance.minorUnits, 11500000);
    });
  });

  group('ProfitAndLoss over persisted data', () {
    test('produces the same figures as the in-memory worked example', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      await seed(db);
      final entries = await DriftJournalRepository(db).all();
      final report = ProfitAndLoss.from(entries: entries, currency: npr);

      expect(report.totalIncome.minorUnits, 2000000);
      expect(report.totalExpenses.minorUnits, 1700000);
      expect(report.netResult.minorUnits, 300000);
      expect(report.isProfit, isTrue);
    });

    test('agrees with the trial balance read back from storage', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      await seed(db);
      final entries = await DriftJournalRepository(db).all();

      final pnl = ProfitAndLoss.from(entries: entries, currency: npr);
      final trial = TrialBalance.from(entries: entries, currency: npr);

      var income = Money.minor(0, npr);
      var expenses = Money.minor(0, npr);
      for (final row in trial.rows) {
        if (row.account.type == AccountType.income) {
          income = income.add(row.balance);
        } else if (row.account.type == AccountType.expense) {
          expenses = expenses.add(row.balance);
        }
      }

      expect(pnl.totalIncome, income);
      expect(pnl.totalExpenses, expenses);
      expect(pnl.netResult, income.subtract(expenses));
    });

    test('survives a close and reopen of the database', () async {
      final file = File(p.join(tempDir.path, 'accounting-FY-2082-83.db'));

      final db = openFileDatabase(file);
      await seed(db);
      final before = ProfitAndLoss.from(
        entries: await DriftJournalRepository(db).all(),
        currency: npr,
      );
      await db.close();

      final reopened = openFileDatabase(file);
      final after = ProfitAndLoss.from(
        entries: await DriftJournalRepository(reopened).all(),
        currency: npr,
      );
      await reopened.close();

      expect(after.totalIncome, before.totalIncome);
      expect(after.totalExpenses, before.totalExpenses);
      expect(after.netResult, before.netResult);
      expect(after.netResult.minorUnits, 300000);
    });
  });

  group('BalanceSheet over persisted data', () {
    test('balances and matches the hand-computed totals', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      await seed(db);
      final sheet = BalanceSheet.from(
        entries: await DriftJournalRepository(db).all(),
        currency: npr,
      );

      expect(sheet.totalAssets.minorUnits, 13300000);
      expect(sheet.totalLiabilities.minorUnits, 3000000);
      expect(sheet.totalEquity.minorUnits, 10300000);
      expect(sheet.isBalanced, isTrue);
      expect(sheet.assertBalanced, returnsNormally);
    });

    test('the equation holds against a real database, not just in memory',
        () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      await seed(db);
      final entries = await DriftJournalRepository(db).all();

      final sheet = BalanceSheet.from(entries: entries, currency: npr);
      final pnl = ProfitAndLoss.from(entries: entries, currency: npr);

      // Three independent statements must agree about the same book.
      expect(sheet.totalAssets, sheet.totalLiabilities.add(sheet.totalEquity));
      expect(sheet.currentResult, pnl.netResult);
      expect(
        sheet.totalAssets,
        sheet.totalLiabilities
            .add(sheet.equityAccountsTotal)
            .add(pnl.netResult),
      );
    });

    test('survives a close and reopen of the database', () async {
      final file = File(p.join(tempDir.path, 'accounting-FY-2082-83.db'));

      final db = openFileDatabase(file);
      await seed(db);
      final before = BalanceSheet.from(
        entries: await DriftJournalRepository(db).all(),
        currency: npr,
      );
      await db.close();

      final reopened = openFileDatabase(file);
      final after = BalanceSheet.from(
        entries: await DriftJournalRepository(reopened).all(),
        currency: npr,
      );
      await reopened.close();

      expect(after.totalAssets, before.totalAssets);
      expect(after.totalLiabilities, before.totalLiabilities);
      expect(after.totalEquity, before.totalEquity);
      expect(after.isBalanced, isTrue);
    });
  });
}
