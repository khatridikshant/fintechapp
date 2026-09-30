import '../shared/money.dart';

/// One line on an invoice.
class InvoiceLine {
  const InvoiceLine._({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  /// Builds a line. The quantity must be at least 1 and the unit price must be
  /// positive; a zero-value line is a data-entry mistake, and allowing it would
  /// let a meaningless row reach the ledger.
  factory InvoiceLine({
    required String description,
    required int quantity,
    required Money unitPrice,
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
    );
  }

  final String description;

  /// Whole units. Fractional quantities need a unit-of-measure decision that
  /// has not been made, so they are not accepted yet.
  final int quantity;

  final Money unitPrice;

  /// Unit price times quantity. Exact, with no rounding, because both factors
  /// are whole numbers of minor units.
  Money get lineTotal => unitPrice.times(quantity);

  @override
  String toString() => '$quantity x ${unitPrice.format()} $description';
}
