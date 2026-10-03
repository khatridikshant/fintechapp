import '../domain/accounting/chart_of_accounts.dart';
import '../domain/accounting/journal_entry.dart';
import '../domain/accounting/journal_line.dart';
import '../domain/accounting/journal_repository.dart';
import '../domain/billing/business_profile_repository.dart';
import '../domain/billing/customer_repository.dart';
import '../domain/billing/document_number.dart';
import '../domain/billing/document_number_sequence.dart';
import '../domain/billing/document_type.dart';
import '../domain/billing/invoice.dart';
import '../domain/billing/invoice_line.dart';
import '../domain/billing/invoice_repository.dart';
import '../domain/billing/issued_invoice.dart';
import '../domain/fiscal/fiscal_year.dart';
import '../domain/inventory/inventory_movement.dart';
import '../domain/inventory/inventory_repository.dart';
import '../domain/inventory/product.dart';
import '../domain/inventory/product_stock.dart';
import '../domain/shared/money.dart';
import '../domain/shared/unit_of_work.dart';

/// The outcome of attempting to issue an invoice.
sealed class IssueInvoiceOutcome {
  const IssueInvoiceOutcome();
}

/// The invoice was issued, numbered, and posted.
final class InvoiceIssued extends IssueInvoiceOutcome {
  const InvoiceIssued({
    required this.invoice,
    required this.number,
    required this.journalEntry,
    required this.issued,
    this.stockPositions = const {},
    this.costOfGoodsSold,
  });

  final Invoice invoice;

  /// The serial allocated at issuance. This is the first time the invoice has a
  /// number, because a draft does not consume one.
  final DocumentNumber number;

  final JournalEntry journalEntry;

  /// The stored document: the invoice together with its number and the id of the
  /// entry that records it.
  final IssuedInvoice issued;

  /// The resulting stock position for every product sold, keyed by product id.
  ///
  /// **Empty when no line named a product**, which is normal: a service or a
  /// one-off job has no stock to move.
  final Map<String, ProductStock> stockPositions;

  /// The cost of the goods sold, derived from the running stock value.
  ///
  /// Null when the invoice sold nothing that came from stock. **Never taken from
  /// the operator** Ã¢â‚¬â€ see [IssueInvoice] for why that matters.
  final Money? costOfGoodsSold;

  /// Whether this sale moved any stock.
  bool get movedStock => stockPositions.isNotEmpty;
}

/// The invoice was refused and nothing was written.
final class InvoiceRejected extends IssueInvoiceOutcome {
  const InvoiceRejected({
    required this.invoice,
    required this.reason,
    required this.fiscalYear,
  });

  final Invoice invoice;
  final IssueRejectionReason reason;
  final FiscalYear fiscalYear;

  String get message => switch (reason) {
        IssueRejectionReason.outsideFiscalYear =>
          'This invoice is dated outside ${fiscalYear.label} and cannot be '
              'issued into it.',
        IssueRejectionReason.unknownCustomer =>
          'There is no customer with id "${invoice.customerId}". A sale cannot '
              'be recorded as a receivable owed by nobody.',
        IssueRejectionReason.unknownProduct =>
          'This invoice names a product that does not exist, so the stock it '
              'sold cannot be issued. Create the product first, or remove the '
              'product from the line.',
        IssueRejectionReason.insufficientStock =>
          'Not enough stock to satisfy this invoice. Reduce the quantity, or '
              'record the missing stock first.',
      };
}

enum IssueRejectionReason {
  /// The invoice is dated outside the active fiscal year.
  outsideFiscalYear,

  /// The customer the invoice bills does not exist.
  unknownCustomer,

  /// A line names a product that does not exist.
  ///
  /// **A separate reason, not folded into [unknownCustomer].** The remedy is
  /// completely different Ã¢â‚¬â€ create the product rather than pick a customer Ã¢â‚¬â€ so
  /// reporting it as a customer problem would send the operator to the wrong
  /// screen.
  unknownProduct,

