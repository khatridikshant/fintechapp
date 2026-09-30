import 'package:financeapp/src/domain/inventory/inventory_movement.dart';
import 'package:financeapp/src/domain/inventory/product.dart';
import 'package:financeapp/src/domain/inventory/product_stock.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:flutter_test/flutter_test.dart';

const npr = 'NPR';

Money rs(int majorUnits) => Money.minor(majorUnits * 100, npr);

DateTime day(int d) => DateTime(2026, 9, d);

final keyboard = Product(
  id: 'prod-keyboard',
  name: 'Keyboard',
  salePrice: rs(200),
);

final service = Product(
  id: 'prod-service',
  name: 'Installation service',
  salePrice: rs(500),
  stockTrackingEnabled: false,
);

InventoryMovement receipt(
  int quantity,
  int valueRupees, {
  String id = 'MV-1',
  String productId = 'prod-keyboard',
  MovementReason reason = MovementReason.purchase,
  DateTime? date,
}) =>
    InventoryMovement.receipt(
      id: id,
      productId: productId,
      date: date ?? day(1),
      reason: reason,
      quantity: quantity,
      value: rs(valueRupees),
    );

InventoryMovement issue(
  int quantity,
  int valueRupees, {
  String id = 'MV-1',
  String productId = 'prod-keyboard',
  MovementReason reason = MovementReason.sale,
  DateTime? date,
}) =>
    InventoryMovement.issue(
      id: id,
      productId: productId,
      date: date ?? day(2),
      reason: reason,
      quantity: quantity,
      value: rs(valueRupees),
    );

