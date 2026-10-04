/// A declared link between a product and a supplier that can provide it.
///
/// ## What this is
///
/// **Catalogue** reference data: who this business normally buys this product from.
/// It exists so that later reports can group spend by supplier and by category
/// together -- "what do we buy from this supplier, and how does it break down by
/// category" -- without re-deriving the answer from old bills every time.
///
/// ## Why this is many-to-many, not one supplier per product
///
/// A business may buy the same product from two suppliers at two different prices,
/// and that is ordinary trading rather than a data error. One supplier per product
/// would force the second purchase to be recorded against the wrong supplier, which
/// is a worse lie than the omission this relation was added to fix.
///
/// ## What this is deliberately **not**
///
/// It is **not** a rule about who may be billed for the product. The purchase bill
/// is the authority on who actually supplied the goods, and it records that on every
/// line. **A purchase from a supplier who is not on this list is recorded and then
/// reported, never refused** -- because refusing it would mean refusing to record
/// goods that genuinely arrived.
///
/// ## Why the ids and not the objects
///
/// **Both ends are ids, not [Product] and [Supplier]**, which is why this file
/// imports nothing. A link that held the two objects would silently embed a copy of
/// each, and the copy would not change when the real one did.
///
/// The same reasoning is why the real home of this relation is the join table and
/// **not a `supplierIds` list on [Product]**. Two copies of a many-to-many relation
/// drift, and specification section 23 forbids keeping the same fact twice: the copy
/// that is out of date is silently wrong in a report, which is the failure this whole
/// screen was built to prevent.
class ProductSupplier {
  const ProductSupplier._({required this.productId, required this.supplierId});

  factory ProductSupplier(
      {required String productId, required String supplierId}) {
    return ProductSupplier._(
      productId:
          _requireText(productId, 'A product-supplier link needs a product.'),
      supplierId: _requireText(
        supplierId,
        'A product-supplier link needs a supplier.',
      ),
    );
  }

  /// The product that can be bought from [supplierId].
  final String productId;

  /// A supplier that can supply [productId].
  final String supplierId;

  /// Whether this link names the given supplier.
  ///
  /// [supplierId] is compared exactly. **No blank-means-absent rule here**, because
  /// unlike an account name a supplier id is not free text a person types -- it is
  /// written by the system, so there is no second spelling to reconcile.
  bool names(String supplierId) => this.supplierId == supplierId;

  /// Identity is the **pair**, so re-saving the same link is not a second fact.
  ///
  /// This is what lets a repository replace a product's set with delete-then-insert
  /// and never end up holding a duplicate.
  @override
  bool operator ==(Object other) =>
      other is ProductSupplier &&
      other.productId == productId &&
      other.supplierId == supplierId;

  @override
  int get hashCode => Object.hash(productId, supplierId);

  @override
  String toString() => 'ProductSupplier($productId, $supplierId)';

  static String _requireText(String value, String message) {
    if (value.trim().isEmpty) throw ArgumentError(message);
    return value.trim();
  }
}
