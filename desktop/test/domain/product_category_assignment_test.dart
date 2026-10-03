import 'package:financeapp/src/domain/inventory/product.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final npr = Money.minor(100000, 'NPR');

  group('A product category is optional', () {
    test('a product with no category is an ordinary product', () {
      // **The decision ADR 013 turns on.** If a missing category made a product
      // invalid, every book created before categories existed would be unusable
      // and a placeholder category would have to be invented for historical stock.
      final product = Product(id: 'p-1', name: 'Chair', salePrice: npr);

      expect(product.categoryId, isNull);
      expect(product.hasCategory, isFalse);
    });

    test('a product may carry a category', () {
      final product = Product(
        id: 'p-1',
        name: 'Chair',
        salePrice: npr,
        categoryId: 'cat-1',
      );

      expect(product.categoryId, 'cat-1');
      expect(product.hasCategory, isTrue);
    });

    test('a blank category is absent, not an empty id', () {
      // Two spellings of "no category" is the defect 4.11 warns about: `''` would
      // match no category yet not be null, so a "products without a category"
      // query would miss it entirely.
      final product = Product(
        id: 'p-1',
        name: 'Chair',
        salePrice: npr,
        categoryId: '   ',
      );

      expect(product.categoryId, isNull);
    });

    test('a category id is trimmed', () {
      final product = Product(
        id: 'p-1',
        name: 'Chair',
        salePrice: npr,
        categoryId: '  cat-1  ',
      );
      expect(product.categoryId, 'cat-1');
    });
  });

  group('copyWith can both set and clear a category', () {
    test('setting a category on an uncategorised product', () {
      final product =
          Product(id: 'p-1', name: 'Chair', salePrice: npr).copyWith(
        categoryId: 'cat-1',
      );
      expect(product.categoryId, 'cat-1');
    });

    test('clearing a category, which a plain null cannot express', () {
      // The reason `clearCategory` exists: with `categoryId: null` meaning "not
      // supplied", a category could be **set but never removed**, so a product
      // could never leave a category.
      final product = Product(
        id: 'p-1',
        name: 'Chair',
        salePrice: npr,
        categoryId: 'cat-1',
      ).copyWith(clearCategory: true);

      expect(product.categoryId, isNull);
    });

    test('not mentioning a category leaves it alone', () {
      // The other half of the sentinel: a rename must not silently drop the
      // category, which would reclassify a product by accident.
      final product = Product(
        id: 'p-1',
        name: 'Chair',
        salePrice: npr,
        categoryId: 'cat-1',
      ).copyWith(name: 'Folding Chair');

      expect(product.name, 'Folding Chair');
      expect(product.categoryId, 'cat-1');
    });

    test('the id cannot be changed', () {
      final product = Product(
        id: 'p-1',
        name: 'Chair',
        salePrice: npr,
        categoryId: 'cat-1',
      );
      expect(product.copyWith(name: 'Renamed').id, 'p-1');
    });
  });

  group('Adding a category did not change what a product is', () {
    test('identity is still the id alone', () {
      // Guarding against a regression in the *existing* contract: a product
      // referenced by inventory movements and invoices must not become a
      // different product because a category field was added.
      final a = Product(id: 'p-1', name: 'Chair', salePrice: npr);
      final b = Product(
        id: 'p-1',
        name: 'Renamed Chair',
        salePrice: npr,
        categoryId: 'cat-1',
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('the required fields are still validated', () {
      expect(
        () => Product(id: '', name: 'Chair', salePrice: npr),
        throwsArgumentError,
      );
      expect(
        () => Product(id: 'p-1', name: '  ', salePrice: npr),
        throwsArgumentError,
      );
      expect(
        () => Product(
          id: 'p-1',
          name: 'Chair',
          salePrice: Money.minor(-1, 'NPR'),
        ),
        throwsArgumentError,
      );
    });
  });
}