import 'package:financeapp/src/domain/accounting/account.dart';
import 'package:financeapp/src/domain/accounting/account_type.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/reporting/general_ledger.dart';
import 'package:financeapp/src/domain/reporting/trial_balance.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:flutter_test/flutter_test.dart';

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
const cash = Account(
    id: 'acct-cash', code: '1020', name: 'Cash', type: AccountType.asset);

/// The worked example from the architecture specification.
///
/// Hand-computed, independently of any report code:
///
///   Opening      Dr Bank 100,000        Cr Equity  100,000
///   Purchase     Dr Inventory 30,000    Cr Payable  30,000
///   Sale         Dr Bank 20,000         Cr Sales    20,000
///                Dr COGS 12,000         Cr Inventory 12,000
///   Expense      Dr Rent 5,000          Cr Bank       5,000
///
///   Bank      120,000 Dr -  5,000 Cr = 115,000
///   Inventory  30,000 Dr - 12,000 Cr =  18,000
///   Payable     0    Dr - 30,000 Cr =  30,000
///   Equity      0    Dr -100,000 Cr = 100,000
///   Sales       0    Dr - 20,000 Cr =  20,000
///   Rent        5,000 Dr -  0    Cr =   5,000
///   COGS       12,000 Dr -  0    Cr =  12,000
///
///   Totals: 167,000 Dr = 167,000 Cr
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
  group('TrialBalance', () {
    test('reports every account with activity, in chart order', () {
      final report = TrialBalance.from(
        entries: workedExample(),
        currency: npr,
      );

      expect(
        report.rows.map((r) => r.account.code),
        ['1010', '1040', '2010', '3010', '4010', '5010', '5020'],
      );
    });

    test('reports the hand-computed balance for each account', () {
      final report = TrialBalance.from(entries: workedExample(), currency: npr);
      final byCode = {for (final row in report.rows) row.account.code: row};

      expect(byCode['1010']!.balance.minorUnits, 11500000);
      expect(byCode['1040']!.balance.minorUnits, 1800000);
      expect(byCode['2010']!.balance.minorUnits, 3000000);
      expect(byCode['3010']!.balance.minorUnits, 10000000);
      expect(byCode['4010']!.balance.minorUnits, 2000000);
      expect(byCode['5010']!.balance.minorUnits, 500000);
      expect(byCode['5020']!.balance.minorUnits, 1200000);
    });

    test('reports the debit and credit totals separately from the balance', () {
      final report = TrialBalance.from(entries: workedExample(), currency: npr);
      final bankRow = report.rows.firstWhere((r) => r.account.code == '1010');

      expect(bankRow.debitTotal.minorUnits, 12000000);
      expect(bankRow.creditTotal.minorUnits, 500000);
      expect(bankRow.balance.minorUnits, 11500000);
    });

    test('reports credit-normal accounts with a positive balance', () {
      final report = TrialBalance.from(entries: workedExample(), currency: npr);
      final payableRow =
          report.rows.firstWhere((r) => r.account.code == '2010');

      expect(payableRow.debitTotal.isZero, isTrue);
      expect(payableRow.creditTotal.minorUnits, 3000000);
      expect(payableRow.balance.minorUnits, 3000000,
          reason: 'a liability balance is reported in its natural direction, '
              'so it reads as money owed rather than as a negative number');
    });

    test('proves itself: total debits equal total credits', () {
      final report = TrialBalance.from(entries: workedExample(), currency: npr);

      expect(report.totalDebits.minorUnits, 16700000);
      expect(report.totalCredits.minorUnits, 16700000);
      expect(report.isBalanced, isTrue);
      expect(report.assertBalanced, returnsNormally);
    });

    test('the totals agree with its own rows', () {
      final report = TrialBalance.from(entries: workedExample(), currency: npr);

      final rowDebits = Money.sum(report.rows.map((r) => r.debitTotal), npr);
      final rowCredits = Money.sum(report.rows.map((r) => r.creditTotal), npr);

      expect(report.totalDebits, rowDebits);
      expect(report.totalCredits, rowCredits);
    });

    test('an empty ledger produces a balanced, empty report', () {
      final report = TrialBalance.from(entries: [], currency: npr);

      expect(report.rows, isEmpty);
      expect(report.totalDebits.isZero, isTrue);
      expect(report.totalCredits.isZero, isTrue);
      expect(report.isBalanced, isTrue);
    });

    test('a date range restricts the report', () {
      // Through day 2: only the opening and the purchase.
      final report = TrialBalance.from(
        entries: workedExample(),
        currency: npr,
        to: day(2),
      );

      final byCode = {for (final row in report.rows) row.account.code: row};
      expect(byCode['1010']!.balance.minorUnits, 10000000,
          reason: 'the sale and the expense are both after day 2');
      expect(byCode['1040']!.balance.minorUnits, 3000000);
      expect(byCode['2010']!.balance.minorUnits, 3000000);
      expect(byCode.containsKey('4010'), isFalse,
          reason: 'no revenue has been earned by day 2');
      expect(report.isBalanced, isTrue);
    });

    test('a from date excludes earlier transactions', () {
      final report = TrialBalance.from(
        entries: workedExample(),
        currency: npr,
        from: day(3),
      );

      final byCode = {for (final row in report.rows) row.account.code: row};
      expect(byCode['1010']!.balance.minorUnits, 1500000,
          reason: 'only the day 3 and day 4 bank movements: 20,000 - 5,000');
      expect(byCode.containsKey('3010'), isFalse,
          reason: 'the opening entry is before the from date');
      expect(report.isBalanced, isTrue);
    });

    test('accounts with no activity are omitted by default', () {
      final report = TrialBalance.from(
        entries: workedExample(),
        currency: npr,
        chart: [cash],
      );

      expect(report.rows.any((r) => r.account.code == '1020'), isFalse);
    });

    test('zero-balance accounts can be requested explicitly', () {
      final report = TrialBalance.from(
        entries: workedExample(),
        currency: npr,
        chart: [cash],
        includeZeroBalances: true,
      );

      final cashRow = report.rows.firstWhere((r) => r.account.code == '1020');
      expect(cashRow.balance.isZero, isTrue);
      expect(cashRow.debitTotal.isZero, isTrue);
      expect(cashRow.creditTotal.isZero, isTrue);
    });
  });

  group('GeneralLedger', () {
    test('lists every posting to one account with a running balance', () {
      final report = GeneralLedger.forAccount(
        account: bank,
        entries: workedExample(),
        currency: npr,
      );

      expect(report.lines.length, 3);
      expect(report.lines.map((l) => l.entry.id), ['OB-1', 'SA-1', 'EX-1']);
      expect(
        report.lines.map((l) => l.runningBalance.minorUnits),
        [10000000, 12000000, 11500000],
      );
    });

    test('an account with no activity produces an empty ledger, not an error',
        () {
      final report = GeneralLedger.forAccount(
        account: cash,
        entries: workedExample(),
        currency: npr,
      );

      expect(report.lines, isEmpty);
      expect(report.openingBalance.isZero, isTrue);
      expect(report.closingBalance.isZero, isTrue);
    });

    test('the closing balance agrees with the trial balance', () {
      final entries = workedExample();
      final ledger = GeneralLedger.forAccount(
        account: bank,
        entries: entries,
        currency: npr,
      );
      final trial = TrialBalance.from(entries: entries, currency: npr);
      final bankRow = trial.rows.firstWhere((r) => r.account.code == '1010');

      expect(ledger.closingBalance, bankRow.balance,
          reason: 'two independent derivations of the same number must agree');
      expect(ledger.closingBalance.minorUnits, 11500000);
    });

    test('a credit-normal account accumulates in its natural direction', () {
      final report = GeneralLedger.forAccount(
        account: sales,
        entries: workedExample(),
        currency: npr,
      );

      expect(report.lines.length, 1);
      expect(report.lines.single.runningBalance.minorUnits, 2000000);
      expect(report.closingBalance.minorUnits, 2000000);
    });

    test('a date range produces an opening balance from prior history', () {
      // From day 3 onwards. Bank already held 100,000 before the range.
      final report = GeneralLedger.forAccount(
        account: bank,
        entries: workedExample(),
        currency: npr,
        from: day(3),
      );

      expect(report.openingBalance.minorUnits, 10000000,
          reason: 'the opening entry is before the range and must be carried '
              'in as the opening balance, not lost');
      expect(report.lines.map((l) => l.entry.id), ['SA-1', 'EX-1']);
      expect(
        report.lines.map((l) => l.runningBalance.minorUnits),
        [12000000, 11500000],
      );
      expect(report.closingBalance.minorUnits, 11500000);
    });

    test('a date range through an earlier date excludes later postings', () {
      final report = GeneralLedger.forAccount(
        account: bank,
        entries: workedExample(),
        currency: npr,
        to: day(3),
      );

      expect(report.lines.map((l) => l.entry.id), ['OB-1', 'SA-1']);
      expect(report.closingBalance.minorUnits, 12000000);
      expect(report.openingBalance.isZero, isTrue);
    });

    test('the opening and closing balances reconcile with the lines', () {
      final report = GeneralLedger.forAccount(
        account: bank,
        entries: workedExample(),
        currency: npr,
        from: day(3),
      );

      final movement = Money.sum(
        report.lines.map((l) => l.movement),
        npr,
      );
      expect(report.openingBalance.add(movement), report.closingBalance);
    });

    test('each line exposes its own entry and posting side', () {
      final report = GeneralLedger.forAccount(
        account: bank,
        entries: workedExample(),
        currency: npr,
      );

      expect(report.lines[0].line.isDebit, isTrue);
      expect(report.lines[0].line.debit.minorUnits, 10000000);
      expect(report.lines[0].entry.description, 'Opening balance');
      expect(report.lines[2].line.isCredit, isTrue);
      expect(report.lines[2].line.credit.minorUnits, 500000);
    });

    test('postings are ordered by date even if the entries arrive unordered',
        () {
      final shuffled = workedExample().reversed.toList();
      final report = GeneralLedger.forAccount(
        account: bank,
        entries: shuffled,
        currency: npr,
      );

      expect(report.lines.map((l) => l.entry.id), ['OB-1', 'SA-1', 'EX-1']);
      expect(report.closingBalance.minorUnits, 11500000);
    });
  });

  group('Reports agree with each other', () {
    test('every account closing balance matches its trial balance row', () {
      final entries = workedExample();
      final trial = TrialBalance.from(entries: entries, currency: npr);

      for (final row in trial.rows) {
        final ledger = GeneralLedger.forAccount(
          account: row.account,
          entries: entries,
          currency: npr,
        );
        expect(
          ledger.closingBalance,
          row.balance,
          reason: '${row.account.name} disagrees between the two reports',
        );
      }
    });
  });
}
