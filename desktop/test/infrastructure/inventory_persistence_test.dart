import 'dart:io';

import 'package:financeapp/src/domain/inventory/inventory_movement.dart';
import 'package:financeapp/src/domain/inventory/product.dart';
import 'package:financeapp/src/domain/inventory/product_stock.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/drift_inventory_repository.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const npr = 'NPR';

Money rs(int majorUnits) => Money.minor(majorUnits * 100, npr);

DateTime day(int d) => DateTime(2026, 9, d);

final keyboard = Product(
  id: 'prod-keyboard',
  name: 'Keyboard',
  salePrice: rs(200),
);

InventoryMovement receipt(
  int quantity,
  int valueRupees, {
  String id = 'MV-1',
  DateTime? date,
}) =>
    InventoryMovement.receipt(
      id: id,
      productId: keyboard.id,
      date: date ?? day(1),
      reason: MovementReason.purchase,
      quantity: quantity,
      value: rs(valueRupees),
    );

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('financeapp_inventory_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('Products persist', () {
    test('round-trip every field', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final inventory = DriftInventoryRepository(db);

      await inventory.saveProduct(keyboard);

      final loaded = await inventory.productById('prod-keyboard');
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Keyboard');
      expect(loaded.salePrice.minorUnits, 20000);
      expect(loaded.stockTrackingEnabled, isTrue);
    });

    test('the stock-tracking flag round-trips when false', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final inventory = DriftInventoryRepository(db);

      await inventory.saveProduct(
        Product(
          id: 'prod-service',
          name: 'Service',
          salePrice: rs(500),
          stockTrackingEnabled: false,
        ),
      );

      final loaded = await inventory.productById('prod-service');
      expect(loaded!.stockTrackingEnabled, isFalse,
          reason: 'a flag that silently reloads as true would start enforcing '
              'stock rules on a service');
    });

    test('saving the same id updates rather than duplicating', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final inventory = DriftInventoryRepository(db);

      await inventory.saveProduct(keyboard);
      await inventory.saveProduct(
        Product(id: keyboard.id, name: 'Renamed', salePrice: rs(250)),
      );

      final all = await inventory.allProducts();
      expect(all, hasLength(1));
      expect(all.single.name, 'Renamed');
    });

    test('an unknown product id returns null', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      expect(
        await DriftInventoryRepository(db).productById('nobody'),
        isNull,
      );
    });
  });

  group('Movements build up stock', () {
    test('the worked example from the explainer, through the database',
        () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final inventory = DriftInventoryRepository(db);
      await inventory.saveProduct(keyboard);

      await inventory.applyMovement(keyboard, receipt(10, 1000, id: 'MV-1'));
      final afterSecond = await inventory.applyMovement(
        keyboard,
        receipt(10, 1200, id: 'MV-2', date: day(3)),
      );

      expect(afterSecond.quantity, 20);
      expect(afterSecond.value.minorUnits, 220000, reason: 'Rs 2,200');
      expect(afterSecond.costPerUnit.minorUnits, 11000, reason: 'Rs 110 each');
    });

    test('issuing takes value out at the derived cost', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final inventory = DriftInventoryRepository(db);
      await inventory.saveProduct(keyboard);

      await inventory.applyMovement(keyboard, receipt(10, 1000, id: 'MV-1'));
      await inventory.applyMovement(
        keyboard,
        receipt(10, 1200, id: 'MV-2', date: day(3)),
      );

      final current = await inventory.stockOf(keyboard);
      final cost = current.valueOfIssue(10);
      final after = await inventory.applyMovement(
        keyboard,
        InventoryMovement(
          id: 'MV-3',
          productId: keyboard.id,
          date: day(4),
          reason: MovementReason.sale,
          quantity: -10,
          value: cost,
        ),
      );

      expect(cost.minorUnits, -110000);
      expect(after.quantity, 10);
      expect(after.value.minorUnits, 110000);
    });

    test('reloaded stock equals the sum of the persisted movements', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final inventory = DriftInventoryRepository(db);
      await inventory.saveProduct(keyboard);

      await inventory.applyMovement(keyboard, receipt(10, 1000, id: 'MV-1'));
      await inventory.applyMovement(
        keyboard,
        receipt(5, 850, id: 'MV-2', date: day(3)),
      );
      await inventory.applyMovement(
        keyboard,
        InventoryMovement(
          id: 'MV-3',
          productId: keyboard.id,
          date: day(4),
          reason: MovementReason.sale,
          quantity: -3,
          value: rs(-600),
        ),
      );

      final movements = await inventory.movementsFor(keyboard.id);
      final stock = await inventory.stockOf(keyboard);

      expect(movements, hasLength(3));
      expect(stock.quantity, movements.fold<int>(0, (a, m) => a + m.quantity));
      expect(
        stock.value.minorUnits,
        movements.fold<int>(0, (a, m) => a + m.value.minorUnits),
      );
    });

    test('a movement round-trips with its reason intact', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final inventory = DriftInventoryRepository(db);
      await inventory.saveProduct(keyboard);

      await inventory.applyMovement(
        keyboard,
        InventoryMovement.receipt(
          id: 'MV-1',
          productId: keyboard.id,
          date: day(1),
          reason: MovementReason.openingStock,
          quantity: 7,
          value: rs(700),
        ),
      );

      final loaded = await inventory.movementsFor(keyboard.id);
      expect(loaded.single.reason, MovementReason.openingStock);
      expect(loaded.single.quantity, 7);
      expect(loaded.single.value.minorUnits, 70000);
      expect(loaded.single.date, day(1));
    });
  });

  group('Negative stock is blocked at the repository', () {
    test('an issue beyond what is held is refused, and nothing is written',
        () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final inventory = DriftInventoryRepository(db);
      await inventory.saveProduct(keyboard);

      await inventory.applyMovement(keyboard, receipt(10, 1000, id: 'MV-1'));

      await expectLater(
        inventory.applyMovement(
          keyboard,
          InventoryMovement(
            id: 'MV-TOOMANY',
            productId: keyboard.id,
            date: day(2),
            reason: MovementReason.sale,
            quantity: -11,
            value: rs(-1100),
          ),
        ),
        throwsA(isA<NegativeStockException>()),
      );

      expect(await inventory.movementsFor(keyboard.id), hasLength(1),
          reason: 'the refused movement must not be written at all');
      final stock = await inventory.stockOf(keyboard);
      expect(stock.quantity, 10);
      expect(stock.value.minorUnits, 100000);
    });

    test('issuing exactly the holding leaves zero quantity and zero value',
        () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final inventory = DriftInventoryRepository(db);
      await inventory.saveProduct(keyboard);

      await inventory.applyMovement(keyboard, receipt(3, 1000, id: 'MV-1'));

      final current = await inventory.stockOf(keyboard);
      final after = await inventory.applyMovement(
        keyboard,
        InventoryMovement(
          id: 'MV-2',
          productId: keyboard.id,
          date: day(2),
          reason: MovementReason.sale,
          quantity: -3,
          value: current.valueOfIssue(3),
        ),
      );

      expect(after.quantity, 0);
      expect(after.value.isZero, isTrue);
    });
  });

  group('The database refuses bad inventory rows', () {
    test('a movement for a product that does not exist is rejected', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      await expectLater(
        db.customStatement(
          'INSERT INTO inventory_movements '
          '(id, product_id, date, reason, quantity, value_minor_units, currency) '
          'VALUES (?, ?, ?, ?, ?, ?, ?)',
          ['MV-ORPHAN', 'prod-nobody', 1, 'purchase', 1, 100, npr],
        ),
        throwsA(
          predicate((e) => e.toString().toLowerCase().contains('foreign key')),
        ),
      );
    });

    test('a zero quantity is rejected', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final inventory = DriftInventoryRepository(db);
      await inventory.saveProduct(keyboard);

      await expectLater(
        db.customStatement(
          'INSERT INTO inventory_movements '
          '(id, product_id, date, reason, quantity, value_minor_units, currency) '
          'VALUES (?, ?, ?, ?, ?, ?, ?)',
          ['MV-ZERO', keyboard.id, 1, 'adjustment', 0, 100, npr],
        ),
        throwsA(predicate((e) => e.toString().toLowerCase().contains('check'))),
      );
    });

    test('quantity and value pointing opposite ways is rejected', () async {
      // The direction rule is enforced by the database too, not only by the
      // domain, so a bad row cannot be written by bypassing the domain.
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final inventory = DriftInventoryRepository(db);
      await inventory.saveProduct(keyboard);

      await expectLater(
        db.customStatement(
          'INSERT INTO inventory_movements '
          '(id, product_id, date, reason, quantity, value_minor_units, currency) '
          'VALUES (?, ?, ?, ?, ?, ?, ?)',
          ['MV-BADSIGN', keyboard.id, 1, 'adjustment', 5, -100, npr],
        ),
        throwsA(predicate((e) => e.toString().toLowerCase().contains('check'))),
      );
    });

    test('a product with a blank name is rejected', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      await expectLater(
        db.customStatement(
          'INSERT INTO products '
          '(id, name, sale_price_minor_units, currency, stock_tracking_enabled) '
          'VALUES (?, ?, ?, ?, ?)',
          ['prod-bad', '   ', 100, npr, 1],
        ),
        throwsA(predicate((e) => e.toString().toLowerCase().contains('check'))),
      );
    });
  });

  group('Money is stored exactly', () {
    test('inventory money columns are INTEGER, never REAL', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      Future<Map<String, String>> columnsOf(String table) async {
        final rows = await db
            .customSelect("SELECT name, type FROM pragma_table_info('$table')")
            .get();
        return {
          for (final row in rows)
            row.read<String>('name'): row.read<String>('type'),
        };
      }

      final productColumns = await columnsOf('products');
      expect(
          productColumns['sale_price_minor_units']?.toUpperCase(), 'INTEGER');
      final movementColumns = await columnsOf('inventory_movements');
      expect(movementColumns['value_minor_units']?.toUpperCase(), 'INTEGER');
      expect(movementColumns['quantity']?.toUpperCase(), 'INTEGER');
    });

    test('an awkward value round-trips exactly', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final inventory = DriftInventoryRepository(db);
      await inventory.saveProduct(keyboard);

      await inventory.applyMovement(
        keyboard,
        InventoryMovement.receipt(
          id: 'MV-1',
          productId: keyboard.id,
          date: day(1),
          reason: MovementReason.openingStock,
          quantity: 1,
          value: const Money.minor(128450007, npr),
        ),
      );

      final stock = await inventory.stockOf(keyboard);
      expect(stock.value.minorUnits, 128450007);
    });
  });

  group('Durability', () {
    test('products and movements survive closing and reopening', () async {
      final file = File(p.join(tempDir.path, 'accounting-FY-2082-83.db'));

      final db = openFileDatabase(file);
      final inventory = DriftInventoryRepository(db);
      await inventory.saveProduct(keyboard);
      await inventory.applyMovement(keyboard, receipt(10, 1000, id: 'MV-1'));
      await inventory.applyMovement(
        keyboard,
        receipt(10, 1200, id: 'MV-2', date: day(3)),
      );
      await db.close();

      final reopened = openFileDatabase(file);
      final reloaded = DriftInventoryRepository(reopened);
      final product = await reloaded.productById(keyboard.id);
      final stock = await reloaded.stockOf(product!);
      await reopened.close();

      expect(product.name, 'Keyboard');
      expect(stock.quantity, 20,
          reason: 'stock must be reconstructible after a restart, since it is '
              'derived rather than stored');
      expect(stock.value.minorUnits, 220000);
      expect(stock.costPerUnit.minorUnits, 11000);
    });
  });
}
