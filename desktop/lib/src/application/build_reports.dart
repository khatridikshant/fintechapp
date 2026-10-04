/// The four reports that were missing, as use cases.
///
/// Grouped in one file rather than four because they read the same data for the
/// same period, and splitting them would spread the definitions of "the period"
/// across four files that could then disagree.
///
/// Every one of these is a use case rather than something a screen assembles,
/// because a screen that built its own report would hold business logic in the
/// presentation layer, which docs/AI_RULES.md prohibits.
library;

/// The four reports that were missing, as use cases.
///
/// Grouped in one file rather than four because they read the same data for the
/// same period, and splitting them would spread the definition of the period
/// across four files that could then disagree.
///
/// Every one is a use case rather than something a screen assembles, because a
/// screen that built its own report would hold business logic in the presentation
/// layer, which `docs/AI_RULES.md` prohibits.

import '../domain/accounting/chart_of_accounts.dart';
import '../domain/shared/currency.dart';
import '../domain/accounting/journal_repository.dart';
import '../domain/billing/credit_note_repository.dart';
import '../domain/billing/invoice_repository.dart';
import '../domain/billing/purchase_repository.dart';
import '../domain/billing/supplier_repository.dart';
import '../domain/fiscal/fiscal_year.dart';
import '../domain/inventory/inventory_repository.dart';
import '../domain/inventory/product_category.dart';
import '../domain/reporting/financial_reports.dart';
import '../domain/shared/money.dart';

/// Builds the cash statement for a period.
class BuildCashFlow {
  const BuildCashFlow({
    required this.fiscalYear,
    required this.journal,
    this.currency = bookCurrency,
  });

  final FiscalYear fiscalYear;
  final JournalRepository journal;
  final String currency;

  Future<CashFlow> load({DateTime? from, DateTime? to}) async {
    final entries = await journal.all();

    // **The period opens at the start of the fiscal year when the caller gives no
    // date.** Without this, every entry in the year would be a movement, and the
    // opening-balance entry that concludes one year and opens the next would be
    // reported as cash *received* during the year -- which is the opposite of what
    // it is.
    //
    // The boundary is included in opening cash **only for that whole-year view**.
    // An explicit date range keeps the strict rule, because there the caller chose
    // the boundary and a transaction on the first day really did happen in the
    // period.
    final wholeYear = from == null;
    final start = from ?? fiscalYear.startDate;

    return CashFlow.from(
      entries: entries,
      // **Derived from the chart of accounts, not named here**, so a business that
      // adds a second cash box is included without a code change.
      isCashAccount: _isCashAccount,
      currency: currency,
      from: start,
      to: to,
      openingIncludesBoundary: wholeYear,
    );
  }

  /// The accounts whose movement is cash.
  ///
  /// Named ids rather than a chart flag, because the chart has no "is cash" property
  /// and adding one is a schema change for a reporting need.
  static bool _isCashAccount(String accountId) =>
      accountId == ChartOfAccounts.bank.id ||
      accountId == ChartOfAccounts.cash.id;
}

/// Builds sales for a period: what was invoiced, net of credits.
class BuildSalesSummary {
  const BuildSalesSummary({
    required this.fiscalYear,
    required this.invoices,
    required this.creditNotes,
    this.currency = bookCurrency,
  });

  final FiscalYear fiscalYear;
  final InvoiceRepository invoices;
  final CreditNoteRepository creditNotes;
  final String currency;

