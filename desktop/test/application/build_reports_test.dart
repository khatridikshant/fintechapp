import 'package:financeapp/src/application/build_reports.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/billing/customer.dart';
import 'package:financeapp/src/domain/billing/credit_note.dart';
import 'package:financeapp/src/domain/billing/document_number.dart';
import 'package:financeapp/src/domain/billing/document_type.dart';
import 'package:financeapp/src/domain/billing/invoice.dart';
import 'package:financeapp/src/domain/billing/invoice_line.dart';
import 'package:financeapp/src/domain/billing/issued_credit_note.dart';
import 'package:financeapp/src/domain/billing/issued_invoice.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/inventory/inventory_movement.dart';
import 'package:financeapp/src/domain/inventory/inventory_repository.dart';
import 'package:financeapp/src/domain/inventory/product.dart';
import 'package:financeapp/src/domain/inventory/product_stock.dart';
import 'package:financeapp/src/domain/reporting/financial_reports.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_credit_note_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_customer_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_inventory_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_invoice_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';

const npr = 'NPR';
const chart = ChartOfAccounts();

Money rs(int majorUnits) => Money.minor(majorUnits * 100, npr);

final fiscalYear = const NepaliFiscalCalendar().forBsYear(2082);

/// The worked example, hand-computed before any code was written:
///
///   Opening  Dr Bank 100,000   Cr Equity   100,000   (2 Jan, before March)
///   Sale     Dr Bank  20,000   Cr Sales     20,000   (5 Mar, inside March)
///   Rent     Dr Rent   5,000   Cr Bank       5,000   (8 Mar, inside March)
///
/// So **for March alone**: opening cash 100,000, received 20,000, paid 5,000,
/// closing 115,000. Not one of those numbers comes from the report.
List<JournalEntry> journalForMarch() => [
      JournalEntry(
        id: 'OB-1',
        date: DateTime(2026, 2, 1),
        description: 'Opening balance',
        lines: [
          JournalLine.debit(account: ChartOfAccounts.bank, amount: rs(100000)),
          JournalLine.credit(
              account: ChartOfAccounts.ownersEquity, amount: rs(100000)),
        ],
      ),
      JournalEntry(
        id: 'SA-1',
        date: DateTime(2026, 3, 5),
        description: 'Cash sale',
        lines: [
          JournalLine.debit(account: ChartOfAccounts.bank, amount: rs(20000)),
          JournalLine.credit(
              account: ChartOfAccounts.salesRevenue, amount: rs(20000)),
        ],
      ),
      JournalEntry(
        id: 'EX-1',
        date: DateTime(2026, 3, 8),
        description: 'Office rent',
        lines: [
          JournalLine.debit(
              account: ChartOfAccounts.officeRent, amount: rs(5000)),
          JournalLine.credit(account: ChartOfAccounts.bank, amount: rs(5000)),
        ],
      ),
      // **After March.** Present so a date range has something to exclude.
      JournalEntry(
        id: 'EX-2',
        date: DateTime(2026, 4, 2),
        description: 'Rent paid in April',
        lines: [
          JournalLine.debit(
              account: ChartOfAccounts.officeRent, amount: rs(1000)),
          JournalLine.credit(account: ChartOfAccounts.bank, amount: rs(1000)),
        ],
      ),
    ];

InvoiceLine line(int quantity, int unitPriceRupees,
        {String description = 'item'}) =>
    InvoiceLine(
      description: description,
      quantity: quantity,
      unitPrice: rs(unitPriceRupees),
    );

Invoice invoiceOn(
  DateTime date, {
  String id = 'INV-1',
  List<InvoiceLine>? lines,
}) =>
    Invoice(
      id: id,
      issueDate: date,
      customerId: 'cust-1',
      lines: lines ?? [line(1, 1000, description: 'Keyboard')],
    );

CreditNote noteOn(
  DateTime date, {
  String id = 'CN-1',
  String invoiceId = 'INV-1',
  List<InvoiceLine>? lines,
}) =>
    CreditNote(
      id: id,
      invoiceId: invoiceId,
      date: date,
      lines: lines ?? [line(1, 400, description: 'Keyboard')],
    );

