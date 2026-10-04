import '../domain/accounting/account.dart';
import '../domain/accounting/chart_of_accounts.dart';
import '../domain/accounting/journal_entry.dart';
import '../domain/accounting/journal_line.dart';
import '../domain/accounting/journal_repository.dart';
import '../domain/billing/document_number.dart';
import '../domain/billing/document_number_sequence.dart';
import '../domain/billing/document_type.dart';
import '../domain/billing/issued_purchase.dart';
import '../domain/billing/purchase.dart';
import '../domain/billing/purchase_line.dart';
import '../domain/billing/purchase_repository.dart';
import '../domain/billing/supplier.dart';
import '../domain/billing/supplier_repository.dart';
import '../domain/fiscal/fiscal_year.dart';
import '../domain/inventory/inventory_movement.dart';
import '../domain/inventory/inventory_repository.dart';
import '../domain/inventory/product.dart';
import '../domain/inventory/product_stock.dart';
import '../domain/shared/unit_of_work.dart';

/// The outcome of attempting to issue a purchase.
sealed class IssuePurchaseOutcome {
  const IssuePurchaseOutcome();
}

/// The purchase was issued, numbered, posted, and its stock recorded.
final class PurchaseIssued extends IssuePurchaseOutcome {
  const PurchaseIssued({
    required this.purchase,
    required this.number,
    required this.journalEntry,
    required this.issued,
    required this.supplier,
    required this.stockPositions,
    this.inputCreditWarning,
    this.undeclaredSupplierWarnings = const <String>[],
  });

  final Purchase purchase;

  /// The serial allocated at issuance. A draft does not have one, so an abandoned
  /// draft leaves no gap in the purchase numbering.
  final DocumentNumber number;

  final JournalEntry journalEntry;

  /// The stored document.
  final IssuedPurchase issued;

  final Supplier supplier;

  /// The resulting stock position for every product the bill delivered, keyed by
  /// product id.
  ///
  /// **Empty for a bill of services or freight**, which is a real purchase that
  /// simply does not move tracked stock.
  final Map<String, ProductStock> stockPositions;

  /// Set when the purchase's input VAT may be **disallowed as credit in an audit**
  /// because the supplier has no PAN.
  ///
  /// ## Why this warns rather than refuses
  ///
  /// `NEPALI_BILLING.md` records that a purchase bill lacking the vendor's PAN may
  /// be disallowed as input credit. The obvious response is to refuse the purchase,
  /// and that would be wrong: the stock genuinely arrived and genuinely had VAT
  /// charged on it, so refusing would leave the business with stock it does not
  /// record and a payable it cannot see. The VAT is posted — it was really paid —
  /// and the risk is surfaced so the operator can chase the PAN or decide knowingly.
  ///
  /// `null` means no warning.
  final String? inputCreditWarning;

  /// Whether the bill's VAT can be expected to survive an audit.
  bool get supplierCanSupportInputCredit => inputCreditWarning == null;

  /// Products on this bill whose **declared** suppliers do not include the one
  /// being billed.
  ///
  /// ## Why this warns rather than refuses
  ///
  /// A product's declared supplier list is **catalogue reference data**, and the
  /// purchase bill is the **authority** on who actually supplied the goods. Buying
  /// the same product from a second supplier at a different price is ordinary
  /// trading, so refusing it would mean refusing to record goods that genuinely
  /// arrived -- leaving the business with stock it does not record and a payable it
  /// cannot see.
  ///
  /// This is the same reasoning as [inputCreditWarning], and deliberately the same
  /// shape: a risk worth seeing, posted rather than blocked.
  ///
  /// **Empty is the ordinary case**, including for a product that declares no
  /// suppliers at all. A product with an empty list is an ordinary product, exactly
  /// as one with no category is (ADR 013), so warning about it would produce a
  /// warning on nearly every bill forever.
  final List<String> undeclaredSupplierWarnings;

  /// The stock position for one product, or `null` when the bill did not deliver it.
  ProductStock? stockFor(String productId) => stockPositions[productId];
}

/// The purchase was refused and nothing was written.
final class PurchaseRejected extends IssuePurchaseOutcome {
  const PurchaseRejected({
    required this.purchase,
    required this.reason,
    required this.fiscalYear,
    this.supplier,
  });

  final Purchase purchase;
  final IssuePurchaseRejectionReason reason;
  final FiscalYear fiscalYear;

