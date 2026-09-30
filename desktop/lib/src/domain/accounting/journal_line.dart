import '../shared/money.dart';
import 'account.dart';

/// One side of a journal entry: either a debit or a credit, never both.
///
/// The "never both and never neither" rule is enforced by construction rather
/// than by validation. The only way to build a line is [JournalLine.debit] or
/// [JournalLine.credit], both of which demand a strictly positive amount. A
/// line with two amounts, or with no amount, cannot be represented.
///
/// A reduction is never expressed as a negative amount. It is expressed as the
/// opposite side of the entry, or as a reversing entry.
class JournalLine {
  const JournalLine._({
    required this.account,
    required this.debit,
    required this.credit,
  });

  /// A debit line. [amount] must be greater than zero.
  factory JournalLine.debit({
    required Account account,
    required Money amount,
  }) {
    _rejectNonPositive(amount);
    return JournalLine._(
      account: account,
      debit: amount,
      credit: _zeroLike(amount),
    );
  }

  /// A credit line. [amount] must be greater than zero.
  factory JournalLine.credit({
    required Account account,
    required Money amount,
  }) {
    _rejectNonPositive(amount);
    return JournalLine._(
      account: account,
      debit: _zeroLike(amount),
      credit: amount,
    );
  }

  final Account account;

  /// The debit side. Zero when this is a credit line.
  final Money debit;

  /// The credit side. Zero when this is a debit line.
  final Money credit;

  bool get isDebit => debit.isPositive;

  bool get isCredit => credit.isPositive;

  /// The non-zero side, whichever it is.
  Money get amount => isDebit ? debit : credit;

  /// Currency of this line. Both sides share one currency.
  String get currency => debit.currency;

  /// The same account and amount on the opposite side.
  ///
  /// This is the building block of a reversal.
  JournalLine get opposite => isDebit
      ? JournalLine.credit(account: account, amount: debit)
      : JournalLine.debit(account: account, amount: credit);

  static Money _zeroLike(Money reference) => Money.minor(0, reference.currency);

  static void _rejectNonPositive(Money amount) {
    if (!amount.isPositive) {
      throw ArgumentError(
        'A journal line must carry an amount greater than zero for a '
        'subsidiary ledger to remain auditable, got ${amount.format()}.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is JournalLine &&
      other.account == account &&
      other.debit == debit &&
      other.credit == credit;

  @override
  int get hashCode => Object.hash(account, debit, credit);

  @override
  String toString() => isDebit
      ? 'Dr ${account.code} ${debit.format()}'
      : 'Cr ${account.code} ${credit.format()}';
}