  Future<SalesSummary> load({DateTime? from, DateTime? to}) async {
    final issued = await invoices.all();
    final credited = await creditNotes.all();

    // **The year is the boundary, not the whole of time.** A document dated
    // outside the fiscal year belongs to another year's books and must not appear
    // in this year's sales.
    final start = from ?? fiscalYear.startDate;

    bool inRange(DateTime date) {
      if (date.isBefore(start)) return false;
      if (to != null && date.isAfter(to)) return false;
      return true;
    }

    // By product, so the biggest lines are visible without reading every invoice.
    final byProduct = <String, int>{};
    for (final issuedInvoice in issued) {
      if (!inRange(issuedInvoice.invoice.issueDate)) continue;
      for (final line in issuedInvoice.invoice.lines) {
        byProduct.update(
          line.description,
          (existing) => existing + line.lineTotal.minorUnits,
          ifAbsent: () => line.lineTotal.minorUnits,
        );
      }
    }

    final credits = <ReportTotal>[];
    for (final note in credited) {
      if (!inRange(note.creditNote.date)) continue;
      var total = 0;
      for (final line in note.creditNote.lines) {
        total += line.lineTotal.minorUnits;
      }
      credits.add(
        ReportTotal(
            label: note.number.value, amount: Money.minor(total, currency)),
      );
    }

    final grossLines = byProduct.entries
        .map(
          (MapEntry<String, int> e) =>
              ReportTotal(label: e.key, amount: Money.minor(e.value, currency)),
        )
        .toList()
      // Largest first, because that is the order a reader wants.
      ..sort((ReportTotal a, ReportTotal b) =>
          b.amount.minorUnits.compareTo(a.amount.minorUnits));

    return SalesSummary.from(
      grossSales: grossLines,
      credits: credits,
      currency: currency,
    );
  }
}

/// Builds what stock is held, by product, at a point.
class BuildInventorySummary {
  const BuildInventorySummary({
    required this.fiscalYear,
    required this.inventory,
    this.currency = bookCurrency,
  });

  final FiscalYear fiscalYear;
  final InventoryRepository inventory;
  final String currency;

  Future<InventorySummary> load() async {
    final movements = await inventory.allMovements();
    final products = await inventory.allProducts();

    // **Stock held is as at today, so every movement in the year counts** --
    // including the opening entry that set the year up. Unlike the other three
    // reports there is nothing to exclude here: stock is a balance, not a period's
    // movement.
    //
    // Movements from before the fiscal year still count, because they are what the
    // opening entry carried forward.
    final byProduct = <String, int>{};
    for (final movement in movements) {
      byProduct.update(
        movement.productId,
        (existing) => existing + movement.value.minorUnits,
        ifAbsent: () => movement.value.minorUnits,
      );
    }

    final labels = <String, String>{
      for (final product in products) product.id: product.name,
    };

    final lines = byProduct.entries
        .map(
          (MapEntry<String, int> e) => ReportTotal(
            // The product's name, falling back to its id when the product has been
            // removed from the catalogue but its movements remain.
            label: labels[e.key] ?? e.key,
            amount: Money.minor(e.value, currency),
          ),
        )
        .toList()
      ..sort((ReportTotal a, ReportTotal b) =>
          b.amount.minorUnits.compareTo(a.amount.minorUnits));

    return InventorySummary.from(lines: lines);
  }
}

/// Builds the stock report grouped by product category.
///
/// This is the reason [ProductCategory] exists (ADR 013): a flat
/// stock list is unusable for a business with a hundred products. It
/// groups the same stock value [BuildInventorySummary] shows, by the
/// category each product belongs to, so the two reports must agree on
/// the total — and a test asserts that they do.
///
/// ## One level of nesting, resolved
///
/// A product in a child category is reported under its **top-level**
/// parent. That is what "resolves one level of nesting" means: the
/// report is flat, so a child's stock is rolled up to the heading a
/// reader would look for it under.
///
/// ## A tree it cannot report is refused, not flattened
///
/// A category whose parent does not exist, or that sits more than one
/// level down, would otherwise be flattened into a wrong group. The
/// tree is validated before anything is grouped, so such a book
/// reports a failure rather than a number nobody chose (ADR 013).
class BuildCategoryReport {
  const BuildCategoryReport({
    required this.fiscalYear,
    required this.inventory,
    this.currency = bookCurrency,
  });

  final FiscalYear fiscalYear;
  final InventoryRepository inventory;
  final String currency;