/// An inventory holding movements for a product that is no longer in the
/// catalogue.
///
/// Exists for one test only, and the comment there says why. Everything else in
/// these tests uses the real repository against a real database, because a fake
/// that disagrees with the real thing proves nothing.
class _MovementsWithoutCatalogue implements InventoryRepository {
  @override
  Future<List<InventoryMovement>> allMovements() async => <InventoryMovement>[
        InventoryMovement.receipt(
          id: 'MV-9',
          productId: 'prod-legacy',
          date: DateTime(2026, 3, 2),
          reason: MovementReason.openingStock,
          quantity: 5,
          value: Money.minor(100000, npr),
        ),
      ];

  @override
  Future<List<Product>> allProducts() async => const <Product>[];

  @override
  Future<Product?> productById(String id) async => null;

  @override
  Future<List<InventoryMovement>> movementsFor(String productId) async =>
      allMovements();

  @override
  Future<void> saveProduct(Product product) async {}

  @override
  Future<void> saveProducts(Iterable<Product> products) async {}

  @override
  Future<ProductStock> applyMovement(
    Product product,
    InventoryMovement movement, {
    String? journalEntryId,
  }) async =>
      throw UnimplementedError('this fake only reads');

  @override
  Future<ProductStock> stockOf(Product product) async =>
      throw UnimplementedError('this fake only reads');
}

