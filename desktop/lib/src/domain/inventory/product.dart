import '../shared/money.dart';

/// A product the business sells.
///
/// `cost` is deliberately **absent**. ADR 004 chose moving weighted average with
/// the running inventory *value* authoritative, and a cost per unit is derived
/// from that value rather than stored on the product. A stored cost is a second
/// source of truth that drifts. See `docs/INVENTORY_EXPLAINED.md`.
class Product {
  const Product._({
    required this.id,
    required this.name,
    required this.salePrice,
    required this.stockTrackingEnabled,
  });

  factory Product({
    required String id,
    required String name,
    required Money salePrice,
    bool stockTrackingEnabled = true,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('A product needs an id.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('A product needs a name.');
    }
    if (salePrice.isNegative) {
      throw ArgumentError(
        'A product sale price must not be negative, got '
        '${salePrice.format()}.',
      );
    }
    return Product._(
      id: id.trim(),
      name: name.trim(),
      salePrice: salePrice,
      stockTrackingEnabled: stockTrackingEnabled,
    );
  }

  final String id;

  final String name;

  /// What the product is sold for. The cost is derived from the inventory value,
  /// not stored here.
  final Money salePrice;

  /// Whether stock is tracked for this product.
  ///
  /// A service or a non-physical item is not stock-tracked, and is exempt from
  /// the negative-stock rule because it never has stock to go negative.
  final bool stockTrackingEnabled;

  @override
  bool operator ==(Object other) => other is Product && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Product($id, $name)';
}