  /// The supplier, when the refusal is **about** the supplier rather than about its
  /// absence.
  ///
  /// **Null for [IssuePurchaseRejectionReason.unknownSupplier]**, because there is no
  /// supplier to name. Carrying it so the message can say *who* is shut turns the
  /// refusal into something the operator can act on, rather than a rule stated at
  /// them.
  final Supplier? supplier;

  String get message => switch (reason) {
        IssuePurchaseRejectionReason.outsideFiscalYear =>
          'This purchase is dated outside ${fiscalYear.label} and cannot be '
              'recorded into it.',
        IssuePurchaseRejectionReason.unknownSupplier =>
          'There is no supplier with id "${purchase.supplierId}". Stock '
              'received from nobody cannot be recorded as stock on hand.',
        IssuePurchaseRejectionReason.supplierNotActive =>
          '${supplier?.name ?? 'This supplier'} is marked as no longer used, so a '
              'new bill cannot be recorded against them. If they should be usable '
              'again, reactivate them first.',
        IssuePurchaseRejectionReason.unknownProduct =>
          'This purchase names a product that does not exist, so the goods '
              'received cannot be added to stock. Create the product first.',
      };
}

enum IssuePurchaseRejectionReason {
  /// The purchase is dated outside the active fiscal year.
  outsideFiscalYear,

  /// The supplier the purchase bills does not exist.
  unknownSupplier,

  /// The supplier exists but has been **deactivated**.
  ///
  /// **A separate reason from [unknownSupplier], not folded into it.** The remedies
  /// are opposite -- create the supplier, versus reactivate one that already exists
  /// -- and "no supplier by that id" would send the operator to create a duplicate
  /// of a business they already have on file.
  ///
  /// **Only new purchases are refused.** A payment settling an existing bill is not,
  /// because refusing to let a business pay a debt it owes would leave the payable
  /// stranded.
  supplierNotActive,

  /// A stock line names a product that does not exist.
  ///
  /// **A separate reason, not folded into [unknownSupplier].** The remedy is
  /// completely different — create the product rather than pick a supplier — so
  /// reporting it as an unknown supplier would send the operator to the wrong
  /// screen.
  unknownProduct,
}

/// Records a purchase bill: numbers it, accounts for it, stores it, and moves the
/// stock it delivered.
///
/// ## The entry
///
/// ```
/// Dr  1040 Inventory              subtotal — the NET cost of the goods
/// Dr  1150 Input VAT Recoverable  VAT charged on the purchase
/// Cr  2010 Accounts Payable       total, including VAT
/// ```
///
/// **Inventory is debited with the subtotal, never the gross.** Goods are carried
/// at cost and a recoverable tax is not part of cost; capitalising the gross would
/// turn 13% of the purchase into an expense the moment the stock is sold. This is
/// the difference between ADR 012's purchase side and ADR 004's inventory rule, and
/// it is the one line here that is easy to get wrong in a way that still balances.
///
/// ## Four things happen, atomically
///
/// The serial, the journal entry, the document record, and one inventory movement
/// per stock line. All four commit together or none does:
///
/// - A refused purchase writes **nothing**, so it consumes no serial.
/// - A posting failure rolls the allocation back, so the sequence has no gap.
/// - A purchase whose stock cannot be applied rolls back its entry with it.
///
/// ## Why the stock movement happens here rather than on a separate screen
///
/// Buying stock is one business fact, not two. Recording the bill without the
/// movement would leave `1040` and the physical stock as two unrelated numbers —
/// precisely the defect 4.17 recorded as a Gate 6 blocker.
class IssuePurchase {
  const IssuePurchase({
    required this.fiscalYear,
    required this.suppliers,
    required this.purchases,
    required this.numbers,
    required this.journal,
    required this.unitOfWork,
    this.inventory,
  });

  /// The fiscal year currently open for writing.
  final FiscalYear fiscalYear;

  final SupplierRepository suppliers;

  /// Where the issued purchase is recorded as a document.
  final PurchaseRepository purchases;

  final DocumentNumberSequence numbers;

  final JournalRepository journal;

  final UnitOfWork unitOfWork;

  /// Where the received stock is recorded.
  ///
  /// **Optional so the use case can be exercised without an inventory store**, the
  /// same arrangement `IssueInvoice` uses for the seller snapshot. A purchase of
  /// services or freight legitimately has no stock lines, so its absence changes
  /// nothing for those bills; a purchase *with* stock lines and no inventory store
  /// would record the bill while silently losing the stock, so the application
  /// always supplies this and [PurchaseIssued] reports the resulting positions.
  final InventoryRepository? inventory;