  /// The invoice sells more of a product than is on hand.
  ///
  /// **Refused rather than allowed to go negative.** Selling stock the business
  /// does not have is possible in the real world, but recording it would post a
  /// cost derived from a negative holding and leave inventory and the physical
  /// count irreconcilable. The stock is recorded first and the sale follows.
  insufficientStock,
}

/// Issues a sales invoice: numbers it, accounts for it, and records it.
///
/// The whole operation runs inside a **single unit of work**. That is the point
/// of this use case, and it is what makes the failure behaviour correct:
///
/// - The serial is allocated only after the date has been validated, so a
///   refused invoice never consumes one.
/// - If the posting fails, the allocation rolls back with it. The sequence has
///   no gap, and the next attempt receives the same number.
///
/// A partly issued invoice Ã¢â‚¬â€ numbered but not posted, or posted without a number
/// Ã¢â‚¬â€ is impossible, because neither half can commit on its own.
///
/// The journal entry id is derived from the invoice id. That gives two things at
/// once: the entry is traceable back to the invoice that caused it, and
/// re-issuing an invoice id that has already been posted is refused by the
/// primary key rather than silently double-posting.
class IssueInvoice {
  const IssueInvoice({
    required this.fiscalYear,
    required this.customers,
    required this.numbers,
    required this.journal,
    required this.invoices,
    required this.unitOfWork,
    this.sellers,
    this.inventory,
  });

  /// The fiscal year currently open for writing.
  final FiscalYear fiscalYear;

  final CustomerRepository customers;

  final DocumentNumberSequence numbers;

  final JournalRepository journal;

  /// Where the issued invoice is recorded as a document.
  final InvoiceRepository invoices;

  final UnitOfWork unitOfWork;

  /// Where the business's own details come from.
  ///
  /// **Read by the use case rather than passed in by the caller**, so the snapshot
  /// cannot be forgotten: the printed invoice is the evidence in an audit, and a
  /// caller that remembered to stamp it only sometimes is worse than one that
  /// never can.
  ///
  /// Optional so the use case can be exercised without a database. **The
  /// application always supplies it**, and an invoice issued without a snapshot is
  /// reported by `InvoiceCompliance` rather than passing unnoticed.
  final BusinessProfileRepository? sellers;

  /// Where stock is issued when a line names a product.
  ///
  /// **Optional so the use case can be exercised without an inventory store**, the
  /// same arrangement [sellers] uses. The application always supplies it, and an
  /// invoice naming a product with no inventory store is **refused** rather than
  /// recorded with the stock silently lost.
  final InventoryRepository? inventory;

  /// The journal entry id for an invoice.
  ///
  /// Delegates to [IssuedInvoice], which owns the rule, so there is one
  /// definition rather than two.
  static String journalEntryIdFor(Invoice invoice) =>
      IssuedInvoice.journalEntryIdFor(invoice);

