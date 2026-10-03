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
    this.categoryId,
  });

  factory Product({
    required String id,
    required String name,
    required Money salePrice,
    bool stockTrackingEnabled = true,
    String? categoryId,
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
      categoryId: _blankToNull(categoryId),
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

  /// The category this product belongs to, or `null`.
  ///
  /// **Optional, and a product with none is an ordinary product** — see ADR 013.
  /// Making it mandatory would block every book created before categories existed
  /// and would require inventing a placeholder category for historical stock,
  /// which is a fabrication.
  final String? categoryId;

  /// Whether this product sits in a category.
  bool get hasCategory => categoryId != null;

  /// A copy with different details. [id] cannot change.
  ///
  /// [clearCategory] exists because `null` otherwise cannot be distinguished from
  /// "not supplied", so a category could be set but never removed.
  Product copyWith({
    String? name,
    Money? salePrice,
    bool? stockTrackingEnabled,
    String? categoryId,
    bool clearCategory = false,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      salePrice: salePrice ?? this.salePrice,
      stockTrackingEnabled: stockTrackingEnabled ?? this.stockTrackingEnabled,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    );
  }

  @override
  bool operator ==(Object other) => other is Product && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Product($id, $name)';

  /// Blank means absent, so `''` and `null` cannot both spell "no category". A
  /// blank stored as `''` would match no category yet not be null, so a "products
  /// without a category" query would quietly miss it.
  static String? _blankToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
