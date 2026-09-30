import '../accounting/account.dart';
import '../accounting/journal_entry.dart';
import '../accounting/ledger.dart';
import '../shared/money.dart';

/// One account's line in a trial balance.
class TrialBalanceRow {
  const TrialBalanceRow({
    required this.account,
    required this.debitTotal,
    required this.creditTotal,
    required this.balance,
  });

  final Account account;

  /// Everything debited to this account in the period.
  final Money debitTotal;

  /// Everything credited to this account in the period.
  final Money creditTotal;

  /// [debitTotal] minus [creditTotal], reported in the account's natural
  /// direction. A positive asset balance means value held; a positive liability
  /// balance means money owed. Neither is presented as a negative number.
  final Money balance;
}

/// A trial balance: every account with activity, with debit and credit totals.
///
/// Derived, never stored. The architecture prohibits keeping a report total as
/// a mutable number anywhere, because it would drift from the journal that
/// produced it.
///
/// The report proves itself. [isBalanced] states whether total debits equal
/// total credits, and [assertBalanced] turns that into a hard failure for
/// callers that should refuse to present an unbalanced book. An unbalanced trial
/// balance means the accounting model has already been violated somewhere, and
/// showing it to a user as though it were fine would hide the problem.
class TrialBalance {
  TrialBalance._({
    required this.rows,
    required this.totalDebits,
    required this.totalCredits,
  });

  /// Builds a trial balance from journal entries.
  ///
  /// [from] and [to] are inclusive instants. Accounts are taken from the
  /// entries themselves, plus any [chart] supplied. Accounts with no activity
  /// are omitted unless [includeZeroBalances] is set.
  factory TrialBalance.from({
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
      accounts[account.id] = account;
    }
    for (final entry in filtered) {
      for (final line in entry.lines) {
        accounts[line.account.id] = line.account;
      }
    }

    final rows = <TrialBalanceRow>[];
    for (final account in accounts.values) {
      final debitTotal = ledger.debitTotalOf(account);
      final creditTotal = ledger.creditTotalOf(account);
      final hasActivity = !debitTotal.isZero || !creditTotal.isZero;
      if (!hasActivity && !includeZeroBalances) continue;

      rows.add(
        TrialBalanceRow(
          account: account,
          debitTotal: debitTotal,
          creditTotal: creditTotal,
          balance: ledger.balanceOf(account),
        ),
      );
    }

    rows.sort((a, b) => a.account.code.compareTo(b.account.code));

    return TrialBalance._(
      rows: List.unmodifiable(rows),
      totalDebits: Money.sum(rows.map((row) => row.debitTotal), currency),
      totalCredits: Money.sum(rows.map((row) => row.creditTotal), currency),
    );
  }

  final List<TrialBalanceRow> rows;

  /// Total of every debit column. Must equal [totalCredits].
  final Money totalDebits;

  /// Total of every credit column.
  final Money totalCredits;

  bool get isBalanced => totalDebits == totalCredits;

  /// The difference, for diagnostics.
  Money get difference => totalDebits.subtract(totalCredits);

  /// Throws if the book does not balance.
  ///
  /// Callers that present a report to a user should call this. A trial balance
  /// that does not balance is not a report, it is evidence of a defect.
  void assertBalanced() {
    if (!isBalanced) {
      throw UnbalancedTrialBalanceException(totalDebits, totalCredits);
    }
  }
}

/// Raised when a trial balance does not balance.
///
/// This should be unreachable if every entry was constructed balanced. If it is
/// ever thrown, something has written to the journal without going through
/// [JournalEntry], and that is a defect worth stopping for.
class UnbalancedTrialBalanceException implements Exception {
  UnbalancedTrialBalanceException(this.totalDebits, this.totalCredits);

  final Money totalDebits;
  final Money totalCredits;

  Money get difference => totalDebits.subtract(totalCredits);

  @override
  String toString() =>
      'UnbalancedTrialBalanceException: total debits ${totalDebits.format()} '
      'do not equal total credits ${totalCredits.format()}. The book is '
      'unbalanced, which means a journal entry was written without going '
      'through the accounting engine.';
}

/// Filters entries to an inclusive date range.
///
/// Shared by the reports so that "the period" means the same thing everywhere.
Iterable<JournalEntry> entriesWithin(
  Iterable<JournalEntry> entries, {
  DateTime? from,
  DateTime? to,
}) {
  return entries.where((entry) {
    if (from != null && entry.date.isBefore(from)) return false;
    if (to != null && entry.date.isAfter(to)) return false;
    return true;
  });
}
