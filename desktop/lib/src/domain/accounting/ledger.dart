import '../shared/money.dart';
import 'account.dart';
import 'account_type.dart';
import 'journal_entry.dart';
import 'journal_line.dart';

/// Read model over a set of posted journal entries.
///
/// Balances are always derived from the journal. Nothing here is stored, so a
/// balance cannot drift away from the entries that produced it. This is the
/// only place account balances come from.
///
/// The currency is required so that an account with no activity still returns a
/// zero of the right currency rather than no answer at all.
class Ledger {
  Ledger({required Iterable<JournalEntry> entries, required this.currency})
      : entries = List.unmodifiable(entries);

  final List<JournalEntry> entries;

  final String currency;

  Iterable<JournalLine> get _lines => entries.expand((entry) => entry.lines);

  /// Total debits posted to [account].
  Money debitTotalOf(Account account) => Money.sum(
        _lines
            .where((line) => line.account == account)
            .map((line) => line.debit),
        currency,
      );

  /// Total credits posted to [account].
  Money creditTotalOf(Account account) => Money.sum(
        _lines
            .where((line) => line.account == account)
            .map((line) => line.credit),
        currency,
      );

  /// The balance of [account], expressed in its natural direction.
  ///
  /// A positive result always means the account grew in the direction it is
  /// supposed to grow: a positive asset balance means value held, a positive
  /// income balance means revenue earned, a positive liability balance means
  /// money owed. An account can still legitimately go negative, for example an
  /// overdrawn bank account.
  Money balanceOf(Account account) {
    final debits = debitTotalOf(account);
    final credits = creditTotalOf(account);
    return account.normalBalance == NormalBalance.debit
        ? debits.subtract(credits)
        : credits.subtract(debits);
  }
}
