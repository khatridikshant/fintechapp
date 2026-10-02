import 'dart:math';

import '../domain/inventory/inventory_repository.dart';
import '../domain/inventory/product.dart';
import '../domain/shared/money.dart';
import '../domain/shared/unit_of_work.dart';

/// The outcome of attempting to create a product.
sealed class CreateProductOutcome {
  const CreateProductOutcome();
}

/// The product was created.
final class ProductCreated extends CreateProductOutcome {
  const ProductCreated(this.product);

  final Product product;
}

/// The product could not be created, and **nothing was written**.
///
/// Carries the domain's own wording, so a screen shows the reason rather than
/// inventing a second version of it.
final class ProductRejected implements Exception {
  ProductRejected(this.reason);

  final String reason;

  @override
  String toString() => 'ProductRejected: $reason';
}

/// Creates a product in the catalogue.
///
/// ## Why the identifier is random
///
/// Stock movements and invoices reference a product by id. An id that changed, or
/// that a person could type into another product, would repoint historical stock
/// and sales at the wrong item. So it is random and never derived from anything
/// visible, the same reasoning as a customer's (ADR 010).
///
/// ## Why no product code
///
/// A product is a line the business sells, **not a party**. It carries no PAN and
/// appears on no tax document as a counterparty, so unlike a customer it needs no
/// quotable business reference.
class CreateProduct {
  CreateProduct({
    required this.inventory,
    required this.unitOfWork,
  }) : _random = Random();

  final InventoryRepository inventory;
  final UnitOfWork unitOfWork;

  final Random _random;

  Future<ProductCreated> call({
    required String name,
    required num salePriceRupees,
    bool stockTrackingEnabled = true,
  }) async {
    // Validated before a transaction is opened, so a rejected product leaves no
    // trace at all. The domain constructor is the authority.
    final Product draft;
    try {
      draft = Product(
        id: _newId(),
        name: name,
        // Priced in whole paisa. The typing may be a double, so the value is
        // rounded once here and every derived total is the domain's own.
        salePrice: Money.fromMajorUnits(salePriceRupees, 'NPR'),
        stockTrackingEnabled: stockTrackingEnabled,
      );
    } on ArgumentError catch (error) {
      throw ProductRejected(error.message);
    }

    return unitOfWork.run<ProductCreated>(() async {
      await inventory.saveProduct(draft);
      return ProductCreated(draft);
    });
  }

  /// A random, collision-resistant identifier: a timestamp plus randomness.
  String _newId() {
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final noise =
        List<int>.generate(8, (_) => _random.nextInt(36)).map(_digit).join();
    return 'prd-$stamp-$noise';
  }

  static const String _alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';
  static String _digit(int value) => _alphabet[value % _alphabet.length];
}
