import '../accounting/account.dart';
import '../accounting/account_type.dart';
import '../accounting/journal_entry.dart';
import '../accounting/ledger.dart';
import '../shared/money.dart';
import 'trial_balance.dart' show entriesWithin;

/// One account's line in a balance sheet.
class BalanceSheetLine {
  const BalanceSheetLine({required this.account, required this.balance});

  final Account account;

  /// The account's balance in its own natural direction, so a liability reads as
  /// money owed and an asset as value held. Neither is a negative number.
  final Money balance;
}

/// A balance sheet: what the business owns, what it owes, and what is left.
///
/// Derived, never stored.
///
/// ## Why this report has no `from`
///
/// A balance sheet shows a position **at a point in time**, not over a period, so
/// it takes `to` and not `from`. The other reports take both because they cover a
/// span.
///
/// This also matters for the arithmetic. Equity has to include the result earned
/// so far, or the equation cannot hold — there is no year-end closing entry that
/// moves profit into equity, so it is folded in here instead. And because ADR 002
/// gives **one database per fiscal year**, "so far" means from the beginning of
/// this database, which is exactly the start of the fiscal year. Passing a `from`
/// would slice the result and leave the equation unbalanced against equity that
/// has no prior-year residue to absorb it.
class BalanceSheet {
  BalanceSheet._({
    required this.assets,
    required this.liabilities,
    required this.equity,
    required this.currency,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.equityAccountsTotal,
    required this.currentResult,
  });

  /// Builds a balance sheet from journal entries, as at [to].
  ///
  /// Accounts are taken from the entries themselves, plus any [chart] supplied.
  /// Accounts with no activity are omitted unless [includeZeroBalances] is set.
  factory BalanceSheet.from({
    required Iterable<JournalEntry> entries,
    required String currency,
    DateTime? to,
    Iterable<Account> chart = const <Account>[],
    bool includeZeroBalances = false,
  }) {
    // Everything up to and including `to`.
    final upTo = entriesWithin(entries, to: to);
    final ledger = Ledger(entries: upTo, currency: currency);

    final accounts = <String, Account>{};
    for (final account in chart) {
      accounts[account.id] = account;
    }
    for (final entry in upTo) {
      for (final line in entry.lines) {
        accounts[line.account.id] = line.account;
      }
    }

    final assets = <BalanceSheetLine>[];
    final liabilities = <BalanceSheetLine>[];
    final equity = <BalanceSheetLine>[];
    var incomeTotal = Money.minor(0, currency);
    var expenseTotal = Money.minor(0, currency);

    for (final account in accounts.values) {
      final balance = ledger.balanceOf(account);

      // Income and expenses are not shown as their own lines. They appear only
      // through the derived result folded into equity below.
      if (account.type == AccountType.income) {
        incomeTotal = incomeTotal.add(balance);
        continue;
      }
      if (account.type == AccountType.expense) {
        expenseTotal = expenseTotal.add(balance);
        continue;
      }

      if (balance.isZero && !includeZeroBalances) continue;

      final line = BalanceSheetLine(account: account, balance: balance);
      switch (account.type) {
        case AccountType.asset:
          assets.add(line);
        case AccountType.liability:
          liabilities.add(line);
        case AccountType.equity:
          equity.add(line);
        case AccountType.income:
        case AccountType.expense:
          // Handled above.
          break;
      }
    }

    int byCode(BalanceSheetLine a, BalanceSheetLine b) =>
        a.account.code.compareTo(b.account.code);
    assets.sort(byCode);
    liabilities.sort(byCode);
    equity.sort(byCode);

    return BalanceSheet._(
      assets: List.unmodifiable(assets),
      liabilities: List.unmodifiable(liabilities),
      equity: List.unmodifiable(equity),
      currency: currency,
      totalAssets: Money.sum(assets.map((l) => l.balance), currency),
      totalLiabilities: Money.sum(liabilities.map((l) => l.balance), currency),
      equityAccountsTotal: Money.sum(equity.map((l) => l.balance), currency),
      currentResult: incomeTotal.subtract(expenseTotal),
    );
  }

  final List<BalanceSheetLine> assets;
  final List<BalanceSheetLine> liabilities;

  /// Only the **equity accounts**. The period result is separate; see
  /// [currentResult] and [totalEquity].
  final List<BalanceSheetLine> equity;

  final String currency;

  final Money totalAssets;

  final Money totalLiabilities;

  /// The equity accounts alone, before the period result is added.
  final Money equityAccountsTotal;

  /// Profit or loss earned so far, folded into equity.
  ///
  /// Negative means a loss so far. This is the line that makes the sheet balance:
  /// without it, equity would be missing everything the business has earned.
  final Money currentResult;

  /// Equity accounts plus the period result.
  Money get totalEquity => equityAccountsTotal.add(currentResult);

  /// Liabilities plus equity. Must equal [totalAssets].
  Money get totalLiabilitiesAndEquity => totalLiabilities.add(totalEquity);

  /// Assets minus liabilities and equity. Zero when the sheet is correct.
  Money get difference => totalAssets.subtract(totalLiabilitiesAndEquity);

  /// Whether the accounting equation holds.
  bool get isBalanced => difference.isZero;

  /// Throws if the accounting equation does not hold.
  ///
  /// Callers that present a balance sheet to a user should call this. A balance
  /// sheet that does not balance is not a report, it is evidence of a defect.
  void assertBalanced() {
    if (!isBalanced) {
      throw UnbalancedBalanceSheetException(
        totalAssets: totalAssets,
        totalLiabilities: totalLiabilities,
        totalEquity: totalEquity,
      );
    }
  }

  @override
  String toString() => 'BalanceSheet(assets ${totalAssets.format()}, '
      'liabilities ${totalLiabilities.format()}, '
      'equity ${totalEquity.format()})';
}

/// Raised when assets do not equal liabilities plus equity.
///
/// This should be unreachable if every entry was constructed balanced. If it is
/// ever thrown, something has written to the journal without going through
/// [JournalEntry], or a report is slicing the result while showing cumulative
/// equity.
class UnbalancedBalanceSheetException implements Exception {
  UnbalancedBalanceSheetException({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.totalEquity,
  });

  final Money totalAssets;
  final Money totalLiabilities;
  final Money totalEquity;

  Money get difference =>
      totalAssets.subtract(totalLiabilities).subtract(totalEquity);

  @override
  String toString() =>
      'UnbalancedBalanceSheetException: assets ${totalAssets.format()} do not '
      'equal liabilities ${totalLiabilities.format()} plus equity '
      '${totalEquity.format()}. The difference is ${difference.format()}.';
}