  /// The journal entry id for a purchase.
  ///
  /// Delegates to [IssuedPurchase], which owns the rule, so there is one definition
  /// rather than two. Deriving it from the purchase id means re-posting a purchase
  /// is refused by the primary key rather than doubling the payable and the input
  /// VAT claim at once.
  static String journalEntryIdFor(Purchase purchase) =>
      IssuedPurchase.journalEntryIdFor(purchase);

  Future<IssuePurchaseOutcome> call(Purchase purchase) async {
    // Validated before anything is opened. A refused purchase must leave no trace,
    // and the cheapest way to guarantee that is never to start.
    if (!fiscalYear.contains(purchase.issueDate)) {
      return PurchaseRejected(
        purchase: purchase,
        reason: IssuePurchaseRejectionReason.outsideFiscalYear,
        fiscalYear: fiscalYear,
      );
    }

    return unitOfWork.run<IssuePurchaseOutcome>(() async {
      // Inside the transaction, so the read that proves the supplier exists and the
      // writes that reference them cannot be separated by a change in between.
      final supplier = await suppliers.byId(purchase.supplierId);
      if (supplier == null) {
        return PurchaseRejected(
          purchase: purchase,
          reason: IssuePurchaseRejectionReason.unknownSupplier,
          fiscalYear: fiscalYear,
        );
      }

      // **Refused before a serial is allocated**, so a shut supplier costs no
      // document number and leaves no gap in the sequence. Only *new* bills are
      // refused -- settling an old one is not this use case's business.
      if (!supplier.canBeBilledOnNewPurchase) {
        return PurchaseRejected(
          purchase: purchase,
          reason: IssuePurchaseRejectionReason.supplierNotActive,
          fiscalYear: fiscalYear,
          supplier: supplier,
        );
      }

      // Every stock line must name a product that exists, and this is checked here
      // rather than letting `applyMovement` fail later: the refusal message is far
      // better, and no serial has been consumed yet at that point either way.
      final products = await _resolveStockProducts(purchase);
      if (products == null) {
        return PurchaseRejected(
          purchase: purchase,
          reason: IssuePurchaseRejectionReason.unknownProduct,
          fiscalYear: fiscalYear,
        );
      }

      final number = await numbers.allocateNext(
        type: DocumentType.purchase,
        fiscalYear: fiscalYear,
      );

      final issued = IssuedPurchase(purchase: purchase, number: number);
      final entry = journalEntryFor(purchase, number);

      // The entry first, because the purchase and every movement hold a foreign
      // key to it.
      await journal.append(entry);

      await purchases.save(issued);

      final stockPositions = <String, ProductStock>{};
      for (final line in purchase.stockLines) {
        final product = products[line.productId]!;
        final movement = movementFor(purchase, line);

        // applyMovement re-checks its own invariants inside this same
        // transaction, so a line that cannot be applied rolls the entry, the bill,
        // and the serial back with it.
        stockPositions[product.id] = await inventory!.applyMovement(
          product,
          movement,
          journalEntryId: entry.id,
        );
      }

      return PurchaseIssued(
        purchase: purchase,
        number: number,
        journalEntry: entry,
        issued: issued,
        supplier: supplier,
        stockPositions: Map.unmodifiable(stockPositions),
        undeclaredSupplierWarnings: await _undeclaredSupplierWarnings(
          purchase,
          supplier,
          products,
        ),
        inputCreditWarning: supplier.canSupportInputCredit
            ? null
            : 'This bill is from a supplier with no PAN, so the '
                '${purchase.vat.format()} of VAT charged on it may be '
                'disallowed as input credit in an audit. The purchase is still '
                'recorded, because the goods really were received.',
      );
    });
  }

  /// A warning for each product whose declared suppliers do not include this one.
  ///
  /// ## Nothing is refused
  ///
  /// The bill is the authority on who supplied the goods, so it is posted whatever
  /// the catalogue says. See [PurchaseIssued.undeclaredSupplierWarnings].
  ///
  /// ## Only products that **declare** anything can warn
  ///
  /// A product with no declared suppliers is ordinary, so it never produces a
  /// warning. **Warning on an empty list would mean nearly every bill carries a
  /// warning forever**, and a warning that always fires is a warning nobody reads.
  ///
  /// Reads through [InventoryRepository.declaredSuppliersFor] rather than holding a
  /// list on the product, so there is only one copy of the fact.
  Future<List<String>> _undeclaredSupplierWarnings(
    Purchase purchase,
    Supplier supplier,
    Map<String, Product> products,
  ) async {
    final store = inventory;
    if (store == null) return const [];

    final warnings = <String>[];
    for (final line in purchase.stockLines) {
      final productId = line.productId;
      if (productId == null) continue;

      final declared = await store.declaredSuppliersFor(productId);
      if (declared.isEmpty) continue;
      if (declared.any((link) => link.names(supplier.id))) continue;

      final name = products[productId]?.name ?? productId;
      warnings.add(
        'This bill bought "$name" from ${supplier.name}, who is not one of the '
        'suppliers declared for it. The purchase has been recorded, because the '
        'goods were received.',
      );
    }
    return warnings;
  }

