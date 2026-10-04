import 'package:financeapp/src/application/build_reports.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/accounting/journal_repository.dart';
import 'package:financeapp/src/domain/billing/credit_note_repository.dart';
import 'package:financeapp/src/domain/billing/invoice_repository.dart';
import 'package:financeapp/src/domain/billing/issued_credit_note.dart';
import 'package:financeapp/src/domain/billing/issued_invoice.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/inventory/inventory_movement.dart';
import 'package:financeapp/src/domain/inventory/inventory_repository.dart';
import 'package:financeapp/src/domain/inventory/product.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/presentation/finance_app.dart';
import 'package:financeapp/src/presentation/app_services.dart';
import 'package:financeapp/src/presentation/screens/financial_reports_screen.dart';
import 'package:financeapp/src/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const npr = 'NPR';

Money rs(int majorUnits) => Money.minor(majorUnits * 100, npr);

final fiscalYear = const NepaliFiscalCalendar().forBsYear(2082);

/// A journal with one cash movement, hand-computed: opening 100,000, in 20,000,
/// out 5,000, closing 115,000.
class _Journal implements JournalRepository {
  @override
  Future<List<JournalEntry>> all() async => <JournalEntry>[
        JournalEntry(
          id: 'OB-1',
          date: DateTime(2026, 2, 1),
          description: 'Opening',
          lines: [
            JournalLine.debit(
                account: ChartOfAccounts.bank, amount: rs(100000)),
            JournalLine.credit(
                account: ChartOfAccounts.ownersEquity, amount: rs(100000)),
          ],
        ),
        JournalEntry(
          id: 'SA-1',
          date: DateTime(2026, 3, 5),
          description: 'Sale',
          lines: [
            JournalLine.debit(account: ChartOfAccounts.bank, amount: rs(20000)),
            JournalLine.credit(
                account: ChartOfAccounts.salesRevenue, amount: rs(20000)),
          ],
        ),
        JournalEntry(
          id: 'EX-1',
          date: DateTime(2026, 3, 8),
          description: 'Rent',
          lines: [
            JournalLine.debit(
                account: ChartOfAccounts.officeRent, amount: rs(5000)),
            JournalLine.credit(account: ChartOfAccounts.bank, amount: rs(5000)),
          ],
        ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget build(AppServices services) => FinanceApp(services: services);

AppServices servicesWith({
  JournalRepository? journal,
}) =>
    AppServices(
      cashFlow:
          BuildCashFlow(fiscalYear: fiscalYear, journal: journal ?? _Journal()),
      sales: BuildSalesSummary(
        fiscalYear: fiscalYear,
        invoices: _NoInvoices(),
        creditNotes: _NoCreditNotes(),
      ),
      inventoryReport: BuildInventorySummary(
        fiscalYear: fiscalYear,
        inventory: _NoStock(),
      ),
      categoryReport: BuildCategoryReport(
        fiscalYear: fiscalYear,
        inventory: _NoStock(),
      ),
      tax: BuildTaxSummary(
        fiscalYear: fiscalYear,
        invoices: _NoInvoices(),
        creditNotes: _NoCreditNotes(),
      ),
    );

/// Opens the reports screen from the shell's own navigation.
///
/// **Through the navigation, not by constructing the screen**, because the
/// question these tests answer is whether a user can reach the report -- not
/// merely whether the widget can draw itself.
Future<void> openReports(WidgetTester tester) async {
  final entry = find.text('Cash Flow');
  if (entry.evaluate().isEmpty) {
    throw TestFailure('the Reports navigation entry is missing');
  }
  await tester.tap(entry.first);
  await tester.pumpAndSettle();
}

/// Sizes the window so the whole navigation, including the Reports group, is on
/// screen. Without this the entry is laid out off-view and cannot be tapped.
void useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('opens on cash flow and shows the closing figure',
      (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(build(servicesWith()));
    await tester.pumpAndSettle();
    await openReports(tester);

    expect(find.text('Cash Flow'), findsWidgets);
    expect(find.text('Closing cash'), findsOneWidget);

// The figure the statement exists to deliver, and the one the use case test
    // computed by hand: 100,000 opening, 20,000 received, 5,000 paid,
    // 115,000 closing.
    expect(find.text('Rs 115,000.00'), findsOneWidget);
  });

  testWidgets('shows all four cash figures, not only the closing one',
      (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(build(servicesWith()));
    await tester.pumpAndSettle();
    await openReports(tester);

    expect(find.text('Opening cash'), findsOneWidget);
    expect(find.text('Received'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Closing cash'), findsOneWidget);
  });

  testWidgets('a cash flow with no detail rows is not shown as an empty book',
      (tester) async {
    // Cash flow has totals and no breakdown. Hiding the totals because the
    // breakdown was empty would look exactly like a business with no activity.
    useDesktopSurface(tester);
    await tester.pumpWidget(build(servicesWith()));
    await tester.pumpAndSettle();
    await openReports(tester);

    expect(find.text('Opening cash'), findsOneWidget);
    expect(find.textContaining('No cash has moved'), findsNothing);
  });

  testWidgets('says what a cash statement is, so it is not read as profit',
      (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(build(servicesWith()));
    await tester.pumpAndSettle();
    await openReports(tester);

    expect(find.textContaining('A cash statement'), findsOneWidget);
  });

  testWidgets('switching to sales shows net sales', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(build(servicesWith()));
    await tester.pumpAndSettle();
    await openReports(tester);

    await tester.tap(find.byKey(ValueKey('report-tab-sales')));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(find.text('Net sales'), findsOneWidget);
    expect(
        find.text('Nothing has been invoiced in this period.'), findsOneWidget);
  });

  testWidgets('switching to inventory shows the stock total', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(build(servicesWith()));
    await tester.pumpAndSettle();
    await openReports(tester);

    await tester.tap(find.byKey(ValueKey('report-tab-inventory')));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(find.text('Total stock value'), findsOneWidget);
  });

  testWidgets('the VAT report shows its rate and admits its own limit',
      (tester) async {
    // A VAT figure read without its rate is meaningless, and a figure that looks
    // complete when the purchase side is missing would mislead.
    useDesktopSurface(tester);
    await tester.pumpWidget(build(servicesWith()));
    await tester.pumpAndSettle();
    await openReports(tester);

    await tester.tap(find.byKey(ValueKey('report-tab-tax')));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(find.textContaining('13%'), findsOneWidget);
    expect(find.text('Net VAT payable'), findsOneWidget);
    expect(
        find.textContaining('no purchases have been recorded'), findsOneWidget);
  });

  testWidgets('can be opened directly on one report', (tester) async {
    // Each navigation entry opens the shared screen on its own report.
    // **Under the real theme**, because the screen reads `AppPalette` from the
    // theme and refuses to build without it. A bare `MaterialApp` would make this
    // test pass for a screen that cannot actually render in the application.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: FinancialReportsScreen(
          cashFlow: BuildCashFlow(fiscalYear: fiscalYear, journal: _Journal()),
          sales: BuildSalesSummary(
            fiscalYear: fiscalYear,
            invoices: _NoInvoices(),
            creditNotes: _NoCreditNotes(),
          ),
          inventory: BuildInventorySummary(
            fiscalYear: fiscalYear,
            inventory: _NoStock(),
          ),
          categoryReport: BuildCategoryReport(
            fiscalYear: fiscalYear,
            inventory: _NoStock(),
          ),
          tax: BuildTaxSummary(
            fiscalYear: fiscalYear,
            invoices: _NoInvoices(),
            creditNotes: _NoCreditNotes(),
          ),
          initialReport: FinancialReport.inventory,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Total stock value'), findsOneWidget);
  });
}

/// Stubs for the repositories the reports read.
///
/// Each reports nothing, which is a state the application reaches on its first
/// day and must handle without an error.
class _NoInvoices implements InvoiceRepository {
  @override
  Future<List<IssuedInvoice>> all() async => const <IssuedInvoice>[];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoCreditNotes implements CreditNoteRepository {
  @override
  Future<List<IssuedCreditNote>> all() async => const <IssuedCreditNote>[];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoStock implements InventoryRepository {
  @override
  Future<List<InventoryMovement>> allMovements() async =>
      const <InventoryMovement>[];
  @override
  Future<List<Product>> allProducts() async => const <Product>[];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
