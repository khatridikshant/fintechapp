import 'package:financeapp/src/application/create_product.dart';
import 'package:financeapp/src/domain/inventory/inventory_repository.dart';
import 'package:financeapp/src/domain/inventory/product.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/domain/shared/unit_of_work.dart';
import 'package:financeapp/src/presentation/app_services.dart';
import 'package:financeapp/src/presentation/finance_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake for [CreateProduct], recording what the screen passed.
class _FakeCreateProduct implements CreateProduct {
  _FakeCreateProduct({this.refuse});

  ProductRejected? refuse;
  final List<Map<String, Object?>> calls = <Map<String, Object?>>[];

  // Never reached: the screen only hands over what was typed.
  @override
  final InventoryRepository inventory = _UnusedInventory();
  @override
  final UnitOfWork unitOfWork = _UnusedUnitOfWork();

  @override
  Future<ProductCreated> call({
    required String name,
    required num salePriceRupees,
    bool stockTrackingEnabled = true,
  }) async {
    calls.add(<String, Object?>{
      'name': name,
      'salePriceRupees': salePriceRupees,
      'stockTrackingEnabled': stockTrackingEnabled,
    });

    final scripted = refuse;
    if (scripted != null) throw scripted;

    return ProductCreated(
      Product(
        id: 'prd-1',
        name: name,
        salePrice: _money(salePriceRupees),
        stockTrackingEnabled: stockTrackingEnabled,
      ),
    );
  }
}

/// Widget tests for the New Product screen.
///
/// The screen is a catalogue entry, so the only thing worth protecting is that it
/// **passes the typed price through untouched** and asks for nothing that would
/// become a second source of truth.
void main() {
  Future<void> open(
      WidgetTester tester, _FakeCreateProduct createProduct) async {
    tester.view.physicalSize = const Size(1600, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      FinanceApp(services: AppServices(createProduct: createProduct)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Products'));
    await tester.pumpAndSettle();
  }

  group('the form', () {
    testWidgets('asks for a name, a price, and whether stock is tracked',
        (tester) async {
      await open(tester, _FakeCreateProduct());

      for (final key in <String>[
        'product-name-field',
        'product-price-field',
        'product-track-stock-field',
        'product-save-button',
      ]) {
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget,
            reason: '$key must be on the form');
      }
    });

    testWidgets('never asks for a cost, which would drift from the stock value',
        (tester) async {
      await open(tester, _FakeCreateProduct());

      expect(find.textContaining('cost comes from the stock'), findsOneWidget);
      expect(find.textContaining('Cost'), findsNothing);
    });

    testWidgets('will not save without a name', (tester) async {
      final fake = _FakeCreateProduct();
      await open(tester, fake);

      await tester.enterText(
        find.byKey(const ValueKey<String>('product-price-field')),
        '100',
      );
      await tester
          .tap(find.byKey(const ValueKey<String>('product-save-button')));
      await tester.pumpAndSettle();

      expect(fake.calls, isEmpty);
      expect(find.text('Enter a name.'), findsOneWidget);
    });
  });

  group('saving', () {
    testWidgets('passes the typed price through exactly', (tester) async {
      final fake = _FakeCreateProduct();
      await open(tester, fake);

      await tester.enterText(
        find.byKey(const ValueKey<String>('product-name-field')),
        'Keyboard',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('product-price-field')),
        '2500.50',
      );
      await tester
          .tap(find.byKey(const ValueKey<String>('product-save-button')));
      await tester.pumpAndSettle();

      expect(fake.calls, hasLength(1));
      expect(fake.calls.single['salePriceRupees'], 2500.50);
    });

    testWidgets('treats a blank price as zero, because a product may be free',
        (tester) async {
      final fake = _FakeCreateProduct();
      await open(tester, fake);

      await tester.enterText(
        find.byKey(const ValueKey<String>('product-name-field')),
        'Sample',
      );
      await tester
          .tap(find.byKey(const ValueKey<String>('product-save-button')));
      await tester.pumpAndSettle();

      expect(fake.calls.single['salePriceRupees'], 0);
    });

    testWidgets('can record a service, which is not stock-tracked',
        (tester) async {
      final fake = _FakeCreateProduct();
      await open(tester, fake);

      await tester.enterText(
        find.byKey(const ValueKey<String>('product-name-field')),
        'Delivery',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('product-track-stock-field')),
      );
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey<String>('product-save-button')));
      await tester.pumpAndSettle();

      expect(fake.calls.single['stockTrackingEnabled'], isFalse);
    });

    testWidgets("shows the domain's own refusal", (tester) async {
      await open(
        tester,
        _FakeCreateProduct(
          refuse: ProductRejected('A product sale price must not be negative.'),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('product-name-field')),
        'Keyboard',
      );
      await tester
          .tap(find.byKey(const ValueKey<String>('product-save-button')));
      await tester.pumpAndSettle();

      expect(
        find.text('A product sale price must not be negative.'),
        findsOneWidget,
      );
    });

    testWidgets('clears the form after saving', (tester) async {
      await open(tester, _FakeCreateProduct());

      await tester.enterText(
        find.byKey(const ValueKey<String>('product-name-field')),
        'Keyboard',
      );
      await tester
          .tap(find.byKey(const ValueKey<String>('product-save-button')));
      await tester.pumpAndSettle();

      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('product-name-field')),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.controller.text, isEmpty);
    });
  });
}

/// The money a fake price becomes.
Money _money(num rupees) => Money.fromMajorUnits(rupees, 'NPR');

class _UnusedInventory implements InventoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedUnitOfWork implements UnitOfWork {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
