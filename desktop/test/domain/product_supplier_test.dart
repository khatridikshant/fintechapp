import 'package:financeapp/src/domain/billing/supplier.dart';
import 'package:financeapp/src/domain/inventory/product_supplier.dart';
import 'package:flutter_test/flutter_test.dart';

/// The declared link between a product and the suppliers it can be bought from.
///
/// ## What this is
///
/// A **catalogue** fact: who this business normally buys this product from. It is
/// reference data for reports, so that spend can be grouped by supplier and by
/// category together.
///
/// ## What this is deliberately **not**
///
/// It is **not** a rule about who may be billed for the product. The purchase bill
/// is the authority on who actually supplied the goods, and it already records that
/// on every line. A business that buys the same product from two suppliers at two
/// different prices has done nothing wrong, and a catalogue that made it impossible
/// to record the second purchase would be hiding a real business fact behind a
/// reference-data field.
void main() {
  group('a declared product-supplier link', () {
    test('needs both a product and a supplier', () {
      expect(
        () => ProductSupplier(productId: '  ', supplierId: 's-1'),
        throwsArgumentError,
      );
      expect(
        () => ProductSupplier(productId: 'p-1', supplierId: ''),
        throwsArgumentError,
      );
    });

    test('trims its ids, so a typed space cannot make two spellings', () {
      final link = ProductSupplier(productId: ' p-1 ', supplierId: ' s-1 ');

      expect(link.productId, 'p-1');
      expect(link.supplierId, 's-1');
    });

    test('is identified by the pair, so re-saving it is not a second link', () {
      // The same pair twice is the same fact. Identity on the pair is what lets a
      // repository delete-and-reinsert without ever holding a duplicate.
      final one = ProductSupplier(productId: 'p-1', supplierId: 's-1');
      final again = ProductSupplier(productId: 'p-1', supplierId: 's-1');
      final other = ProductSupplier(productId: 'p-1', supplierId: 's-2');

      expect(one, again);
      expect(one.hashCode, again.hashCode);
      expect(one, isNot(other));
    });

    test('reports whether a given supplier is one of the declared ones', () {
      final link = ProductSupplier(productId: 'p-1', supplierId: 's-1');

      expect(link.names('s-1'), isTrue);
      expect(link.names('s-2'), isFalse);
    });
  });

  group('deactivating a supplier', () {
    test('keeps the supplier, because purchases already reference it', () {
      // **History outlives the need to buy more.** A purchase bill names this
      // supplier, and deleting the record would leave those bills pointing at
      // nothing and change a stored document.
      final supplier =
          Supplier(id: 's-1', name: 'Wholesale Traders').deactivate();

      expect(supplier.isActive, isFalse);
      expect(supplier.name, 'Wholesale Traders');
      expect(supplier.id, 's-1');
    });

    test('may not be used for a new purchase once inactive', () {
      final supplier = Supplier(id: 's-1', name: 'Wholesale Traders');

      expect(supplier.canBeBilledOnNewPurchase, isTrue);
      expect(supplier.deactivate().canBeBilledOnNewPurchase, isFalse);
    });

    test('does not change what the supplier can support for input credit', () {
      // **Separate concerns.** A PAN is evidence about a bill the business already
      // holds; being shut is about whether to buy more. Deactivating must not turn
      // a historical input-credit claim into a false one.
      final supplier = Supplier(id: 's-1', name: 'Wholesale Traders');

      expect(supplier.canSupportInputCredit, isFalse);
      expect(
        supplier.deactivate().canSupportInputCredit,
        isFalse,
        reason: 'whether past bills can be claimed is a fact about those bills',
      );
    });

    test('can be reactivated, so shutting one is not permanent', () {
      final supplier = Supplier(id: 's-1', name: 'Wholesale Traders')
          .deactivate()
          .reactivate();

      expect(supplier.isActive, isTrue);
      expect(supplier.canBeBilledOnNewPurchase, isTrue);
    });

    test('round-trips through copyWith', () {
      final supplier = Supplier(id: 's-1', name: 'Wholesale Traders')
          .copyWith(isActive: false);

      expect(supplier.isActive, isFalse);
      expect(supplier.copyWith().isActive, isFalse);
    });
  });
}
