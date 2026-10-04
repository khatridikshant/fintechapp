import 'package:drift/drift.dart' show OrderingTerm, Value;

import '../../domain/inventory/inventory_movement.dart';
import '../../domain/inventory/inventory_repository.dart';
import '../../domain/inventory/product.dart';
import '../../domain/inventory/product_category.dart';
import '../../domain/inventory/product_stock.dart';
import '../../domain/shared/money.dart';
import 'app_database.dart';

class DriftInventoryRepository implements InventoryRepository {
  DriftInventoryRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> saveProduct(Product product) async {
    await _db.into(_db.products).insertOnConflictUpdate(_toCompanion(product));
    await _saveCategoryAssignment(product);
  }

  @override
  Future<void> saveProducts(Iterable<Product> products) async {
    final companions = products.map(_toCompanion).toList();
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.products, companions);
    });
    for (final product in products) {
      await _saveCategoryAssignment(product);
    }
  }

  /// The product's category, in the separate assignments table.
  ///
  /// The row is deleted then re-inserted, so a product that had a
  /// category and no longer does ends up with no row at all rather
  /// than a stale one pointing at a category it left.
  Future<void> _saveCategoryAssignment(Product product) async {
    await (_db.delete(_db.productCategoryAssignments)
          ..where((t) => t.productId.equals(product.id)))
        .go();
    final categoryId = product.categoryId;
    if (categoryId == null) return;
    await _db.into(_db.productCategoryAssignments).insert(
          ProductCategoryAssignmentsCompanion.insert(
            productId: product.id,
            categoryId: categoryId,
          ),
        );
  }

  @override
  Future<void> saveCategory(ProductCategory category) async {
    // **Refuse a tree V1 cannot report before writing it** (ADR 013).
    // The report would refuse it anyway; refusing here keeps the bad
    // data out of the book in the first place. The parent must already
    // exist, so a category is saved parent-first.
    final tree = <String, ProductCategory>{
      for (final existing in await allCategories()) existing.id: existing,
      category.id: category,
    };
    category.assertWithinV1Depth(tree);

    await _db.into(_db.productCategories).insertOnConflictUpdate(
          ProductCategoriesCompanion.insert(
            id: category.id,
            code: category.code,
            name: category.name,
            parentId: Value(category.parentId),
          ),
        );
  }

  @override
  Future<List<ProductCategory>> allCategories() async {
    final rows = await (_db.select(_db.productCategories)
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
    return rows.map(_toDomainCategory).toList();
  }

  ProductCategory _toDomainCategory(ProductCategoryRow row) => ProductCategory(
        id: row.id,
        code: row.code,
        name: row.name,
        parentId: row.parentId,
      );

  @override
  Future<Product?> productById(String id) async {
    final row = await (_db.select(_db.products)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    final categoryOf = await _categoryAssignments();
    return _toDomain(row, categoryOf[row.id]);
  }

  @override
  Future<List<Product>> allProducts() async {
    final rows = await (_db.select(_db.products)
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
    final categoryOf = await _categoryAssignments();
    return rows
        .map((ProductRow row) => _toDomain(row, categoryOf[row.id]))
        .toList();
  }

  /// The category each product is assigned to, by product id.
  ///
  /// Read once for a whole read, so listing every product is two
  /// queries rather than one per product.
  Future<Map<String, String>> _categoryAssignments() async {
    final rows = await _db.select(_db.productCategoryAssignments).get();
    return <String, String>{
      for (final row in rows) row.productId: row.categoryId,
    };
  }

  @override
  Future<ProductStock> applyMovement(
    Product product,
    InventoryMovement movement, {
    String? journalEntryId,
  }) {
    // The out-of-stock check and the write happen in one transaction, so two
    // issues cannot both be validated against a quantity that only one of them
    // should have been allowed to take.
    return _db.transaction(() async {
      final current = await _stockWithin(product);
      // Throws NegativeStockException when this would go below zero, in which
      // case the transaction is abandoned and nothing is written.
      final updated = current.apply(movement);

      await _db.into(_db.inventoryMovements).insert(
            InventoryMovementsCompanion.insert(
              id: movement.id,
              productId: movement.productId,
              date: movement.date,
              reason: movement.reason.name,
              quantity: movement.quantity,
              valueMinorUnits: movement.value.minorUnits,
              currency: movement.currency,
              journalEntryId: Value(journalEntryId),
            ),
          );

      return updated;
    });
  }

  @override
  Future<List<InventoryMovement>> movementsFor(String productId) async {
    final rows = await (_db.select(_db.inventoryMovements)
          ..where((t) => t.productId.equals(productId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.date),
            (t) => OrderingTerm(expression: t.id),
          ]))
        .get();
    return rows.map(_toDomainMovement).toList();
  }

  @override
  Future<List<InventoryMovement>> allMovements() async {
    final rows = await (_db.select(_db.inventoryMovements)
          ..orderBy([
            (t) => OrderingTerm(expression: t.date),
            (t) => OrderingTerm(expression: t.id),
          ]))
        .get();
    return rows.map(_toDomainMovement).toList();
  }

  @override
  Future<ProductStock> stockOf(Product product) => _stockWithin(product);

  /// The product's stock position, read inside the caller's transaction.
  Future<ProductStock> _stockWithin(Product product) async {
    final rows = await (_db.select(_db.inventoryMovements)
          ..where((t) => t.productId.equals(product.id)))
        .get();
    return ProductStock.of(
      product,
      rows.map(_toDomainMovement),
      currency: product.salePrice.currency,
    );
  }

  ProductsCompanion _toCompanion(Product product) => ProductsCompanion.insert(
        id: product.id,
        name: product.name,
        salePriceMinorUnits: product.salePrice.minorUnits,
        currency: product.salePrice.currency,
        stockTrackingEnabled: product.stockTrackingEnabled,
      );

  Product _toDomain(ProductRow row, String? categoryId) => Product(
        id: row.id,
        name: row.name,
        salePrice: Money.minor(row.salePriceMinorUnits, row.currency),
        stockTrackingEnabled: row.stockTrackingEnabled,
        categoryId: categoryId,
      );

  /// Rebuilds a movement from its row.
  ///
  /// The reason is resolved rather than assumed, so a row written by a future
  /// release with a reason this one does not know about fails loudly instead of
  /// being silently treated as an adjustment.
  InventoryMovement _toDomainMovement(InventoryMovementRow row) {
    final reason = MovementReason.fromName(row.reason);
    if (reason == null) {
      throw StateError(
        'Inventory movement ${row.id} has an unknown reason "${row.reason}".',
      );
    }
    return InventoryMovement(
      id: row.id,
      productId: row.productId,
      date: row.date,
      reason: reason,
      quantity: row.quantity,
      value: Money.minor(row.valueMinorUnits, row.currency),
    );
  }
}
