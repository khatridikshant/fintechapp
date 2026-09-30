import 'package:drift/drift.dart' show OrderingTerm, Value;

import '../../domain/inventory/inventory_movement.dart';
import '../../domain/inventory/inventory_repository.dart';
import '../../domain/inventory/product.dart';
import '../../domain/inventory/product_stock.dart';
import '../../domain/shared/money.dart';
import 'app_database.dart';

class DriftInventoryRepository implements InventoryRepository {
  DriftInventoryRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> saveProduct(Product product) async {
    await _db.into(_db.products).insertOnConflictUpdate(_toCompanion(product));
  }

  @override
  Future<void> saveProducts(Iterable<Product> products) async {
    final companions = products.map(_toCompanion).toList();
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.products, companions);
    });
  }

  @override
  Future<Product?> productById(String id) async {
    final row = await (_db.select(_db.products)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<Product>> allProducts() async {
    final rows = await (_db.select(_db.products)
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
    return rows.map(_toDomain).toList();
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

  Product _toDomain(ProductRow row) => Product(
        id: row.id,
        name: row.name,
        salePrice: Money.minor(row.salePriceMinorUnits, row.currency),
        stockTrackingEnabled: row.stockTrackingEnabled,
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
