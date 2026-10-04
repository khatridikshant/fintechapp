import 'package:financeapp/src/application/build_reports.dart';
import 'package:financeapp/src/application/issue_invoice.dart';
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
import 'package:financeapp/src/domain/inventory/product_category.dart';
import 'package:financeapp/src/domain/inventory/product_stock.dart';
import 'package:financeapp/src/domain/inventory/product_supplier.dart';
import 'package:financeapp/src/domain/reporting/financial_reports.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_credit_note_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_customer_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_inventory_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_document_number_sequence.dart';
import 'package:financeapp/src/infrastructure/database/drift_invoice_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_unit_of_work.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:drift/drift.dart' show Value;
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
  Future<void> saveCategory(ProductCategory category) async {}

  @override
  Future<List<ProductCategory>> allCategories() async =>
      const <ProductCategory>[];

  @override
  Future<void> saveDeclaredSuppliers(
    String productId,
    List<ProductSupplier> suppliers,
  ) async {}

  @override
  Future<List<ProductSupplier>> declaredSuppliersFor(String productId) async =>
      const <ProductSupplier>[];

  @override
  Future<List<ProductSupplier>> allDeclaredSuppliers() async =>
      const <ProductSupplier>[];

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

  group('BuildCategoryReport', () {
    Future<void> seedCategorizedStock(AppDatabase db) async {
      final inventory = DriftInventoryRepository(db);

      // Electronics is top level; Smartphones sits one level down, under
      // it; Spices is top level again.
      await inventory.saveCategory(ProductCategory(
        id: 'cat-elec',
        code: 'ELEC-01',
        name: 'Electronics',
      ));
      await inventory.saveCategory(ProductCategory(
        id: 'cat-phone',
        code: 'ELEC-01-PHONE',
        name: 'Smartphones',
        parentId: 'cat-elec',
      ));
      await inventory.saveCategory(ProductCategory(
        id: 'cat-spice',
        code: 'SPC-01',
        name: 'Spices',
      ));

      // The smartphone sits in the child category, so it must be reported
      // under Electronics. The notebook belongs to no category at all,
      // which is an ordinary state, not an incomplete one.
      final keyboard = Product(
        id: 'prod-keyboard',
        name: 'Keyboard',
        salePrice: rs(200),
        categoryId: 'cat-elec',
      );
      final phone = Product(
        id: 'prod-phone',
        name: 'Smartphone',
        salePrice: rs(1500),
        categoryId: 'cat-phone',
      );
      final pepper = Product(
        id: 'prod-pepper',
        name: 'Pepper',
        salePrice: rs(100),
        categoryId: 'cat-spice',
      );
      final notebook = Product(
        id: 'prod-notebook',
        name: 'Notebook',
        salePrice: rs(50),
      );
      await inventory.saveProduct(keyboard);
      await inventory.saveProduct(phone);
      await inventory.saveProduct(pepper);
      await inventory.saveProduct(notebook);

      // Stock value, hand-computed below.
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
        phone,
        InventoryMovement.receipt(
          id: 'MV-3',
          productId: 'prod-phone',
          date: DateTime(2026, 3, 5),
          reason: MovementReason.purchase,
          quantity: 10,
          value: rs(3000),
        ),
      );
      await inventory.applyMovement(
        pepper,
        InventoryMovement.receipt(
          id: 'MV-4',
          productId: 'prod-pepper',
          date: DateTime(2026, 3, 5),
          reason: MovementReason.purchase,
          quantity: 5,
          value: rs(1000),
        ),
      );
      await inventory.applyMovement(
        notebook,
        InventoryMovement.receipt(
          id: 'MV-5',
          productId: 'prod-notebook',
          date: DateTime(2026, 3, 5),
          reason: MovementReason.openingStock,
          quantity: 50,
          value: rs(500),
        ),
      );
    }

    test('groups stock by category, rolling a child up to its parent',
        () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seedCategorizedStock(db);

      final summary = await BuildCategoryReport(
        fiscalYear: fiscalYear,
        inventory: DriftInventoryRepository(db),
      ).load();

      // **Hand-computed.** Electronics holds the keyboard (6,000 in less
      // 1,800 out = 4,200) and the smartphone (3,000), the latter a
      // child category reported under its parent: 7,200.
      expect(
        summary.lines
            .firstWhere((ReportTotal l) => l.label == 'Electronics')
            .amount
            .minorUnits,
        720000,
      );
      // Spices holds the pepper: 1,000.
      expect(
        summary.lines
            .firstWhere((ReportTotal l) => l.label == 'Spices')
            .amount
            .minorUnits,
        100000,
      );
      // A product with no category is ordinary, so it is reported, not
      // hidden: the notebook's 500.
      expect(
        summary.lines
            .firstWhere((ReportTotal l) =>
                l.label == CategorySummary.uncategorizedLabel)
            .amount
            .minorUnits,
        50000,
      );
      expect(summary.totalValue.minorUnits, 870000);
    });

    test('agrees with the inventory report, which reads the same movements',
        () async {
      // Both reports read the same movement history, so the total stock
      // value they report must be identical. Two independent derivations
      // of the same number agreeing is worth more than either alone.
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seedCategorizedStock(db);
      final inventory = DriftInventoryRepository(db);

      final byCategory = await BuildCategoryReport(
        fiscalYear: fiscalYear,
        inventory: inventory,
      ).load();
      final byProduct = await BuildInventorySummary(
        fiscalYear: fiscalYear,
        inventory: inventory,
      ).load();

      expect(
        byCategory.totalValue.minorUnits,
        byProduct.totalValue.minorUnits,
      );
    });

    test('lines are ordered largest first', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seedCategorizedStock(db);

      final summary = await BuildCategoryReport(
        fiscalYear: fiscalYear,
        inventory: DriftInventoryRepository(db),
      ).load();

      expect(summary.lines.first.label, 'Electronics');
    });

    test('saving a category two levels down is refused at write time',
        () async {
      // **The case ADR 013 exists for.** Android Handsets under
      // Smartphones under Electronics is two levels down. `saveCategory`
      // refuses it before anything is written, so such a category never
      // reaches the book.
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final inventory = DriftInventoryRepository(db);
      await inventory.saveCategory(ProductCategory(
        id: 'cat-elec',
        code: 'ELEC-01',
        name: 'Electronics',
      ));
      await inventory.saveCategory(ProductCategory(
        id: 'cat-phone',
        code: 'ELEC-01-PHONE',
        name: 'Smartphones',
        parentId: 'cat-elec',
      ));

      await expectLater(
        inventory.saveCategory(ProductCategory(
          id: 'cat-android',
          code: 'ELEC-01-PHONE-ANDROID',
          name: 'Android Handsets',
          parentId: 'cat-phone',
        )),
        throwsA(isA<CategoryDepthException>()),
      );

      // And nothing was written: the refused category is not in the book.
      expect(
        (await inventory.allCategories())
            .where((ProductCategory c) => c.id == 'cat-android'),
        isEmpty,
      );
    });

    test('a category two levels down is refused by the report, not flattened',
        () async {
      // **Written straight into the database**, because `saveCategory`
      // refuses this tree, so the only way a report can ever see it is a
      // row that did not go through the domain -- exactly the corruption
      // the report exists to catch.
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await db.into(db.productCategories).insert(
            ProductCategoriesCompanion.insert(
              id: 'cat-elec',
              code: 'ELEC-01',
              name: 'Electronics',
            ),
          );
      await db.into(db.productCategories).insert(
            ProductCategoriesCompanion.insert(
              id: 'cat-phone',
              code: 'ELEC-01-PHONE',
              name: 'Smartphones',
              parentId: const Value('cat-elec'),
            ),
          );
      await db.into(db.productCategories).insert(
            ProductCategoriesCompanion.insert(
              id: 'cat-android',
              code: 'ELEC-01-PHONE-ANDROID',
              name: 'Android Handsets',
              parentId: const Value('cat-phone'),
            ),
          );

      await expectLater(
        BuildCategoryReport(
          fiscalYear: fiscalYear,
          inventory: DriftInventoryRepository(db),
        ).load(),
        throwsA(isA<CategoryDepthException>()),
      );
    });

    test('a category whose parent does not exist is refused', () async {
      // A dangling parent would otherwise be flattened to the root, which
      // is a different answer and not one anybody chose.
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await db.into(db.productCategories).insert(
            ProductCategoriesCompanion.insert(
              id: 'cat-orphan',
              code: 'ELEC-99',
              name: 'Orphan',
              parentId: const Value('cat-ghost'),
            ),
          );

      await expectLater(
        BuildCategoryReport(
          fiscalYear: fiscalYear,
          inventory: DriftInventoryRepository(db),
        ).load(),
        throwsA(isA<CategoryDepthException>()),
      );
    });

    test('a business with no categories reports zero, not an error', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      final summary = await BuildCategoryReport(
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

    test('output VAT is what each invoice actually charged', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      // Built through the real posting path, so the VAT in the ledger is the VAT
      // `IssueInvoice` would really have charged. `seedBilling` creates the
      // customer, the chart, and the matching journal entries.
      //
      // Two invoices at **different rates**. The old report added the subtotals
      // together and applied 13% once to the total, so the zero-rated invoice was
      // charged 13% it never bore.
      final standard = Invoice(
        id: 'INV-A',
        issueDate: DateTime(2026, 3, 5),
        customerId: 'cust-1',
        vatRateBasisPoints: 1300,
        lines: <InvoiceLine>[line(1, 10000, description: 'Standard rated')],
      );
      final zeroRated = Invoice(
        id: 'INV-B',
        issueDate: DateTime(2026, 3, 6),
        customerId: 'cust-1',
        vatRateBasisPoints: 0,
        lines: <InvoiceLine>[line(1, 10000, description: 'Zero rated')],
      );
      await seedBilling(db, invoices: <Invoice>[standard, zeroRated]);
      final invoices = DriftInvoiceRepository(db);

      await invoices.save(IssuedInvoice(
        invoice: standard,
        number: DocumentNumber.of(
            type: DocumentType.invoice, fiscalYear: fiscalYear, sequence: 1),
      ));
      await invoices.save(IssuedInvoice(
        invoice: zeroRated,
        number: DocumentNumber.of(
            type: DocumentType.invoice, fiscalYear: fiscalYear, sequence: 2),
      ));

      final tax = await BuildTaxSummary(
        fiscalYear: fiscalYear,
        invoices: invoices,
        creditNotes: DriftCreditNoteRepository(db),
      ).load();

      // 10,000 at 13% is 1,300. 10,000 at 0% is nothing. Total 1,300.
      expect(tax.outputVat.minorUnits, 130000,
          reason: 'the zero-rated invoice must contribute no VAT');
      expect(tax.taxableSales.minorUnits, 2000000,
          reason: 'both invoices count towards taxable sales');
    });

    test('the return agrees with the VAT posted to the ledger', () async {
      // **The property that matters: the return equals the books.**
      //
      // Issued through the real `IssueInvoice`, so the VAT credited to account 2020
      // is the VAT the business actually charged. The report is then compared with
      // that ledger balance -- not with a second re-derivation, which would only
      // prove the code agrees with itself.
      //
      // **Three five-paisa invoices**, chosen because per-invoice rounding differs
      // from rounding the aggregate:
      //
      //   per invoice: 5 x 13% = 0.65 -> 1 paisa, so 3 x 1 = **3**
      //   aggregate:  15 x 13% = 1.95 -> **2**
      //
      // The old report returned 2. One paisa, which was my first choice, does not
      // work: 13% of 1 paisa is 0.13, which rounds to nothing.
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seedBilling(db);

      final invoiceRepo = DriftInvoiceRepository(db);
      final useCase = IssueInvoice(
        fiscalYear: fiscalYear,
        customers: DriftCustomerRepository(db),
        numbers: DriftDocumentNumberSequence(db),
        journal: DriftJournalRepository(db),
        invoices: invoiceRepo,
        unitOfWork: DriftUnitOfWork(db),
      );

      for (var i = 1; i <= 3; i++) {
        final issued = await useCase(Invoice(
          id: 'INV-R$i',
          issueDate: DateTime(2026, 3, i),
          customerId: 'cust-1',
          vatRateBasisPoints: 1300,
          lines: <InvoiceLine>[
            InvoiceLine(
              description: 'item',
              quantity: 1,
              unitPrice: Money.minor(5, npr),
            ),
          ],
        ));
        expect(issued, isA<InvoiceIssued>(),
            reason:
                'the invoice must be accepted for this test to mean anything');
      }

      final vatPosted = (await DriftJournalRepository(db).all())
          .expand((JournalEntry e) => e.lines)
          .where((JournalLine l) => l.account == ChartOfAccounts.vatPayable)
          .fold<int>(
            0,
            (int sum, JournalLine l) => sum + l.amount.minorUnits,
          );

      final tax = await BuildTaxSummary(
        fiscalYear: fiscalYear,
        invoices: invoiceRepo,
        creditNotes: DriftCreditNoteRepository(db),
      ).load();

      // **Hand-computed:** 3 x (5 paisa of sales -> 0.65 -> 1 paisa of VAT) = 3.
      expect(tax.outputVat.minorUnits, 3,
          reason: 'per-invoice rounding, not rounding the aggregate');

      expect(
        tax.outputVat.minorUnits,
        vatPosted,
        reason:
            'the return must equal the VAT posted to 2020, or it cannot be filed',
      );
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
      // in credit**, and its VAT is a credit too: 2,000 at 13% is 260, reversed.
      //
      // Both negatives are the honest ones. Clamping either to zero would say "no
      // VAT due" and hide a credit the business is entitled to carry forward. This
      // is the same principle already asserted on `taxableSales` below, applied to
      // the tax — and the old implementation clamped exactly here, because its
      // `_vatOn` helper returned 0 for any non-positive input.
      final april = await BuildTaxSummary(
        fiscalYear: fiscalYear,
        invoices: invoices,
        creditNotes: notes,
      ).load(from: DateTime(2026, 4, 1), to: DateTime(2026, 4, 30));
      expect(april.taxableSales.minorUnits, -200000);
      expect(april.outputVat.minorUnits, -26000,
          reason: 'the credit note reversed the VAT it had charged');
      expect(april.netVatPayable.minorUnits, -26000,
          reason: 'with no input VAT, a credit position is a refund due');
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
      // **Rewritten, deliberately.**
      //
      // This used to assert that 3,333 paisa of sales at 13% rounds to 433 -- which
      // tested the aggregate computation that was itself the defect. Rounding a
      // rate to whole paisa is now `Money.applyBasisPoints`' job, tested there,
      // and it happens **per document** because that is where it is applied.
      //
      // What matters here is the opposite property: the return reports the figures
      // it is handed, without recomputing anything. 3333 paisa of sales with 100
      // paisa of VAT charged is a legitimate position -- a single zero-rated or
      // reduced-rated document -- and the return must show 100, not a figure
      // derived from the sales total.
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
        outputVatCharged: Money.minor(100, npr),
        inputVatClaimable: Money.minor(0, npr),
        standardRateBasisPoints: 1300,
        currency: npr,
      );

      expect(tax.outputVat.minorUnits, 100,
          reason:
              'the return must show the VAT the documents charged, not a figure '
              're-derived from the sales total');
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
