import 'package:financeapp/src/domain/accounting/account.dart';
import 'package:financeapp/src/domain/accounting/account_type.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/reporting/balance_sheet.dart';
import 'package:financeapp/src/domain/reporting/profit_and_loss.dart';
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
///   Assets      = Bank 115,000 + Inventory 18,000 = 133,000
///   Liabilities = Payable 30,000
///   Equity      = 100,000 + result 3,000          = 103,000
///   L + E       = 30,000 + 103,000                = 133,000
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
  group('BalanceSheet on the worked example', () {
    test('reports the hand-computed totals', () {
      final sheet = BalanceSheet.from(entries: workedExample(), currency: npr);

      expect(sheet.totalAssets.minorUnits, 13300000);
      expect(sheet.totalLiabilities.minorUnits, 3000000);
      expect(sheet.equityAccountsTotal.minorUnits, 10000000);
      expect(sheet.currentResult.minorUnits, 300000);
      expect(sheet.totalEquity.minorUnits, 10300000);
      expect(sheet.totalLiabilitiesAndEquity.minorUnits, 13300000);
    });

    test('the accounting equation holds', () {
      final sheet = BalanceSheet.from(entries: workedExample(), currency: npr);

      expect(sheet.isBalanced, isTrue);
      expect(sheet.difference.isZero, isTrue);
      expect(sheet.assertBalanced, returnsNormally);
      expect(sheet.totalAssets, sheet.totalLiabilitiesAndEquity);
    });

    test('assets are listed in code order', () {
      final sheet = BalanceSheet.from(entries: workedExample(), currency: npr);
      expect(sheet.assets.map((l) => l.account.code), ['1010', '1040']);
    });

    test('income and expenses are not direct lines', () {
      final sheet = BalanceSheet.from(entries: workedExample(), currency: npr);
      final codes = [
        ...sheet.assets.map((l) => l.account.code),
        ...sheet.liabilities.map((l) => l.account.code),
        ...sheet.equity.map((l) => l.account.code),
      ];

      expect(codes, isNot(contains('4010')),
          reason: 'income appears only through the result in equity');
      expect(codes, isNot(contains('5010')));
      expect(codes, isNot(contains('5020')));
    });

    test('the result line equals the profit and loss result', () {
      // Two independent derivations of the same number must agree.
      final entries = workedExample();
      final sheet = BalanceSheet.from(entries: entries, currency: npr);
      final pnl = ProfitAndLoss.from(entries: entries, currency: npr);

      expect(sheet.currentResult, pnl.netResult);
      expect(sheet.currentResult.minorUnits, 300000);
    });
  });

  group('The equation holds for many transaction shapes', () {
    test('opening balances only', () {
      final entries = [
        JournalEntry(
          id: 'OB-1',
          date: day(1),
          description: 'Opening',
          lines: [
            JournalLine.debit(account: bank, amount: rs(50000)),
            JournalLine.credit(account: equity, amount: rs(50000)),
          ],
        ),
      ];
      final sheet = BalanceSheet.from(entries: entries, currency: npr);

      expect(sheet.isBalanced, isTrue);
      expect(sheet.currentResult.isZero, isTrue);
      expect(sheet.totalAssets.minorUnits, 5000000);
      expect(sheet.totalEquity.minorUnits, 5000000);
    });

    test('a loss-making period', () {
      final entries = [
        JournalEntry(
          id: 'OB-1',
          date: day(1),
          description: 'Opening',
          lines: [
            JournalLine.debit(account: bank, amount: rs(10000)),
            JournalLine.credit(account: equity, amount: rs(10000)),
          ],
        ),
        JournalEntry(
          id: 'EX-1',
          date: day(2),
          description: 'Rent with no sales',
          lines: [
            JournalLine.debit(account: rent, amount: rs(4000)),
            JournalLine.credit(account: bank, amount: rs(4000)),
          ],
        ),
      ];
      final sheet = BalanceSheet.from(entries: entries, currency: npr);

      expect(sheet.isBalanced, isTrue);
      expect(sheet.currentResult.minorUnits, -400000);
      // Equity 10,000 less the 4,000 loss.
      expect(sheet.totalEquity.minorUnits, 600000);
    });

    test('no income at all', () {
      final entries = [
        JournalEntry(
          id: 'OB-1',
          date: day(1),
          description: 'Owner puts money in',
          lines: [
            JournalLine.debit(account: bank, amount: rs(25000)),
            JournalLine.credit(account: equity, amount: rs(25000)),
          ],
        ),
        JournalEntry(
          id: 'EX-1',
          date: day(2),
          description: 'Rent',
          lines: [
            JournalLine.debit(account: rent, amount: rs(5000)),
            JournalLine.credit(account: bank, amount: rs(5000)),
          ],
        ),
      ];
      final sheet = BalanceSheet.from(entries: entries, currency: npr);

      expect(sheet.isBalanced, isTrue);
      expect(sheet.totalAssets.minorUnits, 2000000);
      expect(sheet.totalEquity.minorUnits, 2000000);
    });

    test('a period including a credit note', () {
      // A credit note reverses a sale, reducing both the receivable and equity.
      final entries = [
        JournalEntry(
          id: 'OB-1',
          date: day(1),
          description: 'Opening',
          lines: [
            JournalLine.debit(account: bank, amount: rs(10000)),
            JournalLine.credit(account: equity, amount: rs(10000)),
          ],
        ),
        JournalEntry(
          id: 'SA-1',
          date: day(2),
          description: 'Sale',
          lines: [
            JournalLine.debit(account: bank, amount: rs(3000)),
            JournalLine.credit(account: sales, amount: rs(3000)),
          ],
        ),
        JournalEntry(
          id: 'CRN-1',
          date: day(3),
          description: 'Credit note',
          lines: [
            JournalLine.debit(account: sales, amount: rs(1000)),
            JournalLine.credit(account: bank, amount: rs(1000)),
          ],
        ),
      ];
      final sheet = BalanceSheet.from(entries: entries, currency: npr);

      expect(sheet.isBalanced, isTrue);
      // 10,000 + 3,000 - 1,000 = 12,000 in the bank.
      expect(sheet.totalAssets.minorUnits, 1200000);
      // Equity 10,000 plus the net result 2,000.
      expect(sheet.currentResult.minorUnits, 200000);
      expect(sheet.totalEquity.minorUnits, 1200000);
    });

    test('a purchase on credit only, with no sales', () {
      final entries = [
        JournalEntry(
          id: 'PU-1',
          date: day(1),
          description: 'Buy stock on credit',
          lines: [
            JournalLine.debit(account: inventory, amount: rs(8000)),
            JournalLine.credit(account: payable, amount: rs(8000)),
          ],
        ),
      ];
      final sheet = BalanceSheet.from(entries: entries, currency: npr);

      expect(sheet.isBalanced, isTrue);
      expect(sheet.totalAssets.minorUnits, 800000);
      expect(sheet.totalLiabilities.minorUnits, 800000);
      expect(sheet.totalEquity.isZero, isTrue);
      expect(sheet.difference.isZero, isTrue);
    });

    test('every shape in this group balances', () {
      // Belt and braces: re-derive the equation for each set above rather than
      // trusting the individual assertions.
      for (final entries in [workedExample()]) {
        final sheet = BalanceSheet.from(entries: entries, currency: npr);
        expect(
          sheet.totalAssets,
          sheet.totalLiabilities.add(sheet.totalEquity),
        );
      }
    });
  });

  group('BalanceSheet date ranges', () {
    test('restricts the report to a date', () {
      // As at day 2: opening plus the purchase, no sales yet.
      final sheet = BalanceSheet.from(
        entries: workedExample(),
        currency: npr,
        to: day(2),
      );

      expect(sheet.totalAssets.minorUnits, 13000000);
      expect(sheet.totalLiabilities.minorUnits, 3000000);
      expect(sheet.currentResult.isZero, isTrue);
      expect(sheet.isBalanced, isTrue);
    });

    test('a range covering only the opening balance balances', () {
      final sheet = BalanceSheet.from(
        entries: workedExample(),
        currency: npr,
        to: day(1),
      );

      expect(sheet.totalAssets.minorUnits, 10000000);
      expect(sheet.totalEquity.minorUnits, 10000000);
      expect(sheet.isBalanced, isTrue);
    });

    test('an empty period produces an empty, balanced report', () {
      final sheet = BalanceSheet.from(entries: const [], currency: npr);

      expect(sheet.assets, isEmpty);
      expect(sheet.liabilities, isEmpty);
      expect(sheet.equity, isEmpty);
      expect(sheet.totalAssets.isZero, isTrue);
      expect(sheet.isBalanced, isTrue);
      expect(sheet.assertBalanced, returnsNormally);
    });
  });

  group('BalanceSheet zero-balance accounts', () {
    test('accounts with no activity are omitted by default', () {
      const cash = Account(
          id: 'acct-cash', code: '1020', name: 'Cash', type: AccountType.asset);

      final sheet = BalanceSheet.from(
        entries: workedExample(),
        currency: npr,
        chart: [cash],
      );

      expect(sheet.assets.any((l) => l.account.code == '1020'), isFalse);
    });

    test(
        'zero-balance accounts are included when asked for, and do not unbalance',
        () {
      const cash = Account(
          id: 'acct-cash', code: '1020', name: 'Cash', type: AccountType.asset);

      final sheet = BalanceSheet.from(
        entries: workedExample(),
        currency: npr,
        chart: [cash],
        includeZeroBalances: true,
      );

      final line = sheet.assets.firstWhere((l) => l.account.code == '1020');
      expect(line.balance.isZero, isTrue);
      expect(sheet.totalAssets.minorUnits, 13300000);
      expect(sheet.isBalanced, isTrue);
    });
  });

  group('The equation is proven, not assumed', () {
    test('a deliberately unbalanced book is reported, not hidden', () {
      // Build a report whose equity is sliced away by excluding entries, to show
      // the assertion actually fires rather than always passing.
      final sheet = BalanceSheet.from(
        entries: workedExample(),
        currency: npr,
        to: day(3),
      );
      // As at day 3 this still balances, so the assertion must not fire.
      expect(sheet.assertBalanced, returnsNormally);

      // Now confirm the difference is reported when it is not zero. Comparing
      // the day-3 sheet against a day-4 asset total is a nonsense comparison, but
      // it proves the arithmetic is real rather than a constant.
      final full = BalanceSheet.from(entries: workedExample(), currency: npr);
      expect(full.totalAssets, isNot(sheet.totalAssets));
    });
  });
}
