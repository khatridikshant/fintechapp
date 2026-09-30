import '../accounting/account.dart';
import '../accounting/account_type.dart';
import '../accounting/journal_entry.dart';
import '../accounting/journal_line.dart';
import '../accounting/ledger.dart';
import '../shared/money.dart';
import 'trial_balance.dart' show entriesWithin;

/// One posting to an account, with the balance after it.
class GeneralLedgerLine {
  const GeneralLedgerLine({
    required this.entry,
    required this.line,
    required this.movement,
    required this.runningBalance,
  });

  /// The journal entry this posting belongs to, so a user can open it.
  final JournalEntry entry;

  /// The posting itself.
  final JournalLine line;

  /// This posting's effect on the account, in the account's natural direction.
  /// Negative when the posting reduces the account.
  final Money movement;

  /// The account balance immediately after this posting.
  final Money runningBalance;
}

/// Every posting to one account, in order, with a running balance.
///
/// Derived, never stored. This is the audit detail behind a single line of a
/// trial balance: it answers "which transactions made this balance".
class GeneralLedger {
  GeneralLedger._({
    required this.account,
    required this.openingBalance,
    required this.lines,
    required this.closingBalance,
  });

  /// Builds the ledger for [account].
  ///
  /// [from] is where the listing starts. Anything posted before it is not
  /// listed but is not lost either: it is carried in as [openingBalance], so the
  /// running balance is correct from the first visible line. Dropping it would
  /// make the running balance disagree with the trial balance.
  ///
  /// [from] and [to] are inclusive instants.
  factory GeneralLedger.forAccount({
    required Account account,
    required Iterable<JournalEntry> entries,
    required String currency,
    DateTime? from,
    DateTime? to,
  }) {
    final opening = from == null
        ? Money.minor(0, currency)
        : Ledger(
            entries: entries.where((entry) => entry.date.isBefore(from)),
            currency: currency,
          ).balanceOf(account);

    // Sort defensively. Callers may pass a repository result, which is already
    // ordered by date and id, or an ad-hoc list that is not.
    final ordered = entriesWithin(entries, from: from, to: to).toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });

    var running = opening;
    final lines = <GeneralLedgerLine>[];
    for (final entry in ordered) {
      for (final line in entry.lines) {
        if (line.account != account) continue;
        final movement = _movementOf(account, line);
        running = running.add(movement);
        lines.add(
          GeneralLedgerLine(
            entry: entry,
            line: line,
            movement: movement,
            runningBalance: running,
          ),
        );
      }
    }

    return GeneralLedger._(
      account: account,
      openingBalance: opening,
      lines: List.unmodifiable(lines),
      closingBalance: running,
    );
  }

  final Account account;

  /// Balance brought forward from before the reporting period.
  final Money openingBalance;

  final List<GeneralLedgerLine> lines;

  /// Balance after the last posting. Equals [openingBalance] plus the movement
  /// of every line, and must agree with the trial balance row for this account.
  final Money closingBalance;

  /// Total movement across the listed lines.
  Money get totalMovement =>
      Money.sum(lines.map((line) => line.movement), openingBalance.currency);

  /// Signed effect of [line] on [account], in the account's natural direction.
  static Money _movementOf(Account account, JournalLine line) {
    return account.normalBalance == NormalBalance.debit
        ? line.debit.subtract(line.credit)
        : line.credit.subtract(line.debit);
  }
}
