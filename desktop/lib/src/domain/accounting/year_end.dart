import '../shared/money.dart';
import 'account.dart';
import 'account_type.dart';

/// One account's year-end transfer to retained earnings.
///
/// At the end of a fiscal year every income and expense account is closed: its
/// balance for the year is transferred to equity, so next year's profit and loss
/// starts from zero instead of continuing to accumulate.
///
/// **This is not optional bookkeeping.** A ledger that carries revenue forward
/// year after year reports a profit that is the sum of several years and cannot
/// be compared with anything.
class ClosingEntry {
  const ClosingEntry({
    required this.account,
    required this.yearBalance,
    required this.transferAmount,
  });

  /// The nominal account being closed.
  final Account account;

  /// That account's balance for the year, signed by its normal balance.
  ///
  /// Retained rather than recomputed, so the transfer and the balance it came
  /// from can never disagree.
  final Money yearBalance;

  /// What is moved to retained earnings. Always positive: the direction is
  /// carried by [debitsRetainedEarnings], not by a negative amount, because a
  /// negative amount reads as a reversal.
  final Money transferAmount;

  /// Which side of retained earnings the transfer lands on.
  ///
  /// A revenue account closing leaves retained earnings **credited**; an expense
  /// account closing leaves it **debited**. Getting this backwards would report
  /// a profit as a loss.
  bool get creditsRetainedEarnings => account.type == AccountType.income;

  /// True when there is nothing to transfer.
  ///
  /// An account untouched all year has no balance, and posting a zero transfer
  /// would only add noise to the ledger.
  bool get isEmpty => transferAmount.isZero;

  @override
  String toString() =>
      'ClosingEntry(${account.code} ${account.name}, $transferAmount)';
}

/// The year-end closing: every nominal account's transfer, and the year's result.
///
/// ## The result is computed from the transfers, not summed separately
///
/// Summing the same numbers twice is how a profit and loss statement ends up
/// disagreeing with the ledger it came from. Here the result **is** the transfers.
class YearEndClosing {
  const YearEndClosing._(
      {required this.entries, required this.fiscalYearLabel});

  /// Builds the closing plan from each nominal account's year balance.
  ///
  /// [yearBalanceFor] is given the signed balance of every income and expense
  /// account, and returns the plan. Accounts with a zero balance are dropped.
  factory YearEndClosing.from({
    required String fiscalYearLabel,
    required Map<Account, Money> yearBalanceFor,
  }) {
    final entries = <ClosingEntry>[];
    yearBalanceFor.forEach((Account account, Money balance) {
      if (!account.type.isProfitAndLoss) return;
      if (balance.isZero) return;
      entries.add(
        ClosingEntry(
          account: account,
          yearBalance: balance,
          transferAmount: balance.abs(),
        ),
      );
    });

    // Ordered by account code so the closing entry is deterministic: the same
    // books closed twice must produce identical postings, or a retry looks like a
    // change.
    entries.sort(
      (ClosingEntry a, ClosingEntry b) =>
          a.account.code.compareTo(b.account.code),
    );

    return YearEndClosing._(
      entries: List.unmodifiable(entries),
      fiscalYearLabel: fiscalYearLabel,
    );
  }

  /// What was transferred, in posting order.
  final List<ClosingEntry> entries;

  /// The year these entries close.
  final String fiscalYearLabel;

  /// The year's profit or loss.
  ///
  /// **Revenue closed increases retained earnings; expenses closed decrease it.**
  /// A loss is negative, and that is what the sign means.
  Money get result {
    var total = 0;
    for (final entry in entries) {
      total += entry.creditsRetainedEarnings
          ? entry.transferAmount.minorUnits
          : -entry.transferAmount.minorUnits;
    }
    return Money.minor(total, 'NPR');
  }

  bool get isProfit => result.isPositive;

  bool get hasWork => entries.isNotEmpty;

  /// The amounts to post as retained earnings' side, per entry.
  ///
  /// Kept here so the closing use case never has to work out the direction.
  Map<ClosingEntry, bool> get retainedEarningsSides => <ClosingEntry, bool>{
        for (final entry in entries) entry: entry.creditsRetainedEarnings,
      };

  @override
  String toString() =>
      'YearEndClosing($fiscalYearLabel, ${entries.length} entries, $result)';
}

/// Why a year cannot be closed yet.
///
/// These are **blocking conditions**, not warnings. Closing a year whose books are
/// wrong freezes the wrongness: the next year inherits it, and by then the mistake
/// is months old and much harder to find.
enum YearEndBlocker {
  /// A journal entry does not balance. The ledger cannot be trusted.
  unbalancedEntry,

  /// An entry is dated outside the fiscal year being closed.
  entryOutsideFiscalYear,

  /// An invoice was issued in this year but its number was never consumed.
  incompleteNumbering,
}

/// The outcome of trying to close a year.
sealed class YearEndValidation {
  const YearEndValidation();
}

/// The books are sound and the year may be closed.
class YearEndReady extends YearEndValidation {
  const YearEndReady(this.closing);

  final YearEndClosing closing;
}

/// The year cannot be closed, and here is why.
class YearEndNotReady extends YearEndValidation {
  const YearEndNotReady(this.blockers);

  final List<YearEndBlocker> blockers;

  /// One sentence per blocker, so a screen can list them.
  List<String> get messages => blockers.map(describe).toList(growable: false);

  static String describe(YearEndBlocker blocker) => switch (blocker) {
        YearEndBlocker.unbalancedEntry =>
          'A journal entry does not balance, so the ledger cannot be trusted.',
        YearEndBlocker.entryOutsideFiscalYear =>
          'An entry is dated outside the year being closed.',
        YearEndBlocker.incompleteNumbering =>
          'A document number was issued but its record is missing.',
      };
}
