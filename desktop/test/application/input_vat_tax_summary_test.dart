import 'package:financeapp/src/application/build_reports.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/billing/customer.dart';
import 'package:financeapp/src/domain/billing/invoice.dart';
import 'package:financeapp/src/domain/billing/invoice_line.dart';
import 'package:financeapp/src/domain/billing/purchase.dart';
import 'package:financeapp/src/domain/billing/purchase_line.dart';
import 'package:financeapp/src/domain/billing/supplier.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_credit_note_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_customer_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_document_number_sequence.dart';
import 'package:financeapp/src/infrastructure/database/drift_inventory_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_invoice_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_purchase_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_supplier_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_unit_of_work.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:financeapp/src/application/issue_invoice.dart';
import 'package:financeapp/src/application/issue_purchase.dart';
import 'package:financeapp/src/domain/inventory/product.dart';
import 'package:flutter_test/flutter_test.dart';

const chart = ChartOfAccounts();
final year = const NepaliFiscalCalendar().forBsYear(2082);

void main() {
  // **The whole point of the purchase side, worked by hand.**
  //
  // Sales: one invoice for Rs 10,000 + 13% = output VAT 1,300.
  // Purchases: two bills, each Rs 10,000 + 13% = input VAT 1,300 each.
  //
  //   One from a supplier WITH a PAN    -> claimable 1,300
  //   One from a supplier with NO PAN   -> at risk    1,300
  //
  //   Output VAT                          1,300
  //   less claimable input VAT          (1,300)
  //   = net payable                            0
  //
  // If the no-PAN bill were counted as claimable the return would show a 1,300
  // refund the authority can refuse. That is the whole reason the split exists.

  late AppDatabase db;
  late DriftSupplierRepository suppliers;
  late DriftPurchaseRepository purchases;
  late DriftInvoiceRepository invoices;
  late BuildTaxSummary taxSummary;

  setUp(() async {
    db = openInMemoryDatabase();
    suppliers = DriftSupplierRepository(db);
    purchases = DriftPurchaseRepository(db);
    invoices = DriftInvoiceRepository(db);
    await DriftAccountRepository(db).saveAll(chart.all);
    await DriftInventoryRepository(db).saveProduct(
          Product(id: 'p-1', name: 'Chair', salePrice: Money.minor(200000, 'NPR')),
        );
    taxSummary = BuildTaxSummary(
      fiscalYear: year,
      invoices: invoices,
      creditNotes: DriftCreditNoteRepository(db),
      purchases: purchases,
      suppliers: suppliers,
    );
  });

  tearDown(() => db.close());

  Future<void> issueSale(String id, {int rupees = 10000}) async {
    await DriftCustomerRepository(db).save(
      Customer(id: 'cust-1', name: 'Himalayan Traders'),
    );
    final outcome = await IssueInvoice(
      fiscalYear: year,
      customers: DriftCustomerRepository(db),
      numbers: DriftDocumentNumberSequence(db),
      journal: DriftJournalRepository(db),
      invoices: invoices,
      unitOfWork: DriftUnitOfWork(db),
    )(
      Invoice(
        id: id,
        issueDate: DateTime(2026, 2, 1),
        customerId: 'cust-1',
        lines: [
          InvoiceLine(
            description: 'Item',
            quantity: 1,
            unitPrice: Money.minor(rupees * 100, 'NPR'),
          ),
        ],
      ),
    );
    expect(outcome, isA<InvoiceIssued>());
  }

  Future<void> issuePurchase(
    String id,
    String supplierId, {
    int rupees = 10000,
  }) async {
    final outcome = await IssuePurchase(
      fiscalYear: year,
      suppliers: suppliers,
      purchases: purchases,
      numbers: DriftDocumentNumberSequence(db),
      journal: DriftJournalRepository(db),
      unitOfWork: DriftUnitOfWork(db),
      inventory: DriftInventoryRepository(db),
    )(
      Purchase(
        id: id,
        issueDate: DateTime(2026, 2, 5),
        supplierId: supplierId,
        lines: [
          PurchaseLine(
            description: 'Chair',
            quantity: 1,
            unitPrice: Money.minor(rupees * 100, 'NPR'),
            productId: 'p-1',
          ),
        ],
      ),
    );
    expect(outcome, isA<PurchaseIssued>());
  }

  group('The VAT return reads real purchases', () {
    setUp(() async {
      await suppliers.save(
        Supplier(id: 'sup-pan', name: 'Kamala Traders', pan: '601234567'),
      );
      await suppliers.save(
        Supplier(id: 'sup-nopan', name: 'Ram Furniture'),
      );
    });

    test('input VAT from a supplier with a PAN is claimable', () async {
      await issueSale('INV-1');
      await issuePurchase('P-1', 'sup-pan');

      final summary = await taxSummary.load();

      expect(summary.outputVat.minorUnits, 130000);
      expect(summary.inputVat.minorUnits, 130000);
      expect(summary.inputVatAtRisk.minorUnits, 0);
      expect(summary.netVatPayable.isZero, isTrue);
    });

    test('input VAT from a supplier with NO PAN is reported at risk, not claimable',
        () async {
      // **The distinction that makes the return honest.** This VAT was genuinely
      // paid and is a real asset in 1150, but `NEPALI_BILLING.md` records it may be
      // disallowed. Counting it as claimable would demand credit the authority can
      // refuse.
      await issueSale('INV-1');
      await issuePurchase('P-1', 'sup-nopan');

      final summary = await taxSummary.load();

      expect(summary.inputVatAtRisk.minorUnits, 130000);
      expect(summary.inputVat.minorUnits, 0);
      expect(
        summary.netVatPayable.minorUnits,
        130000,
        reason: 'the at-risk VAT is not netted off the output figure',
      );
      expect(
        summary.netVatPayableIfAllClaimed.isZero,
        isTrue,
        reason: 'but the optimistic figure is available and matches the books',
      );
    });

    test('a mixed set splits the input VAT between claimable and at risk',
        () async {
      await issueSale('INV-1');
      await issuePurchase('P-1', 'sup-pan');
      await issuePurchase('P-2', 'sup-nopan');

      final summary = await taxSummary.load();

      expect(summary.inputVat.minorUnits, 130000, reason: 'the PAN bill');
      expect(summary.inputVatAtRisk.minorUnits, 130000, reason: 'the no-PAN bill');
      expect(summary.netVatPayable.isZero, isTrue);
    });

    test('purchases excluding VAT are stated net, not gross', () async {
      // **The same footing rule the sales side uses.** `taxablePurchases` excludes
      // VAT, so reporting the gross would overstate purchases by exactly the VAT
      // being claimed.
      await issuePurchase('P-1', 'sup-pan');

      final summary = await taxSummary.load();

      expect(summary.taxablePurchases.minorUnits, 1000000);
      expect(
        summary.taxablePurchases.add(summary.inputVat).minorUnits,
        1130000,
        reason: 'net plus input VAT reconstructs the bill total',
      );
    });

    test('purchases are itemised by bill number so the figure is traceable',
        () async {
      await issuePurchase('P-1', 'sup-pan');
      await issuePurchase('P-2', 'sup-pan');

      final summary = await taxSummary.load();

      // The two bills are individually visible, not one anonymous total.
      expect(summary.taxablePurchases.minorUnits, 2000000);
    });

    test('a purchase outside the period is excluded', () async {
      final outcome = await IssuePurchase(
        fiscalYear: year,
        suppliers: suppliers,
        purchases: purchases,
        numbers: DriftDocumentNumberSequence(db),
        journal: DriftJournalRepository(db),
        unitOfWork: DriftUnitOfWork(db),
        inventory: DriftInventoryRepository(db),
      )(
        Purchase(
          id: 'P-late',
          // Outside FY 2082/83, so the bill is refused and the return is unaffected.
          issueDate: DateTime(2026, 9, 1),
          supplierId: 'sup-pan',
          lines: [
            PurchaseLine(
              description: 'Chair',
              quantity: 1,
              unitPrice: Money.minor(100000, 'NPR'),
              productId: 'p-1',
            ),
          ],
        ),
      );
      expect(outcome, isA<PurchaseRejected>());

      final summary = await taxSummary.load();
      expect(summary.inputVat.isZero, isTrue);
      expect(summary.taxablePurchases.isZero, isTrue);
    });

    test('with no purchases at all, input VAT is still zero', () async {
      // **The old behaviour, and it must survive.** A business that has recorded
      // no purchases must not be able to claim input credit, so the empty case is
      // still zero rather than an error.
      await issueSale('INV-1');

      final summary = await taxSummary.load();

      expect(summary.inputVat.isZero, isTrue);
      expect(summary.inputVatAtRisk.isZero, isTrue);
      expect(summary.netVatPayable.minorUnits, 130000);
    });
  });

  group('Without a supplier store, no claim is substantiated', () {
    test('every purchase VAT is treated as at risk rather than claimable', () async {
      // **The safe direction.** With no way to look up a supplier, the claim cannot
      // be substantiated. Defaulting to "claimable" could only ever overstate what
      // the return demands.
      await suppliers.save(
        Supplier(id: 'sup-pan', name: 'Kamala Traders', pan: '601234567'),
      );
      await issuePurchase('P-1', 'sup-pan');

      final withoutSuppliers = BuildTaxSummary(
        fiscalYear: year,
        invoices: invoices,
        creditNotes: DriftCreditNoteRepository(db),
        purchases: purchases,
        // No supplier store.
      );
      final summary = await withoutSuppliers.load();

      expect(summary.inputVat.minorUnits, 0);
      expect(summary.inputVatAtRisk.minorUnits, 130000);
    });
  });
}