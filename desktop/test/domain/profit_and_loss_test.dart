import 'package:financeapp/src/domain/accounting/account.dart';
import 'package:financeapp/src/domain/accounting/account_type.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/reporting/profit_and_loss.dart';
import 'package:financeapp/src/domain/reporting/trial_balance.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:flutter_test/flutter_test.dart';

const npr = 'NPR';

Money rs(int majorUnits) => Money.minor(majorUnits * 100, npr);

DateTime day(int d) => DateTime(2026, 9, d);

const bank = Account(
    id: 'acct-bank', code: '1010', name: 'Bank', type: AccountType.asset);
const inventory = Account(
    id: 'acct-inventory',
    code: '1040',
    name: 'Inventory',
    type: AccountType.asset);
const payable = Account(
    id: 'acct-payable',
    code: '2010',
    name: 'Accounts Payable',
    type: AccountType.liability);
const equity = Account(
    id: 'acct-owners-equity',
    code: '3010',
    name: "Owner's Equity",
    type: AccountType.equity);
const sales = Account(
    id: 'acct-sales-revenue',
    code: '4010',
    name: 'Sales Revenue',
    type: AccountType.income);
const otherIncome = Account(
    id: 'acct-other-income',
    code: '4020',
    name: 'Other Income',
    type: AccountType.income);
const rent = Account(
    id: 'acct-office-rent',
    code: '5010',
    name: 'Office Rent',
    type: AccountType.expense);
const cogs = Account(
    id: 'acct-cost-of-goods-sold',
    code: '5020',
    name: 'Cost of Goods Sold',
    type: AccountType.expense);

/// The worked example from the architecture specification.
///
///   Opening    Dr Bank 100,000       Cr Equity 100,000
///   Purchase   Dr Inventory 30,000   Cr Payable 30,000
///   Sale       Dr Bank 20,000        Cr Sales 20,000
///              Dr COGS 12,000        Cr Inventory 12,000
///   Expense    Dr Rent 5,000         Cr Bank 5,000
///
///   Income   = Sales 20,000                        =  20,000
///   Expenses = COGS 12,000 + Rent 5,000            =  17,000
///   Profit   = 20,000 - 17,000                     =   3,000
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

