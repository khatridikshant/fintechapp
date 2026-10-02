import 'package:financeapp/src/application/record_payment.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/accounting/journal_repository.dart';
import 'package:financeapp/src/domain/billing/credit_note_repository.dart';
import 'package:financeapp/src/domain/billing/invoice_balance.dart';
import 'package:financeapp/src/domain/billing/invoice_repository.dart';
import 'package:financeapp/src/domain/billing/invoice.dart';
import 'package:financeapp/src/domain/billing/invoice_line.dart';
import 'package:financeapp/src/domain/billing/payment.dart';
import 'package:financeapp/src/domain/billing/payment_repository.dart';
import 'package:financeapp/src/domain/fiscal/fiscal_year.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/domain/shared/unit_of_work.dart';
import 'package:financeapp/src/presentation/app_services.dart';
import 'package:financeapp/src/presentation/finance_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake for [RecordPayment], recording what the screen passed.
class _FakeRecordPayment implements RecordPayment {
  _FakeRecordPayment({this.refuse});

  RecordPaymentOutcome? refuse;
  final List<Payment> calls = <Payment>[];

  static final FiscalYear _year = FiscalYear(
    label: 'FY 2082/83',
    start: DateTime(2026, 7),
    end: DateTime(2027, 7),
  );

  // Never reached by a screen test: the screen only hands over a Payment.
  @override
  final FiscalYear fiscalYear = _year;
  @override
  final InvoiceRepository invoices = _UnusedInvoices();
  @override
  final PaymentRepository payments = _UnusedPayments();
  @override
  final CreditNoteRepository creditNotes = _UnusedCreditNotes();
  @override
  final JournalRepository journal = _UnusedJournal();
  @override
  final UnitOfWork unitOfWork = _UnusedUnitOfWork();

  @override
  JournalEntry journalEntryFor(Payment payment) => JournalEntry(
        id: RecordPayment.journalEntryIdFor(payment),
        date: payment.date,
        description: 'Payment received',
        lines: [
          JournalLine.debit(account: payment.account, amount: payment.amount),
          JournalLine.credit(
            account: ChartOfAccounts.receivable,
            amount: payment.amount,
          ),
        ],
      );

  @override
  Future<RecordPaymentOutcome> call(Payment payment) async {
    calls.add(payment);
    final scripted = refuse;
    if (scripted != null) return scripted;

    return PaymentRecorded(
      payment: payment,
      journalEntry: journalEntryFor(payment),
      balance: InvoiceBalance.of(_draftInvoice, const []),
    );
  }
}

class _UnusedInvoices implements InvoiceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedPayments implements PaymentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedCreditNotes implements CreditNoteRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedJournal implements JournalRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedUnitOfWork implements UnitOfWork {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Widget tests for the payment form.
///
/// A payment settles a receivable, so the amount the screen sends matters: the
/// use case refuses one paisa too much, and a screen that rounded or trimmed it
/// would turn a correct refusal into an accepted overpayment.
void main() {
  Future<void> open(
      WidgetTester tester, _FakeRecordPayment recordPayment) async {
    tester.view.physicalSize = const Size(1600, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      FinanceApp(services: AppServices(recordPayment: recordPayment)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Receipts'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, {String amount = '5000'}) async {
    await tester.enterText(
      find.byKey(const ValueKey<String>('payment-invoice-field')),
      'INV-2082-83-0001',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('payment-amount-field')),
      amount,
    );
  }

  group('before submitting', () {
    testWidgets('offers an invoice, an amount, a way to pay, and a button',
        (tester) async {
      await open(tester, _FakeRecordPayment());

      for (final key in <String>[
        'payment-invoice-field',
        'payment-amount-field',
        'payment-method-bank',
        'payment-method-cash',
        'payment-record-button',
      ]) {
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget,
            reason: '$key must be on the form');
      }
    });

    testWidgets('will not submit without an invoice', (tester) async {
      final fake = _FakeRecordPayment();
      await open(tester, fake);

      await tester.enterText(
        find.byKey(const ValueKey<String>('payment-amount-field')),
        '5000',
      );
      await tester
          .tap(find.byKey(const ValueKey<String>('payment-record-button')));
      await tester.pumpAndSettle();

      expect(fake.calls, isEmpty);
      expect(find.textContaining('invoice'), findsWidgets);
    });

    testWidgets('will not submit a zero or empty amount', (tester) async {
      final fake = _FakeRecordPayment();
      await open(tester, fake);

      await tester.enterText(
        find.byKey(const ValueKey<String>('payment-invoice-field')),
        'INV-2082-83-0001',
      );
      await tester
          .tap(find.byKey(const ValueKey<String>('payment-record-button')));
      await tester.pumpAndSettle();

      expect(fake.calls, isEmpty);
    });
  });

  group('recording', () {
    testWidgets('passes the typed amount untouched', (tester) async {
      final fake = _FakeRecordPayment();
      await open(tester, fake);

      await fill(tester, amount: '5000.50');
      await tester
          .tap(find.byKey(const ValueKey<String>('payment-record-button')));
      await tester.pumpAndSettle();

      expect(fake.calls, hasLength(1));
      // Exactly what was typed: 5000.50 is 500050 paisa, not 500000.
      expect(fake.calls.single.amount.minorUnits, 500050);
    });

    testWidgets('defaults to money in the bank', (tester) async {
      final fake = _FakeRecordPayment();
      await open(tester, fake);

      await fill(tester);
      await tester
          .tap(find.byKey(const ValueKey<String>('payment-record-button')));
      await tester.pumpAndSettle();

      expect(fake.calls.single.account, ChartOfAccounts.bank);
    });

    testWidgets('can record money received in cash instead', (tester) async {
      final fake = _FakeRecordPayment();
      await open(tester, fake);

      await tester
          .tap(find.byKey(const ValueKey<String>('payment-method-cash')));
      await tester.pumpAndSettle();
      await fill(tester);
      await tester
          .tap(find.byKey(const ValueKey<String>('payment-record-button')));
      await tester.pumpAndSettle();

      expect(fake.calls.single.account, ChartOfAccounts.cash);
    });

    testWidgets("shows the use case's own refusal, not a second wording",
        (tester) async {
      final fake = _FakeRecordPayment(
        refuse: PaymentRejected(
          payment: _draft(),
          reason: RecordPaymentRejectionReason.exceedsOutstanding,
          fiscalYear: _FakeRecordPayment._year,
          outstanding: Money.fromMajorUnits(1000, 'NPR'),
        ),
      );
      await open(tester, fake);

      await fill(tester);
      await tester
          .tap(find.byKey(const ValueKey<String>('payment-record-button')));
      await tester.pumpAndSettle();

      // The wording names the overpayment, because the screen must not invent its
      // own explanation for an accounting refusal.
      expect(find.textContaining('credit note'), findsOneWidget);
    });
  });
}

/// A real invoice for the balance to be computed from.
Invoice get _draftInvoice => Invoice(
      id: 'inv-1',
      issueDate: DateTime(2026, 8, 15),
      customerId: 'C-0001',
      lines: <InvoiceLine>[
        InvoiceLine(
          description: 'Keyboard',
          quantity: 1,
          unitPrice: Money.fromMajorUnits(5000, 'NPR'),
        ),
      ],
    );

Payment _draft() => Payment(
      id: 'pay-1',
      invoiceId: 'INV-2082-83-0001',
      date: DateTime(2026, 8, 15),
      amount: Money.fromMajorUnits(5000, 'NPR'),
      account: ChartOfAccounts.bank,
    );