  Future<IssueInvoiceOutcome> call(Invoice invoice) async {
    // Validate the date before opening anything. A refused invoice must leave no
    // trace at all, and the cheapest way to guarantee that is never to start.
    if (!fiscalYear.contains(invoice.issueDate)) {
      return InvoiceRejected(
        invoice: invoice,
        reason: IssueRejectionReason.outsideFiscalYear,
        fiscalYear: fiscalYear,
      );
    }

    return unitOfWork.run<IssueInvoiceOutcome>(() async {
      // The customer check runs inside the transaction, so the read that proves
      // the customer exists and the writes that reference them cannot be
      // separated by a change in between.
      final customer = await customers.byId(invoice.customerId);
      if (customer == null) {
        return InvoiceRejected(
          invoice: invoice,
          reason: IssueRejectionReason.unknownCustomer,
          fiscalYear: fiscalYear,
        );
      }

      // Stock is resolved and costed **before** the serial is allocated, so an
      // invoice that cannot be satisfied burns no number and writes nothing.
      final stockPlan = await _planStock(invoice);
      if (stockPlan == null) {
        return InvoiceRejected(
          invoice: invoice,
          reason: IssueRejectionReason.unknownProduct,
          fiscalYear: fiscalYear,
        );
      }
      if (stockPlan.insufficient != null) {
        return InvoiceRejected(
          invoice: invoice,
          reason: IssueRejectionReason.insufficientStock,
          fiscalYear: fiscalYear,
        );
      }

      final number = await numbers.allocateNext(
        type: DocumentType.invoice,
        fiscalYear: fiscalYear,
      );

      // The seller's details are copied onto the invoice **before** it is
      // recorded, so the stored document carries what was printed on it. Read
      // inside the transaction: the profile a customer was shown and the one
      // stamped must be the same.
      final seller = await sellers?.load();
      final stamped = seller == null
          ? invoice
          : invoice.stampedWithSeller(
              name: seller.name,
              pan: seller.panNumber,
            );

      final issued = IssuedInvoice(invoice: stamped, number: number);
      final entry = journalEntryFor(
        stamped,
        number,
        costOfGoodsSold: stockPlan.cost,
      );

      // The journal entry is written first, because the invoice record holds a
      // foreign key to it.
      await journal.append(entry);

      // The document record. All three writes commit together or none does, so a
      // numbered invoice always has a record and an entry behind it.
      await invoices.save(issued);

      // Stock moves **last and inside the same unit of work**, so a movement that
      // cannot be applied rolls the entry, the document, and the serial back
      // together. Selling stock and recording the sale is one business fact, and
      // splitting it across two commits is how inventory and the ledger diverge.
      final positions = <String, ProductStock>{};
      for (final movement in stockPlan.movements) {
        positions[movement.product.id] = await inventory!.applyMovement(
          movement.product,
          movement.movement,
          journalEntryId: entry.id,
        );
      }

      return InvoiceIssued(
        invoice: stamped,
        number: number,
        journalEntry: entry,
        issued: issued,
        stockPositions: Map.unmodifiable(positions),
        costOfGoodsSold: stockPlan.cost,
      );
    });
  }

  /// Resolves the stock a sale will issue and the cost it derives.
  ///
  /// Returns null when a line names a product that cannot be resolved, and a plan
  /// whose `insufficient` is set when there is not enough on hand.
  ///
  /// ## The cost is derived, never supplied
  ///
  /// Cost of sales comes from [ProductStock.valueOfIssue] Ã¢â‚¬â€ the running weighted
  /// average Ã¢â‚¬â€ and not from anything the operator types. This is ADR 004's rule,
  /// and it is the reason a product may be put on an invoice line at all: a COGS
  /// figure entered by hand is whatever someone believed the cost was, while the
  /// figure the stock movement produces is the one the books can prove.
  Future<_StockPlan?> _planStock(Invoice invoice) async {
    final stockLines = <InvoiceLine>[
      for (final line in invoice.lines)
        if (line.issuesStock) line,
    ];

    if (stockLines.isEmpty) {
      return const _StockPlan(movements: [], cost: null, insufficient: null);
    }

    final store = inventory;
    if (store == null) {
      // No inventory store with stock to move: recording the sale would leave the
      // goods still on hand and post no cost, which is worse than refusing.
      return null;
    }

    final movements = <_PlannedMovement>[];
    var cost = 0;

    for (final line in stockLines) {
      final product = await store.productById(line.productId!);
      if (product == null) return null;

      // Services and non-physical items are exempt: they never had stock to go
      // negative, so the check below would be meaningless for them.
      if (!product.stockTrackingEnabled) {
        movements.add(
          _PlannedMovement(
            product: product,
            movement: InventoryMovement.issue(
              id: movementId(invoice, line),
              productId: product.id,
              date: invoice.issueDate,
              reason: MovementReason.sale,
              quantity: line.quantity,
              value: Money.minor(0, invoice.currency),
            ),
          ),
        );
        continue;
      }

      final current = await store.stockOf(product);
      if (current.quantity < line.quantity) {
        return _StockPlan(
          movements: const [],
          cost: null,
          insufficient: '${product.name}: ${line.quantity} sold but only '
              '${current.quantity} on hand.',
        );
      }

      // **The derived cost.** `valueOfIssue` returns a *negative* figure because
      // stock is leaving. `InventoryMovement.issue` takes a positive quantity and a
      // positive value and applies the sign itself, so the magnitude is what gets
      // handed over -- passing the signed figure straight through would negate it
      // twice and add stock instead of removing it.
      final costOfLine = current.valueOfIssue(line.quantity);

      movements.add(
        _PlannedMovement(
          product: product,
          movement: InventoryMovement.issue(
            id: movementId(invoice, line),
            productId: product.id,
            date: invoice.issueDate,
            reason: MovementReason.sale,
            quantity: line.quantity,
            value: Money.minor(
              costOfLine.minorUnits.abs(),
              costOfLine.currency,
            ),
          ),
        ),
      );

      cost += costOfLine.minorUnits.abs();
    }

    return _StockPlan(
      movements: movements,
      cost: cost == 0 ? null : Money.minor(cost, invoice.currency),
      insufficient: null,
    );
  }

