import '../shared/money.dart';

/// One line on an invoice.
class InvoiceLine {
  const InvoiceLine._({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.productId,
  });

  /// Builds a line. The quantity must be at least 1 and the unit price must be
  /// positive; a zero-value line is a data-entry mistake, and allowing it would
  /// let a meaningless row reach the ledger.
  factory InvoiceLine({
    required String description,
    required int quantity,
    required Money unitPrice,
    String? productId,
  }) {
    if (description.trim().isEmpty) {
      throw ArgumentError('An invoice line needs a description.');
    }
    if (quantity < 1) {
      throw ArgumentError(
        'An invoice line quantity must be at least 1, got $quantity. Use a '
        'credit note to reverse a sale; do not post a negative quantity.',
      );
    }
    if (!unitPrice.isPositive) {
      throw ArgumentError(
        'An invoice line unit price must be greater than zero, got '
        '${unitPrice.format()}.',
      );
    }
    return InvoiceLine._(
      description: description.trim(),
      quantity: quantity,
      unitPrice: unitPrice,
      productId: _blankToNull(productId),
    );
  }

  final String description;

  /// Whole units. Fractional quantities need a unit-of-measure decision that
  /// has not been made, so they are not accepted yet.
  final int quantity;

  final Money unitPrice;

  /// The catalogue product this line sells, or `null`.
  ///
  /// ## Why optional rather than required
  ///
  /// A business sells more than catalogue products: a service, a repair, an
  /// on-site job. Requiring a product would make those unrecordable, and refusing
  /// them would be worse than the inconsistency they introduce.
  ///
  /// ## What a product reference buys
  ///
  /// With one, issuing the invoice **issues stock and posts cost of sales at the
  /// derived cost** ([ProductStock.valueOfIssue]) in the same unit of work. Without
  /// one the line is a description and moves nothing — which is the state this field
  /// exists to end.
  final String? productId;

  /// Whether selling this line should reduce stock.
  bool get issuesStock => productId != null;

  /// Unit price times quantity. Exact, with no rounding, because both factors
  /// are whole numbers of minor units.
  Money get lineTotal => unitPrice.times(quantity);

  @override
  String toString() => '$quantity x ${unitPrice.format()} $description';

  /// Blank means absent, so `''` and `null` cannot both spell "not a product".
  /// A blank stored as `''` would match no product yet not be null, so a "stock to
  /// issue" query would miss the line.
  static String? _blankToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
