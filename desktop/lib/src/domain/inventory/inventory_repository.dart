import 'inventory_movement.dart';
import 'product.dart';
import 'product_stock.dart';

/// Port for storing products and their stock movements.
///
/// This is an interface owned by the domain. The implementation lives in
/// `infrastructure/`.
abstract interface class InventoryRepository {
  Future<void> saveProduct(Product product);

  Future<void> saveProducts(Iterable<Product> products);

  Future<Product?> productById(String id);

  Future<List<Product>> allProducts();

  /// Records a movement, refusing it if it would take the product below zero.
  ///
  /// The out-of-stock check and the write happen inside **one transaction**, so
  /// two issues cannot both be validated against a quantity that only one of them
  /// should have been allowed to take. Returns the resulting stock position.
  ///
  /// [journalEntryId] links the movement to the entry that accounts for it. The
  /// entry must already exist, because the column is a foreign key.
  ///
  /// Throws [NegativeStockException] when the movement would go below zero, in
  /// which case nothing is written.
  Future<ProductStock> applyMovement(
    Product product,
    InventoryMovement movement, {
    String? journalEntryId,
  });

  /// Every movement for one product, in date order then id.
  Future<List<InventoryMovement>> movementsFor(String productId);

  /// Every movement, in date order then id.
  Future<List<InventoryMovement>> allMovements();

  /// The product's current derived stock position.
  Future<ProductStock> stockOf(Product product);
}
