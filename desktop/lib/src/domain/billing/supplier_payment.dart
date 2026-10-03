import '../shared/money.dart';

/// Money paid to a supplier, settling part or all of a purchase bill.
///
/// ## The mirror of [Payment], and it exists for the same reason
///
/// Until a payment is recorded, a purchase leaves `2010 Accounts Payable`
/// outstanding forever. Before purchases existed the account was credited by hand
/// with no document behind it, so a payable could not be aged, settled against a
/// bill, or defended in an audit. ADR 012 is what closes that.
class SupplierPayment {
  const SupplierPayment._({
    required this.id,
    required this.purchaseId,
    required this.date,
    required this.amount,
    required this.accountId,
  });

  factory SupplierPayment({
    required String id,
    required String purchaseId,
    required DateTime date,
    required Money amount,
    required String accountId,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('A supplier payment needs an id.');
    }
    if (purchaseId.trim().isEmpty) {
      throw ArgumentError(
        'A supplier payment needs a purchase. Paying money with nothing to '
        'settle it would reduce the payable without naming what it paid.',
      );
    }
    if (!amount.isPositive) {
      throw ArgumentError(
        'A supplier payment must be greater than zero, got '
        '${amount.format()}. A zero payment settles nothing and is a '
        'data-entry mistake.',
      );
    }
    if (accountId.trim().isEmpty) {
      throw ArgumentError(
        'A supplier payment needs the account the money left. Without it the '
        'double entry would be one-sided.',
      );
    }
    return SupplierPayment._(
      id: id.trim(),
      purchaseId: purchaseId.trim(),
      date: date,
      amount: amount,
      accountId: accountId.trim(),
    );
  }

  /// Random and permanent. The journal entry id is derived from this, so
  /// reusing one is refused by the primary key rather than counting the same
  /// payment twice against the payable.
  final String id;

  /// The purchase this settles.
  final String purchaseId;

  final DateTime date;

  /// Amount in minor units. **Always positive** — a refund to a supplier is a
  /// separate document, not a negative payment.
  final Money amount;

  /// The account the money was paid from, for example Bank or Cash.
  ///
  /// **Construction does not check this is a balance-sheet account**, because the
  /// domain does not hold the chart. The posting use case refuses a revenue or
  /// expense account here, exactly as `RecordPayment` does on the sales side.
  final String accountId;

  /// The journal entry id for this payment.
  static String journalEntryIdFor(SupplierPayment payment) =>
      'JE-SPAY-${payment.id}';

  @override
  String toString() =>
      'SupplierPayment($id, ${amount.format()} against $purchaseId)';
}