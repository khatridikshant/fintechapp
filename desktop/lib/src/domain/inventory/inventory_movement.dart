import '../shared/money.dart';

/// Why stock changed.
///
/// Specification section 14 requires every stock change to have a reason, so that
/// a movement can be explained rather than being an anonymous adjustment. The
/// name of each value is persisted, so **renaming a value is a schema
/// migration**.
enum MovementReason {
  /// Stock the business started with, entered during onboarding.
  openingStock(label: 'Opening stock'),

  /// Stock bought from a supplier.
  purchase(label: 'Purchase'),

  /// Stock sold to a customer.
  sale(label: 'Sale'),

  /// Stock returned by a customer.
  saleReturn(label: 'Sale return'),

  /// Stock returned to a supplier.
  purchaseReturn(label: 'Purchase return'),

  /// Stock coming back in for another reason.
  returnIn(label: 'Return in'),

  /// Stock going out for another reason.
  returnOut(label: 'Return out'),

  /// A stock-count correction, damage, or loss.
  adjustment(label: 'Adjustment'),

  /// A reduction in the carrying value of stock that is still held.
  ///
  /// Required by IAS 2 and NAS 2: inventory is carried at the **lower** of cost
  /// and net realisable value, so stock that can no longer be sold for what it
  /// cost must be written down now rather than when it is eventually sold.
  ///
  /// Distinct from [adjustment] because the goods are **still there**. A
  /// write-down changes what the stock is worth, not how much of it there is. The
  /// separation keeps that visible in the history, and keeps a write-down from
  /// being mistaken for a stock count correction.
  writeDown(label: 'Write-down'),

  /// A move between locations.
  transfer(label: 'Transfer');

  const MovementReason({required this.label});

  /// Human-facing name.
  final String label;

  /// Whether this reason normally increases stock.
  ///
  /// Not enforced, because an adjustment can go either way. It exists so callers
  /// can choose a sensible default direction.
  bool get isReceipt =>
      this == openingStock ||
      this == purchase ||
      this == saleReturn ||
      this == returnIn;

  /// Resolves a persisted name back to a reason.
  static MovementReason? fromName(String name) {
    for (final reason in MovementReason.values) {
      if (reason.name == name) return reason;
    }
    return null;
  }
}

/// A single change in a product's stock.
///
/// Both [quantity] and [value] are **signed**, and always in the same direction:
/// a receipt raises both, an issue lowers both. That is what lets the quantity on
/// hand and the value on hand each be a plain sum of the movements, which in turn
/// is what makes the value-first design in ADR 004 reconcile by construction.
///
/// A movement is a financial record. It is never edited or deleted; a correction
/// is a compensating movement, as specification section 33 requires.
class InventoryMovement {
  const InventoryMovement._({
    required this.id,
    required this.productId,
    required this.date,
    required this.reason,
    required this.quantity,
    required this.value,
  });

  factory InventoryMovement({
    required String id,
    required String productId,
    required DateTime date,
    required MovementReason reason,
    required int quantity,
    required Money value,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('An inventory movement needs an id.');
    }
    if (productId.trim().isEmpty) {
      throw ArgumentError('An inventory movement must name its product.');
    }
    if (quantity == 0 && value.isZero) {
      throw ArgumentError(
        'An inventory movement must change the quantity, the value, or both. A '
        'movement that changes neither records nothing and only adds noise to '
        'the history.',
      );
    }
    // Stock moving without its value moving would break the reconciliation
    // between the units on the shelf and what they are worth.
    if (quantity != 0 && value.isZero) {
      throw ArgumentError(
        'A movement that changes the quantity must carry a value. Changing the '
        'units without changing what they are worth would break the '
        'reconciliation between the stock count and the stock value.',
      );
    }
    // A **value-only** movement is allowed, and is how a write-down is recorded:
    // the goods are still held, so the quantity is untouched while the carrying
    // value falls. It is restricted to that one reason, because any other stock
    // change must move the quantity too.
    if (quantity == 0 && reason != MovementReason.writeDown) {
      throw ArgumentError(
        'A value-only movement is only allowed for a write-down, got '
        '${reason.label}. Any other stock change must move the quantity too, or '
        'the stock count and the stock value stop describing the same thing.',
      );
    }
    // When both move, they must agree in direction.
    if (quantity != 0 &&
        !value.isZero &&
        ((quantity > 0) != value.isPositive)) {
      throw ArgumentError(
        'An inventory movement must have quantity and value pointing the same '
        'way when both change: got a quantity of $quantity and a value of '
        '${value.format()}.',
      );
    }
    return InventoryMovement._(
      id: id.trim(),
      productId: productId.trim(),
      date: date,
      reason: reason,
      quantity: quantity,
      value: value,
    );
  }

  /// A receipt: stock coming in.
  factory InventoryMovement.receipt({
    required String id,
    required String productId,
    required DateTime date,
    required MovementReason reason,
    required int quantity,
    required Money value,
  }) {
    if (quantity <= 0) {
      throw ArgumentError(
        'A receipt must have a positive quantity, got $quantity. Use issue for '
        'stock going out.',
      );
    }
    return InventoryMovement(
      id: id,
      productId: productId,
      date: date,
      reason: reason,
      quantity: quantity,
      value: value,
    );
  }

  /// An issue: stock going out.
  factory InventoryMovement.issue({
    required String id,
    required String productId,
    required DateTime date,
    required MovementReason reason,
    required int quantity,
    required Money value,
  }) {
    if (quantity <= 0) {
      throw ArgumentError(
        'An issue must have a positive quantity to remove, got $quantity.',
      );
    }
    return InventoryMovement(
      id: id,
      productId: productId,
      date: date,
      reason: reason,
      quantity: -quantity,
      value: value.negated(),
    );
  }

  final String id;

  final String productId;

  final DateTime date;

  final MovementReason reason;

  /// Signed change in units. Positive is stock coming in.
  final int quantity;

  /// Signed change in value, in minor units. Same sign as [quantity].
  final Money value;

  String get currency => value.currency;

  /// True when this movement brings stock in.
  bool get isReceipt => quantity > 0;

  /// True when this movement takes stock out.
  bool get isIssue => quantity < 0;

  /// True when this movement changes only the value, leaving the quantity alone.
  ///
  /// This is a write-down: the goods are still held, they are simply worth less
  /// than they cost.
  bool get isValueOnly => quantity == 0;

  /// The units removed, as a positive number, for an issue.
  int get issuedQuantity => quantity < 0 ? -quantity : 0;

  @override
  bool operator ==(Object other) =>
      other is InventoryMovement && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'InventoryMovement($id, $productId, ${reason.label}, $quantity, '
      '${value.format()})';
}
