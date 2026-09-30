import '../domain/accounting/account.dart';
import '../domain/accounting/chart_of_accounts.dart';
import '../domain/accounting/journal_entry.dart';
import '../domain/accounting/journal_line.dart';
import '../domain/accounting/journal_repository.dart';
import '../domain/inventory/inventory_movement.dart';
import '../domain/inventory/inventory_repository.dart';
import '../domain/inventory/product.dart';
import '../domain/inventory/product_stock.dart';
import '../domain/fiscal/fiscal_year.dart';
import '../domain/shared/unit_of_work.dart';

/// The outcome of attempting to post an inventory movement.
sealed class PostInventoryMovementOutcome {
  const PostInventoryMovementOutcome();
}

/// The movement was recorded and posted.
final class InventoryMovementPosted extends PostInventoryMovementOutcome {
  const InventoryMovementPosted({
    required this.movement,
    required this.product,
    required this.journalEntry,
    required this.stock,
  });

  final InventoryMovement movement;
  final Product product;

  /// The entry that accounts for the movement.
  final JournalEntry journalEntry;

  /// The product's stock position **after** this movement.
  final ProductStock stock;
}

/// The movement was refused and nothing was written.
final class InventoryMovementRejected extends PostInventoryMovementOutcome {
  const InventoryMovementRejected({
    required this.movement,
    required this.reason,
    required this.fiscalYear,
  });

  final InventoryMovement movement;
  final PostInventoryMovementRejectionReason reason;
  final FiscalYear fiscalYear;

  String get message => switch (reason) {
        PostInventoryMovementRejectionReason.outsideFiscalYear =>
          'This movement is dated outside ${fiscalYear.label} and cannot be '
              'posted into it.',
        PostInventoryMovementRejectionReason.unknownProduct =>
          'There is no product with id "${movement.productId}".',
        PostInventoryMovementRejectionReason.unsupportedReason =>
          'A "${movement.reason.label}" movement cannot be posted yet. A '
              'transfer moves stock between locations, and locations are not '
              'modelled, so there is nothing to transfer between and no entry '
              'that would mean anything.',
      };
}

enum PostInventoryMovementRejectionReason {
  /// The movement is dated outside the active fiscal year.
  outsideFiscalYear,

  /// The product does not exist.
  unknownProduct,

  /// The movement's reason has no meaningful accounting yet.
  unsupportedReason,
}

/// Records an inventory movement and posts the entry that accounts for it.
///
/// Specification RULE 5 requires that *"Inventory-affecting sales must create
/// appropriate accounting entries."* A movement on its own changes the stock on
/// the shelf without changing the books, which leaves the inventory account and
/// the physical stock as two unrelated numbers. This is what ties them together.
///
/// The whole operation is one unit of work, so the movement and its entry commit
/// together or not at all. A refusal — an out-of-stock issue, a date outside the
/// fiscal year, an unknown product — writes neither.
class PostInventoryMovement {
  const PostInventoryMovement({
    required this.fiscalYear,
    required this.inventory,
    required this.journal,
    required this.unitOfWork,
  });

  final FiscalYear fiscalYear;

  final InventoryRepository inventory;

  final JournalRepository journal;

  final UnitOfWork unitOfWork;

  /// The journal entry id for a movement.
  ///
  /// Derived from the movement id, so posting the same movement twice is refused
  /// by the primary key rather than double-counted against the stock and the
  /// ledger both.
  static String journalEntryIdFor(InventoryMovement movement) =>
      'JE-MV-${movement.id}';