void main() {
  /// The customer every invoice in this file bills, plus the journal entry each
  /// invoice points at.
  ///
  /// Seeded because `invoices` has two real foreign keys, to `customers` and to
  /// `journal_entries`, so an invoice cannot be stored without both. That is the
  /// database agreeing with the domain: a sales document with no posting behind it
  /// is not a document, it is a claim.
  ///
  /// **The journal entry here is a placeholder, not a real posting.** These tests
  /// read documents, not postings, so the amounts on it are irrelevant — but it
  /// must be balanced, because `JournalEntry` will not hold an entry that is not.
  Future<void> seedBilling(AppDatabase db,
      {List<Invoice> invoices = const <Invoice>[],
      List<CreditNote> notes = const <CreditNote>[]}) async {
    await DriftAccountRepository(db).saveAll(chart.all);
    await DriftCustomerRepository(db).save(
      Customer(id: 'cust-1', name: 'Himalayan Traders'),
    );
    final journal = DriftJournalRepository(db);
    final entryIds = <String>[
      for (final invoice in invoices) IssuedInvoice.journalEntryIdFor(invoice),
      for (final note in notes) IssuedCreditNote.journalEntryIdFor(note),
    ];
    for (final id in entryIds) {
      await journal.append(
        JournalEntry(
          id: id,
          date: DateTime(2026, 3, 5),
          description: 'Supporting entry for $id',
          lines: [
            JournalLine.debit(
                account: ChartOfAccounts.receivable, amount: rs(1)),
            JournalLine.credit(
                account: ChartOfAccounts.salesRevenue, amount: rs(1)),
          ],
        ),
      );
    }
  }

  Future<DriftJournalRepository> seedJournal(AppDatabase db) async {
    await DriftAccountRepository(db).saveAll(chart.all);
    final journal = DriftJournalRepository(db);
    for (final entry in journalForMarch()) {
      await journal.append(entry);
    }
    return journal;
  }

  group('BuildCashFlow', () {
    test('reports March cash, hand-computed above', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final journal = await seedJournal(db);

      final flow = await BuildCashFlow(fiscalYear: fiscalYear, journal: journal)
          .load(from: DateTime(2026, 3, 1), to: DateTime(2026, 3, 31));

      expect(flow.openingCash.minorUnits, 10000000);
      expect(flow.received.minorUnits, 2000000);
      expect(flow.paid.minorUnits, 500000);
      expect(flow.closingCash.minorUnits, 11500000);
      expect(flow.isNetInflow, isTrue);
    });

    test('closing cash equals opening plus what moved', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final journal = await seedJournal(db);

      final flow = await BuildCashFlow(fiscalYear: fiscalYear, journal: journal)
          .load(from: DateTime(2026, 3, 1), to: DateTime(2026, 3, 31));

      // The identity must hold exactly, in paisa, or the statement is unusable.
      expect(
        flow.closingCash.minorUnits,
        flow.openingCash.minorUnits +
            flow.received.minorUnits -
            flow.paid.minorUnits,
      );
    });

    test('a credit sale moves no cash and so is not in the statement',
        () async {
      // This is the whole point of a cash statement, and it is why it cannot be
      // derived from the profit and loss report: the sale is in the profit and
      // loss and must not be here.
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await DriftAccountRepository(db).saveAll(chart.all);
      final journal = DriftJournalRepository(db);
      await journal.append(
        JournalEntry(
          id: 'CR-1',
          date: DateTime(2026, 3, 5),
          description: 'Sale on credit',
          lines: [
            JournalLine.debit(
                account: ChartOfAccounts.receivable, amount: rs(20000)),
            JournalLine.credit(
                account: ChartOfAccounts.salesRevenue, amount: rs(20000)),
          ],
        ),
      );

      final flow = await BuildCashFlow(fiscalYear: fiscalYear, journal: journal)
          .load(from: DateTime(2026, 3, 1), to: DateTime(2026, 3, 31));

      expect(flow.received.minorUnits, 0);
      expect(flow.paid.minorUnits, 0);
      expect(flow.closingCash.isZero, isTrue);
    });

    test('paying an old invoice is cash in even with no new sale', () async {
      // The mirror of the case above. A receipt of an old debt is cash in this
      // month and no revenue this month.
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await DriftAccountRepository(db).saveAll(chart.all);
      final journal = DriftJournalRepository(db);
      await journal.append(
        JournalEntry(
          id: 'RC-1',
          date: DateTime(2026, 3, 9),
          description: 'Receipt of an earlier debt',
          lines: [
            JournalLine.debit(account: ChartOfAccounts.bank, amount: rs(7500)),
            JournalLine.credit(
                account: ChartOfAccounts.receivable, amount: rs(7500)),
          ],
        ),
      );

      final flow = await BuildCashFlow(fiscalYear: fiscalYear, journal: journal)
          .load(from: DateTime(2026, 3, 1), to: DateTime(2026, 3, 31));

      expect(flow.received.minorUnits, 750000);
    });

    test('the cash box counts as cash, not only the bank', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await DriftAccountRepository(db).saveAll(chart.all);
      final journal = DriftJournalRepository(db);
      await journal.append(
        JournalEntry(
          id: 'CB-1',
          date: DateTime(2026, 3, 3),
          description: 'Takings into the cash box',
          lines: [
            JournalLine.debit(account: ChartOfAccounts.cash, amount: rs(500)),
            JournalLine.credit(
                account: ChartOfAccounts.salesRevenue, amount: rs(500)),
          ],
        ),
      );

      final flow = await BuildCashFlow(fiscalYear: fiscalYear, journal: journal)
          .load(from: DateTime(2026, 3, 1), to: DateTime(2026, 3, 31));

      expect(flow.received.minorUnits, 50000);
    });

    test('an entry after the period is excluded from it', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final journal = await seedJournal(db);

      // 1,000 of rent was paid on 2 April. It is not March's cash out.
      final flow = await BuildCashFlow(fiscalYear: fiscalYear, journal: journal)
          .load(from: DateTime(2026, 3, 1), to: DateTime(2026, 3, 31));

      expect(flow.paid.minorUnits, 500000);
    });

    test('a whole-year view still puts the opening entry in opening cash',
        () async {
      // Without a date range, the period is the fiscal year. The opening-balance
      // entry that opens a year must read as **opening cash, not as cash received
      // during it** -- otherwise a year's statement claims income the business did
      // not receive, which is the most misleading way a cash statement can be
      // wrong.
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await DriftAccountRepository(db).saveAll(chart.all);
      final journal = DriftJournalRepository(db);
      // The opening entry, dated on the first day of FY 2082/83 (17 Jul 2025).
      await journal.append(
        JournalEntry(
          id: 'OB-FY',
          date: DateTime(2025, 7, 17),
          description: 'Opening balance for the year',
          lines: [
            JournalLine.debit(
                account: ChartOfAccounts.bank, amount: rs(100000)),
            JournalLine.credit(
                account: ChartOfAccounts.ownersEquity, amount: rs(100000)),
          ],
        ),
      );
      await journal.append(
        JournalEntry(
          id: 'SA-FY',
          date: DateTime(2026, 3, 5),
          description: 'Sale in the year',
          lines: [
            JournalLine.debit(account: ChartOfAccounts.bank, amount: rs(20000)),
            JournalLine.credit(
                account: ChartOfAccounts.salesRevenue, amount: rs(20000)),
          ],
        ),
      );

      final flow =
          await BuildCashFlow(fiscalYear: fiscalYear, journal: journal).load();

      // The opening entry sits exactly on the boundary, so it is opening cash.
      expect(flow.openingCash.minorUnits, 10000000);
      expect(flow.received.minorUnits, 2000000);
      expect(flow.closingCash.minorUnits, 12000000);
    });

    test('an empty book is zero, not an error', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      final flow = await BuildCashFlow(
        fiscalYear: fiscalYear,
        journal: DriftJournalRepository(db),
      ).load();

      expect(flow.openingCash.isZero, isTrue);
      expect(flow.received.isZero, isTrue);
      expect(flow.paid.isZero, isTrue);
      expect(flow.closingCash.isZero, isTrue);
      expect(flow.isNetInflow, isFalse);
    });
  });

  group('BuildSalesSummary', () {
    Future<void> seedSales(AppDatabase db) async {
      final keyboard = invoiceOn(DateTime(2026, 3, 5),
          lines: [line(2, 1000, description: 'Keyboard')]);
      final mouse = invoiceOn(DateTime(2026, 3, 20),
          id: 'INV-2', lines: [line(1, 500, description: 'Mouse')]);
      final credit = noteOn(DateTime(2026, 3, 25));

      await seedBilling(db,
          invoices: <Invoice>[keyboard, mouse], notes: <CreditNote>[credit]);

      final invoices = DriftInvoiceRepository(db);
      final notes = DriftCreditNoteRepository(db);

      await invoices.save(
        IssuedInvoice(
          invoice: keyboard,
          number: DocumentNumber.of(
              type: DocumentType.invoice, fiscalYear: fiscalYear, sequence: 1),
        ),
      );
      await invoices.save(
        IssuedInvoice(
          invoice: mouse,
          number: DocumentNumber.of(
              type: DocumentType.invoice, fiscalYear: fiscalYear, sequence: 2),
        ),
      );
      await notes.save(
        IssuedCreditNote(
          creditNote: credit,
          number: DocumentNumber.of(
              type: DocumentType.creditNote,
              fiscalYear: fiscalYear,
              sequence: 1),
        ),
      );
    }

    test('gross sales net of credits, hand-computed', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seedSales(db);

      final summary = await BuildSalesSummary(
        fiscalYear: fiscalYear,
        invoices: DriftInvoiceRepository(db),
        creditNotes: DriftCreditNoteRepository(db),
      ).load(from: DateTime(2026, 3, 1), to: DateTime(2026, 3, 31));

      // Gross: 2 x 1,000 keyboard = 2,000, plus 1 x 500 mouse = 2,500.
      // Credit note: 1 x 400 keyboard = 400 back.
      expect(summary.grossSales.minorUnits, 250000);
      expect(summary.credits.minorUnits, 40000);
      expect(summary.netSales.minorUnits, 210000);
    });

    test('net sales is gross less credits, in paisa exactly', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seedSales(db);

      final summary = await BuildSalesSummary(
        fiscalYear: fiscalYear,
        invoices: DriftInvoiceRepository(db),
        creditNotes: DriftCreditNoteRepository(db),
      ).load();

      expect(
        summary.netSales.minorUnits,
        summary.grossSales.minorUnits - summary.credits.minorUnits,
      );
    });

    test('breaks sales down by product, largest first', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seedSales(db);

      final summary = await BuildSalesSummary(
        fiscalYear: fiscalYear,
        invoices: DriftInvoiceRepository(db),
        creditNotes: DriftCreditNoteRepository(db),
      ).load();

      expect(summary.byProduct.first.label, 'Keyboard');
      expect(summary.byProduct.first.amount.minorUnits, 200000);
      expect(summary.byProduct.last.label, 'Mouse');
      expect(summary.byProduct.last.amount.minorUnits, 50000);
    });

    test('an invoice outside the period is excluded', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seedSales(db);

      // Through 10 March the mouse has not been sold yet.
      final summary = await BuildSalesSummary(
        fiscalYear: fiscalYear,
        invoices: DriftInvoiceRepository(db),
        creditNotes: DriftCreditNoteRepository(db),
      ).load(from: DateTime(2026, 3, 1), to: DateTime(2026, 3, 10));

      expect(summary.grossSales.minorUnits, 200000);
      expect(summary.credits.minorUnits, 0);
    });

    test('a business that sold nothing reports zero, not an error', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      final summary = await BuildSalesSummary(
        fiscalYear: fiscalYear,
        invoices: DriftInvoiceRepository(db),
        creditNotes: DriftCreditNoteRepository(db),
      ).load();

      expect(summary.grossSales.isZero, isTrue);
      expect(summary.netSales.isZero, isTrue);
      expect(summary.byProduct, isEmpty);
    });
  });

  group('BuildInventorySummary', () {
    Future<void> seedStock(AppDatabase db) async {
      final inventory = DriftInventoryRepository(db);
      final keyboard =
          Product(id: 'prod-keyboard', name: 'Keyboard', salePrice: rs(200));
      final mouse =
          Product(id: 'prod-mouse', name: 'Mouse', salePrice: rs(150));
      await inventory.saveProduct(keyboard);
      await inventory.saveProduct(mouse);
      await inventory.applyMovement(
        keyboard,
        InventoryMovement.receipt(
          id: 'MV-1',
          productId: 'prod-keyboard',
          date: DateTime(2026, 3, 1),
          reason: MovementReason.purchase,
          quantity: 20,
          value: rs(6000),
        ),
      );
      await inventory.applyMovement(
        keyboard,
        InventoryMovement.issue(
          id: 'MV-2',
          productId: 'prod-keyboard',
          date: DateTime(2026, 3, 10),
          reason: MovementReason.sale,
          quantity: 3,
          value: rs(1800),
        ),
      );
      await inventory.applyMovement(
        mouse,
        InventoryMovement.receipt(
          id: 'MV-3',
          productId: 'prod-mouse',
          date: DateTime(2026, 3, 5),
          reason: MovementReason.purchase,
          quantity: 10,
          value: rs(3000),
        ),
      );
    }

    test('values stock held from the movements, hand-computed', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seedStock(db);

      final summary = await BuildInventorySummary(
        fiscalYear: fiscalYear,
        inventory: DriftInventoryRepository(db),
      ).load();

      // Keyboard: 6,000 in less 1,800 out = 4,200.
      final keyboard = summary.lines.firstWhere((l) => l.label == 'Keyboard');
      expect(keyboard.amount.minorUnits, 420000);
      // Mouse: 3,000 in, nothing out.
      final mouse = summary.lines.firstWhere((l) => l.label == 'Mouse');
      expect(mouse.amount.minorUnits, 300000);
      expect(summary.totalValue.minorUnits, 720000);
    });

    test('agrees with the stock balance the application itself holds',
        () async {
      // The report and the balance must not disagree. This compares two
      // independent derivations of the same number.
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seedStock(db);
      final inventory = DriftInventoryRepository(db);

      final summary = await BuildInventorySummary(
        fiscalYear: fiscalYear,
        inventory: inventory,
      ).load();

      for (final product in await inventory.allProducts()) {
        final stock = await inventory.stockOf(product);
        final reported =
            summary.lines.firstWhere((l) => l.label == product.name);
        // Stock value comes from the same movement history the report reads.
        expect(reported.amount.minorUnits, stock.value.minorUnits,
            reason: 'the report and the stock balance must agree for '
                '${product.name}');
      }
    });

    test('lines are ordered largest first', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seedStock(db);

      final summary = await BuildInventorySummary(
        fiscalYear: fiscalYear,
        inventory: DriftInventoryRepository(db),
      ).load();

      expect(summary.lines.first.label, 'Keyboard');
    });

    test('a product removed from the catalogue still appears by its id',
        () async {
      // Movements are history and must not disappear when a product is deleted, or
      // the value of stock would silently vanish from the books.
      //
      // **A fake repository, because this state cannot be built through the real
      // one:** `applyMovement` requires the product to exist, so the real
      // repository cannot produce a movement whose product has been removed. This
      // is the one case in these tests that needs a stand-in, and it says so.
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      final summary = await BuildInventorySummary(
        fiscalYear: fiscalYear,
        inventory: _MovementsWithoutCatalogue(),
      ).load();

      expect(summary.lines.single.label, 'prod-legacy');
      expect(summary.totalValue.minorUnits, 100000);
    });

    test('an empty warehouse is zero', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      final summary = await BuildInventorySummary(
        fiscalYear: fiscalYear,
        inventory: DriftInventoryRepository(db),
      ).load();

      expect(summary.lines, isEmpty);
      expect(summary.totalValue.isZero, isTrue);
    });
  });

  group('BuildTaxSummary', () {
    Future<void> seedSales(AppDatabase db) async {
      final keyboard = invoiceOn(DateTime(2026, 3, 5),
          lines: [line(1, 10000, description: 'Keyboard')]);
      final credit = noteOn(DateTime(2026, 3, 20),
          lines: [line(1, 2000, description: 'Keyboard')]);

      await seedBilling(db,
          invoices: <Invoice>[keyboard], notes: <CreditNote>[credit]);

      final invoices = DriftInvoiceRepository(db);
      await invoices.save(
        IssuedInvoice(
          invoice: keyboard,
          number: DocumentNumber.of(
              type: DocumentType.invoice, fiscalYear: fiscalYear, sequence: 1),
        ),
      );
      await DriftCreditNoteRepository(db).save(
        IssuedCreditNote(
          creditNote: credit,
          number: DocumentNumber.of(
              type: DocumentType.creditNote,
              fiscalYear: fiscalYear,
              sequence: 1),
        ),
      );
    }

    test('computes VAT on the amount excluding VAT, hand-computed', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seedSales(db);

      final tax = await BuildTaxSummary(
        fiscalYear: fiscalYear,
        invoices: DriftInvoiceRepository(db),
        creditNotes: DriftCreditNoteRepository(db),
      ).load(from: DateTime(2026, 3, 1), to: DateTime(2026, 3, 31));

      // Sales 10,000, credit note 2,000, so 8,000 excluding VAT.
      expect(tax.taxableSales.minorUnits, 800000);
      // 8,000 at 13% is 1,040. Checked by hand, not by the code.
      expect(tax.outputVat.minorUnits, 104000);
      expect(tax.netVatPayable.minorUnits, 104000);
    });

    test('records the rate, so a return cannot be read without it', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seedSales(db);

      final tax = await BuildTaxSummary(
        fiscalYear: fiscalYear,
        invoices: DriftInvoiceRepository(db),
        creditNotes: DriftCreditNoteRepository(db),
      ).load();

      expect(tax.rateBasisPoints, TaxSummary.standardRateBasisPoints);
      expect(tax.rateBasisPoints, 1300);
    });

    test('input VAT is zero, because no purchases are recorded yet', () async {
      // **A real limitation, stated rather than papered over.** There are no
      // purchase records in the application, so there is nothing to compute input
      // VAT from. Returning zero is correct: claiming input VAT on purchases that
      // have never been recorded would be claiming credit for nothing.
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seedSales(db);

      final tax = await BuildTaxSummary(
        fiscalYear: fiscalYear,
        invoices: DriftInvoiceRepository(db),
        creditNotes: DriftCreditNoteRepository(db),
      ).load();

      expect(tax.taxablePurchases.isZero, isTrue);
      expect(tax.inputVat.isZero, isTrue);
    });

    test('output VAT follows invoices issued, not money received', () async {
      // A sale invoiced but unpaid creates output VAT. Waiting for the cash would
      // understate the liability, and the return would be wrong.
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final unpaid = invoiceOn(DateTime(2026, 3, 5),
          lines: [line(1, 10000, description: 'Keyboard')]);
      await seedBilling(db, invoices: <Invoice>[unpaid]);
      final invoices = DriftInvoiceRepository(db);
      await invoices.save(
        IssuedInvoice(
          invoice: unpaid,
          number: DocumentNumber.of(
              type: DocumentType.invoice, fiscalYear: fiscalYear, sequence: 1),
        ),
      );

      final tax = await BuildTaxSummary(
        fiscalYear: fiscalYear,
        invoices: invoices,
        creditNotes: DriftCreditNoteRepository(db),
      ).load();

      expect(tax.outputVat.minorUnits, 130000);
    });

    test('a credit note reduces the period it falls in', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final sold = invoiceOn(DateTime(2026, 3, 5),
          lines: [line(1, 10000, description: 'Keyboard')]);
      final aprilCredit = noteOn(DateTime(2026, 4, 2),
          lines: [line(1, 2000, description: 'Keyboard')]);
      await seedBilling(db,
          invoices: <Invoice>[sold], notes: <CreditNote>[aprilCredit]);

      final invoices = DriftInvoiceRepository(db);
      final notes = DriftCreditNoteRepository(db);
      await invoices.save(
        IssuedInvoice(
          invoice: sold,
          number: DocumentNumber.of(
              type: DocumentType.invoice, fiscalYear: fiscalYear, sequence: 1),
        ),
      );
      await notes.save(
        IssuedCreditNote(
          creditNote: aprilCredit,
          number: DocumentNumber.of(
              type: DocumentType.creditNote,
              fiscalYear: fiscalYear,
              sequence: 1),
        ),
      );

      // March, before the credit note: the full 10,000 is taxable.
      final march = await BuildTaxSummary(
        fiscalYear: fiscalYear,
        invoices: invoices,
        creditNotes: notes,
      ).load(from: DateTime(2026, 3, 1), to: DateTime(2026, 3, 31));
      expect(march.taxableSales.minorUnits, 1000000);

      // April, where the credit note lands but no sale does. The period is **2,000
      // in credit**: nothing was sold, 2,000 was credited back.
      //
      // The negative figure is the honest one. Clamping it to zero would say "no
      // VAT due" and hide a credit the business is entitled to carry forward, so
      // the report shows a negative position instead.
      final april = await BuildTaxSummary(
        fiscalYear: fiscalYear,
        invoices: invoices,
        creditNotes: notes,
      ).load(from: DateTime(2026, 4, 1), to: DateTime(2026, 4, 30));
      expect(april.taxableSales.minorUnits, -200000);
      expect(april.outputVat.minorUnits, 0);
      expect(april.credits.minorUnits, 200000);
    });

    test('net VAT payable is output less input', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seedSales(db);

      final tax = await BuildTaxSummary(
        fiscalYear: fiscalYear,
        invoices: DriftInvoiceRepository(db),
        creditNotes: DriftCreditNoteRepository(db),
      ).load();

      expect(
        tax.netVatPayable.minorUnits,
        tax.outputVat.minorUnits - tax.inputVat.minorUnits,
      );
    });

    test('rounds VAT to whole paisa, half up', () async {
      // 3,333 paisa at 13% is 433.29 paisa. The return cannot show a fraction of
      // a paisa, so it rounds to 433.
      const threeThousandThreeHundredThirtyThree = 3333;
      final tax = TaxSummary.from(
        taxableSales: <ReportTotal>[
          ReportTotal(
            label: 'Sales excluding VAT',
            amount: Money.minor(threeThousandThreeHundredThirtyThree, npr),
          ),
        ],
        taxablePurchases: const <ReportTotal>[],
        credits: const <ReportTotal>[],
        rateBasisPoints: 1300,
        currency: npr,
      );

      expect(tax.outputVat.minorUnits, 433);
    });

    test('a business that sold nothing owes no VAT', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      final tax = await BuildTaxSummary(
        fiscalYear: fiscalYear,
        invoices: DriftInvoiceRepository(db),
        creditNotes: DriftCreditNoteRepository(db),
      ).load();

      expect(tax.taxableSales.isZero, isTrue);
      expect(tax.outputVat.isZero, isTrue);
      expect(tax.netVatPayable.isZero, isTrue);
    });
  });
}
