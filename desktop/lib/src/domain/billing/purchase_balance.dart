import '../shared/money.dart';
import 'purchase.dart';
import 'supplier_payment.dart';

/// How much of a purchase has been paid, and how much is still owed to the
/// supplier.
///
/// **Derived every time, never stored.** A running balance kept on the purchase
/// would be a second source of truth that can disagree with the payments that
/// produced it, and the disagreement would be silent. This is `InvoiceBalance`
/// mirrored onto the purchase side, for the same reason.
class PurchaseBalance {
  const PurchaseBalance({
    required this.purchaseTotal,
    required this.paid,
    required this.outstanding,
  });

  /// Computes the balance from the purchase and the payments against it.
  factory PurchaseBalance.of(
    Purchase purchase,
    Iterable<SupplierPayment> payments,
  ) {
    final paid = Money.sum(
      payments.map((payment) => payment.amount),
      purchase.currency,
    );

    return PurchaseBalance(
      purchaseTotal: purchase.total,
      paid: paid,
      outstanding: purchase.total.subtract(paid),
    );
  }

  /// The bill's total, including VAT.
  final Money purchaseTotal;

  /// Total paid to the supplier against this purchase so far.
  final Money paid;

  /// What is still owed to the supplier.
  ///
  /// **This can go negative**, and that is meaningful rather than a bug: an
  /// overpayment means the business is owed money back. Clamping it to zero would
  /// hide an amount somebody is waiting to receive.
  final Money outstanding;

  /// True when the purchase is exactly settled.
  bool get isSettled => outstanding.isZero;

  /// True when something has been paid but the purchase is not settled.
  bool get isPartiallyPaid => paid.isPositive && !isSettled;

  /// True when the supplier has been paid more than the bill was for.
  bool get isRefundDue => outstanding.isNegative;

  /// The amount owed back by the supplier, when [isRefundDue].
  Money get refundDue => isRefundDue
      ? outstanding.negated()
      : Money.minor(0, outstanding.currency);

  @override
  String toString() => 'PurchaseBalance(${paid.format()} paid, '
      '${outstanding.format()} outstanding)';
}