  /// The products named by the stock lines, or `null` if any is unknown.
  ///
  /// Resolved **before** the serial is allocated, so a bill naming a product that
  /// does not exist burns nothing.
  Future<Map<String, Product>?> _resolveStockProducts(Purchase purchase) async {
    if (!purchase.receivesStock) return const {};

    final store = inventory;
    if (store == null) {
      // No inventory store and a stock line: the bill would be recorded while the
      // goods silently vanished, which is worse than refusing it.
      return null;
    }

    final resolved = <String, Product>{};
    for (final line in purchase.stockLines) {
      final product = await store.productById(line.productId!);
      if (product == null) return null;
      resolved[product.id] = product;
    }
    return resolved;
  }

  /// The inventory movement for a purchase line.
  ///
  /// **The movement value is the line's net total**, so the VAT never enters
  /// inventory and lands in `1150` instead. The reason is
  /// [MovementReason.purchase], which is what makes the posting layer treat this
  /// as a receipt rather than an issue.
  ///
  /// The id is derived from the purchase and line number, so re-running the
  /// operation cannot create a second movement for the same line.
  static InventoryMovement movementFor(Purchase purchase, PurchaseLine line) {
    final number = purchase.lines.indexOf(line) + 1;
    return InventoryMovement.receipt(
      id: '${movementIdPrefix(purchase)}-$number',
      productId: line.productId!,
      date: purchase.issueDate,
      reason: MovementReason.purchase,
      quantity: line.quantity,
      value: line.lineTotal,
    );
  }

  /// The prefix shared by every movement this purchase creates.
  static String movementIdPrefix(Purchase purchase) => 'MV-PUR-${purchase.id}';

  /// The double entry for a purchase.
  ///
  /// ```
  /// Dr  1040 Inventory              subtotal
  /// Dr  1150 Input VAT Recoverable  VAT
  /// Cr  2010 Accounts Payable       total
  /// ```
  ///
  /// A zero-rated purchase **omits the input VAT line** rather than posting a zero,
  /// because a journal line must carry a positive amount on one side and a return
  /// expects no line rather than a zero line.
  ///
  /// The standard chart is referenced directly rather than injected, for the same
  /// reason `IssueInvoice` does: a purchase always posts to Inventory, Input VAT
  /// and Accounts Payable, and those are fixed domain facts rather than
  /// configuration. The ids are permanent, so this cannot repoint history.
  JournalEntry journalEntryFor(Purchase purchase, DocumentNumber number) {
    return JournalEntry(
      id: journalEntryIdFor(purchase),
      date: purchase.issueDate,
      description: 'Purchase ${number.value}',
      reference: number.value,
      lines: [
        JournalLine.debit(
          account: ChartOfAccounts.inventory,
          amount: purchase.subtotal,
        ),
        if (!purchase.vat.isZero)
          JournalLine.debit(
            account: ChartOfAccounts.inputVatRecoverable,
            amount: purchase.vat,
          ),
        JournalLine.credit(
          account: ChartOfAccounts.payable,
          amount: purchase.total,
        ),
      ],
    );
  }

  /// The accounts a purchase posts to, as one readable table.
  ///
  /// Kept beside the entry builder rather than scattered, because this mapping
  /// **is** the accounting policy:
  ///
  /// | | Debit | Credit |
  /// | --- | --- | --- |
  /// | goods | 1040 Inventory (net) | — |
  /// | tax | 1150 Input VAT Recoverable | — |
  /// | the liability | — | 2010 Accounts Payable (gross) |
  static ({Account goods, Account tax, Account liability}) get accounts => (
        goods: ChartOfAccounts.inventory,
        tax: ChartOfAccounts.inputVatRecoverable,
        liability: ChartOfAccounts.payable,
      );
}