  Future<CategorySummary> load() async {
    final categories = await inventory.allCategories();
    final products = await inventory.allProducts();
    final movements = await inventory.allMovements();

    // **The tree is validated before anything is grouped.** A category
    // whose parent is missing, or that sits below the one level V1
    // reports, would otherwise be flattened into a wrong group.
    // Refusing is the honest answer, and it is cheap.
    final byId = <String, ProductCategory>{
      for (final category in categories) category.id: category,
    };
    for (final category in categories) {
      category.assertWithinV1Depth(byId);
    }

    // **Stock held is as at today, so every movement counts** — the
    // same rule as the inventory report, because both read the same
    // history. A balance, not a period's movement.
    final valueByProduct = <String, int>{};
    for (final movement in movements) {
      valueByProduct.update(
        movement.productId,
        (existing) => existing + movement.value.minorUnits,
        ifAbsent: () => movement.value.minorUnits,
      );
    }

    // Group each product's stock under the top-level category it
    // belongs to. A product with no category is ordinary (ADR 013), so
    // it is reported under its own heading rather than hidden.
    final byCategory = <String, int>{};
    for (final product in products) {
      final value = valueByProduct[product.id] ?? 0;
      if (value == 0) continue;

      final categoryId = product.categoryId;
      final key = categoryId == null
          ? CategorySummary.uncategorizedLabel
          : _topLevel(byId[categoryId]!, byId).id;
      byCategory.update(
        key,
        (existing) => existing + value,
        ifAbsent: () => value,
      );
    }

    final labels = <String, String>{
      for (final category in categories) category.id: category.name,
    };

    final lines = byCategory.entries
        .map(
          (MapEntry<String, int> e) => ReportTotal(
            // The category's name, or the uncategorized heading for the
            // products that belong to none.
            label: labels[e.key] ?? e.key,
            amount: Money.minor(e.value, currency),
          ),
        )
        .toList()
      // Largest first, because that is the order a reader wants, and
      // the order the inventory report uses.
      ..sort((ReportTotal a, ReportTotal b) =>
          b.amount.minorUnits.compareTo(a.amount.minorUnits));

    return CategorySummary.from(lines: lines, currency: currency);
  }

  /// The top-level category [category] sits under, walking up the
  /// parent chain.
  ///
  /// Safe to call only on a tree that has already been validated,
  /// because every parent in the chain is then known to exist.
  ProductCategory _topLevel(
    ProductCategory category,
    Map<String, ProductCategory> byId,
  ) {
    var current = category;
    while (current.parentId != null) {
      current = byId[current.parentId!]!;
    }
    return current;
  }
}

/// Builds the VAT figures a return needs, for a period.
///
/// ## Input VAT is real, and part of it is at risk
///
/// Input VAT is summed from **purchase documents**, each contributing the VAT it
/// actually charged — the same rule as output VAT, and for the same reason: the
/// return must equal the ledger rather than re-derive it.
///
/// A purchase's VAT is split by whether the supplier had a PAN:
///
/// - **Claimable** — the bill carries the supplier's PAN, so the claim is one the
///   authority will accept.
/// - **At risk** — no PAN, so `NEPALI_BILLING.md` records that it *may* be
///   disallowed in an audit. It is still a real asset in `1150` and still shown,
///   but it is **not** netted off the output figure by [TaxSummary.netVatPayable].
///
/// Both are reported. Claiming the at-risk portion anyway would produce a return
/// demanding credit that can be refused, and the shortfall would arrive with no
/// explanation attached.
class BuildTaxSummary {
  const BuildTaxSummary({
    required this.fiscalYear,
    required this.invoices,
    required this.creditNotes,
    this.purchases,
    this.suppliers,
    this.currency = bookCurrency,
    this.rateBasisPoints = TaxSummary.standardRateBasisPoints,
  });

  final FiscalYear fiscalYear;
  final InvoiceRepository invoices;
  final CreditNoteRepository creditNotes;

  /// The purchase side. **Optional**, so a caller with no purchase records still
  /// builds a valid return rather than failing.
  final PurchaseRepository? purchases;

  /// Used to decide whether each purchase's VAT is claimable.
  ///
  /// **Optional, and its absence is not treated as "everything is claimable."**
  /// When no supplier store is supplied, every purchase is treated as at risk,
  /// because that is the safe direction: it can never overstate a claim.
  final SupplierRepository? suppliers;

  final String currency;

  /// The standard rate in force. **Data, not a constant in the logic**, because
  /// the Finance Act changes it.
  final int rateBasisPoints;

