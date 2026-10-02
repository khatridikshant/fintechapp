import 'package:financeapp/src/application/create_product.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_inventory_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_unit_of_work.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Creating a product, so stock can be recorded against it.
///
/// The identifier is random, for the same reason a customer's is: a product
/// referenced by stock movements must never be reassigned to a different item.
void main() {
  late AppDatabase db;
  late DriftInventoryRepository inventory;
  late CreateProduct createProduct;

  setUp(() {
    db = openInMemoryDatabase();
    inventory = DriftInventoryRepository(db);
    createProduct = CreateProduct(
      inventory: inventory,
      unitOfWork: DriftUnitOfWork(db),
    );
  });

  tearDown(() async => db.close());

  test('a new product is saved', () async {
    final outcome = await createProduct(
      name: 'Keyboard',
      salePriceRupees: 2500,
    );

    expect(outcome, isA<ProductCreated>());
    final product = (outcome).product;
    expect(product.name, 'Keyboard');
    expect(product.salePrice.minorUnits, 250000);

    final stored = await inventory.productById(product.id);
    expect(stored?.name, 'Keyboard');
  });

  test('ids are random, so two products never collide', () async {
    final first = await createProduct(name: 'Same', salePriceRupees: 100);
    final second = await createProduct(name: 'Same', salePriceRupees: 100);

    expect(first.product.id, isNot(second.product.id));
  });

  test('stock tracking is on unless the product is a service', () async {
    final tracked = await createProduct(name: 'Keyboard', salePriceRupees: 100);
    final service = await createProduct(
      name: 'Delivery',
      salePriceRupees: 100,
      stockTrackingEnabled: false,
    );

    expect(tracked.product.stockTrackingEnabled, isTrue);
    expect(service.product.stockTrackingEnabled, isFalse);
  });

  test('an empty name is refused and nothing is written', () async {
    var rejected = false;
    try {
      await createProduct(name: '  ', salePriceRupees: 100);
    } on ProductRejected {
      rejected = true;
    }

    expect(rejected, isTrue);
    expect(await inventory.allProducts(), isEmpty);
  });

  test('a negative price is refused', () async {
    var rejected = false;
    try {
      await createProduct(name: 'Keyboard', salePriceRupees: -5);
    } on ProductRejected {
      rejected = true;
    }

    expect(rejected, isTrue);
    expect(await inventory.allProducts(), isEmpty);
  });

  test('a price of zero is allowed, because giving stock away is legitimate',
      () async {
    // Distinct from the invoice line rule, which forbids a zero price: a
    // *product* may be free, whereas a zero-value invoice line is a mistake.
    final outcome = await createProduct(name: 'Sample', salePriceRupees: 0);

    expect(outcome.product.salePrice.isZero, isTrue);
  });

  test('a price with paisa keeps them exactly', () async {
    final outcome = await createProduct(
      name: 'Keyboard',
      salePriceRupees: 2500.50,
    );

    expect(outcome.product.salePrice.minorUnits, 250050);
  });
}