void main() {
  group('ProfitAndLoss totals', () {
    test('reports the hand-computed income, expenses and profit', () {
      final report =
          ProfitAndLoss.from(entries: workedExample(), currency: npr);

      // Income: Sales 20,000 = 2,000,000 paisa.
      expect(report.totalIncome.minorUnits, 2000000);
      // Expenses: COGS 12,000 + Rent 5,000 = 1,700,000 paisa.
      expect(report.totalExpenses.minorUnits, 1700000);
      // Profit: 300,000 paisa.
      expect(report.netResult.minorUnits, 300000);
      expect(report.profit.minorUnits, 300000);
      expect(report.isProfit, isTrue);
    });

    test('income and expense balances are reported positive', () {
      final report =
          ProfitAndLoss.from(entries: workedExample(), currency: npr);

      // Income is credit-normal and expenses debit-normal. Both must read as
      // positive, not as one of them being negative.
      final salesLine =
          report.income.firstWhere((l) => l.account.code == '4010');
      expect(salesLine.balance.minorUnits, 2000000);
      expect(salesLine.balance.isPositive, isTrue);

      final rentLine =
          report.expenses.firstWhere((l) => l.account.code == '5010');
      expect(rentLine.balance.minorUnits, 500000);
      expect(rentLine.balance.isPositive, isTrue);

      final cogsLine =
          report.expenses.firstWhere((l) => l.account.code == '5020');
      expect(cogsLine.balance.minorUnits, 1200000);
    });

    test('the expense total is positive, not a negative sum', () {
      final report =
          ProfitAndLoss.from(entries: workedExample(), currency: npr);
      expect(report.totalExpenses.isPositive, isTrue);
    });

    test('lines are ordered by code', () {
      final report =
          ProfitAndLoss.from(entries: workedExample(), currency: npr);

      expect(report.income.map((l) => l.account.code), ['4010']);
      expect(report.expenses.map((l) => l.account.code), ['5010', '5020']);
    });
  });

  group('ProfitAndLoss covers only income and expenses', () {
    test('balance sheet accounts appear nowhere', () {
      final report =
          ProfitAndLoss.from(entries: workedExample(), currency: npr);
      final codes = [
        ...report.income.map((l) => l.account.code),
        ...report.expenses.map((l) => l.account.code),
      ];

      for (final balanceSheetCode in ['1010', '1040', '2010', '3010']) {
        expect(codes, isNot(contains(balanceSheetCode)),
            reason: 'account $balanceSheetCode belongs on the balance sheet, '
                'not in a profit and loss statement');
      }
    });

    test('a balance sheet account supplied in the chart is still excluded', () {
      final report = ProfitAndLoss.from(
        entries: workedExample(),
        currency: npr,
        chart: [bank, inventory, payable, equity, otherIncome],
        includeZeroBalances: true,
      );

      final codes = [
        ...report.income.map((l) => l.account.code),
        ...report.expenses.map((l) => l.account.code),
      ];
      expect(codes, isNot(contains('1010')));
      expect(codes, isNot(contains('3010')));
      expect(codes, contains('4020'));
    });
  });

  group('ProfitAndLoss result reporting', () {
    test('a loss is reported as a positive loss, not a negative profit', () {
      // Expenses exceed income, so the period lost money.
      final entries = [
        JournalEntry(
          id: 'EX-1',
          date: day(4),
          description: 'Rent with no sales',
          lines: [
            JournalLine.debit(account: rent, amount: rs(5000)),
            JournalLine.credit(account: bank, amount: rs(5000)),
          ],
        ),
      ];
      final report = ProfitAndLoss.from(entries: entries, currency: npr);

      expect(report.netResult.minorUnits, -500000);
      expect(report.isLoss, isTrue);
      expect(report.isProfit, isFalse);
      expect(report.loss.minorUnits, 500000,
          reason: 'a loss reads as Rs 5,000, not as a negative profit');
      expect(report.profit.isZero, isTrue);
    });

    test('breaking even is neither a profit nor a loss', () {
      // Income 1,000 exactly offset by an expense of 1,000.
      final entries = [
        JournalEntry(
          id: 'JE-1',
          date: day(4),
          description: 'Sale',
          lines: [
            JournalLine.debit(account: bank, amount: rs(1000)),
            JournalLine.credit(account: sales, amount: rs(1000)),
          ],
        ),
        JournalEntry(
          id: 'JE-2',
          date: day(5),
          description: 'Rent',
          lines: [
            JournalLine.debit(account: rent, amount: rs(1000)),
            JournalLine.credit(account: bank, amount: rs(1000)),
          ],
        ),
      ];
      final report = ProfitAndLoss.from(entries: entries, currency: npr);

      expect(report.isBreakEven, isTrue);
      expect(report.isProfit, isFalse);
      expect(report.isLoss, isFalse);
      expect(report.profit.isZero, isTrue);
      expect(report.loss.isZero, isTrue);
    });

    test('an empty period produces zeroes, not an error', () {
      final report = ProfitAndLoss.from(entries: const [], currency: npr);

      expect(report.income, isEmpty);
      expect(report.expenses, isEmpty);
      expect(report.totalIncome.isZero, isTrue);
      expect(report.totalExpenses.isZero, isTrue);
      expect(report.netResult.isZero, isTrue);
      expect(report.isBreakEven, isTrue);
    });
  });

  group('ProfitAndLoss zero-balance accounts', () {
    test('accounts with no activity are omitted by default', () {
      final report = ProfitAndLoss.from(
        entries: workedExample(),
        currency: npr,
        chart: [otherIncome],
      );

      expect(report.income.any((l) => l.account.code == '4020'), isFalse);
    });

    test('zero-balance accounts are included when asked for', () {
      final report = ProfitAndLoss.from(
        entries: workedExample(),
        currency: npr,
        chart: [otherIncome],
        includeZeroBalances: true,
      );

      final line = report.income.firstWhere((l) => l.account.code == '4020');
      expect(line.balance.isZero, isTrue);
      // A zero income line must not change the total.
      expect(report.totalIncome.minorUnits, 2000000);
    });
  });

  group('ProfitAndLoss date ranges', () {
    test('a range excludes later transactions', () {
      // Through day 2 only the purchase happened, which is a balance sheet
      // movement, so nothing reaches the profit and loss statement.
      final report = ProfitAndLoss.from(
        entries: workedExample(),
        currency: npr,
        to: day(2),
      );

      expect(report.totalIncome.isZero, isTrue);
      expect(report.totalExpenses.isZero, isTrue);
      expect(report.netResult.isZero, isTrue);
    });

    test('a range covering the sale but not the expense', () {
      // Through day 3: Sales 20,000 income, COGS 12,000 expense, profit 8,000.
      final report = ProfitAndLoss.from(
        entries: workedExample(),
        currency: npr,
        to: day(3),
      );

      expect(report.totalIncome.minorUnits, 2000000);
      expect(report.totalExpenses.minorUnits, 1200000);
      expect(report.netResult.minorUnits, 800000);
      expect(report.isProfit, isTrue);
    });

    test('a from date excludes earlier transactions', () {
      // From day 4: only the rent expense, so the period shows a loss.
      final report = ProfitAndLoss.from(
        entries: workedExample(),
        currency: npr,
        from: day(4),
      );

      expect(report.totalIncome.isZero, isTrue);
      expect(report.totalExpenses.minorUnits, 500000);
      expect(report.netResult.minorUnits, -500000);
      expect(report.isLoss, isTrue);
    });

    test('the whole range reproduces the full-period figures', () {
      final report = ProfitAndLoss.from(
        entries: workedExample(),
        currency: npr,
        from: day(1),
        to: day(4),
      );

      expect(report.netResult.minorUnits, 300000);
    });
  });

  group('ProfitAndLoss agrees with the trial balance', () {
    test(
        'the result equals income minus expenses computed from the trial balance',
        () {
      // Two independent derivations of the same number must agree.
      final entries = workedExample();

      final pnl = ProfitAndLoss.from(entries: entries, currency: npr);
      final trial = TrialBalance.from(entries: entries, currency: npr);

      var incomeFromTrial = Money.minor(0, npr);
      var expensesFromTrial = Money.minor(0, npr);
      for (final row in trial.rows) {
        if (row.account.type == AccountType.income) {
          incomeFromTrial = incomeFromTrial.add(row.balance);
        } else if (row.account.type == AccountType.expense) {
          expensesFromTrial = expensesFromTrial.add(row.balance);
        }
      }

      expect(pnl.totalIncome, incomeFromTrial);
      expect(pnl.totalExpenses, expensesFromTrial);
      expect(pnl.netResult, incomeFromTrial.subtract(expensesFromTrial));
      expect(pnl.netResult.minorUnits, 300000);
    });
  });
}
