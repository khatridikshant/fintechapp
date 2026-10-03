import 'package:financeapp/src/domain/inventory/product_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('A category needs an id, a code, and a name', () {
    test('a blank id is refused', () {
      expect(
        () => ProductCategory(id: '  ', code: 'ELEC-01', name: 'Phones'),
        throwsArgumentError,
      );
    });

    test('a blank code is refused', () {
      expect(
        () => ProductCategory(id: 'cat-1', code: '', name: 'Phones'),
        throwsArgumentError,
      );
    });

    test('a blank name is refused', () {
      expect(
        () => ProductCategory(id: 'cat-1', code: 'ELEC-01', name: '   '),
        throwsArgumentError,
      );
    });

    test('text is trimmed, so " ELEC-01 " and "ELEC-01" are one category', () {
      final category = ProductCategory(
        id: '  cat-1 ',
        code: '  ELEC-01 ',
        name: '  Phones  ',
      );
      expect(category.id, 'cat-1');
      expect(category.code, 'ELEC-01');
      expect(category.name, 'Phones');
    });

    test('identity is the id alone, so renaming cannot break history', () {
      // **The reason id and name are separate**, and the same reason as ADR 010.
      // A category referenced by stock records must survive a rename: equality is
      // by id, so a renamed category is the *same* category and every product
      // pointing at it is still correct. Were equality by name, a rename would
      // silently reclassify historical stock.
      final before = ProductCategory(id: 'cat-1', code: 'ELEC-01', name: 'Phones');
      final after =
          before.copyWith(name: 'Handsets and Feature Phones');

      expect(after, before);
      expect(after.name, 'Handsets and Feature Phones');
    });

    test('the id cannot be changed by copyWith', () {
      // An id that moved would repoint every product that referenced it. There is
      // deliberately no parameter for it.
      final category =
          ProductCategory(id: 'cat-1', code: 'ELEC-01', name: 'Phones');
      expect(category.copyWith(name: 'Renamed').id, 'cat-1');
    });

    test('the code is not identity, so it may be re-sequenced', () {
      final a =
          ProductCategory(id: 'cat-1', code: 'ELEC-01', name: 'Phones');
      final b = a.copyWith(code: 'ELEC-99');
      expect(b.code, 'ELEC-99');
      expect(b, a, reason: 'still the same category');
    });

    test('the reference people quote is the code, never the id', () {
      // An id is meaningless outside the system. Printing one on a stock report
      // tells the reader nothing and invites them to treat it as an identifier.
      final category =
          ProductCategory(id: 'cat-1', code: 'ELEC-01', name: 'Phones');
      expect(category.displayReference, 'ELEC-01');
    });
  });

  group('A parent is optional, and V1 refuses a tree it cannot report', () {
    test('a category may have no parent', () {
      final category =
          ProductCategory(id: 'cat-1', code: 'ELEC-01', name: 'Phones');
      expect(category.parentId, isNull);
      expect(category.isTopLevel, isTrue);
    });

    test('a category may have a parent', () {
      final category = ProductCategory(
        id: 'cat-2',
        code: 'ELEC-01-PHONE',
        name: 'Smartphones',
        parentId: 'cat-1',
      );
      expect(category.parentId, 'cat-1');
      expect(category.isTopLevel, isFalse);
    });

    test('a category cannot be its own parent', () {
      // **A cycle is refused rather than walked.** A report that walks parents to
      // find the root would loop forever on a self-referencing category, and the
      // result is a hang rather than a wrong number — which is a worse failure
      // because nothing fails visibly.
      expect(
        () => ProductCategory(
          id: 'cat-1',
          code: 'ELEC-01',
          name: 'Phones',
          parentId: 'cat-1',
        ),
        throwsArgumentError,
      );
    });

    test('the parent id is trimmed, so a blank parent is absent not empty', () {
      // **Blank means absent**, so `''` and `null` cannot become two spellings of
      // the same fact. A blank parent that stored as '' would be a parent id that
      // matches no category and is not null, so a "top level" query would miss it.
      final category = ProductCategory(
        id: 'cat-1',
        code: 'ELEC-01',
        name: 'Phones',
        parentId: '   ',
      );
      expect(category.parentId, isNull);
    });

    test('copyWith can clear a parent, which blanking cannot express', () {
      // The one asymmetry, and it is deliberate: `copyWith` uses a sentinel so
      // `null` means "deliberately remove the parent" rather than "leave it
      // alone", which is the only way an optional field can ever be unset.
      final child = ProductCategory(
        id: 'cat-2',
        code: 'ELEC-01-PHONE',
        name: 'Smartphones',
        parentId: 'cat-1',
      );
      expect(child.copyWith(clearParent: true).parentId, isNull);
      expect(child.copyWith(name: 'Renamed').parentId, 'cat-1');
    });
  });

  group('V1 resolves at most one level of nesting', () {
    // ADR 013: the schema expresses a hierarchy, but V1 reports one level and
    // refuses more. A tree walked correctly but looped on hangs; a tree walked
    // partially produces a report that silently groups wrongly. Refusing is the
    // honest answer, and it is cheap to relax later.

    group('depthOf', () {
      /// A lookup over a fixed map, returning null for an unknown id — which is
      /// what makes the dangling-parent case reachable.
      ProductCategory? Function(String) lookup(Map<String, ProductCategory> all) =>
          (id) => all[id];

      test('a top-level category is depth 0', () {
        final top =
            ProductCategory(id: 'cat-1', code: 'ELEC-01', name: 'Phones');
        expect(top.depthOf(lookup({})), 0);
      });

      test('a category under a top-level one is depth 1', () {
        final all = {
          'cat-1': ProductCategory(
            id: 'cat-1',
            code: 'ELEC-01',
            name: 'Phones',
          ),
          'cat-2': ProductCategory(
            id: 'cat-2',
            code: 'ELEC-01-PHONE',
            name: 'Smartphones',
            parentId: 'cat-1',
          ),
        };
        expect(all['cat-2']!.depthOf(lookup(all)), 1);
      });

      test('a category two levels down exceeds what V1 reports, and is refused', () {
        // **The case ADR 013 exists for.** This tree is representable, and V1
        // cannot report it, so building it is refused rather than stored and
        // later reported wrongly.
        final grandchild = ProductCategory(
          id: 'cat-3',
          code: 'ELEC-01-PHONE-ANDROID',
          name: 'Android Handsets',
          parentId: 'cat-2',
        );
        final all = {
          'cat-1': ProductCategory(
            id: 'cat-1',
            code: 'ELEC-01',
            name: 'Phones',
          ),
          'cat-2': ProductCategory(
            id: 'cat-2',
            code: 'ELEC-01-PHONE',
            name: 'Smartphones',
            parentId: 'cat-1',
          ),
          'cat-3': grandchild,
        };

        expect(
          () => grandchild.assertWithinV1Depth(all),
          throwsA(isA<CategoryDepthException>()),
        );
      });

      test('a parent that does not exist is a depth that cannot be resolved', () {
        // **A dangling parent is refused rather than treated as top level.**
        // Treating it as top level would silently reclassify the category: a stock
        // report grouped by parent would place it at the root, which is a
        // different answer and not one anybody chose.
        final orphan = ProductCategory(
          id: 'cat-9',
          code: 'ELEC-99',
          name: 'Orphan',
          parentId: 'cat-does-not-exist',
        );

        expect(
          // An empty map: the parent is absent, which is the condition under test.
          () => orphan.assertWithinV1Depth(const {}),
          throwsA(isA<CategoryDepthException>()),
        );
      });
    });
  });
}