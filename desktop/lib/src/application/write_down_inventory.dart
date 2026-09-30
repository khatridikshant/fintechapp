import '../domain/accounting/chart_of_accounts.dart';
import '../domain/accounting/journal_entry.dart';
import '../domain/accounting/journal_line.dart';
import '../domain/accounting/journal_repository.dart';
import '../domain/fiscal/fiscal_year.dart';
import '../domain/inventory/inventory_movement.dart';
import '../domain/inventory/inventory_repository.dart';
import '../domain/inventory/product.dart';
import '../domain/inventory/product_stock.dart';
import '../domain/shared/money.dart';
import '../domain/shared/unit_of_work.dart';

/// The outcome of attempting to write inventory down.
sealed class WriteDownInventoryOutcome {
  const WriteDownInventoryOutcome();
}

/// The stock was written down and posted.
final class InventoryWrittenDown extends WriteDownInventoryOutcome {
  const InventoryWrittenDown({
    required this.product,
    required this.carryingValueBefore,
    required this.carryingValueAfter,
    required this.reduction,
    required this.movement,
    required this.journalEntry,
    required this.stock,
  });

  final Product product;

  /// What the stock was carried at before the write-down.
  final Money carryingValueBefore;

  /// What it is carried at afterwards, which is the net realisable value given.
  final Money carryingValueAfter;

  /// The loss recognised, as a positive amount.
  final Money reduction;

  final InventoryMovement movement;
  final JournalEntry journalEntry;

  /// The product's stock position after the write-down.
  final ProductStock stock;
}

/// The write-down was refused and nothing was written.
final class WriteDownRejected extends WriteDownInventoryOutcome {
  const WriteDownRejected({
    required this.productId,
    required this.reason,
    required this.fiscalYear,
    this.carryingValue,
    this.netRealisableValue,
  });

  final String productId;
  final WriteDownRejectionReason reason;
  final FiscalYear fiscalYear;

  /// The stock's current carrying value, when relevant to the refusal.
  final Money? carryingValue;

  /// The value that was asked for, when relevant.
  final Money? netRealisableValue;

  String get message => switch (reason) {
        WriteDownRejectionReason.outsideFiscalYear =>
          'This write-down is dated outside ${fiscalYear.label} and cannot be '
              'posted into it.',
        WriteDownRejectionReason.unknownProduct =>
          'There is no product with id "$productId".',
        WriteDownRejectionReason.nothingToWriteDown =>
          'There is no stock of this product to write down. There is nothing '
              'held, so there is nothing to reduce in value.',
        WriteDownRejectionReason.notBelowCarryingValue =>
          'A write-down must take the value below what the stock is carried at. '
              'It is carried at ${carryingValue?.format() ?? '0'} and the value '
              'given was ${netRealisableValue?.format() ?? '0'}, which is not '
              'lower. Inventory is carried at the lower of cost and net '
              'realisable value, so nothing needs adjusting.',
        WriteDownRejectionReason.negativeValue =>
          'Net realisable value must not be negative. Stock that costs more to '
              'sell than it is worth is a decision to dispose of it, which is a '
              'separate movement, not a write-down.',
      };
}

enum WriteDownRejectionReason {
  /// The write-down is dated outside the active fiscal year.
  outsideFiscalYear,

  /// The product does not exist.
  unknownProduct,

  /// The product holds no stock, so there is nothing to reduce.
  nothingToWriteDown,

  /// The value given is not below the current carrying value.
  notBelowCarryingValue,

  /// The value given is negative.
  negativeValue,
}

/// Writes inventory down to its net realisable value.
///
/// IAS 2 and NAS 2 require inventory to be carried at the **lower** of cost and
/// net realisable value. If stock that cost Rs 100 can now only be sold for
/// Rs 80, the Rs 20 loss is recognised **now**, not whenever the stock is
/// eventually sold. Deferring it would overstate assets and profit until the
/// sale, which is exactly what the rule exists to prevent.
///
/// See `docs/INVENTORY_EXPLAINED.md` for the plain-language explanation.
///
/// ```
/// Dr  5070 Inventory Adjustments   the reduction
/// Cr  1040 Inventory               the reduction
/// ```
///
/// **The quantity does not change.** A write-down is not a disposal: the goods
/// are still on the shelf, they are simply worth less than they cost. Disposing
/// of them is a separate movement. Conflating the two would make the stock count
/// wrong, and would count the loss twice.
///
/// The reduction is recorded as an inventory movement, with a quantity of zero
/// and a negative value, which is why the movement type now allows a value-only
/// change. Going through the movement ledger is what keeps the stock value and
/// the inventory account equal by construction, rather than by two separate
/// calculations that can drift.
class WriteDownInventory {
  const WriteDownInventory({
    required this.fiscalYear,
    required this.inventory,
    required this.journal,
    required this.unitOfWork,
  });

