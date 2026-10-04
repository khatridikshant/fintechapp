import 'inventory_movement.dart';
import 'product.dart';
import 'product_category.dart';
import 'product_stock.dart';
import 'product_supplier.dart';

/// Port for storing products and their stock movements.
///
/// This is an interface owned by the domain. The implementation lives in
/// `infrastructure/`.
abstract interface class InventoryRepository {
  Future<void> saveProduct(Product product);

  Future<void> saveProducts(Iterable<Product> products);

  Future<Product?> productById(String id);

  Future<List<Product>> allProducts();

  /// Saves a category.
  ///
  /// Categories are reference data for the reports that group by them
  /// (ADR 013): they have no account and post nothing. The
  /// implementation refuses a tree V1 cannot report — a category whose
  /// parent does not exist, or that sits more than one level down —
  /// before anything is written, so such a category never reaches the
  /// book.
  Future<void> saveCategory(ProductCategory category);

  /// Every category, for the reports that group stock by them.
  Future<List<ProductCategory>> allCategories();

  /// Replaces a product's declared suppliers with exactly [suppliers].
  ///
  /// **Replaces rather than adds**, so the stored set is always what the caller
  /// last declared and cannot accumulate stale entries. Passing an empty list clears
  /// it, which is how a product goes back to having none.
  ///
  /// The product and every supplier must already exist; they are foreign keys, so a
  /// link naming something absent is a defect rather than a value to skip.
  Future<void> saveDeclaredSuppliers(
    String productId,
    List<ProductSupplier> suppliers,
  );

  /// The suppliers declared for one product.
  ///
  /// **Empty when none are declared**, which is an ordinary state — exactly as a
  /// product with no category is, for the same reason.
  Future<List<ProductSupplier>> declaredSuppliersFor(String productId);

  /// Every declared product-supplier link, for the reports that group by both.
  Future<List<ProductSupplier>> allDeclaredSuppliers();

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
