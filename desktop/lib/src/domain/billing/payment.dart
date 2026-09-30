import '../accounting/account.dart';
import '../shared/money.dart';

/// A payment received from a customer against an invoice.
///
/// A payment is a financial record: once recorded it is never edited or deleted.
/// A mistake is corrected by a reversal or a credit note, not by overwriting the
/// original.
///
/// The `id` is supplied by the caller and is permanent, like every other record
/// id in this project. The journal entry id is derived from it, so recording the
/// same payment twice is refused rather than double-counted.
class Payment {
  const Payment._({
    required this.id,
    required this.invoiceId,
    required this.date,
    required this.amount,
    required this.account,
  });

  factory Payment({
    required String id,
    required String invoiceId,
    required DateTime date,
    required Money amount,
    required Account account,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('A payment needs an id.');
    }
    if (invoiceId.trim().isEmpty) {
      throw ArgumentError(
        'A payment must name the invoice it settles. Money received against '
        'nothing cannot be reconciled to a sale.',
      );
    }
    if (!amount.isPositive) {
      throw ArgumentError(
        'A payment amount must be greater than zero, got ${amount.format()}. '
        'Money going the other way is a refund, which is not modelled yet.',
      );
    }
    if (!account.type.isBalanceSheet) {
      throw ArgumentError(
        'A payment must be received into a balance sheet account such as Bank '
        'or Cash, got a ${account.type.name} account "${account.name}".',
      );
    }
    return Payment._(
      id: id.trim(),
      invoiceId: invoiceId.trim(),
      date: date,
      amount: amount,
      account: account,
    );
  }

  final String id;

  /// The invoice this payment settles.
  final String invoiceId;

  final DateTime date;

  final Money amount;

  /// The account the money arrived in, for example Bank or Cash.
  final Account account;

  String get currency => amount.currency;

  @override
  bool operator ==(Object other) => other is Payment && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Payment($id, $invoiceId, ${amount.format()})';
}