void main() {
  group('Product', () {
    test('accepts a well-formed product', () {
      expect(keyboard.id, 'prod-keyboard');
      expect(keyboard.name, 'Keyboard');
      expect(keyboard.salePrice.minorUnits, 20000);
      expect(keyboard.stockTrackingEnabled, isTrue);
    });

    test('a blank id or name is rejected', () {
      expect(
        () => Product(id: '  ', name: 'X', salePrice: rs(1)),
        throwsArgumentError,
      );
      expect(
        () => Product(id: 'p', name: '  ', salePrice: rs(1)),
        throwsArgumentError,
      );
    });

    test('a negative sale price is rejected', () {
      expect(
        () => Product(id: 'p', name: 'X', salePrice: Money.minor(-1, npr)),
        throwsArgumentError,
      );
    });

    test('a free product is allowed', () {
      // A zero price is legitimate: a giveaway, or an item priced later.
      expect(
        Product(id: 'p', name: 'Sample', salePrice: rs(0)).salePrice.isZero,
        isTrue,
      );
    });

    test('compares by id', () {
      expect(
        Product(id: 'p', name: 'A', salePrice: rs(1)),
        Product(id: 'p', name: 'B', salePrice: rs(9)),
      );
    });
  });

  group('InventoryMovement', () {
    test('a receipt raises both quantity and value', () {
      final movement = receipt(10, 1000);

      expect(movement.quantity, 10);
      expect(movement.value.minorUnits, 100000);
      expect(movement.isReceipt, isTrue);
      expect(movement.isIssue, isFalse);
      expect(movement.reason, MovementReason.purchase);
    });

    test('an issue lowers both quantity and value', () {
      final movement = issue(10, 1100);

      expect(movement.quantity, -10);
      expect(movement.value.minorUnits, -110000);
      expect(movement.isIssue, isTrue);
      expect(movement.issuedQuantity, 10);
    });

    test('a zero quantity is rejected', () {
      expect(
        () => InventoryMovement(
          id: 'MV-1',
          productId: 'prod-keyboard',
          date: day(1),
          reason: MovementReason.adjustment,
          quantity: 0,
          value: rs(100),
        ),
        throwsArgumentError,
      );
    });

    test('a zero value is rejected', () {
      // Quantity changing without value changing would break the reconciliation
      // between units and what they are worth.
      expect(
        () => InventoryMovement(
          id: 'MV-1',
          productId: 'prod-keyboard',
          date: day(1),
          reason: MovementReason.adjustment,
          quantity: 5,
          value: rs(0),
        ),
        throwsArgumentError,
      );
    });

    test('quantity and value must point the same way', () {
      expect(
        () => InventoryMovement(
          id: 'MV-1',
          productId: 'prod-keyboard',
          date: day(1),
          reason: MovementReason.adjustment,
          quantity: 5,
          value: Money.minor(-100, npr),
        ),
        throwsArgumentError,
      );
    });

    test('the convenience factories refuse the wrong direction', () {
      expect(
          () => InventoryMovement.receipt(
                id: 'MV-1',
                productId: 'p',
                date: day(1),
                reason: MovementReason.purchase,
                quantity: -1,
                value: rs(1),
              ),
          throwsArgumentError);
      expect(
          () => InventoryMovement.issue(
                id: 'MV-1',
                productId: 'p',
                date: day(1),
                reason: MovementReason.sale,
                quantity: -1,
                value: rs(1),
              ),
          throwsArgumentError);
    });

    test('a blank id or product is rejected', () {
      expect(
        () => InventoryMovement(
          id: ' ',
          productId: 'p',
          date: day(1),
          reason: MovementReason.purchase,
          quantity: 1,
          value: rs(1),
        ),
        throwsArgumentError,
      );
      expect(
        () => InventoryMovement(
          id: 'MV-1',
          productId: '',
          date: day(1),
          reason: MovementReason.purchase,
          quantity: 1,
          value: rs(1),
        ),
        throwsArgumentError,
      );
    });

    test('every reason resolves from its persisted name', () {
      for (final reason in MovementReason.values) {
        expect(MovementReason.fromName(reason.name), reason);
        expect(reason.label, isNotEmpty);
      }
      expect(MovementReason.fromName('nonsense'), isNull);
    });

    test('receipt reasons are marked as such', () {
      expect(MovementReason.openingStock.isReceipt, isTrue);
      expect(MovementReason.purchase.isReceipt, isTrue);
      expect(MovementReason.saleReturn.isReceipt, isTrue);
      expect(MovementReason.sale.isReceipt, isFalse);
      expect(MovementReason.purchaseReturn.isReceipt, isFalse);
    });
  });

  group('ProductStock', () {
    test('a product with no movements is empty, not an error', () {
      final stock = ProductStock.of(keyboard, const []);

      expect(stock.quantity, 0);
      expect(stock.value.isZero, isTrue);
      expect(stock.isEmpty, isTrue);
      expect(stock.costPerUnit.isZero, isTrue);
    });

    test('the worked example from the explainer: 10 at 100 then 10 at 120', () {
      final stock = ProductStock.of(keyboard, [
        receipt(10, 1000, id: 'MV-1'),
        receipt(10, 1200, id: 'MV-2', date: day(3)),
      ]);

      expect(stock.quantity, 20);
      expect(stock.value.minorUnits, 220000, reason: 'Rs 2,200');
      expect(stock.costPerUnit.minorUnits, 11000, reason: 'Rs 110 each');
    });

    test('issuing 10 of those 20 takes out exactly half the value', () {
      final stock = ProductStock.of(keyboard, [
        receipt(10, 1000, id: 'MV-1'),
        receipt(10, 1200, id: 'MV-2', date: day(3)),
      ]);

      final cost = stock.valueOfIssue(10);

      // Half of Rs 2,200 is Rs 1,100.
      expect(cost.minorUnits, -110000);

      final after = stock.apply(issue(10, 1100, id: 'MV-3', date: day(4)));
      expect(after.quantity, 10);
      expect(after.value.minorUnits, 110000);
    });

    test('remaining value is exactly the original less what left', () {
      // This is the property that makes value-first accounting work: the book
      // reconciles by construction, so there is nothing to reconcile.
      final stock = ProductStock.of(keyboard, [
        receipt(10, 1000, id: 'MV-1'),
        receipt(10, 1200, id: 'MV-2', date: day(3)),
      ]);

      final issued = stock.valueOfIssue(7);
      final after = stock.apply(
        InventoryMovement(
          id: 'MV-3',
          productId: 'prod-keyboard',
          date: day(4),
          reason: MovementReason.sale,
          quantity: -7,
          value: issued,
        ),
      );

      expect(
        after.value.minorUnits,
        stock.value.minorUnits + issued.minorUnits,
      );
      expect(after.quantity, 13);
    });

    test('the total value always equals the sum of the movements', () {
      final movements = [
        receipt(10, 1000, id: 'MV-1'),
        receipt(5, 850, id: 'MV-2', date: day(3)),
        issue(3, 600, id: 'MV-3', date: day(4)),
        receipt(2, 400, id: 'MV-4', date: day(5)),
        issue(1, 220, id: 'MV-5', date: day(6)),
      ];
      final stock = ProductStock.of(keyboard, movements);

      final summedQuantity = movements.fold<int>(0, (a, m) => a + m.quantity);
      final summedValue = movements.fold<int>(
        0,
        (a, m) => a + m.value.minorUnits,
      );

      expect(stock.quantity, summedQuantity);
      expect(stock.value.minorUnits, summedValue);
    });

    test('issuing everything leaves exactly zero value, not stray paisa', () {
      // 3 units at an awkward value so the unit cost does not divide evenly.
      final stock = ProductStock.of(keyboard, [receipt(3, 1000, id: 'MV-1')]);

      final cost = stock.valueOfIssue(3);
      expect(cost.minorUnits, -100000,
          reason: 'clearing the holding must take the whole value, however '
              'awkwardly the unit cost divides');

      final after = stock.apply(
        InventoryMovement(
          id: 'MV-2',
          productId: 'prod-keyboard',
          date: day(2),
          reason: MovementReason.sale,
          quantity: -3,
          value: cost,
        ),
      );
      expect(after.quantity, 0);
      expect(after.value.isZero, isTrue);
      expect(after.isEmpty, isTrue);
    });

    test('summing another product\'s movements is refused', () {
      expect(
        () => ProductStock.of(keyboard, [receipt(1, 100, productId: 'other')]),
        throwsArgumentError,
      );
    });

    test('applying another product\'s movement is refused', () {
      final stock = ProductStock.of(keyboard, const []);
      expect(
        () => stock.apply(receipt(1, 100, productId: 'other')),
        throwsArgumentError,
      );
    });
  });

  group('Negative stock is blocked', () {
    test('issuing more than is on hand throws', () {
      final stock = ProductStock.of(keyboard, [receipt(10, 1000, id: 'MV-1')]);

      expect(
        () => stock.apply(issue(11, 1100, id: 'MV-2')),
        throwsA(isA<NegativeStockException>()),
      );
    });

    test('the exception explains the shortfall', () {
      final stock = ProductStock.of(keyboard, [receipt(10, 1000, id: 'MV-1')]);

      try {
        stock.apply(issue(13, 1300, id: 'MV-2'));
        fail('expected the issue to be refused');
      } on NegativeStockException catch (e) {
        expect(e.onHand, 10);
        expect(e.requested, 13);
        expect(e.shortfall, 3);
        expect(e.toString(), contains('13'));
        expect(e.toString(), contains('10'));
      }
    });

    test('issuing exactly what is on hand is allowed', () {
      final stock = ProductStock.of(keyboard, [receipt(10, 1000, id: 'MV-1')]);

      final after = stock.apply(issue(10, 1000, id: 'MV-2'));
      expect(after.quantity, 0);
    });

    test('a non-stock-tracked product may go negative', () {
      // A service has no stock to run out of, so the rule does not apply.
      final stock = ProductStock.of(service, const []);

      final after = stock.apply(issue(1, 500, productId: 'prod-service'));
      expect(after.quantity, -1);
    });

    test('valueOfIssue refuses to remove more than is held', () {
      final stock = ProductStock.of(keyboard, [receipt(5, 500, id: 'MV-1')]);

      expect(
        () => stock.valueOfIssue(6),
        throwsA(isA<NegativeStockException>()),
      );
    });

    test('valueOfIssue refuses a non-positive quantity', () {
      final stock = ProductStock.of(keyboard, [receipt(5, 500, id: 'MV-1')]);

      expect(() => stock.valueOfIssue(0), throwsArgumentError);
      expect(() => stock.valueOfIssue(-1), throwsArgumentError);
    });
  });
}
