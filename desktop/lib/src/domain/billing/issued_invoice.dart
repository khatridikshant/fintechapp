import 'document_number.dart';
import 'invoice.dart';

/// An invoice that has been numbered and posted.
///
/// This is the unit that gets stored. A draft `Invoice` has no number and no
/// accounting behind it; an `IssuedInvoice` has both, and the two are created
/// together or not at all.
///
/// The journal entry id is **derived from the invoice id** rather than stored
/// separately at creation time. That gives two things at once:
///
/// - the entry is traceable back to the invoice that caused it, and
/// - re-issuing an invoice id that has already been posted is refused by the
///   journal's primary key, so an invoice cannot be double-posted.
class IssuedInvoice {
  const IssuedInvoice._({
    required this.invoice,
    required this.number,
    required this.journalEntryId,
  });

  factory IssuedInvoice({
    required Invoice invoice,
    required DocumentNumber number,
  }) =>
      IssuedInvoice._(
        invoice: invoice,
        number: number,
        journalEntryId: journalEntryIdFor(invoice),
      );

  /// The journal entry id for an invoice.
  static String journalEntryIdFor(Invoice invoice) => 'JE-INV-${invoice.id}';

  final Invoice invoice;

  /// The serial allocated at issuance. A draft does not have one.
  final DocumentNumber number;

  /// The journal entry that records this sale.
  final String journalEntryId;

  /// The invoice's own identity, which is also its storage key.
  String get id => invoice.id;

  @override
  bool operator ==(Object other) =>
      other is IssuedInvoice &&
      other.invoice == invoice &&
      other.number == number &&
      other.journalEntryId == journalEntryId;

  @override
  int get hashCode => Object.hash(invoice, number, journalEntryId);

  @override
  String toString() =>
      'IssuedInvoice(${number.value}, ${invoice.total.format()})';
}
