import 'package:financeapp/src/domain/accounting/account_type.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/reporting/trial_balance.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:flutter_test/flutter_test.dart';

const npr = 'NPR';
const chart = ChartOfAccounts();

Money rs(int majorUnits) => Money.minor(majorUnits * 100, npr);

DateTime day(int d) => DateTime(2026, 9, d);

void main() {
  group('Chart integrity', () {
    test('every account id is unique', () {
      final ids = chart.all.map((a) => a.id).toList();
      final duplicates = _duplicates(ids);

      expect(duplicates, isEmpty,
          reason: 'duplicate account ids: $duplicates. Journal lines reference '
              'accounts by id, so a duplicate would be ambiguous.');
    });

    test('every account code is unique', () {
      final codes = chart.all.map((a) => a.code).toList();
      final duplicates = _duplicates(codes);

      expect(duplicates, isEmpty,
          reason: 'duplicate account codes: $duplicates');
    });

    test('ids are literal and stable, so they survive reordering', () {
      // The id must not be derived from the code or from a position, because
      // renumbering the chart would then silently repoint every historical
      // journal line at a different account.
      for (final account in chart.all) {
        expect(account.id, isNotEmpty);
        expect(account.id, isNot(equals(account.code)),
            reason: '${account.name} uses its code as its id, so renumbering '
                'the chart would corrupt history');
        expect(account.id, startsWith('acct-'),
            reason: '${account.name} has an unconventional id; keep the '
                'acct- prefix so ids are recognisable and obviously permanent');
      }
    });

    test('every code falls in the range for its account type', () {
      const expectedPrefix = {
        AccountType.asset: '1',
        AccountType.liability: '2',
        AccountType.equity: '3',
        AccountType.income: '4',
        AccountType.expense: '5',
      };

      for (final account in chart.all) {
        expect(account.code.length, 4,
            reason: '${account.name} code ${account.code} is not four digits');
        expect(account.code[0], expectedPrefix[account.type],
            reason: '${account.name} is a ${account.type.name} but its code '
                '${account.code} is outside the ${expectedPrefix[account.type]}xxx '
                'range');
      }
    });

    test('all accounts are listed in code order', () {
      final codes = chart.all.map((a) => a.code).toList();
      final sorted = [...codes]..sort();

      expect(codes, sorted, reason: 'the chart is documented as code-ordered');
    });

    test('every account reports the normal balance for its type', () {
      for (final account in chart.all) {
        expect(account.normalBalance, account.type.normalBalance);
      }
    });
  });

  group('Required accounts', () {
    // These are asserted by code so that deleting or renaming one fails the
    // build here, rather than breaking a report or a use case much later.
    const required = {
      '1010': 'Bank',
      '1020': 'Cash',
      '1030': 'Accounts Receivable',
      '1040': 'Inventory',
      '2010': 'Accounts Payable',
      '3010': "Owner's Equity",
      '4010': 'Sales Revenue',
      '5010': 'Office Rent',
      '5020': 'Cost of Goods Sold',
    };

    test('the accounts the rest of the system depends on are present', () {
      for (final entry in required.entries) {
        final account = chart.byCode(entry.key);
        expect(account, isNotNull, reason: 'missing account ${entry.key}');
        expect(account!.name, entry.value);
      }
    });

    test('lookup by code and by id both resolve', () {
      expect(chart.byCode('1010'), ChartOfAccounts.bank);
      expect(chart.byId('acct-bank'), ChartOfAccounts.bank);
      expect(chart.byCode('9999'), isNull);
      expect(chart.byId('acct-nonexistent'), isNull);
    });

    test('all five account types are represented', () {
      for (final type in AccountType.values) {
        expect(chart.ofType(type), isNotEmpty,
            reason: 'no ${type.name} accounts are defined');
      }
    });

    test('expense accounts are debit-normal and income accounts credit-normal',
        () {
      for (final account in chart.ofType(AccountType.expense)) {
        expect(account.normalBalance, NormalBalance.debit);
      }
      for (final account in chart.ofType(AccountType.income)) {
        expect(account.normalBalance, NormalBalance.credit);
      }
    });
  });

  group('The chart posts a complete business cycle', () {
    /// The worked example from the architecture specification, posted against
    /// the real chart rather than against test-local accounts.
    ///
    ///   Opening      Dr Bank 100,000        Cr Equity  100,000
    ///   Purchase     Dr Inventory 30,000    Cr Payable  30,000
    ///   Sale         Dr Bank 20,000         Cr Sales    20,000
    ///                Dr COGS 12,000         Cr Inventory 12,000
    ///   Expense      Dr Rent 5,000          Cr Bank       5,000
    List<JournalEntry> workedExample() => [
          JournalEntry(
            id: 'OB-1',
            date: day(1),
            description: 'Opening balance',
            lines: [
              JournalLine.debit(
                  account: ChartOfAccounts.bank, amount: rs(100000)),
              JournalLine.credit(
                  account: ChartOfAccounts.ownersEquity, amount: rs(100000)),
            ],
          ),
          JournalEntry(
            id: 'PU-1',
            date: day(2),
            description: 'Purchased goods on credit',
            lines: [
              JournalLine.debit(
                  account: ChartOfAccounts.inventory, amount: rs(30000)),
              JournalLine.credit(
                  account: ChartOfAccounts.payable, amount: rs(30000)),
            ],
          ),
          JournalEntry(
            id: 'SA-1',
            date: day(3),
            description: 'Sale with cost of goods sold',
            lines: [
              JournalLine.debit(
                  account: ChartOfAccounts.bank, amount: rs(20000)),
              JournalLine.credit(
                  account: ChartOfAccounts.salesRevenue, amount: rs(20000)),
              JournalLine.debit(
                  account: ChartOfAccounts.costOfGoodsSold, amount: rs(12000)),
              JournalLine.credit(
                  account: ChartOfAccounts.inventory, amount: rs(12000)),
            ],
          ),
          JournalEntry(
            id: 'EX-1',
            date: day(4),
            description: 'Office rent',
            lines: [
              JournalLine.debit(
                  account: ChartOfAccounts.officeRent, amount: rs(5000)),
              JournalLine.credit(
                  account: ChartOfAccounts.bank, amount: rs(5000)),
            ],
          ),
        ];

    test('produces the hand-computed balances', () {
      final report = TrialBalance.from(
        entries: workedExample(),
        currency: npr,
      );
      final byCode = {for (final row in report.rows) row.account.code: row};

      expect(byCode['1010']!.balance.minorUnits, 11500000);
      expect(byCode['1040']!.balance.minorUnits, 1800000);
      expect(byCode['2010']!.balance.minorUnits, 3000000);
      expect(byCode['3010']!.balance.minorUnits, 10000000);
      expect(byCode['4010']!.balance.minorUnits, 2000000);
      expect(byCode['5010']!.balance.minorUnits, 500000);
      expect(byCode['5020']!.balance.minorUnits, 1200000);
    });

    test('balances at 167,000', () {
      final report = TrialBalance.from(
        entries: workedExample(),
        currency: npr,
      );

      expect(report.isBalanced, isTrue);
      expect(report.totalDebits.minorUnits, 16700000);
      expect(report.totalCredits.minorUnits, 16700000);
      expect(report.assertBalanced, returnsNormally);
    });

    test('the accounting equation holds on the real chart', () {
      final report = TrialBalance.from(
        entries: workedExample(),
        currency: npr,
      );
      final byCode = {for (final row in report.rows) row.account.code: row};

      final assets = byCode['1010']!.balance.add(byCode['1040']!.balance);
      final profit = byCode['4010']!
          .balance
          .subtract(byCode['5020']!.balance)
          .subtract(byCode['5010']!.balance);
      final liabilitiesAndEquity =
          byCode['2010']!.balance.add(byCode['3010']!.balance).add(profit);

      expect(assets, liabilitiesAndEquity,
          reason: 'assets must equal liabilities plus equity');
    });
  });
}

List<String> _duplicates(List<String> values) {
  final seen = <String>{};
  final duplicates = <String>{};
  for (final value in values) {
    if (!seen.add(value)) duplicates.add(value);
  }
  return duplicates.toList()..sort();
}
