import 'package:financeapp/src/application/issue_purchase.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/billing/document_type.dart';
import 'package:financeapp/src/domain/billing/purchase.dart';
import 'package:financeapp/src/domain/billing/purchase_balance.dart';
import 'package:financeapp/src/domain/billing/purchase_line.dart';
import 'package:financeapp/src/domain/billing/supplier.dart';
import 'package:financeapp/src/domain/billing/supplier_payment.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_document_number_sequence.dart';
import 'package:financeapp/src/infrastructure/database/drift_inventory_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_purchase_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_supplier_payment_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_supplier_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_unit_of_work.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:financeapp/src/domain/inventory/product.dart';
import 'package:flutter_test/flutter_test.dart';

const chart = ChartOfAccounts();
final fiscalYear = const NepaliFiscalCalendar().forBsYear(2082);

void main() {
  // **The accounting, worked by hand before the implementation.**
  //
  // Buy 10 chairs at Rs 100.00 each from a VAT-registered supplier at 13%:
  //   subtotal = 10 x 100,000 paisa = 1,000,000 paisa  (Rs 10,000.00)
  //   VAT      = 13% of 1,000,000  =   130,000 paisa  (Rs  1,300.00)
  //   total                          1,130,000 paisa  (Rs 11,300.00)
  //
  //   Dr 1040 Inventory              1,000,000    <- NET, not the gross
  //   Dr 1150 Input VAT Recoverable    130,000
  //   Cr 2010 Accounts Payable       1,130,000
  //
  // 1,000,000 + 130,000 = 1,130,000, so it balances. The **net** figure in 1040 is
  // the whole design: inventory carries at cost and a recoverable tax is not part
  // of cost, so putting the gross there would push 130,000 of recoverable VAT
  // into cost of goods sold the day those chairs are sold.

  late AppDatabase db;
  late DriftSupplierRepository suppliers;
  late DriftPurchaseRepository purchases;
  late DriftSupplierPaymentRepository payments;
  late DriftDocumentNumberSequence numbers;
  late DriftJournalRepository journal;
  late DriftInventoryRepository inventory;
  late IssuePurchase issue;

  final date = DateTime(2026, 1, 10);

  setUp(() async {
    db = openInMemoryDatabase();
    suppliers = DriftSupplierRepository(db);
    purchases = DriftPurchaseRepository(db);
    payments = DriftSupplierPaymentRepository(db);
    numbers = DriftDocumentNumberSequence(db);
    journal = DriftJournalRepository(db);
    inventory = DriftInventoryRepository(db);

    await DriftAccountRepository(db).saveAll(chart.all);
    await inventory.saveProduct(
      Product(id: 'p-1', name: 'Chair', salePrice: Money.minor(200000, 'NPR')),
    );

    issue = IssuePurchase(
      fiscalYear: fiscalYear,
      suppliers: suppliers,
      purchases: purchases,
      numbers: numbers,
      journal: journal,
      unitOfWork: DriftUnitOfWork(db),
      inventory: inventory,
    );
  });

  tearDown(() => db.close());

  Purchase build({
    String id = 'P-1',
    String supplierId = 'sup-1',
    DateTime? when,
    List<PurchaseLine>? lines,
    int vatRateBasisPoints = 1300,
  }) =>
      Purchase(
        id: id,
        issueDate: when ?? date,
        supplierId: supplierId,
        lines: lines ??
            [
              PurchaseLine(
                description: 'Chair',
                quantity: 10,
                unitPrice: Money.minor(100000, 'NPR'),
                productId: 'p-1',
              ),
            ],
        vatRateBasisPoints: vatRateBasisPoints,
      );

  JournalLine? lineFor(JournalEntry entry, String accountId) {
    for (final line in entry.lines) {
      if (line.account.id == accountId) return line;
    }
    return null;
  }

  group('Issuing a purchase', () {
    setUp(() async {
      await suppliers.save(
        Supplier(id: 'sup-1', name: 'Kamala Traders', pan: '601234567'),
      );
    });

    test(
      'posts Dr Inventory / Dr Input VAT / Cr Payable at the hand-computed '
      'amounts',
      () async {
      // **The assertion that matters.** By account id *and* by side, so a swapped
      // debit and credit cannot pass: the entry would still balance, and a purchase
      // recorded as a disposal of stock is exactly the class of error that leaves
      // books that balance while being wrong.
      final issued = await issue(build()) as PurchaseIssued;

      expect(issued.purchase.subtotal.minorUnits, 1000000);
      expect(issued.purchase.vat.minorUnits, 130000);
      expect(issued.purchase.total.minorUnits, 1130000);

      final entry = issued.journalEntry;

      final inventory = lineFor(entry, ChartOfAccounts.inventory.id)!;
      expect(inventory.isDebit, isTrue);
      expect(
        inventory.amount.minorUnits,
        1000000,
        reason: 'inventory carries the NET cost, never the gross',
      );

      final inputVat = lineFor(entry, ChartOfAccounts.inputVatRecoverable.id)!;
      expect(inputVat.isDebit, isTrue);
      expect(inputVat.amount.minorUnits, 130000);

      final payable = lineFor(entry, ChartOfAccounts.payable.id)!;
      expect(payable.isCredit, isTrue);
      expect(payable.amount.minorUnits, 1130000);
    });

    test('the entry balances', () async {
      // `JournalEntry` cannot be constructed unbalanced, so reaching this line
      // proves it; the assertion keeps it proven if the entry is ever built by hand.
      final issued = await issue(build()) as PurchaseIssued;
      expect(issued.journalEntry.totalDebits.minorUnits, 1130000);
      expect(issued.journalEntry.totalCredits.minorUnits, 1130000);
    });

    test('the purchase is numbered from its own PUR sequence', () async {
      final issued = await issue(build()) as PurchaseIssued;
      expect(issued.number.value, 'PUR-2082-83-0001');
    });

    test('purchases and invoices do not share a counter', () async {
      // **ADR 005.** A purchase must never consume an invoice serial, or both
      // numbering streams become unauditable.
      await numbers.allocateNext(
        type: DocumentType.invoice,
        fiscalYear: fiscalYear,
      );
      await numbers.allocateNext(
        type: DocumentType.invoice,
        fiscalYear: fiscalYear,
      );

      final issued = await issue(build()) as PurchaseIssued;
      expect(issued.number.value, 'PUR-2082-83-0001');

      // The invoice counter is untouched by the purchase.
      final nextInvoice = await numbers.allocateNext(
        type: DocumentType.invoice,
        fiscalYear: fiscalYear,
      );
      expect(nextInvoice.value, 'INV-2082-83-0003');
    });

    test('the bill is stored with its number, its lines, and its entry', () async {
      await issue(build());

      final stored = (await purchases.byId('P-1'))!;
      expect(stored.number.value, 'PUR-2082-83-0001');
      expect(stored.journalEntryId, 'JE-PUR-P-1');
      expect(stored.purchase.lines.length, 1);
      expect(
        stored.purchase.total.minorUnits,
        1130000,
        reason: 'the stored total must equal the recomputed one',
      );
    });

    test('the stock the bill delivered is recorded, at the net figure', () async {
      // Purchasing stock must do two things atomically. Without the movement, 1040
      // and the physical stock diverge Ã¢â‚¬â€ the defect 4.17 recorded as a Gate 6
      // blocker.
      final issued = await issue(build()) as PurchaseIssued;

      expect(issued.stockFor('p-1')!.quantity, 10);
      expect(
        issued.stockFor('p-1')!.value.minorUnits,
        1000000,
        reason: 'stock carries the net figure; the VAT sits in 1150',
      );

      final movements = await inventory.movementsFor('p-1');
      expect(movements.length, 1);
      expect(movements.single.value.minorUnits, 1000000);
      expect(movements.single.reason.name, 'purchase');

      // The movement must be linked to the entry that accounts for it, or `1040`
      // and the physical stock become two unrelated numbers again â€” the defect
      // 4.17 recorded. The link lives on the row, so it is checked there.
      final row = await (db.select(db.inventoryMovements)).getSingle();
      expect(row.journalEntryId, 'JE-PUR-P-1');
    });

    test('the inventory account and the stock value agree, exactly', () async {
      // **The property ADR 004 exists to preserve.** After buying, the trial
      // balance balance of 1040 must equal the derived stock value. If it does not,
      // one of the two is wrong and the books no longer reconcile.
      await issue(build());

      final stock = await inventory.stockOf(
        Product(
    id: 'p-1',
          name: 'Chair',
          salePrice: Money.minor(200000, 'NPR'),
        ),
      );
      final entries = await journal.all();
      var inventoryBalance = 0;
      for (final entry in entries) {
        for (final line in entry.lines) {
          if (line.account.id != ChartOfAccounts.inventory.id) continue;
          inventoryBalance +=
              line.isDebit ? line.amount.minorUnits : -line.amount.minorUnits;
        }
      }

      expect(stock.value.minorUnits, 1000000);
      expect(inventoryBalance, stock.value.minorUnits);
    });
  });

  group('Refusals, and the rule that a refusal writes nothing', () {
    // **Awaited.** An un-awaited `save` here would still be in flight when
    // `tearDown` closes the database, and the resulting error surfaces as a
    // confusing "database has already been closed" during the rollback rather
    // than as the missing `await` that it actually is.
    setUp(() async {
      await suppliers.save(
        Supplier(id: 'sup-1', name: 'Kamala Traders', pan: '601234567'),
      );
    });

    test('a purchase dated outside the fiscal year is refused', () async {
      final outcome = await issue(build(when: DateTime(2026, 9, 1)));
      expect(outcome, isA<PurchaseRejected>());
      expect(
        (outcome as PurchaseRejected).reason,
        IssuePurchaseRejectionReason.outsideFiscalYear,
      );
    });

    test('the last day of the fiscal year is inside it', () async {
      // **Compares dates, not instants.** A purchase posted at 15:45 on the final
      // day is inside the year. Comparing timestamps would reject it, and that is
      // the single easiest mistake to make in this area.
      final outcome =
          await issue(build(when: DateTime(2026, 7, 16, 15, 45)));
      expect(outcome, isA<PurchaseIssued>());
    });

    test('one day after the year is outside it', () async {
      final outcome = await issue(build(when: DateTime(2026, 7, 17)));
      expect(outcome, isA<PurchaseRejected>());
    });

    test('a purchase from an unknown supplier is refused', () async {
      final outcome = await issue(build(supplierId: 'sup-nope'));
      expect(outcome, isA<PurchaseRejected>());
      expect(
        (outcome as PurchaseRejected).reason,
        IssuePurchaseRejectionReason.unknownSupplier,
      );
    });

    test('a purchase naming an unknown product is refused, with its own reason',
        () async {
      // **A separate reason, not folded into unknownSupplier.** The remedy is
      // completely different, so reporting it as a supplier problem would send the
      // operator to the wrong screen.
      final outcome = await issue(
        build(
          lines: [
            PurchaseLine(
              description: 'Ghost',
              quantity: 1,
              unitPrice: Money.minor(100000, 'NPR'),
              productId: 'p-does-not-exist',
            ),
          ],
        ),
      );
      expect(outcome, isA<PurchaseRejected>());
      expect(
        (outcome as PurchaseRejected).reason,
        IssuePurchaseRejectionReason.unknownProduct,
      );
    });

    test('a refused purchase consumes no serial', () async {
      // **What makes the numbering gap-free.** A refusal must leave the sequence
      // untouched, or every rejected bill punches a hole in a scheme whose whole
      // purpose is to have no holes.
      await issue(build(id: 'P-1', when: DateTime(2026, 9, 1)));

      final issued = await issue(build(id: 'P-2')) as PurchaseIssued;
      expect(issued.number.value, 'PUR-2082-83-0001');
    });

    test('a refused purchase writes no entry, no bill, and no movement', () async {
      await issue(build(id: 'P-1', when: DateTime(2026, 9, 1)));

      expect(await journal.all(), isEmpty);
      expect(await purchases.all(), isEmpty);
      expect(await inventory.movementsFor('p-1'), isEmpty);
    });
  });

  group('A zero-rated purchase', () {
    setUp(() async {
      await suppliers.save(
        Supplier(id: 'sup-1', name: 'Kamala Traders', pan: '601234567'),
      );
    });

    test('omits the input VAT line rather than posting a zero', () async {
      // A journal line must carry a positive amount on one side, and a return
      // expects no line rather than a zero line.
      final issued =
          await issue(build(vatRateBasisPoints: 0)) as PurchaseIssued;

      expect(issued.purchase.isZeroRated, isTrue);
      expect(
        lineFor(issued.journalEntry, ChartOfAccounts.inputVatRecoverable.id),
        isNull,
      );
      expect(
        lineFor(issued.journalEntry, ChartOfAccounts.payable.id)!.amount.minorUnits,
        1000000,
        reason: 'with no VAT the payable is the net figure',
      );
    });

    test('still balances without the VAT line', () async {
      final issued =
          await issue(build(vatRateBasisPoints: 0)) as PurchaseIssued;
      expect(issued.journalEntry.totalDebits.minorUnits, 1000000);
      expect(issued.journalEntry.totalCredits.minorUnits, 1000000);
    });
  });

  group('A mixed-rate purchase', () {
    setUp(() async {
      await suppliers.save(
        Supplier(id: 'sup-1', name: 'Kamala Traders', pan: '601234567'),
      );
      inventory.saveProduct(
        Product(
          id: 'p-2',
          name: 'Exported Goods',
          salePrice: Money.minor(200000, 'NPR'),
        ),
      );
    });

    test('charges each line at its own rate', () async {
      // One supplier invoicing standard-rated goods alongside zero-rated ones.
      // 100,000 at 13% = 13,000; 100,000 at 0% = 0; total VAT 13,000.
      final issued = await issue(
        build(
          lines: [
            PurchaseLine(
              description: 'Standard goods',
              quantity: 1,
              unitPrice: Money.minor(100000, 'NPR'),
              productId: 'p-1',
            ),
            PurchaseLine(
              description: 'Zero-rated goods',
              quantity: 1,
              unitPrice: Money.minor(100000, 'NPR'),
              vatRateBasisPoints: 0,
              productId: 'p-2',
            ),
          ],
        ),
      ) as PurchaseIssued;

      expect(issued.purchase.vat.minorUnits, 13000);
      expect(issued.purchase.total.minorUnits, 213000);
      expect(
        lineFor(
          issued.journalEntry,
          ChartOfAccounts.inputVatRecoverable.id,
        )!.amount.minorUnits,
        13000,
      );
    });

    test('the mixed rates survive a reload of the bill', () async {
      // **A bill that reloads collapsed to one rate would silently overstate input
      // VAT** on every subsequent read, and the return would then disagree with
      // the ledger.
      await issue(
        build(
          lines: [
            PurchaseLine(
              description: 'Standard goods',
              quantity: 1,
              unitPrice: Money.minor(100000, 'NPR'),
              productId: 'p-1',
            ),
            PurchaseLine(
              description: 'Zero-rated goods',
              quantity: 1,
              unitPrice: Money.minor(100000, 'NPR'),
              vatRateBasisPoints: 0,
              productId: 'p-2',
            ),
          ],
        ),
      );

      final reloaded = (await purchases.byId('P-1'))!;
      expect(reloaded.purchase.lines[1].vatRateBasisPoints, 0);
      expect(reloaded.purchase.vat.minorUnits, 13000);
    });
  });

  group('Input credit and a supplier without a PAN', () {
    test('the VAT is still posted, and the risk is reported', () async {
      // **The decision, and why it is a warning rather than a refusal.**
      // `NEPALI_BILLING.md` records that a bill lacking the vendor's PAN may be
      // disallowed as input credit. Refusing would leave the stock unrecorded,
      // which is worse than recording it with a warning.
      suppliers.save(Supplier(id: 'sup-2', name: 'Ram Furniture'));

      final issued = await issue(build(supplierId: 'sup-2')) as PurchaseIssued;

      expect(
        lineFor(issued.journalEntry, ChartOfAccounts.inputVatRecoverable.id),
        isNotNull,
        reason: 'the VAT was genuinely charged and is recoverable in principle',
      );
      expect(issued.supplierCanSupportInputCredit, isFalse);
      expect(issued.inputCreditWarning, contains('PAN'));
    });

    test('a supplier with a PAN raises no warning', () async {
      suppliers.save(
        Supplier(id: 'sup-1', name: 'Kamala Traders', pan: '601234567'),
      );
      final issued = await issue(build()) as PurchaseIssued;
      expect(issued.supplierCanSupportInputCredit, isTrue);
      expect(issued.inputCreditWarning, isNull);
    });
  });

  group('Settling a purchase', () {
    setUp(() async {
      await suppliers.save(
        Supplier(id: 'sup-1', name: 'Kamala Traders', pan: '601234567'),
      );
    });

    test('the balance starts at the full total and is derived, not stored', () async {
      await issue(build());
      final stored = (await purchases.byId('P-1'))!;

      final balance = PurchaseBalance.of(stored.purchase, const []);
      expect(balance.outstanding.minorUnits, 1130000);
    });

    test('a payment reduces the balance', () async {
      await issue(build());
      final stored = (await purchases.byId('P-1'))!;

      await payments.save(
        SupplierPayment(
          id: 'SPAY-1',
          purchaseId: 'P-1',
          date: DateTime(2026, 1, 20),
          amount: Money.minor(500000, 'NPR'),
          accountId: ChartOfAccounts.bank.id,
        ),
      );

      final balance = PurchaseBalance.of(
        stored.purchase,
        await payments.forPurchase('P-1'),
      );
      expect(balance.outstanding.minorUnits, 630000);
      expect(balance.isPartiallyPaid, isTrue);
    });

    test('paying the exact amount settles the purchase', () async {
      await issue(build());
      final stored = (await purchases.byId('P-1'))!;

      await payments.save(
        SupplierPayment(
          id: 'SPAY-1',
          purchaseId: 'P-1',
          date: DateTime(2026, 1, 20),
          amount: Money.minor(1130000, 'NPR'),
          accountId: ChartOfAccounts.bank.id,
        ),
      );

      final balance = PurchaseBalance.of(
        stored.purchase,
        await payments.forPurchase('P-1'),
      );
      expect(balance.isSettled, isTrue);
    });
  });
}