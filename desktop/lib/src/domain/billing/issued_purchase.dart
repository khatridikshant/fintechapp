import 'document_number.dart';
import 'purchase.dart';

/// A purchase that has been numbered and posted.
///
/// The unit that gets stored, and the exact mirror of `IssuedInvoice`: a draft
/// [Purchase] has no number and no accounting behind it, an `IssuedPurchase` has
/// both, and the two are created together or not at all.
///
/// The journal entry id is **derived from the purchase id** rather than stored
/// separately, which gives both traceability back to the bill and a primary key
/// that refuses a double post. The second is why `IssuePurchase` can safely be
/// retried: re-posting the same id fails rather than doubling the payable and the
/// input VAT claim.
class IssuedPurchase {
  const IssuedPurchase._({
    required this.purchase,
    required this.number,
    required this.journalEntryId,
  });

  factory IssuedPurchase({
    required Purchase purchase,
    required DocumentNumber number,
  }) =>
      IssuedPurchase._(
        purchase: purchase,
        number: number,
        journalEntryId: journalEntryIdFor(purchase),
      );

  /// The journal entry id for a purchase.
  static String journalEntryIdFor(Purchase purchase) => 'JE-PUR-${purchase.id}';

  final Purchase purchase;

  /// The serial allocated at issuance. A draft does not have one, so an abandoned
  /// draft leaves no gap in the purchase numbering.
  final DocumentNumber number;

  /// The journal entry that records this bill.
  final String journalEntryId;

  /// The purchase's own identity, which is also its storage key.
  String get id => purchase.id;

  @override
  bool operator ==(Object other) =>
      other is IssuedPurchase &&
      other.purchase == purchase &&
      other.number == number &&
      other.journalEntryId == journalEntryId;

  @override
  int get hashCode => Object.hash(purchase, number, journalEntryId);

  @override
  String toString() =>
      'IssuedPurchase(${number.value}, ${purchase.total.format()})';
}