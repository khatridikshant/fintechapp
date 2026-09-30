import '../shared/money.dart';
import 'invoice_line.dart';

/// A credit note issued against an invoice.
///
/// ADR 005 requires that a posted invoice is never edited or deleted, and that
/// corrections go through credit notes. This is that correction path: a customer
/// returning goods, a pricing error, or a discount agreed after the fact.
///
/// A credit note mirrors an invoice's shape — the same line type, the same
/// derived totals, the same basis-point VAT — because it is the same calculation
/// running in the opposite direction.
///
/// Like an invoice, every total is **derived from the lines**, never stored and
/// never passed in.
class CreditNote {
  const CreditNote._({
    required this.id,
    required this.invoiceId,
    required this.date,
    required this.lines,
    required this.vatRateBasisPoints,
  });

  factory CreditNote({
    required String id,
    required String invoiceId,
    required DateTime date,
    required List<InvoiceLine> lines,
    int vatRateBasisPoints = standardVatRate,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('A credit note needs an id.');
    }
    if (invoiceId.trim().isEmpty) {
      throw ArgumentError(
        'A credit note must name the invoice it credits. A correction with no '
        'original document cannot be audited.',
      );
    }
    if (lines.isEmpty) {
      throw ArgumentError(
        'A credit note needs at least one line. A credit note with no lines '
        'would reverse nothing.',
      );
    }
    if (vatRateBasisPoints < 0) {
      throw ArgumentError(
        'A VAT rate must not be negative, got $vatRateBasisPoints basis points.',
      );
    }
    return CreditNote._(
      id: id.trim(),
      invoiceId: invoiceId.trim(),
      date: date,
      lines: List.unmodifiable(lines),
      vatRateBasisPoints: vatRateBasisPoints,
    );
  }

  /// Nepal's standard VAT rate, 13%, expressed in basis points.
  ///
  /// Held here as well as on `Invoice` so that a credit note can be built
  /// without reaching for the invoice type. The two must agree; a test asserts
  /// it.
  static const int standardVatRate = 1300;

  final String id;

  /// The invoice being credited. Required, so every correction is traceable.
  final String invoiceId;

  final DateTime date;

  final List<InvoiceLine> lines;

  /// The VAT rate applied to the combined subtotal, in basis points.
  final int vatRateBasisPoints;

  /// Currency of the credit note, taken from the lines.
  String get currency => lines.first.unitPrice.currency;

  /// Sum of the line totals, before VAT.
  Money get subtotal =>
      Money.sum(lines.map((line) => line.lineTotal), currency);

  /// VAT credited on the **combined** subtotal, mirroring how the invoice
  /// charged it. Per-line VAT would round differently and leave a residue
  /// against the invoice.
  Money get vat => subtotal.applyBasisPoints(vatRateBasisPoints);

  /// What the customer is credited back: subtotal plus VAT.
  Money get total => subtotal.add(vat);

  @override
  bool operator ==(Object other) => other is CreditNote && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CreditNote($id against $invoiceId, ${total.format()})';
}
