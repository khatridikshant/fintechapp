import 'credit_note.dart';
import 'invoice.dart';
import 'payment.dart';
import '../shared/money.dart';

/// How much of an invoice has been paid and credited, and how much is still
/// owed.
///
/// **Derived every time, never stored.** A running balance kept on the invoice
/// would be a second source of truth that can disagree with the payments and
/// credit notes that produced it, and the disagreement would be silent.
class InvoiceBalance {
  const InvoiceBalance({
    required this.invoiceTotal,
    required this.received,
    required this.credited,
    required this.outstanding,
    required this.uncredited,
  });

  /// Computes the balance from the invoice, the payments recorded against it,
  /// and the credit notes issued against it.
  ///
  /// [payments] stays a positional argument so existing callers are unaffected.
  factory InvoiceBalance.of(
    Invoice invoice,
    Iterable<Payment> payments, {
    Iterable<CreditNote> creditNotes = const [],
  }) {
    final received = Money.sum(
      payments.map((payment) => payment.amount),
      invoice.currency,
    );
    final credited = Money.sum(
      creditNotes.map((creditNote) => creditNote.total),
      invoice.currency,
    );

    return InvoiceBalance(
      invoiceTotal: invoice.total,
      received: received,
      credited: credited,
      outstanding: invoice.total.subtract(received).subtract(credited),
      // Bounds the *next* credit note. Deliberately does not subtract payments:
      // an invoice can be credited even after it has been paid, in which case the
      // business owes the customer a refund.
      uncredited: invoice.total.subtract(credited),
    );
  }

  final Money invoiceTotal;

  /// Total received against the invoice so far.
  final Money received;

  /// Total credited back against the invoice so far.
  final Money credited;

  /// What is still owed, after both payments and credits.
  ///
  /// **This can go negative**, and that is meaningful rather than a bug: an
  /// invoice that was paid in full and then fully credited leaves the business
  /// owing the customer money. See [refundDue]. Refunds are not modelled yet.
  final Money outstanding;

  /// How much of the invoice has not yet been credited.
  ///
  /// This is the ceiling for the next credit note.
  final Money uncredited;

  /// True when the invoice is exactly settled.
  bool get isSettled => outstanding.isZero;

  /// True when something has been received but the invoice is not settled.
  bool get isPartiallyPaid => received.isPositive && !isSettled;

  /// True when the business owes the customer money back.
  bool get isRefundDue => outstanding.isNegative;

  /// The amount owed back to the customer, when [isRefundDue].
  Money get refundDue => isRefundDue
      ? outstanding.negated()
      : Money.minor(0, outstanding.currency);

  /// Whether the invoice has been fully credited.
  bool get isFullyCredited => uncredited.isZero;

  @override
  String toString() => 'InvoiceBalance(${received.format()} received, '
      '${credited.format()} credited, ${outstanding.format()} outstanding)';
}
