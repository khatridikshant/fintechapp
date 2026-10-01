import '../shared/money.dart';
import 'invoice_line.dart';

/// A sales invoice.
///
/// Every total is **derived from the lines**, never stored and never passed in.
/// A stored total is a second source of truth that can disagree with the lines
/// it is supposed to summarise.
///
/// VAT is held in **basis points** rather than as a percentage, so no floating
/// point value ever enters a tax calculation. Nepal's standard rate of 13% is
/// 1300 basis points.
class Invoice {
  const Invoice._({
    required this.id,
    required this.issueDate,
    required this.customerId,
    required this.lines,
    required this.vatRateBasisPoints,
    required this.sellerName,
    required this.sellerPan,
  });

  factory Invoice({
    required String id,
    required DateTime issueDate,
    required String customerId,
    required List<InvoiceLine> lines,
    int vatRateBasisPoints = vatStandardRate,
    String? sellerName,
    String? sellerPan,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('An invoice needs an id.');
    }
    if (customerId.trim().isEmpty) {
      throw ArgumentError(
        'An invoice needs a customer. A sale with nobody to bill cannot be '
        'recorded as a receivable.',
      );
    }
    if (lines.isEmpty) {
      throw ArgumentError(
        'An invoice needs at least one line. An invoice with no lines would '
        'post a receivable for nothing.',
      );
    }
    if (vatRateBasisPoints < 0) {
      throw ArgumentError(
        'A VAT rate must not be negative, got $vatRateBasisPoints basis points.',
      );
    }
    return Invoice._(
      id: id.trim(),
      issueDate: issueDate,
      customerId: customerId.trim(),
      lines: List.unmodifiable(lines),
      vatRateBasisPoints: vatRateBasisPoints,
      sellerName: sellerName,
      sellerPan: sellerPan,
    );
  }

  /// The seller's details **as they were when this invoice was issued**.
  ///
  /// ## Why a copy is kept on the document
  ///
  /// The printed invoice is the evidence in an audit, so the record has to agree
  /// with the paper. If the record held only a reference to the business, then
  /// changing the address in Settings next year would make last year's invoices
  /// regenerate with the **new** details, and the record would contradict the
  /// document the customer was actually handed.
  ///
  /// Null means no snapshot was taken. `InvoiceCompliance` reports that as
  /// [InvoiceComplianceIssue.sellerPanMissing], so an invoice issued without one
  /// is visible rather than silently unevidenced.
  final String? sellerName;

  /// The seller's PAN as printed on this invoice, as nine digits.
  final String? sellerPan;

  /// A copy of this invoice stamped with the seller's details.
  ///
  /// Immutable, so this returns a new invoice rather than mutating one that may
  /// already have been posted.
  Invoice stampedWithSeller({String? name, String? pan}) => Invoice(
        id: id,
        issueDate: issueDate,
        customerId: customerId,
        lines: lines,
        vatRateBasisPoints: vatRateBasisPoints,
        sellerName: name,
        sellerPan: pan,
      );

  /// Nepal's standard VAT rate, 13%, expressed in basis points.
  static const int vatStandardRate = 1300;

  /// The draft's identity. Re-issuing an invoice with an id that has already
  /// been issued is refused, so this must be stable for a given invoice.
  final String id;

  final DateTime issueDate;

  /// Identifies the customer being billed. The `Customer` entity does not exist
  /// yet; see section 5 of `PROGRESS.md`.
  final String customerId;

  final List<InvoiceLine> lines;

  /// The VAT rate applied to the combined subtotal, in basis points.
  final int vatRateBasisPoints;

  /// Currency of the invoice, taken from the lines.
  String get currency => lines.first.unitPrice.currency;

  /// Sum of the line totals, before VAT.
  Money get subtotal =>
      Money.sum(lines.map((line) => line.lineTotal), currency);

  /// VAT charged on the **combined** subtotal, not line by line.
  ///
  /// Charging per line would round each line separately and drift from the
  /// correct total, so the tax would not match the return filed with the tax
  /// authority.
  Money get vat => subtotal.applyBasisPoints(vatRateBasisPoints);

  /// What the customer owes: subtotal plus VAT.
  Money get total => subtotal.add(vat);

  @override
  String toString() => 'Invoice($id, ${lines.length} lines, ${total.format()})';
}