  Future<TaxSummary> load({DateTime? from, DateTime? to}) async {
    final issued = await invoices.all();
    final credited = await creditNotes.all();

    // The fiscal year is the boundary, for the same reason as in the sales report.
    final start = from ?? fiscalYear.startDate;

    bool inRange(DateTime date) {
      if (date.isBefore(start)) return false;
      if (to != null && date.isAfter(to)) return false;
      return true;
    }

    // Output VAT is on invoices issued, not on money received, so a customer
    // paying in instalments creates no extra output VAT.
    //
    // **Each document's own VAT, summed.** Not the subtotal with one rate applied
    // to the total, which is what this used to do: rounding once over an aggregate
    // disagrees with rounding once per document, and a zero-rated invoice was
    // charged the standard rate. Summing what each invoice actually charged makes
    // the return equal the ledger by construction.
    var salesExcludingVat = 0;
    var outputVatCharged = 0;
    for (final record in issued) {
      if (!inRange(record.invoice.issueDate)) continue;
      salesExcludingVat += record.invoice.subtotal.minorUnits;
      outputVatCharged += record.invoice.vat.minorUnits;
    }

    // Input VAT, summed from the purchase documents.
    //
    // **Split by whether the supplier had a PAN**, because `NEPALI_BILLING.md`
    // records that VAT on a bill lacking one may be disallowed as input credit.
    // Both halves are summed from what each bill actually charged, so the return
    // equals `1150` by construction.
    //
    // The net figure is what the bills carried **excluding** recoverable VAT,
    // because [TaxSummary.taxablePurchases] is stated the same way. Putting the
    // gross there would overstate purchases by exactly the VAT being claimed.
    var inputVatClaimable = 0;
    var inputVatAtRisk = 0;
    final purchaseLines = <ReportTotal>[];
    final purchaseStore = purchases;
    if (purchaseStore != null) {
      final supplierStore = suppliers;
      for (final record in await purchaseStore.all()) {
        if (!inRange(record.purchase.issueDate)) continue;

        final supplier = supplierStore == null
            ? null
            : await supplierStore.byId(record.purchase.supplierId);

        // **No supplier store means the claim cannot be substantiated**, so the
        // whole amount is at risk. Defaulting to "claimable" would be the unsafe
        // direction: it could only ever overstate what the return demands.
        final claimable = supplier?.canSupportInputCredit ?? false;
        if (claimable) {
          inputVatClaimable += record.purchase.vat.minorUnits;
        } else {
          inputVatAtRisk += record.purchase.vat.minorUnits;
        }

        purchaseLines.add(
          ReportTotal(
            label: record.number.value,
            amount: Money.minor(record.purchase.subtotal.minorUnits, currency),
          ),
        );
      }
    }

    // A credit note reverses the VAT it charged, so it comes out of the output
    // figure here. Using the note's own `vat` rather than a rate applied to its
    // total means a credit against a zero-rated invoice removes nothing, which is
    // correct.
    //
    // The list below carries the note's **net** amount, because `taxableSales` is
    // stated excluding VAT and the two must be on the same footing. Subtracting a
    // gross figure from a net one would understate sales by exactly the VAT that
    // was credited — which is the same class of mistake this whole change exists
    // to remove.
    var creditVatReversed = 0;
    final credits = <ReportTotal>[];
    for (final note in credited) {
      if (!inRange(note.creditNote.date)) continue;
      creditVatReversed += note.creditNote.vat.minorUnits;
      var net = 0;
      for (final line in note.creditNote.lines) {
        net += line.lineTotal.minorUnits;
      }
      credits.add(
        ReportTotal(
          label: note.number.value,
          amount: Money.minor(net, currency),
        ),
      );
    }

    return TaxSummary.from(
      taxableSales: <ReportTotal>[
        ReportTotal(
          label: 'Sales excluding VAT',
          amount: Money.minor(salesExcludingVat, currency),
        ),
      ],
      // Real purchases, itemised by bill number so the figure can be traced back
      // to the documents behind it.
      taxablePurchases: purchaseLines.isEmpty
          ? <ReportTotal>[
              ReportTotal(
                label: 'Purchases excluding VAT',
                amount: Money.minor(0, currency),
              ),
            ]
          : purchaseLines,
      credits: credits,
      outputVatCharged:
          Money.minor(outputVatCharged - creditVatReversed, currency),
      inputVatClaimable: Money.minor(inputVatClaimable, currency),
      inputVatAtRiskClaimed: Money.minor(inputVatAtRisk, currency),
      standardRateBasisPoints: rateBasisPoints,
      currency: currency,
    );
  }
}
