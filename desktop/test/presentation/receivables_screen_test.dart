import 'package:financeapp/src/application/build_receivables.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/billing/customer.dart';
import 'package:financeapp/src/domain/billing/document_number.dart';
import 'package:financeapp/src/domain/billing/document_type.dart';
import 'package:financeapp/src/domain/billing/invoice.dart';
import 'package:financeapp/src/domain/billing/invoice_line.dart';
import 'package:financeapp/src/domain/billing/issued_invoice.dart';
import 'package:financeapp/src/domain/billing/payment.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_credit_note_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_customer_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_invoice_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_payment_repository.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:financeapp/src/presentation/screens/receivables_screen.dart';
import 'package:financeapp/src/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Who owes what, and the two ways this report can be wrong.
///
/// ## The figures, computed by hand
///
/// One customer, **one invoice of Rs 100,000 net plus Rs 13,000 VAT = Rs 113,000**:
///
/// - outstanding **Rs 113,000** — the customer owes the whole invoice
/// - after a **Rs 40,000 payment**, outstanding **Rs 73,000**
/// - the **VAT of Rs 13,000** is *inside* that. It is owed to the authority rather
///   than by the customer, so a figure that described it as "money owed to the
///   business" would invite chasing the wrong money.
void main() {
  const npr = 'NPR';
  final fiscalYear = const NepaliFiscalCalendar().forBsYear(2082);
  final asAt = DateTime(2026, 3, 31);

  late AppDatabase db;
  late DriftCustomerRepository customers;
  late DriftInvoiceRepository invoices;
  late DriftPaymentRepository payments;
  late DriftCreditNoteRepository creditNotes;
  late DriftJournalRepository journal;

  setUp(() async {
    db = openInMemoryDatabase();
    customers = DriftCustomerRepository(db);
    invoices = DriftInvoiceRepository(db);
    payments = DriftPaymentRepository(db);
    creditNotes = DriftCreditNoteRepository(db);
    journal = DriftJournalRepository(db);
    await DriftAccountRepository(db).saveAll(const ChartOfAccounts().all);
  });

  tearDown(() async => db.close());

  Money rs(int majorUnits) => Money.minor(majorUnits * 100, npr);

  Future<void> seedCustomer(String id, String name) =>
      customers.save(Customer(id: id, name: name));

  Future<void> seedInvoice({
    required String id,
    required String customerId,
    required DateTime date,
    int net = 100000,
    int sequence = 1,
  }) async {
    final invoice = Invoice(
      id: id,
      issueDate: date,
      customerId: customerId,
      // 100,000 net at 13% is a 113,000 gross.
      lines: <InvoiceLine>[
        InvoiceLine(
          description: 'item',
          quantity: 1,
          unitPrice: rs(net),
        ),
      ],
    );

    // **The journal entry is not optional.** `invoices.journal_entry_id` is a
    // foreign key, and the repository derives it from the invoice id, so an
    // invoice cannot be stored without the posting behind it. That is the database
    // agreeing with the domain: a sales document with no posting is not a
    // document, it is a claim.
    await journal.append(JournalEntry(
      id: 'JE-INV-$id',
      date: date,
      description: 'Invoice $id',
      lines: <JournalLine>[
        JournalLine.debit(
          account: ChartOfAccounts.receivable,
          amount: invoice.total,
        ),
        JournalLine.credit(
          account: ChartOfAccounts.salesRevenue,
          amount: invoice.subtotal,
        ),
        JournalLine.credit(
          account: ChartOfAccounts.vatPayable,
          amount: invoice.vat,
        ),
      ],
    ));

    await invoices.save(IssuedInvoice(
      invoice: invoice,
      number: DocumentNumber.of(
        type: DocumentType.invoice,
        fiscalYear: fiscalYear,
        sequence: sequence,
      ),
    ));
  }

  Future<void> seedPayment(String id, String invoiceId, Money amount) async {
    await payments.save(Payment(
      id: id,
      invoiceId: invoiceId,
      date: DateTime(2026, 3, 10),
      amount: amount,
      account: ChartOfAccounts.bank,
    ));
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ReceivablesScreen(
        receivables: BuildReceivables(
          invoices: invoices,
          payments: payments,
          creditNotes: creditNotes,
          customers: customers,
          asAt: asAt,
        ),
        asAt: asAt,
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('outstanding', () {
    testWidgets('an unpaid invoice is owed in full, VAT included',
        (tester) async {
      await seedCustomer('cust-1', 'Himalayan Traders');
      await seedInvoice(
        id: 'INV-1',
        customerId: 'cust-1',
        date: DateTime(2026, 3, 5),
      );

      await pumpScreen(tester);

      expect(find.text('Himalayan Traders'), findsOneWidget);
      // 100,000 net plus 13,000 VAT. The customer owes all of it.
      expect(find.text('Rs 113,000.00'), findsWidgets);
    });

    testWidgets('a payment reduces what is owed', (tester) async {
      await seedCustomer('cust-1', 'Himalayan Traders');
      await seedInvoice(
        id: 'INV-1',
        customerId: 'cust-1',
        date: DateTime(2026, 3, 5),
      );
      await seedPayment('PAY-1', 'INV-1', rs(40000));

      await pumpScreen(tester);

      // 113,000 less 40,000.
      expect(find.text('Rs 73,000.00'), findsWidgets);
    });

    testWidgets('a fully paid invoice is not a receivable', (tester) async {
      await seedCustomer('cust-1', 'Himalayan Traders');
      await seedInvoice(
        id: 'INV-1',
        customerId: 'cust-1',
        date: DateTime(2026, 3, 5),
      );
      await seedPayment('PAY-1', 'INV-1', rs(113000));

      await pumpScreen(tester);

      expect(find.textContaining('Nothing is owed'), findsOneWidget);
    });

    testWidgets('an invoice cannot name a customer that does not exist',
        (tester) async {
      // **Rewritten after it failed, and the failure was the finding.** The test
      // tried to save an invoice for `cust-gone` expecting the report to fall back
      // to the id -- and the database refused the insert, because
      // `invoices.customer_id` is a foreign key.
      //
      // So the guarantee is **stronger than the fallback**: an invoice always has
      // a real customer behind it. The `?? entry.key` fallback in `BuildReceivables`
      // is therefore belt-and-braces for a state the schema forbids, and this test
      // pins the schema rather than the fallback.
      await expectLater(
        seedInvoice(
          id: 'INV-X',
          customerId: 'cust-gone',
          date: DateTime(2026, 3, 5),
        ),
        throwsA(isA<SqliteException>()),
        reason: 'a receivable must never exist without a customer to chase',
      );
    });

    testWidgets('two customers are listed and totalled', (tester) async {
      await seedCustomer('cust-1', 'Himalayan Traders');
      await seedCustomer('cust-2', 'Sita Sharma Supplies');
      await seedInvoice(
        id: 'INV-1',
        customerId: 'cust-1',
        date: DateTime(2026, 3, 5),
        sequence: 1,
      );
      await seedInvoice(
        id: 'INV-2',
        customerId: 'cust-2',
        date: DateTime(2026, 3, 6),
        sequence: 2,
      );

      await pumpScreen(tester);

      expect(find.text('Himalayan Traders'), findsOneWidget);
      expect(find.text('Sita Sharma Supplies'), findsOneWidget);
      // 113,000 + 113,000.
      expect(find.text('Rs 226,000.00'), findsWidgets);
    });
  });

  group('ageing', () {
    testWidgets('says how old the debt is, and does not call it overdue',
        (tester) async {
      // `Invoice` records no due date, so "overdue" would be a claim the data
      // cannot support.
      await seedCustomer('cust-1', 'Himalayan Traders');
      await seedInvoice(
        id: 'INV-1',
        customerId: 'cust-1',
        date: DateTime(2026, 3, 5),
      );

      await pumpScreen(tester);

      // 5 March to 31 March is 26 days.
      expect(find.textContaining('26 days old'), findsOneWidget);
      expect(find.textContaining('overdue'), findsNothing);
    });
  });

  group('the dangerous failure', () {
    testWidgets('a report that could not be read never says nothing is owed',
        (tester) async {
      // **This is why the failure state is tested rather than assumed.** A report
      // that renders as "nothing owed" when it could not be read is worse than no
      // report at all: a user would conclude the business is paid up.
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: const ReceivablesScreen(receivables: _FailingReceivables()),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('could not be produced'), findsOneWidget);
      expect(find.textContaining('Nothing is owed'), findsNothing);
    });
  });
}

class _FailingReceivables implements ReceivablesLoader {
  const _FailingReceivables();

  @override
  Future<ReceivablesReport> load() async =>
      throw StateError('the invoices table could not be read');
}
