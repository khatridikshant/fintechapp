import 'package:financeapp/src/domain/accounting/account.dart';
import 'package:financeapp/src/domain/accounting/account_type.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/accounting/ledger.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:flutter_test/flutter_test.dart';

const npr = 'NPR';
const usd = 'USD';

Money rs(int majorUnits) => Money.minor(majorUnits * 100, npr);

DateTime day(int d) => DateTime(2026, 9, d);

const bank = Account(
    id: 'acct-bank', code: '1010', name: 'Bank', type: AccountType.asset);
const cash = Account(
    id: 'acct-cash', code: '1020', name: 'Cash', type: AccountType.asset);
const receivable = Account(
    id: 'acct-ar',
    code: '1030',
    name: 'Accounts Receivable',
    type: AccountType.asset);
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

JournalEntry entry({
  required List<JournalLine> lines,
  String id = 'JE-1',
  DateTime? date,
  String description = 'test entry',
  String? reference,
}) =>
    JournalEntry(
      id: id,
      date: date ?? day(29),
      description: description,
      reference: reference,
      lines: lines,
    );

void main() {
  group('AccountType', () {
    test('assets and expenses have a debit normal balance', () {
      expect(AccountType.asset.normalBalance, NormalBalance.debit);
      expect(AccountType.expense.normalBalance, NormalBalance.debit);
    });

    test('liabilities, equity and income have a credit normal balance', () {
      expect(AccountType.liability.normalBalance, NormalBalance.credit);
      expect(AccountType.equity.normalBalance, NormalBalance.credit);
      expect(AccountType.income.normalBalance, NormalBalance.credit);
    });

    test('separates balance sheet types from profit and loss types', () {
      expect(AccountType.asset.isBalanceSheet, isTrue);
      expect(AccountType.liability.isBalanceSheet, isTrue);
      expect(AccountType.equity.isBalanceSheet, isTrue);
      expect(AccountType.income.isBalanceSheet, isFalse);
      expect(AccountType.expense.isBalanceSheet, isFalse);
      expect(AccountType.income.isProfitAndLoss, isTrue);
      expect(AccountType.expense.isProfitAndLoss, isTrue);
    });
  });

  group('Account', () {
    test('exposes its identity and carries its normal balance', () {
      expect(bank.code, '1010');
      expect(bank.name, 'Bank');
      expect(bank.type, AccountType.asset);
      expect(bank.normalBalance, NormalBalance.debit);
      expect(sales.normalBalance, NormalBalance.credit);
    });

    test('compares by identity, not by field value', () {
      const same = Account(
          id: 'acct-bank',
          code: '9999',
          name: 'Renamed',
          type: AccountType.asset);
      expect(same, equals(bank));
      expect(same.hashCode, bank.hashCode);
      expect(cash, isNot(equals(bank)));
    });
  });

  group('JournalLine', () {
    test('a debit line carries the debit and a zero credit', () {
      final line = JournalLine.debit(account: rent, amount: rs(500));
      expect(line.isDebit, isTrue);
      expect(line.isCredit, isFalse);
      expect(line.debit.minorUnits, 50000);
      expect(line.credit.minorUnits, 0);
    });

    test('a credit line carries the credit and a zero debit', () {
      final line = JournalLine.credit(account: bank, amount: rs(500));
      expect(line.isCredit, isTrue);
      expect(line.isDebit, isFalse);
      expect(line.credit.minorUnits, 50000);
      expect(line.debit.minorUnits, 0);
    });

    test('the amount is the non-zero side', () {
      expect(
          JournalLine.debit(account: rent, amount: rs(500)).amount.minorUnits,
          50000);
      expect(
          JournalLine.credit(account: bank, amount: rs(250)).amount.minorUnits,
          25000);
    });

    test('rejects a zero amount', () {
      // A line with neither a debit nor a credit is meaningless and must not
      // be constructible.
      expect(() => JournalLine.debit(account: rent, amount: rs(0)),
          throwsArgumentError);
      expect(() => JournalLine.credit(account: bank, amount: rs(0)),
          throwsArgumentError);
    });

    test('rejects a negative amount', () {
      // Negative amounts are a sign-convention error. A reduction is the
      // opposite side of the entry, not a negative line.
      const negative = Money.minor(-50000, npr);
      expect(() => JournalLine.debit(account: rent, amount: negative),
          throwsArgumentError);
      expect(() => JournalLine.credit(account: bank, amount: negative),
          throwsArgumentError);
    });

    test('the opposite of a debit line is a credit line of the same amount',
        () {
      final line = JournalLine.debit(account: rent, amount: rs(500));
      final reversed = line.opposite;
      expect(reversed.account, rent);
      expect(reversed.isCredit, isTrue);
      expect(reversed.credit.minorUnits, 50000);
    });
  });

  group('JournalEntry posting rules', () {
    test('accepts a balanced entry and reports its totals', () {
      final e = entry(lines: [
        JournalLine.debit(account: rent, amount: rs(500)),
        JournalLine.credit(account: bank, amount: rs(500)),
      ]);
      expect(e.isBalanced, isTrue);
      expect(e.totalDebits.minorUnits, 50000);
      expect(e.totalCredits.minorUnits, 50000);
      expect(e.currency, npr);
    });

    test('rejects an unbalanced entry', () {
      expect(
        () => entry(lines: [
          JournalLine.debit(account: rent, amount: rs(500)),
          JournalLine.credit(account: bank, amount: rs(400)),
        ]),
        throwsA(isA<UnbalancedJournalException>()),
      );
    });

    test('the rejection names both totals so the cause is obvious', () {
      try {
        entry(lines: [
          JournalLine.debit(account: rent, amount: rs(500)),
          JournalLine.credit(account: bank, amount: rs(400)),
        ]);
        fail('expected the entry to be rejected');
      } on UnbalancedJournalException catch (e) {
        expect(e.totalDebits.minorUnits, 50000);
        expect(e.totalCredits.minorUnits, 40000);
        expect(e.toString(), contains('unbalanced'));
      }
    });

    test('accepts a multi-line entry that balances overall', () {
      // A sale with cost of goods sold: four lines, balanced.
      final e = entry(lines: [
        JournalLine.debit(account: receivable, amount: rs(3000)),
        JournalLine.credit(account: sales, amount: rs(3000)),
        JournalLine.debit(account: cogs, amount: rs(2000)),
        JournalLine.credit(account: inventory, amount: rs(2000)),
      ]);
      expect(e.isBalanced, isTrue);
      expect(e.totalDebits.minorUnits, 500000);
    });

    test('rejects an entry with fewer than two lines', () {
      expect(
        () => entry(lines: [
          JournalLine.debit(account: rent, amount: rs(500)),
        ]),
        throwsArgumentError,
      );
      expect(() => entry(lines: []), throwsArgumentError);
    });

    test('rejects an entry that mixes currencies', () {
      expect(
        () => entry(lines: [
          JournalLine.debit(account: rent, amount: rs(500)),
          JournalLine.credit(
              account: bank, amount: const Money.minor(50000, usd)),
        ]),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });

    test('carries its reference and description', () {
      final e = entry(
        lines: [
          JournalLine.debit(account: rent, amount: rs(500)),
          JournalLine.credit(account: bank, amount: rs(500)),
        ],
        reference: 'INV-1042',
        description: 'Office rent for September',
      );
      expect(e.reference, 'INV-1042');
      expect(e.description, 'Office rent for September');
    });
  });

  group('JournalEntry immutability', () {
    test('the lines list cannot be modified after construction', () {
      final e = entry(lines: [
        JournalLine.debit(account: rent, amount: rs(500)),
        JournalLine.credit(account: bank, amount: rs(500)),
      ]);
      expect(
        () => e.lines.add(JournalLine.debit(account: rent, amount: rs(1))),
        throwsUnsupportedError,
      );
    });

    test('the source list cannot be used to mutate the entry', () {
      final source = <JournalLine>[
        JournalLine.debit(account: rent, amount: rs(500)),
        JournalLine.credit(account: bank, amount: rs(500)),
      ];
      final e = entry(lines: source);
      source.clear();
      expect(e.lines.length, 2);
    });
  });

  group('Reversal', () {
    test('swaps every debit and credit', () {
      final original = entry(
        id: 'JE-1',
        lines: [
          JournalLine.debit(account: rent, amount: rs(500)),
          JournalLine.credit(account: bank, amount: rs(500)),
        ],
      );
      final reversal =
          original.reverse(id: 'JE-2', date: day(30), reason: 'posted twice');

      expect(reversal.id, 'JE-2');
      expect(reversal.reference, 'JE-1');
      expect(reversal.description, 'posted twice');
      expect(reversal.lines[0].account, rent);
      expect(reversal.lines[0].isCredit, isTrue);
      expect(reversal.lines[1].account, bank);
      expect(reversal.lines[1].isDebit, isTrue);
      expect(reversal.isBalanced, isTrue);
    });

    test('leaves the original entry untouched', () {
      final original = entry(lines: [
        JournalLine.debit(account: rent, amount: rs(500)),
        JournalLine.credit(account: bank, amount: rs(500)),
      ]);
      original.reverse(id: 'JE-2', date: day(30));
      expect(original.lines[0].isDebit, isTrue);
      expect(original.lines[1].isCredit, isTrue);
      expect(original.reference, isNull);
    });

    test('original plus reversal nets to zero for every account', () {
      final original = entry(id: 'JE-1', lines: [
        JournalLine.debit(account: receivable, amount: rs(3000)),
        JournalLine.credit(account: sales, amount: rs(3000)),
      ]);
      final reversal = original.reverse(id: 'JE-2', date: day(30));

      final ledger = Ledger(entries: [original, reversal], currency: npr);
      expect(ledger.balanceOf(receivable).isZero, isTrue);
      expect(ledger.balanceOf(sales).isZero, isTrue);
    });
  });

  group('Ledger balances', () {
    test('an asset balance is debits minus credits', () {
      final ledger = Ledger(currency: npr, entries: [
        entry(id: 'JE-1', lines: [
          JournalLine.debit(account: bank, amount: rs(1000)),
          JournalLine.credit(account: sales, amount: rs(1000)),
        ]),
        entry(id: 'JE-2', lines: [
          JournalLine.debit(account: rent, amount: rs(250)),
          JournalLine.credit(account: bank, amount: rs(250)),
        ]),
      ]);
      expect(ledger.balanceOf(bank).minorUnits, 75000);
    });

    test('an income balance is credits minus debits, reported positive', () {
      final ledger = Ledger(currency: npr, entries: [
        entry(lines: [
          JournalLine.debit(account: receivable, amount: rs(3000)),
          JournalLine.credit(account: sales, amount: rs(3000)),
        ]),
      ]);
      expect(ledger.balanceOf(sales).minorUnits, 300000);
    });

    test('an expense balance is debits minus credits', () {
      final ledger = Ledger(currency: npr, entries: [
        entry(lines: [
          JournalLine.debit(account: rent, amount: rs(500)),
          JournalLine.credit(account: bank, amount: rs(500)),
        ]),
      ]);
      expect(ledger.balanceOf(rent).minorUnits, 50000);
    });

    test('an untouched account has a zero balance', () {
      final ledger = Ledger(currency: npr, entries: []);
      expect(ledger.balanceOf(cash).isZero, isTrue);
    });

    test('debit and credit totals are reported without a normal balance', () {
      final ledger = Ledger(currency: npr, entries: [
        entry(lines: [
          JournalLine.debit(account: bank, amount: rs(1000)),
          JournalLine.credit(account: sales, amount: rs(1000)),
        ]),
      ]);
      expect(ledger.debitTotalOf(bank).minorUnits, 100000);
      expect(ledger.creditTotalOf(bank).minorUnits, 0);
      expect(ledger.creditTotalOf(sales).minorUnits, 100000);
    });

    test('balances accumulate across many entries', () {
      final entries = <JournalEntry>[
        for (var i = 1; i <= 5; i++)
          entry(id: 'JE-$i', lines: [
            JournalLine.debit(account: cash, amount: rs(100)),
            JournalLine.credit(account: sales, amount: rs(100)),
          ]),
      ];
      final ledger = Ledger(currency: npr, entries: entries);
      expect(ledger.balanceOf(cash).minorUnits, 50000);
      expect(ledger.balanceOf(sales).minorUnits, 50000);
    });
  });

  group('Ledger decimal exactness', () {
    test('0.1 plus 0.2 is exactly 0.30, never 0.30000000000000004', () {
      final ledger = Ledger(currency: npr, entries: [
        entry(id: 'JE-1', lines: [
          JournalLine.debit(
              account: cash, amount: Money.fromMajorUnits(0.1, npr)),
          JournalLine.credit(
              account: sales, amount: Money.fromMajorUnits(0.1, npr)),
        ]),
        entry(id: 'JE-2', lines: [
          JournalLine.debit(
              account: cash, amount: Money.fromMajorUnits(0.2, npr)),
          JournalLine.credit(
              account: sales, amount: Money.fromMajorUnits(0.2, npr)),
        ]),
      ]);
      expect(ledger.balanceOf(cash).minorUnits, 30);
      expect(ledger.balanceOf(cash).minorUnits,
          Money.fromMajorUnits(0.3, npr).minorUnits);
    });
  });

  group('Business scenarios', () {
    test('a credit sale then a payment settles the receivable', () {
      final invoice = entry(
        id: 'JE-100',
        description: 'Invoice INV-1042',
        reference: 'INV-1042',
        lines: [
          JournalLine.debit(account: receivable, amount: rs(3000)),
          JournalLine.credit(account: sales, amount: rs(3000)),
        ],
      );
      final payment = entry(
        id: 'JE-101',
        description: 'Payment against INV-1042',
        reference: 'INV-1042',
        lines: [
          JournalLine.debit(account: bank, amount: rs(3000)),
          JournalLine.credit(account: receivable, amount: rs(3000)),
        ],
      );

      final ledger = Ledger(currency: npr, entries: [invoice, payment]);
      expect(ledger.balanceOf(receivable).isZero, isTrue,
          reason: 'the customer has paid in full');
      expect(ledger.balanceOf(bank).minorUnits, 300000);
      expect(ledger.balanceOf(sales).minorUnits, 300000);
    });

    test('a cash expense reduces bank and increases the expense', () {
      final ledger = Ledger(currency: npr, entries: [
        entry(description: 'Electricity bill', lines: [
          JournalLine.debit(account: rent, amount: rs(1000)),
          JournalLine.credit(account: bank, amount: rs(1000)),
        ]),
      ]);
      expect(ledger.balanceOf(rent).minorUnits, 100000);
      expect(ledger.balanceOf(bank).minorUnits, -100000,
          reason: 'a debit-normal account can go negative when overdrawn');
    });

    test('a sale with inventory yields the correct gross profit', () {
      final sale = entry(
        id: 'JE-200',
        description: 'Sold 2 keyboards',
        lines: [
          JournalLine.debit(account: cash, amount: rs(3000)),
          JournalLine.credit(account: sales, amount: rs(3000)),
          JournalLine.debit(account: cogs, amount: rs(2000)),
          JournalLine.credit(account: inventory, amount: rs(2000)),
        ],
      );

      final ledger = Ledger(currency: npr, entries: [sale]);
      final revenue = ledger.balanceOf(sales);
      final cost = ledger.balanceOf(cogs);
      final grossProfit = revenue.subtract(cost);

      expect(revenue.minorUnits, 300000);
      expect(cost.minorUnits, 200000);
      expect(grossProfit.minorUnits, 100000, reason: 'Rs 3,000 - Rs 2,000');
    });

    test('a credit purchase increases inventory and creates a payable', () {
      final ledger = Ledger(currency: npr, entries: [
        entry(description: 'Purchased 10 keyboards on credit', lines: [
          JournalLine.debit(account: inventory, amount: rs(10000)),
          JournalLine.credit(account: payable, amount: rs(10000)),
        ]),
      ]);
      expect(ledger.balanceOf(inventory).minorUnits, 1000000);
      expect(ledger.balanceOf(payable).minorUnits, 1000000);
    });
  });

  group('Accounting equation', () {
    test('the trial balance balances for the worked example', () {
      // Opening bank Rs 100,000; purchase inventory Rs 30,000 on credit;
      // sale Rs 20,000 with COGS Rs 12,000; expense Rs 5,000.
      final ledger = Ledger(currency: npr, entries: [
        entry(id: 'OB-1', date: day(1), description: 'Opening balance', lines: [
          JournalLine.debit(account: bank, amount: rs(100000)),
          JournalLine.credit(account: equity, amount: rs(100000)),
        ]),
        entry(
            id: 'PU-1',
            date: day(2),
            description: 'Purchase on credit',
            lines: [
              JournalLine.debit(account: inventory, amount: rs(30000)),
              JournalLine.credit(account: payable, amount: rs(30000)),
            ]),
        entry(id: 'SA-1', date: day(3), description: 'Sale with COGS', lines: [
          JournalLine.debit(account: bank, amount: rs(20000)),
          JournalLine.credit(account: sales, amount: rs(20000)),
          JournalLine.debit(account: cogs, amount: rs(12000)),
          JournalLine.credit(account: inventory, amount: rs(12000)),
        ]),
        entry(id: 'EX-1', date: day(4), description: 'Expense', lines: [
          JournalLine.debit(account: rent, amount: rs(5000)),
          JournalLine.credit(account: bank, amount: rs(5000)),
        ]),
      ]);

      expect(ledger.balanceOf(bank).minorUnits, 11500000,
          reason: '100,000 - 20,000 + 20,000 - 5,000');
      expect(ledger.balanceOf(inventory).minorUnits, 1800000,
          reason: '30,000 - 12,000');
      expect(ledger.balanceOf(sales).minorUnits, 2000000);
      expect(ledger.balanceOf(cogs).minorUnits, 1200000);
      expect(ledger.balanceOf(rent).minorUnits, 500000);

      final revenue = ledger.balanceOf(sales);
      final profit = revenue
          .subtract(ledger.balanceOf(cogs))
          .subtract(ledger.balanceOf(rent));
      expect(profit.minorUnits, 300000, reason: '20,000 - 12,000 - 5,000');

      // Every entry in the ledger must independently balance.
      for (final e in ledger.entries) {
        expect(e.isBalanced, isTrue, reason: '${e.id} must balance');
      }
    });

    test('assets equal liabilities plus equity after profit is closed', () {
      // Independently hand-computed from the same transactions, not read back
      // out of the engine:
      //   Bank      = 100,000 + 20,000 - 5,000 = 115,000
      //   Inventory =  30,000 - 12,000         =  18,000
      //   Payable   =  30,000
      //   Equity    = 100,000
      //   Profit    =  20,000 - 12,000 - 5,000 =   3,000
      //   Assets    = 115,000 + 18,000 = 133,000
      //   L + E     =  30,000 + 100,000 + 3,000 = 133,000
      final ledger = Ledger(currency: npr, entries: [
        entry(id: 'OB-1', date: day(1), lines: [
          JournalLine.debit(account: bank, amount: rs(100000)),
          JournalLine.credit(account: equity, amount: rs(100000)),
        ]),
        entry(id: 'PU-1', date: day(2), lines: [
          JournalLine.debit(account: inventory, amount: rs(30000)),
          JournalLine.credit(account: payable, amount: rs(30000)),
        ]),
        entry(id: 'SA-1', date: day(3), lines: [
          JournalLine.debit(account: bank, amount: rs(20000)),
          JournalLine.credit(account: sales, amount: rs(20000)),
          JournalLine.debit(account: cogs, amount: rs(12000)),
          JournalLine.credit(account: inventory, amount: rs(12000)),
        ]),
        entry(id: 'EX-1', date: day(4), lines: [
          JournalLine.debit(account: rent, amount: rs(5000)),
          JournalLine.credit(account: bank, amount: rs(5000)),
        ]),
      ]);

      final assets = ledger.balanceOf(bank).add(ledger.balanceOf(inventory));
      final profit = ledger
          .balanceOf(sales)
          .subtract(ledger.balanceOf(cogs))
          .subtract(ledger.balanceOf(rent));
      final liabilitiesAndEquity =
          ledger.balanceOf(payable).add(ledger.balanceOf(equity)).add(profit);

      expect(assets.minorUnits, 13300000);
      expect(liabilitiesAndEquity.minorUnits, 13300000);
      expect(assets.minorUnits, liabilitiesAndEquity.minorUnits,
          reason: 'the accounting equation must hold: assets = liabilities + '
              'equity, with profit closed to equity');
      expect(profit.minorUnits, 300000);
    });
  });
}
