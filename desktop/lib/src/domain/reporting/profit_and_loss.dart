import '../accounting/account.dart';
import '../accounting/account_type.dart';
import '../accounting/journal_entry.dart';
import '../accounting/ledger.dart';
import '../shared/money.dart';
import 'trial_balance.dart' show entriesWithin;

/// One account's line in a profit and loss statement.
class ProfitAndLossLine {
  const ProfitAndLossLine({required this.account, required this.balance});

  final Account account;

  /// The account's balance in its own natural direction, so an income figure is
  /// positive when revenue was earned and an expense figure is positive when
  /// money was spent. Neither is presented as a negative number.
  final Money balance;
}

/// A profit and loss statement: income, expenses, and the result.
///
/// Derived, never stored. The architecture prohibits keeping a report total as a
/// mutable number anywhere.
///
/// This covers **income and expenses only**. Balance sheet accounts — assets,
/// liabilities, and equity — belong on the balance sheet and appear nowhere
/// here, even if they had activity in the period.
class ProfitAndLoss {
  ProfitAndLoss._({
    required this.income,
    required this.expenses,
    required this.currency,
    required this.totalIncome,
    required this.totalExpenses,
    required this.netResult,
  });

  /// Builds a statement from journal entries.
  ///
  /// [from] and [to] are inclusive instants. Accounts are taken from the entries
  /// themselves, plus any [chart] supplied. Accounts with no activity are
  /// omitted unless [includeZeroBalances] is set.
  factory ProfitAndLoss.from({
    required Iterable<JournalEntry> entries,
    required String currency,
    DateTime? from,
    DateTime? to,
    Iterable<Account> chart = const <Account>[],
    bool includeZeroBalances = false,
  }) {
    final filtered = entriesWithin(entries, from: from, to: to);
    final ledger = Ledger(entries: filtered, currency: currency);

    final accounts = <String, Account>{};
    for (final account in chart) {
      if (account.type.isProfitAndLoss) accounts[account.id] = account;
    }
    for (final entry in filtered) {
      for (final line in entry.lines) {
        if (line.account.type.isProfitAndLoss) {
          accounts[line.account.id] = line.account;
        }
      }
    }

    final income = <ProfitAndLossLine>[];
    final expenses = <ProfitAndLossLine>[];
    for (final account in accounts.values) {
      final balance = ledger.balanceOf(account);
      if (balance.isZero && !includeZeroBalances) continue;

      final line = ProfitAndLossLine(account: account, balance: balance);
      if (account.type == AccountType.income) {
        income.add(line);
      } else {
        expenses.add(line);
      }
    }

    int byCode(ProfitAndLossLine a, ProfitAndLossLine b) =>
        a.account.code.compareTo(b.account.code);
    income.sort(byCode);
    expenses.sort(byCode);

    final totalIncome = Money.sum(income.map((l) => l.balance), currency);
    final totalExpenses = Money.sum(expenses.map((l) => l.balance), currency);

    return ProfitAndLoss._(
      income: List.unmodifiable(income),
      expenses: List.unmodifiable(expenses),
      currency: currency,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      netResult: totalIncome.subtract(totalExpenses),
    );
  }

  final List<ProfitAndLossLine> income;

  final List<ProfitAndLossLine> expenses;

  final String currency;

  /// Total income for the period, always reported positive.
  final Money totalIncome;

  /// Total expenses for the period, always reported positive.
  final Money totalExpenses;

  /// Income minus expenses. **Negative means a loss**, which is why callers
  /// should prefer [profit] and [loss] over reading this directly.
  final Money netResult;

  /// The profit, or zero when the period made a loss.
  Money get profit =>
      netResult.isPositive ? netResult : Money.minor(0, currency);

  /// The loss as a **positive** amount, or zero when the period made a profit.
  ///
  /// Positive rather than negative so it can be shown as "Loss: Rs 5,000"
  /// instead of a double negative nobody reads correctly.
  Money get loss =>
      netResult.isNegative ? netResult.negated() : Money.minor(0, currency);

  /// True when the period made money.
  bool get isProfit => netResult.isPositive;

  /// True when the period lost money.
  bool get isLoss => netResult.isNegative;

  /// True when the period exactly broke even.
  bool get isBreakEven => netResult.isZero;

  @override
  String toString() => 'ProfitAndLoss(income ${totalIncome.format()}, '
      'expenses ${totalExpenses.format()}, result ${netResult.format()})';
}