  /// The movement id for one invoice line.
  ///
  /// **Derived from the invoice and line number**, so a retry cannot create a
  /// second movement for the same line.
  static String movementId(Invoice invoice, InvoiceLine line) {
    final lineNumber = invoice.lines.indexOf(line) + 1;
    return 'MV-SALE-${invoice.id}-$lineNumber';
  }

  /// The double entry for a sale.
  ///
  /// ```
  /// Dr  1030 Accounts Receivable   total including VAT
  ///   Cr  4010 Sales Revenue         subtotal
  ///   Cr  2020 VAT Payable           VAT amount
  /// Dr  5010 Cost of Goods Sold    the derived cost of the goods sold
  ///   Cr  1040 Inventory             the same figure
  /// ```
  ///
  /// ## The extra pair only when goods came from stock
  ///
  /// The cost of goods sold lines are **omitted entirely** for an invoice that
  /// sold nothing trackable, rather than posted as zero: a journal line must carry
  /// a positive amount on one side, and a service-only sale genuinely has no cost
  /// to recognise.
  ///
  /// The amount is [ProductStock.valueOfIssue] Ã¢â‚¬â€ the running weighted average Ã¢â‚¬â€ so
  /// the credit to Inventory equals the movement's value by construction. That
  /// equality is what makes the inventory account and the derived stock value
  /// reconcile, and it is the property ADR 004 exists to preserve.
  JournalEntry journalEntryFor(
    Invoice invoice,
    DocumentNumber number, {
    Money? costOfGoodsSold,
  }) {
    return JournalEntry(
      id: journalEntryIdFor(invoice),
      date: invoice.issueDate,
      description: 'Invoice ${number.value}',
      reference: number.value,
      lines: [
        JournalLine.debit(
          account: ChartOfAccounts.receivable,
          amount: invoice.total,
        ),
        JournalLine.credit(
          account: ChartOfAccounts.salesRevenue,
          amount: invoice.subtotal,
        ),
        if (!invoice.vat.isZero)
          JournalLine.credit(
            account: ChartOfAccounts.vatPayable,
            amount: invoice.vat,
          ),
        if (costOfGoodsSold != null && costOfGoodsSold.isPositive) ...[
          JournalLine.debit(
            account: ChartOfAccounts.costOfGoodsSold,
            amount: costOfGoodsSold,
          ),
          JournalLine.credit(
            account: ChartOfAccounts.inventory,
            amount: costOfGoodsSold,
          ),
        ],
      ],
    );
  }
}

/// What a sale will do to stock, worked out before anything is written.
class _StockPlan {
  const _StockPlan({
    required this.movements,
    required this.cost,
    required this.insufficient,
  });

  final List<_PlannedMovement> movements;

  /// The derived cost of goods sold, or null when nothing came from stock.
  final Money? cost;

  /// A description of the shortfall, or null when the sale can proceed.
  ///
  /// Carrying the explanation rather than throwing means the refusal can name the
  /// product and the numbers, which is what the operator needs to act on.
  final String? insufficient;
}

/// One product's movement, with the product already resolved.
class _PlannedMovement {
  const _PlannedMovement({required this.product, required this.movement});

  final Product product;
  final InventoryMovement movement;
}
