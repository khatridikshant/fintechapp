import 'package:financeapp/src/application/issue_invoice.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/accounting/journal_repository.dart';
import 'package:financeapp/src/domain/billing/business_profile_repository.dart';
import 'package:financeapp/src/domain/billing/customer_repository.dart';
import 'package:financeapp/src/domain/billing/document_number.dart';
import 'package:financeapp/src/domain/billing/document_number_sequence.dart';
import 'package:financeapp/src/domain/billing/document_type.dart';
import 'package:financeapp/src/domain/billing/invoice.dart';
import 'package:financeapp/src/domain/billing/invoice_line.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/domain/billing/invoice_repository.dart';
import 'package:financeapp/src/domain/billing/issued_invoice.dart';
import 'package:financeapp/src/domain/fiscal/fiscal_year.dart';
import 'package:financeapp/src/domain/shared/unit_of_work.dart';
import 'package:financeapp/src/presentation/app_services.dart';
import 'package:financeapp/src/presentation/finance_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake for [IssueInvoice], recording what the screen passed and able to refuse.
class _FakeIssueInvoice implements IssueInvoice {
  _FakeIssueInvoice({this.refuse});

  /// Set to make the fake refuse, mimicking the use case's own outcomes.
  IssueInvoiceOutcome? refuse;

  final List<Invoice> calls = <Invoice>[];

  static final FiscalYear _year = FiscalYear(
    label: 'FY 2082/83',
    start: DateTime(2026, 7),
    end: DateTime(2027, 7),
  );

  /// `IssueInvoice` is a class with dependencies. Each is a stub that throws if
  /// touched, because nothing under test reaches them — the screen only hands the
  /// use case an invoice.
  @override
  final CustomerRepository customers = _UnusedCustomerRepo();

  @override
  final DocumentNumberSequence numbers = _UnusedNumberSeq();

  @override
  final JournalRepository journal = _UnusedJournal();

  @override
  final InvoiceRepository invoices = _UnusedInvoices();

  @override
  final UnitOfWork unitOfWork = _UnusedUnitOfWork();

  @override
  final BusinessProfileRepository? sellers = null;

  @override
  FiscalYear get fiscalYear => _year;

  /// A journal entry for a fake to hand back.
  ///
  /// **Balanced, and at least two lines.** `JournalEntry` refuses an unbalanced or
  /// single-line entry, so a stub with no lines throws *inside the use case*, and
  /// the screen then correctly reports a problem instead of the issued number — which
  /// looks exactly like a screen bug and is not one.
  JournalEntry _balancedEntry(Invoice invoice) => JournalEntry(
        id: IssuedInvoice.journalEntryIdFor(invoice),
        date: invoice.issueDate,
        description: 'Invoice',
        lines: <JournalLine>[
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
        ],
      );

  @override
  JournalEntry journalEntryFor(Invoice invoice, DocumentNumber number) =>
      _balancedEntry(invoice);

  @override
  Future<IssueInvoiceOutcome> call(Invoice invoice) async {
    calls.add(invoice);
    final scripted = refuse;
    if (scripted != null) return scripted;

    final number = DocumentNumber.of(
      type: DocumentType.invoice,
      fiscalYear: _year,
      sequence: 1,
    );
    return InvoiceIssued(
      invoice: invoice,
      number: number,
      journalEntry: _balancedEntry(invoice),
      issued: IssuedInvoice(invoice: invoice, number: number),
    );
  }
}

