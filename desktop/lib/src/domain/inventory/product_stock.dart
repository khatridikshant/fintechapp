import '../shared/money.dart';
import 'inventory_movement.dart';
import 'product.dart';

/// What a product is worth and how much of it there is.
///
/// **Both figures are derived by summing the movements, never stored.** ADR 004
/// requires the running inventory *value* to be authoritative and the cost per
/// unit to be derived from it. Because a movement's quantity and value always
/// point the same way, the quantity on hand and the value on hand are each just a
/// sum, and the inventory account reconciles by construction rather than by
/// careful bookkeeping.
class ProductStock {
  const ProductStock._({
    required this.product,
    required this.quantity,
    required this.value,
    required this.currency,
  });

  /// Computes the stock position from a product's movements.
  factory ProductStock.of(
    Product product,
    Iterable<InventoryMovement> movements, {
    String currency = 'NPR',
  }) {
    var quantity = 0;
    var value = Money.minor(0, currency);

    for (final movement in movements) {
      if (movement.productId != product.id) {
        throw ArgumentError(
          'Movement ${movement.id} belongs to product ${movement.productId}, '
          'not ${product.id}. Summing another product\'s movements into this '
          'one would silently corrupt both.',
        );
      }
      quantity += movement.quantity;
      value = value.add(movement.value);
    }

    return ProductStock._(
      product: product,
      quantity: quantity,
      value: value,
      currency: currency,
    );
  }

  final Product product;

  /// Units on hand. Never negative for a stock-tracked product, because issues
  /// that would take it below zero are refused.
  final int quantity;

  /// Total value of the stock on hand, in the account's currency.
  final Money value;

  final String currency;

  /// Cost per unit, **derived** from the value rather than stored.
  ///
  /// Rounded for display only. The value stays authoritative: a caller that needs
  /// to move stock out must take the value from [value], not by multiplying this
  /// figure by a quantity, or rounding will accumulate and the inventory account
  /// will stop reconciling.
  Money get costPerUnit {
    if (quantity == 0) return Money.minor(0, currency);
    return Money.minor(
      _divideRoundHalfUp(value.minorUnits, quantity),
      currency,
    );
  }

  /// Whether there is no stock at all.
  bool get isEmpty => quantity == 0 && value.isZero;

  /// The stock after applying [movement], without writing anything.
  ///
  /// Throws [NegativeStockException] when a stock-tracked product would be taken
  /// below zero. This is the rule from ADR 004: with moving weighted average,
  /// selling stock that does not exist has no defined cost, so allowing it would
  /// force a guess and a guessed cost of sales is a wrong gross profit in two
  /// fiscal years at once.
  ///
  /// The check is against the **total of all movements**, not a position as at
  /// the movement's date. A date-based check would reject a sale simply because
  /// the purchase behind it happened to carry a later date, punishing the user
  /// for the order they entered data in.
  ProductStock apply(InventoryMovement movement) {
    if (movement.productId != product.id) {
      throw ArgumentError(
        'Movement ${movement.id} belongs to product ${movement.productId}, not '
        '${product.id}.',
      );
    }

    final newQuantity = quantity + movement.quantity;
    if (product.stockTrackingEnabled && newQuantity < 0) {
      throw NegativeStockException(
        product: product,
        onHand: quantity,
        requested: -movement.quantity,
      );
    }

    return ProductStock._(
      product: product,
      quantity: newQuantity,
      value: value.add(movement.value),
      currency: currency,
    );
  }

  /// The value to remove from stock when issuing [units] at the current cost.
  ///
  /// Taken from the running value so that the amount leaving matches the book,
  /// and clamped so an issue of the whole holding leaves **exactly zero** rather
  /// than a few stray paisa.
  Money valueOfIssue(int units) {
    if (units <= 0) {
      throw ArgumentError(
          'An issue must remove at least one unit, got $units.');
    }
    if (units > quantity) {
      throw NegativeStockException(
        product: product,
        onHand: quantity,
        requested: units,
      );
    }
    if (units == quantity) return value.negated();
    return Money.minor(
      -_divideRoundHalfUp(value.minorUnits * units, quantity),
      currency,
    );
  }

  static int _divideRoundHalfUp(int numerator, int denominator) {
    final isNegative = numerator < 0;
    final magnitude = numerator.abs();
    final rounded = (magnitude + denominator ~/ 2) ~/ denominator;
    return isNegative ? -rounded : rounded;
  }

  @override
  String toString() => 'ProductStock(${product.name}, $quantity units, '
      '${value.format()}, ${costPerUnit.format()} each)';
}

/// Raised when a movement would take a stock-tracked product below zero.
///
/// This is deliberate, not a limitation. See ADR 004.
class NegativeStockException implements Exception {
  NegativeStockException({
    required this.product,
    required this.onHand,
    required this.requested,
  });

  final Product product;

  /// Units actually on hand.
  final int onHand;

  /// Units the movement wanted to remove.
  final int requested;

  /// How many units short the movement is.
  int get shortfall => requested - onHand;

  @override
  String toString() =>
      'NegativeStockException: cannot issue $requested unit(s) '
      'of "${product.name}" when only $onHand are on hand, a shortfall of '
      '$shortfall. Stock that does not exist has no defined cost, so the issue '
      'is refused rather than given a guessed one. Record the purchase or '
      'opening stock first.';
}