  final FiscalYear fiscalYear;

  final InventoryRepository inventory;

  final JournalRepository journal;

  final UnitOfWork unitOfWork;

  /// The journal entry id for a movement, matching `PostInventoryMovement` so a
  /// write-down posts the same way any other movement does.
  static String journalEntryIdFor(InventoryMovement movement) =>
      'JE-MV-${movement.id}';

  /// Writes [productId]'s stock down to [netRealisableValue].
  ///
  /// [netRealisableValue] is the **total** value the stock should now be carried
  /// at, not the reduction. Stating what stock is worth is the thing a user
  /// actually knows; the reduction is arithmetic.
  Future<WriteDownInventoryOutcome> call({
    required String movementId,
    required String productId,
    required DateTime date,
    required Money netRealisableValue,
  }) async {
    if (!fiscalYear.contains(date)) {
      return WriteDownRejected(
        productId: productId,
        reason: WriteDownRejectionReason.outsideFiscalYear,
        fiscalYear: fiscalYear,
      );
    }

    if (netRealisableValue.isNegative) {
      return WriteDownRejected(
        productId: productId,
        reason: WriteDownRejectionReason.negativeValue,
        fiscalYear: fiscalYear,
        netRealisableValue: netRealisableValue,
      );
    }

    return unitOfWork.run<WriteDownInventoryOutcome>(() async {
      final product = await inventory.productById(productId);
      if (product == null) {
        return WriteDownRejected(
          productId: productId,
          reason: WriteDownRejectionReason.unknownProduct,
          fiscalYear: fiscalYear,
        );
      }

      final current = await inventory.stockOf(product);

      if (current.value.isZero) {
        return WriteDownRejected(
          productId: productId,
          reason: WriteDownRejectionReason.nothingToWriteDown,
          fiscalYear: fiscalYear,
          carryingValue: current.value,
          netRealisableValue: netRealisableValue,
        );
      }

      // Inventory is carried at the *lower* of cost and net realisable value, so
      // a value at or above what it is already carried at is not a write-down.
      if (netRealisableValue >= current.value) {
        return WriteDownRejected(
          productId: productId,
          reason: WriteDownRejectionReason.notBelowCarryingValue,
          fiscalYear: fiscalYear,
          carryingValue: current.value,
          netRealisableValue: netRealisableValue,
        );
      }

      final reduction = current.value.subtract(netRealisableValue);

      // Quantity zero: the goods are still held. Value negative: the carrying
      // value falls.
      final movement = InventoryMovement(
        id: movementId,
        productId: productId,
        date: date,
        reason: MovementReason.writeDown,
        quantity: 0,
        value: reduction.negated(),
      );

      final entry = JournalEntry(
        id: journalEntryIdFor(movement),
        date: date,
        description: 'Write-down of ${product.name} by ${reduction.format()}',
        reference: productId,
        lines: [
          JournalLine.debit(
            account: ChartOfAccounts.inventoryAdjustments,
            amount: reduction,
          ),
          JournalLine.credit(
            account: ChartOfAccounts.inventory,
            amount: reduction,
          ),
        ],
      );

      // The entry first, because the movement holds a foreign key to it.
      await journal.append(entry);
      final stock = await inventory.applyMovement(
        product,
        movement,
        journalEntryId: entry.id,
      );

      return InventoryWrittenDown(
        product: product,
        carryingValueBefore: current.value,
        carryingValueAfter: netRealisableValue,
        reduction: reduction,
        movement: movement,
        journalEntry: entry,
        stock: stock,
      );
    });
  }
}