  /// The accounts a movement's reason and direction post to.
  ///
  /// Kept as **one table** rather than scattered through the code, because the
  /// mapping is the accounting policy and it needs to be readable in one place:
  ///
  /// | reason           | direction | debit                     | credit                    |
  /// | ---------------- | --------- | ------------------------- | ------------------------- |
  /// | opening stock    | receipt   | 1040 Inventory            | 3010 Owner's Equity       |
  /// | purchase         | receipt   | 1040 Inventory            | 2010 Accounts Payable     |
  /// | purchase return  | issue     | 2010 Accounts Payable     | 1040 Inventory            |
  /// | sale             | issue     | 5020 Cost of Goods Sold   | 1040 Inventory            |
  /// | sale return      | receipt   | 1040 Inventory            | 5020 Cost of Goods Sold   |
  /// | adjustment       | receipt   | 1040 Inventory            | 5070 Inventory Adjustments|
  /// | adjustment       | issue     | 5070 Inventory Adjustments| 1040 Inventory            |
  /// | return in        | receipt   | 1040 Inventory            | 5070 Inventory Adjustments|
  /// | return out       | issue     | 5070 Inventory Adjustments| 1040 Inventory            |
  /// | transfer         | either    | not supported             | not supported             |
  ///
  /// Returns `null` when the reason has no meaningful accounting, which the
  /// caller turns into a refusal rather than a silent guess.
  static ({Account debit, Account credit})? accountsFor(
    InventoryMovement movement,
  ) {
    final isReceipt = movement.isReceipt;

    switch (movement.reason) {
      case MovementReason.openingStock:
        return (
          debit: ChartOfAccounts.inventory,
          credit: ChartOfAccounts.ownersEquity,
        );
      case MovementReason.purchase:
        return (
          debit: ChartOfAccounts.inventory,
          credit: ChartOfAccounts.payable,
        );
      case MovementReason.purchaseReturn:
        return (
          debit: ChartOfAccounts.payable,
          credit: ChartOfAccounts.inventory,
        );
      case MovementReason.sale:
        return (
          debit: ChartOfAccounts.costOfGoodsSold,
          credit: ChartOfAccounts.inventory,
        );
      case MovementReason.saleReturn:
        return (
          debit: ChartOfAccounts.inventory,
          credit: ChartOfAccounts.costOfGoodsSold,
        );
      case MovementReason.adjustment:
      case MovementReason.returnIn:
      case MovementReason.returnOut:
      case MovementReason.writeDown:
        // A gain credits the adjustment account, which reduces expenses; a loss
        // debits it. One account in both directions is the conventional
        // treatment for stock shrinkage and gains.
        //
        // A write-down never has a positive quantity, so it always takes the
        // issue branch: debit the adjustment account, credit inventory.
        return isReceipt
            ? (
                debit: ChartOfAccounts.inventory,
                credit: ChartOfAccounts.inventoryAdjustments,
              )
            : (
                debit: ChartOfAccounts.inventoryAdjustments,
                credit: ChartOfAccounts.inventory,
              );
      case MovementReason.transfer:
        // A transfer moves stock between locations. Locations are not modelled,
        // and a transfer that does not change total quantity or total value has
        // no entry that would mean anything. Refusing is honest; posting a
        // plausible-looking entry would not be.
        return null;
    }
  }

  Future<PostInventoryMovementOutcome> call(InventoryMovement movement) async {
    if (!fiscalYear.contains(movement.date)) {
      return InventoryMovementRejected(
        movement: movement,
        reason: PostInventoryMovementRejectionReason.outsideFiscalYear,
        fiscalYear: fiscalYear,
      );
    }

    final accounts = accountsFor(movement);
    if (accounts == null) {
      return InventoryMovementRejected(
        movement: movement,
        reason: PostInventoryMovementRejectionReason.unsupportedReason,
        fiscalYear: fiscalYear,
      );
    }

    return unitOfWork.run<PostInventoryMovementOutcome>(() async {
      final product = await inventory.productById(movement.productId);
      if (product == null) {
        return InventoryMovementRejected(
          movement: movement,
          reason: PostInventoryMovementRejectionReason.unknownProduct,
          fiscalYear: fiscalYear,
        );
      }

      final entry = journalEntryFor(movement, accounts);
      // The entry first, because the movement holds a foreign key to it.
      await journal.append(entry);

      // applyMovement re-checks the out-of-stock rule inside this same
      // transaction, so an issue that would go negative rolls the entry back.
      final stock = await inventory.applyMovement(
        product,
        movement,
        journalEntryId: entry.id,
      );

      return InventoryMovementPosted(
        movement: movement,
        product: product,
        journalEntry: entry,
        stock: stock,
      );
    });
  }

  /// The entry for a movement: the stock account on one side, the reason's
  /// counter-account on the other, for the movement's value.
  JournalEntry journalEntryFor(
    InventoryMovement movement,
    ({Account debit, Account credit}) accounts,
  ) {
    final amount = movement.value.abs();
    return JournalEntry(
      id: journalEntryIdFor(movement),
      date: movement.date,
      description: _descriptionFor(movement),
      reference: movement.productId,
      lines: [
        JournalLine.debit(account: accounts.debit, amount: amount),
        JournalLine.credit(account: accounts.credit, amount: amount),
      ],
    );
  }

  /// A description a person can read.
  ///
  /// A value-only movement has no units to name, so it reads "Write-down of
  /// Rs 200" rather than the nonsense "Write-down of 0 unit(s)".
  static String _descriptionFor(InventoryMovement movement) {
    if (movement.isValueOnly) {
      return '${movement.reason.label} of ${movement.value.abs().format()}';
    }
    return '${movement.reason.label} of ${movement.quantity.abs()} unit(s)';
  }
}
