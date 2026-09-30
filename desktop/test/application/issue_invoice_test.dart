import 'package:financeapp/src/application/issue_invoice.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/billing/customer.dart';
import 'package:financeapp/src/domain/billing/document_type.dart';
import 'package:financeapp/src/domain/billing/invoice.dart';
import 'package:financeapp/src/domain/billing/invoice_line.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/reporting/trial_balance.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_customer_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_document_number_sequence.dart';
import 'package:financeapp/src/infrastructure/database/drift_invoice_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_unit_of_work.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';

const npr = 'NPR';
const chart = ChartOfAccounts();

Money rs(int majorUnits) => Money.minor(majorUnits * 100, npr);

final fiscalYear = const NepaliFiscalCalendar().forBsYear(2082);

/// The customer every invoice in this file bills.
final testCustomer = Customer(id: 'cust-1', name: 'Himalayan Traders');

/// Seeds the chart of accounts and the customer the invoices bill.
Future<void> seed(AppDatabase db) async {
  await DriftAccountRepository(db).saveAll(chart.all);
  await DriftCustomerRepository(db).save(testCustomer);
}

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
      lines: lines ?? [line(1, 1000)],
    );

void main() {
  test('the fixture describes the expected fiscal year', () {
    expect(fiscalYear.label, 'FY 2082/83');
    expect(fiscalYear.startDate, DateTime(2025, 7, 17));
    expect(fiscalYear.endDate, DateTime(2026, 7, 16));
  });

  group('Issuing an invoice', () {
    test('returns the allocated number and the posted entry', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      final useCase = IssueInvoice(
        fiscalYear: fiscalYear,
        customers: DriftCustomerRepository(db),
        numbers: DriftDocumentNumberSequence(db),
        journal: DriftJournalRepository(db),
        invoices: DriftInvoiceRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      );

      final outcome = await useCase(invoiceOn(DateTime(2026, 1, 15)));

      expect(outcome, isA<InvoiceIssued>());
      final issued = outcome as InvoiceIssued;
      expect(issued.number.value, 'INV-2082-83-0001');
      expect(issued.journalEntry.isBalanced, isTrue);
    });

    test('posts exactly three lines with the hand-computed amounts', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      final useCase = IssueInvoice(
        fiscalYear: fiscalYear,
        customers: DriftCustomerRepository(db),
        numbers: DriftDocumentNumberSequence(db),
        journal: DriftJournalRepository(db),
        invoices: DriftInvoiceRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      );

      final issued =
          await useCase(invoiceOn(DateTime(2026, 1, 15))) as InvoiceIssued;
      final lines = issued.journalEntry.lines;

      // Rs 1,000 + 13% VAT: subtotal 100,000, VAT 13,000, total 113,000 paisa.
      expect(lines.length, 3);

      final receivable = lines
          .firstWhere((l) => l.account.id == ChartOfAccounts.receivable.id);
      expect(receivable.isDebit, isTrue);
      expect(receivable.debit.minorUnits, 113000);

      final sales = lines
          .firstWhere((l) => l.account.id == ChartOfAccounts.salesRevenue.id);
      expect(sales.isCredit, isTrue);
      expect(sales.credit.minorUnits, 100000);

      final vat = lines
          .firstWhere((l) => l.account.id == ChartOfAccounts.vatPayable.id);
      expect(vat.isCredit, isTrue);
      expect(vat.credit.minorUnits, 13000);

      expect(issued.journalEntry.totalDebits.minorUnits, 113000);
      expect(issued.journalEntry.totalCredits.minorUnits, 113000);
    });

    test('the posted entry is readable back from the database', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      final journal = DriftJournalRepository(db);

      final useCase = IssueInvoice(
        fiscalYear: fiscalYear,
        customers: DriftCustomerRepository(db),
        numbers: DriftDocumentNumberSequence(db),
        journal: journal,
        invoices: DriftInvoiceRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      );

      final issued =
          await useCase(invoiceOn(DateTime(2026, 1, 15))) as InvoiceIssued;
      final reloaded = await journal.byId(issued.journalEntry.id);

      expect(reloaded, isNotNull);
      expect(reloaded!.totalDebits.minorUnits, 113000);
      expect(reloaded.reference, 'INV-2082-83-0001');
      expect(reloaded.isBalanced, isTrue);
    });

    test('the trial balance balances after issuing', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      final journal = DriftJournalRepository(db);

      final useCase = IssueInvoice(
        fiscalYear: fiscalYear,
        customers: DriftCustomerRepository(db),
        numbers: DriftDocumentNumberSequence(db),
        journal: journal,
        invoices: DriftInvoiceRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      );

      await useCase(invoiceOn(DateTime(2026, 1, 15)));

      final report =
          TrialBalance.from(entries: await journal.all(), currency: npr);
      final byCode = {for (final row in report.rows) row.account.code: row};

      expect(report.isBalanced, isTrue);
      expect(byCode['1030']!.balance.minorUnits, 113000,
          reason: 'the customer owes the full amount including VAT');
      expect(byCode['4010']!.balance.minorUnits, 100000);
      expect(byCode['2020']!.balance.minorUnits, 13000,
          reason: 'VAT collected is owed to the tax authority');
    });

    test('a multi-line invoice posts one receivable line for the total',
        () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      final useCase = IssueInvoice(
        fiscalYear: fiscalYear,
        customers: DriftCustomerRepository(db),
        numbers: DriftDocumentNumberSequence(db),
        journal: DriftJournalRepository(db),
        invoices: DriftInvoiceRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      );

      final issued = await useCase(
        invoiceOn(
          DateTime(2026, 1, 15),
          lines: [line(2, 300), line(1, 400)],
        ),
      ) as InvoiceIssued;

      final lines = issued.journalEntry.lines;
      expect(lines.length, 3,
          reason: 'two sale lines must still produce one receivable line, not '
              'one per line');

      final receivable = lines
          .firstWhere((l) => l.account.id == ChartOfAccounts.receivable.id);
      expect(receivable.debit.minorUnits, 113000,
          reason: 'VAT is charged on the combined subtotal');

      final sales = lines
          .firstWhere((l) => l.account.id == ChartOfAccounts.salesRevenue.id);
      expect(sales.credit.minorUnits, 100000);
    });

    test('numbers are allocated in sequence across invoices', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      final useCase = IssueInvoice(
        fiscalYear: fiscalYear,
        customers: DriftCustomerRepository(db),
        numbers: DriftDocumentNumberSequence(db),
        journal: DriftJournalRepository(db),
        invoices: DriftInvoiceRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      );

      final first = await useCase(invoiceOn(DateTime(2026, 1, 15), id: 'INV-A'))
          as InvoiceIssued;
      final second =
          await useCase(invoiceOn(DateTime(2026, 1, 16), id: 'INV-B'))
              as InvoiceIssued;

      expect(first.number.value, 'INV-2082-83-0001');
      expect(second.number.value, 'INV-2082-83-0002');
    });

    test('the journal entry is traceable to the invoice', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      final useCase = IssueInvoice(
        fiscalYear: fiscalYear,
        customers: DriftCustomerRepository(db),
        numbers: DriftDocumentNumberSequence(db),
        journal: DriftJournalRepository(db),
        invoices: DriftInvoiceRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      );

      final issued = await useCase(
        invoiceOn(DateTime(2026, 1, 15), id: 'INV-A'),
      ) as InvoiceIssued;

      expect(issued.journalEntry.reference, 'INV-2082-83-0001');
      expect(issued.journalEntry.id, contains('INV-A'),
          reason: 'the entry id is derived from the invoice id, which is what '
              'stops an invoice being posted twice');
    });
  });

  group('A refused invoice writes nothing', () {
    test('one day before the fiscal year is refused', () async {
      final database = openInMemoryDatabase();
      addTearDown(database.close);
      await seed(database);
      final journal = DriftJournalRepository(database);
      final useCase = IssueInvoice(
        fiscalYear: fiscalYear,
        customers: DriftCustomerRepository(database),
        numbers: DriftDocumentNumberSequence(database),
        journal: journal,
        invoices: DriftInvoiceRepository(database),
        unitOfWork: DriftUnitOfWork(database),
      );

      final outcome = await useCase(
        invoiceOn(fiscalYear.startDate.subtract(const Duration(days: 1))),
      );

      expect(outcome, isA<InvoiceRejected>());
      expect(
        (outcome as InvoiceRejected).reason,
        IssueRejectionReason.outsideFiscalYear,
      );
      expect(outcome.message, contains('FY 2082/83'));
      expect(await journal.all(), isEmpty);
      expect(await database.select(database.documentSequences).get(), isEmpty,
          reason: 'a refused invoice must not consume a serial');
    });

    test('one day after the fiscal year is refused', () async {
      final database = openInMemoryDatabase();
      addTearDown(database.close);
      await seed(database);
      final journal = DriftJournalRepository(database);
      final useCase = IssueInvoice(
        fiscalYear: fiscalYear,
        customers: DriftCustomerRepository(database),
        numbers: DriftDocumentNumberSequence(database),
        journal: journal,
        invoices: DriftInvoiceRepository(database),
        unitOfWork: DriftUnitOfWork(database),
      );

      final outcome = await useCase(
        invoiceOn(fiscalYear.endDate.add(const Duration(days: 1))),
      );

      expect(outcome, isA<InvoiceRejected>());
      expect(await journal.all(), isEmpty);
      expect(await database.select(database.documentSequences).get(), isEmpty);
    });

    test('the last day of the fiscal year is accepted', () async {
      final database = openInMemoryDatabase();
      addTearDown(database.close);
      await seed(database);
      final journal = DriftJournalRepository(database);
      final useCase = IssueInvoice(
        fiscalYear: fiscalYear,
        customers: DriftCustomerRepository(database),
        numbers: DriftDocumentNumberSequence(database),
        journal: journal,
        invoices: DriftInvoiceRepository(database),
        unitOfWork: DriftUnitOfWork(database),
      );

      final outcome = await useCase(invoiceOn(fiscalYear.endDate));

      expect(outcome, isA<InvoiceIssued>());
      expect(await journal.all(), hasLength(1));
    });
  });

  group('Allocation and posting are one operation', () {
    test('a failed posting does not consume the invoice number', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      final journal = DriftJournalRepository(db);
      final numbers = DriftDocumentNumberSequence(db);

      final useCase = IssueInvoice(
        fiscalYear: fiscalYear,
        customers: DriftCustomerRepository(db),
        numbers: numbers,
        journal: journal,
        invoices: DriftInvoiceRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      );

      await useCase(invoiceOn(DateTime(2026, 1, 15), id: 'INV-A'));

      expect(
          await numbers.lastAllocatedSequence(
              type: DocumentType.invoice, fiscalYear: fiscalYear),
          1);

      // Re-issuing the same invoice id must fail. The posting is rejected by the
      // primary key because the journal entry id is derived from the invoice id.
      await expectLater(
        useCase(invoiceOn(DateTime(2026, 1, 16), id: 'INV-A')),
        throwsA(anything),
      );

      expect(
        await numbers.lastAllocatedSequence(
            type: DocumentType.invoice, fiscalYear: fiscalYear),
        1,
        reason: 'the rolled-back attempt must not have burnt a serial',
      );

      // A genuinely new invoice still gets the next number, with no gap.
      final next = await useCase(invoiceOn(DateTime(2026, 1, 17), id: 'INV-B'))
          as InvoiceIssued;
      expect(next.number.value, 'INV-2082-83-0002');
    });

    test('a failure leaves the journal and the sequence consistent', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      final journal = DriftJournalRepository(db);
      final numbers = DriftDocumentNumberSequence(db);

      final useCase = IssueInvoice(
        fiscalYear: fiscalYear,
        customers: DriftCustomerRepository(db),
        numbers: numbers,
        journal: journal,
        invoices: DriftInvoiceRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      );

      await useCase(invoiceOn(DateTime(2026, 1, 15), id: 'INV-A'));

      await expectLater(
        useCase(invoiceOn(DateTime(2026, 1, 16), id: 'INV-A')),
        throwsA(anything),
      );

      // Exactly one invoice exists, and the sequence agrees with the journal.
      final entries = await journal.all();
      expect(entries.length, 1);
      expect(entries.single.reference, 'INV-2082-83-0001');
      expect(
        await numbers.lastAllocatedSequence(
            type: DocumentType.invoice, fiscalYear: fiscalYear),
        entries.length,
      );
    });
  });

  group('An unknown customer is refused', () {
    test('nothing at all is written', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      // Accounts are seeded but the customer is deliberately not.
      await DriftAccountRepository(db).saveAll(chart.all);
      final journal = DriftJournalRepository(db);
      final numbers = DriftDocumentNumberSequence(db);

      final useCase = IssueInvoice(
        fiscalYear: fiscalYear,
        customers: DriftCustomerRepository(db),
        numbers: numbers,
        journal: journal,
        invoices: DriftInvoiceRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      );

      final outcome = await useCase(invoiceOn(DateTime(2026, 1, 15)));

      expect(outcome, isA<InvoiceRejected>());
      expect(
        (outcome as InvoiceRejected).reason,
        IssueRejectionReason.unknownCustomer,
      );
      expect(outcome.message, contains('cust-1'));

      expect(await journal.all(), isEmpty,
          reason: 'no receivable may be posted against a customer who does not '
              'exist');
      expect(await db.select(db.journalLines).get(), isEmpty);
      expect(await db.select(db.documentSequences).get(), isEmpty,
          reason: 'a refused invoice must not consume a serial');
    });

    test('the sequence is untouched, so the next invoice gets number 1',
        () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await DriftAccountRepository(db).saveAll(chart.all);
      final journal = DriftJournalRepository(db);
      final numbers = DriftDocumentNumberSequence(db);
      final customers = DriftCustomerRepository(db);

      final useCase = IssueInvoice(
        fiscalYear: fiscalYear,
        customers: customers,
        numbers: numbers,
        journal: journal,
        invoices: DriftInvoiceRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      );

      final refused = await useCase(invoiceOn(DateTime(2026, 1, 15)));
      expect(refused, isA<InvoiceRejected>());
      expect(
        await numbers.lastAllocatedSequence(
            type: DocumentType.invoice, fiscalYear: fiscalYear),
        0,
        reason: 'the refusal happened before any allocation',
      );

      // Now create the customer and try again.
      await customers.save(testCustomer);

      final issued =
          await useCase(invoiceOn(DateTime(2026, 1, 15))) as InvoiceIssued;
      expect(issued.number.value, 'INV-2082-83-0001',
          reason: 'the failed attempt must not have burnt number 1');
      expect(await journal.all(), hasLength(1));
    });

    test('an invoice for a saved customer is accepted', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      final useCase = IssueInvoice(
        fiscalYear: fiscalYear,
        customers: DriftCustomerRepository(db),
        numbers: DriftDocumentNumberSequence(db),
        journal: DriftJournalRepository(db),
        invoices: DriftInvoiceRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      );

      final outcome = await useCase(invoiceOn(DateTime(2026, 1, 15)));

      expect(outcome, isA<InvoiceIssued>());
      final issued = outcome as InvoiceIssued;
      expect(issued.journalEntry.totalDebits.minorUnits, 113000,
          reason: 'the hand-computed total is unchanged by the customer check');
      expect(issued.number.value, 'INV-2082-83-0001');
    });
  });
}