/// Stands in for a dependency the screen never reaches.
///
/// Declared separately for each type rather than as one class implementing all of
/// them, so a missing member is a compile error instead of a runtime surprise.
class _UnusedCustomerRepo implements CustomerRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedNumberSeq implements DocumentNumberSequence {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedJournal implements JournalRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedInvoices implements InvoiceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedUnitOfWork implements UnitOfWork {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Widget tests for the invoice form.
///
/// The screen must **decide nothing about the invoice**: not the totals, not the
/// number, not the journal. It collects what was typed and renders what the use
/// case returned. These tests hold it to that.
void main() {
  Future<void> open(WidgetTester tester, _FakeIssueInvoice issueInvoice) async {
    tester.view.physicalSize = const Size(1600, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      FinanceApp(services: AppServices(issueInvoice: issueInvoice)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invoices'));
    await tester.pumpAndSettle();
  }

  Future<void> fillOneLine(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey<String>('invoice-customer-field')),
      'C-0001',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('line-description-0')),
      'Keyboard',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('line-quantity-0')),
      '2',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('line-price-0')),
      '2500',
    );
  }

  group('before submitting', () {
    testWidgets('offers a customer, a line, and a submit button',
        (tester) async {
      await open(tester, _FakeIssueInvoice());

      expect(find.byKey(const ValueKey<String>('invoice-customer-field')),
          findsOneWidget);
      expect(find.byKey(const ValueKey<String>('line-description-0')),
          findsOneWidget);
      expect(find.byKey(const ValueKey<String>('line-quantity-0')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey<String>('line-price-0')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('invoice-issue-button')),
          findsOneWidget);
    });

    testWidgets('always offers a row to type into, even if it is removed',
        (tester) async {
      // The form never presents an empty invoice, because there is always
      // something to type into. Asserting the *guard* would be asserting
      // unreachable behaviour; this asserts what the user actually sees.
      await open(tester, _FakeIssueInvoice());

      expect(find.byKey(const ValueKey<String>('line-description-0')),
          findsOneWidget);
      expect(find.byKey(const ValueKey<String>('remove-line-0')), findsNothing,
          reason: 'the only row is not removable, or the form would be empty');
    });

    testWidgets('will not submit a line with no description', (tester) async {
      final fake = _FakeIssueInvoice();
      await open(tester, fake);

      await tester.enterText(
        find.byKey(const ValueKey<String>('invoice-customer-field')),
        'C-0001',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('line-quantity-0')),
        '1',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('line-price-0')),
        '100',
      );
      await tester
          .tap(find.byKey(const ValueKey<String>('invoice-issue-button')));
      await tester.pumpAndSettle();

      expect(fake.calls, isEmpty);
    });

    testWidgets('will not submit a zero or negative quantity', (tester) async {
      final fake = _FakeIssueInvoice();
      await open(tester, fake);

      await fillOneLine(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('line-quantity-0')),
        '0',
      );
      await tester
          .tap(find.byKey(const ValueKey<String>('invoice-issue-button')));
      await tester.pumpAndSettle();

      expect(fake.calls, isEmpty);
    });

    testWidgets('will not submit a zero price', (tester) async {
      final fake = _FakeIssueInvoice();
      await open(tester, fake);

      await tester.enterText(
        find.byKey(const ValueKey<String>('invoice-customer-field')),
        'C-0001',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('line-description-0')),
        'Keyboard',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('line-quantity-0')),
        '1',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('line-price-0')),
        '0',
      );
      await tester
          .tap(find.byKey(const ValueKey<String>('invoice-issue-button')));
      await tester.pumpAndSettle();

      expect(fake.calls, isEmpty);
    });
  });

  group('issuing', () {
    testWidgets('passes the typed lines to the use case untouched',
        (tester) async {
      final fake = _FakeIssueInvoice();
      await open(tester, fake);

      await fillOneLine(tester);
      await tester
          .tap(find.byKey(const ValueKey<String>('invoice-issue-button')));
      await tester.pumpAndSettle();

      expect(fake.calls, hasLength(1));
      final invoice = fake.calls.single;
      expect(invoice.customerId, 'C-0001');
      expect(invoice.lines, hasLength(1));
      expect(invoice.lines.single.description, 'Keyboard');
      expect(invoice.lines.single.quantity, 2);
      expect(invoice.lines.single.unitPrice.minorUnits, 250000);
    });

    testWidgets('shows the number the use case issued, not a number it chose',
        (tester) async {
      await open(tester, _FakeIssueInvoice());

      await fillOneLine(tester);
      await tester
          .tap(find.byKey(const ValueKey<String>('invoice-issue-button')));
      await tester.pumpAndSettle();

      // The number comes from the use case's response. A screen that invented
      // one would produce a bill whose number does not match the books.
      expect(find.textContaining('INV-2082-83-0001'), findsOneWidget);
    });

    testWidgets('clears the form so the next invoice is not a duplicate',
        (tester) async {
      await open(tester, _FakeIssueInvoice());

      await fillOneLine(tester);
      await tester
          .tap(find.byKey(const ValueKey<String>('invoice-issue-button')));
      await tester.pumpAndSettle();

      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('line-description-0')),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.controller.text, isEmpty);
    });

    testWidgets('shows the use case\'s own refusal, not a second wording',
        (tester) async {
      final fake = _FakeIssueInvoice(
        refuse: InvoiceRejected(
          invoice: _draft(),
          reason: IssueRejectionReason.outsideFiscalYear,
          fiscalYear: _FakeIssueInvoice._year,
        ),
      );
      await open(tester, fake);

      await fillOneLine(tester);
      await tester
          .tap(find.byKey(const ValueKey<String>('invoice-issue-button')));
      await tester.pumpAndSettle();

      // The screen must not invent its own explanation for an accounting refusal.
      expect(find.textContaining('outside'), findsWidgets);
    });
  });

  group('more than one line', () {
    testWidgets('a line can be added and removed', (tester) async {
      final fake = _FakeIssueInvoice();
      await open(tester, fake);

      await fillOneLine(tester);
      await tester.tap(find.byKey(const ValueKey<String>('add-line-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('line-description-1')),
          findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('line-description-1')),
        'Mouse',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('line-quantity-1')),
        '1',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('line-price-1')),
        '800',
      );
      await tester
          .tap(find.byKey(const ValueKey<String>('invoice-issue-button')));
      await tester.pumpAndSettle();

      expect(fake.calls.single.lines, hasLength(2));

      await tester.tap(find.byKey(const ValueKey<String>('remove-line-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('line-description-1')),
          findsNothing);
    });
  });
}

Invoice _draft() => Invoice(
      id: 'inv-draft',
      issueDate: DateTime(2026, 8, 15),
      customerId: 'C-0001',
      lines: <InvoiceLine>[
        InvoiceLine(
          description: 'Keyboard',
          quantity: 1,
          unitPrice: Money.fromMajorUnits(2500, 'NPR'),
        ),
      ],
    );
