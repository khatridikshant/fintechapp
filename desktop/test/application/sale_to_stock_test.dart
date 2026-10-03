import 'package:financeapp/src/application/issue_invoice.dart';
import 'package:financeapp/src/application/issue_purchase.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/billing/customer.dart';
import 'package:financeapp/src/domain/billing/invoice.dart';
import 'package:financeapp/src/domain/billing/invoice_line.dart';
import 'package:financeapp/src/domain/billing/purchase.dart';
import 'package:financeapp/src/domain/billing/purchase_line.dart';
import 'package:financeapp/src/domain/billing/supplier.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/inventory/product.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_customer_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_document_number_sequence.dart';
import 'package:financeapp/src/infrastructure/database/drift_inventory_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_invoice_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_purchase_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_supplier_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_unit_of_work.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';

const chart = ChartOfAccounts();
final year = const NepaliFiscalCalendar().forBsYear(2082);

void main() {
  // **The accounting, worked by hand first.**
  //
  // Receive 10 chairs at Rs 100.00 each, Rs 1,000.00 total.
  //   Dr 1040 Inventory   1,000,000 paisa
  //     Cr 2010 Payable     1,000,000
  //
  // Then sell 4 of them. The running cost per unit is 1,000,000 / 10 = 100,000
  // paisa, so 4 units cost 4 x 100,000 = 400,000 paisa (Rs 4,000.00).
  //
  //   Dr 1030 Receivable   800,000   (4 x Rs 200.00, no VAT)
  //     Cr 4010 Sales        800,000
  //   Dr 5010 Cost of Sales 400,000   <- DERIVED, not typed
  //     Cr 1040 Inventory    400,000
  //
  // Debits 800,000 + 400,000 = 1,200,000; credits 800,000 + 400,000 = 1,200,000.
  //
  // Inventory now holds 6 units worth 600,000, and the inventory account balance
  // is 1,000,000 - 400,000 = 600,000. **The account and the stock agree exactly**,
  // which is the property ADR 004 exists to preserve.

  late AppDatabase db;
  late DriftInventoryRepository inventory;
  late DriftInvoiceRepository invoices;
  late DriftPurchaseRepository purchases;
  late DriftJournalRepository journal;
  late IssueInvoice issue;

  final saleDate = DateTime(2026, 2, 1);

  setUp(() async {
    db = openInMemoryDatabase();
    inventory = DriftInventoryRepository(db);
    invoices = DriftInvoiceRepository(db);
    purchases = DriftPurchaseRepository(db);
    journal = DriftJournalRepository(db);

    await DriftAccountRepository(db).saveAll(chart.all);
    await DriftCustomerRepository(db)
        .save(Customer(id: 'cust-1', name: 'Himalayan Traders'));
    await DriftSupplierRepository(db)
        .save(Supplier(id: 'sup-1', name: 'Kamala Traders', pan: '601234567'));
    await inventory.saveProduct(
      Product(id: 'p-1', name: 'Chair', salePrice: Money.minor(200000, 'NPR')),
    );

    issue = IssueInvoice(
      fiscalYear: year,
      customers: DriftCustomerRepository(db),
      numbers: DriftDocumentNumberSequence(db),
      journal: journal,
      invoices: invoices,
      unitOfWork: DriftUnitOfWork(db),
      inventory: inventory,
    );
  });

  tearDown(() => db.close());

  /// Receive 10 chairs at Rs 100.00 each.
  Future<void> receiveStock() async {
    final outcome = await IssuePurchase(
      fiscalYear: year,
      suppliers: DriftSupplierRepository(db),
      purchases: purchases,
      numbers: DriftDocumentNumberSequence(db),
      journal: journal,
      unitOfWork: DriftUnitOfWork(db),
      inventory: inventory,
    )(
      Purchase(
        id: 'P-1',
        issueDate: DateTime(2026, 1, 10),
        supplierId: 'sup-1',
        lines: [
          PurchaseLine(
            description: 'Chair',
            quantity: 10,
            unitPrice: Money.minor(100000, 'NPR'),
            productId: 'p-1',
          ),
        ],
      ),
    );
    expect(outcome, isA<PurchaseIssued>());
  }

  Invoice buildInvoice({
    String id = 'INV-1',
    int quantity = 4,
    int unitPricePaisa = 200000,
    String? productId = 'p-1',
    int vatRateBasisPoints = 0,
    DateTime? when,
  }) =>
      Invoice(
        id: id,
        issueDate: when ?? saleDate,
        customerId: 'cust-1',
        vatRateBasisPoints: vatRateBasisPoints,
        lines: [
          InvoiceLine(
            description: 'Chair',
            quantity: quantity,
            unitPrice: Money.minor(unitPricePaisa, 'NPR'),
            productId: productId,
          ),
        ],
      );

  JournalLine? lineFor(JournalEntry entry, String accountId) {
    for (final line in entry.lines) {
      if (line.account.id == accountId) return line;
    }
    return null;
  }

  /// The balance of one account across every posted entry.
  Future<int> accountBalance(String accountId) async {
    var balance = 0;
    for (final entry in await journal.all()) {
      for (final line in entry.lines) {
        if (line.account.id != accountId) continue;
        balance += line.isDebit ? line.amount.minorUnits : -line.amount.minorUnits;
      }
    }
    return balance;
  }

  group('Selling stock', () {
    setUp(receiveStock);

    test('issues the stock and posts the derived cost of sales', () async {
      // **The assertion that matters.** 400,000 is 4 x (1,000,000 / 10), read
      // from the running stock value -- not anything the test supplied.
      final issued = await issue(buildInvoice()) as InvoiceIssued;

      expect(
        issued.costOfGoodsSold!.minorUnits,
        400000,
        reason: '4 units at the running cost of Rs 100.00 each',
      );

      final cogs = lineFor(
        issued.journalEntry,
        ChartOfAccounts.costOfGoodsSold.id,
      )!;
      expect(cogs.isDebit, isTrue);
      expect(cogs.amount.minorUnits, 400000);

      final creditedInventory =
          lineFor(issued.journalEntry, ChartOfAccounts.inventory.id)!;
      expect(creditedInventory.isCredit, isTrue);
      expect(creditedInventory.amount.minorUnits, 400000);
    });

    test('the entry still balances with the cost pair added', () async {
      // 800,000 receivable + 400,000 cost = 1,200,000; credits the same.
      final issued = await issue(buildInvoice()) as InvoiceIssued;

      expect(issued.journalEntry.totalDebits.minorUnits, 1200000);
      expect(issued.journalEntry.totalCredits.minorUnits, 1200000);
    });

    test('the stock and the inventory account agree exactly', () async {
      // **The property ADR 004 exists to preserve.** After the sale, the trial
      // balance balance of 1040 must equal the derived stock value. If it does
      // not, one of the two is wrong and the books no longer reconcile.
      await issue(buildInvoice());

      final stock = await inventory.stockOf(
        Product(id: 'p-1', name: 'Chair', salePrice: Money.minor(200000, 'NPR')),
      );

      expect(stock.quantity, 6);
      expect(stock.value.minorUnits, 600000);
      expect(
        await accountBalance(ChartOfAccounts.inventory.id),
        stock.value.minorUnits,
        reason: 'the inventory account must equal the derived stock value',
      );
    });

    test('the movement is recorded against the entry', () async {
      await issue(buildInvoice());

      final movements = await inventory.movementsFor('p-1');
      expect(movements.length, 2, reason: 'the receipt and the sale');
      expect(movements.last.value.minorUnits, -400000);

      final row = await (db.select(db.inventoryMovements)).get();
      final sale = row.firstWhere((r) => r.id.startsWith('MV-SALE'));
      expect(sale.journalEntryId, 'JE-INV-INV-1');
    });

    test('a sale leaving no stock posts no cost of sales line', () async {
      // A zero amount must be **omitted**, not posted: a journal line carries a
      // positive amount on one side.
      final issued = await issue(buildInvoice()) as InvoiceIssued;

      expect(issued.movedStock, isTrue);
      expect(lineFor(issued.journalEntry, ChartOfAccounts.inventory.id), isNotNull);
    });
  });

  group('A sale of something that is not catalogue stock', () {
    setUp(receiveStock);

    test('a line with no product moves nothing and posts no cost', () async {
      // **Normal, not an error.** A service, a repair, or an on-site job has no
      // stock behind it, and must be recordable.
      final issued =
          await issue(buildInvoice(productId: null)) as InvoiceIssued;

      expect(issued.movedStock, isFalse);
      expect(issued.costOfGoodsSold, isNull);
      expect(
        lineFor(issued.journalEntry, ChartOfAccounts.costOfGoodsSold.id),
        isNull,
      );
      expect(
        lineFor(issued.journalEntry, ChartOfAccounts.inventory.id),
        isNull,
      );

      // The sale is still recorded.
      expect(issued.number.value, 'INV-2082-83-0001');
      expect(issued.journalEntry.totalDebits.minorUnits, 800000);
    });

    test('the stock did not move', () async {
      await issue(buildInvoice(productId: null));

      final stock = await inventory.stockOf(
        Product(id: 'p-1', name: 'Chair', salePrice: Money.minor(200000, 'NPR')),
      );
      expect(stock.quantity, 10);
    });
  });

  group('Refusals', () {
    setUp(receiveStock);

    test('a product that does not exist is refused, with its own reason', () async {
      final outcome = await issue(
        buildInvoice(productId: 'p-does-not-exist'),
      );

      expect(outcome, isA<InvoiceRejected>());
      expect(
        (outcome as InvoiceRejected).reason,
        IssueRejectionReason.unknownProduct,
      );
    });

    test('selling more than is on hand is refused', () async {
      // **Refused, not allowed to go negative.** Recording it would post a cost
      // derived from a negative holding and leave inventory and the physical
      // count irreconcilable.
      final outcome = await issue(buildInvoice(quantity: 11));

      expect(outcome, isA<InvoiceRejected>());
      expect(
        (outcome as InvoiceRejected).reason,
        IssueRejectionReason.insufficientStock,
      );
    });

    test('a refused sale consumes no serial', () async {
      // **What keeps invoice numbering gap-free.** The stock plan is built before
      // the serial is allocated, so a refusal burns nothing.
      await issue(buildInvoice(id: 'INV-1', quantity: 11));

      final issued = await issue(buildInvoice(id: 'INV-2')) as InvoiceIssued;
      expect(issued.number.value, 'INV-2082-83-0001');
    });

    test('a refused sale writes no entry and moves no stock', () async {
      await issue(buildInvoice(id: 'INV-1', quantity: 11));

      // Only the purchase entry exists.
      expect(await journal.all(), hasLength(1));
      expect(await inventory.movementsFor('p-1'), hasLength(1));

      final stock = await inventory.stockOf(
        Product(id: 'p-1', name: 'Chair', salePrice: Money.minor(200000, 'NPR')),
      );
      expect(stock.quantity, 10);
    });
  });

  group('The cost is derived from the running average, not the sale price', () {
    setUp(receiveStock);

    test('a sale price far above cost still posts the cost, not the price',
        () async {
      // **The distinction the whole feature exists for.** Selling at Rs 2,000.00
      // goods that cost Rs 100.00 must post Rs 400.00 of cost, not Rs 8,000.00.
      // A COGS figure taken from the sale price would turn gross margin into cost
      // and make the profit and loss report report nothing at all.
      final issued =
          await issue(buildInvoice(unitPricePaisa: 2000000)) as InvoiceIssued;

      expect(issued.invoice.subtotal.minorUnits, 8000000);
      expect(issued.costOfGoodsSold!.minorUnits, 400000);
    });

    test('selling the whole holding leaves exactly zero', () async {
      // `valueOfIssue` clamps a full issue to the exact holding, so a sell-out
      // cannot leave a few stray paisa in both the stock and the account.
      final issued = await issue(buildInvoice(quantity: 10)) as InvoiceIssued;

      expect(issued.costOfGoodsSold!.minorUnits, 1000000);

      final stock = await inventory.stockOf(
        Product(id: 'p-1', name: 'Chair', salePrice: Money.minor(200000, 'NPR')),
      );
      expect(stock.quantity, 0);
      expect(stock.value.minorUnits, 0);
      expect(await accountBalance(ChartOfAccounts.inventory.id), 0);
    });

    test('a later purchase changes the average, and so the next cost', () async {
      // Receive 10 more at Rs 200.00. The holding becomes 20 units worth
      // 1,000,000 + 2,000,000 = 3,000,000, so the average is 150,000 and four
      // units cost 600,000 -- not 400,000.
      await IssuePurchase(
        fiscalYear: year,
        suppliers: DriftSupplierRepository(db),
        purchases: purchases,
        numbers: DriftDocumentNumberSequence(db),
        journal: journal,
        unitOfWork: DriftUnitOfWork(db),
        inventory: inventory,
      )(
        Purchase(
          id: 'P-2',
          issueDate: DateTime(2026, 1, 20),
          supplierId: 'sup-1',
          lines: [
            PurchaseLine(
              description: 'Chair',
              quantity: 10,
              unitPrice: Money.minor(200000, 'NPR'),
              productId: 'p-1',
            ),
          ],
        ),
      );

      final issued = await issue(buildInvoice()) as InvoiceIssued;
      expect(issued.costOfGoodsSold!.minorUnits, 600000);
    });
  });

  group('With VAT', () {
    setUp(receiveStock);

    test('the cost pair is added alongside the VAT line', () async {
      // Dr Receivable 904,000 / Cr Revenue 800,000 / Cr VAT 104,000
      // Dr COGS 400,000 / Cr Inventory 400,000
      // Debits 1,304,000; credits 1,304,000.
      //
      // **13% of 800,000 is 104,000.** An earlier draft of this test said 120,000,
      // which is 13% of 923,077 -- a number that appears nowhere on the invoice.
      // Writing the arithmetic out by hand is what caught it; the code was right.
      final issued = await issue(
        buildInvoice(vatRateBasisPoints: 1300),
      ) as InvoiceIssued;

      expect(issued.invoice.subtotal.minorUnits, 800000);
      expect(issued.invoice.vat.minorUnits, 104000);
      expect(issued.invoice.total.minorUnits, 904000);
      expect(issued.costOfGoodsSold!.minorUnits, 400000);
      expect(issued.journalEntry.totalDebits.minorUnits, 1304000);
      expect(issued.journalEntry.totalCredits.minorUnits, 1304000);
    });
  });
}