import '../shared/money.dart';

/// Nepal's standard VAT rate, 13%, expressed in basis points.
///
/// **Declared here rather than on `Purchase`,** because `Purchase` imports this
/// file: reading it from there would be a circular import. An invoice line already
/// takes its own constant for the same reason, so this keeps the two sides
/// symmetrical. `NepalTaxRules` remains the source of the rate in force; this is
/// the default for a line that does not state one.
const int purchaseStandardVatRate = 1300;

/// One line on a purchase bill.
///
/// ## Unlike an invoice line, a VAT rate may be set per line
///
/// A sales invoice charges VAT on the **combined** subtotal, because rounding each
/// line separately would drift from the return filed with the authority.
///
/// A purchase bill is different, and the reason is a mixed bill. One supplier can
/// invoice standard-rated goods alongside zero-rated ones in the same document,
/// and the correct treatment differs per line: standard-rated goods carry a VAT
/// claim, zero-rated goods **omit the VAT line rather than posting a zero**. That
/// cannot be expressed by a single rate on the purchase, so the rate lives here.
///
/// The common case — one supplier, one rate — is unaffected: [PurchaseLine]
/// defaults to the standard rate and [Purchase.vat] still sums the lines.
class PurchaseLine {
  const PurchaseLine._({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.vatRateBasisPoints,
    this.productId,
  });

  /// Builds a line. Quantity and unit price must both be positive; a zero-value
  /// line is a data-entry mistake and would put a meaningless row in a document
  /// that is evidence in an audit.
  factory PurchaseLine({
    required String description,
    required int quantity,
    required Money unitPrice,
    int? vatRateBasisPoints,
    String? productId,
  }) {
    if (description.trim().isEmpty) {
      throw ArgumentError('A purchase line needs a description.');
    }
    if (quantity < 1) {
      throw ArgumentError(
        'A purchase line quantity must be at least 1, got $quantity. A return '
        'is recorded as a separate purchase document, not a negative quantity.',
      );
    }
    if (!unitPrice.isPositive) {
      throw ArgumentError(
        'A purchase line unit price must be greater than zero, got '
        '${unitPrice.format()}.',
      );
    }
    final rate = vatRateBasisPoints ?? purchaseStandardVatRate;
    if (rate < 0) {
      throw ArgumentError(
        'A VAT rate must not be negative, got $rate basis points.',
      );
    }
    return PurchaseLine._(
      description: description.trim(),
      quantity: quantity,
      unitPrice: unitPrice,
      vatRateBasisPoints: rate,
      productId: _blankToNull(productId),
    );
  }

  final String description;

  /// Whole units. Fractional quantities need a unit-of-measure decision that has
  /// not been made, so they are not accepted — the same restriction as an
  /// invoice line, and for the same reason.
  final int quantity;

  /// Price for **one** unit, excluding VAT.
  ///
  /// Excluding, because this is also the value that enters inventory: goods are
  /// carried at cost and a recoverable tax is not part of cost.
  final Money unitPrice;

  /// The VAT rate for this line, in basis points.
  ///
  /// Defaults to the standard rate. **Zero is meaningful and is not the same as
  /// unset** — a zero-rated line omits its VAT line entirely, which is what a
  /// return expects and what the VAT Act requires for a zero-rated supply.
  final int vatRateBasisPoints;

  /// The product this line received, or `null`.
  ///
  /// **Optional, deliberately.** A purchase can be of something that is not a
  /// tracked product: a service, a consumable, packaging, freight. Refusing a
  /// null `productId` would make those unrecordable, and a purchase of freight
  /// is a real thing a supplier invoices.
  final String? productId;

  /// Whether this line brings stock in.
  bool get receivesStock => productId != null;

  /// Quantity times unit price. Exact, with no rounding.
  Money get lineTotal => unitPrice.times(quantity);

  /// VAT on this line alone, half-up in integer paisa.
  ///
  /// Used only when lines carry **different** rates. A single-rate purchase sums
  /// the combined subtotal and charges once, exactly as a sales invoice does.
  Money get vat => lineTotal.applyBasisPoints(vatRateBasisPoints);

  @override
  String toString() => '$quantity x ${unitPrice.format()} $description';

  /// Blank means absent, so `''` and `null` cannot both spell "no product". A
  /// blank stored as `''` would match no product yet not be null, so a "stock to
  /// receive" query would miss the line.
  static String? _blankToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}