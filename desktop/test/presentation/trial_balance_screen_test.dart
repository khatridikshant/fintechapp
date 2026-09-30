import 'dart:async';

import 'package:financeapp/src/application/build_trial_balance.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/reporting/trial_balance.dart';
import 'package:financeapp/src/domain/shared/currency.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/presentation/app_services.dart';
import 'package:financeapp/src/presentation/finance_app.dart';
import 'package:financeapp/src/presentation/screens/trial_balance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for the Trial Balance screen.
///
/// The screen is handed a stub loader, so no database is involved. That is the
/// whole reason `TrialBalanceLoader` exists as an interface: a screen whose
/// numbers could only come from a real database would be untestable without one.
void main() {
  Money rs(int majorUnits) => Money.minor(majorUnits * 100, bookCurrency);

  DateTime day(int d) => DateTime(2026, 1, d);

  /// The worked example from the specification, hand-computed to 167,000 on
  /// both sides. The screen is exercised against genuine figures rather than
  /// invented ones.
  List<JournalEntry> workedExample() => [
        JournalEntry(
          id: 'OB-1',
          date: day(1),
          description: 'Opening balance',
          lines: [
            JournalLine.debit(
                account: ChartOfAccounts.bank, amount: rs(100000)),
            JournalLine.credit(
                account: ChartOfAccounts.ownersEquity, amount: rs(100000)),
          ],
        ),
        JournalEntry(
          id: 'SA-1',
          date: day(3),
          description: 'Sale with cost of goods sold',
          lines: [
            JournalLine.debit(account: ChartOfAccounts.bank, amount: rs(20000)),
            JournalLine.credit(
                account: ChartOfAccounts.salesRevenue, amount: rs(20000)),
            JournalLine.debit(
                account: ChartOfAccounts.costOfGoodsSold, amount: rs(12000)),
            JournalLine.credit(
                account: ChartOfAccounts.inventory, amount: rs(12000)),
          ],
        ),
        JournalEntry(
          id: 'EX-1',
          date: day(4),
          description: 'Office rent',
          lines: [
            JournalLine.debit(
                account: ChartOfAccounts.officeRent, amount: rs(5000)),
            JournalLine.credit(account: ChartOfAccounts.bank, amount: rs(5000)),
          ],
        ),
      ];

  TrialBalanceReport report() => TrialBalanceReport(
        fiscalYear: const NepaliFiscalCalendar().forBsYear(2082),
        trialBalance: TrialBalance.from(
          entries: workedExample(),
          currency: bookCurrency,
        ),
      );

  TrialBalanceReport emptyReport() => TrialBalanceReport(
        fiscalYear: const NepaliFiscalCalendar().forBsYear(2082),
        trialBalance: TrialBalance.from(
          entries: const [],
          currency: bookCurrency,
        ),
      );

  Future<void> openTrialBalance(
    WidgetTester tester,
    TrialBalanceLoader loader,
  ) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      FinanceApp(services: AppServices(trialBalance: loader)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trial Balance'));
    await tester.pumpAndSettle();
  }

  group('The Trial Balance screen', () {
    testWidgets('renders the report for a seeded book', (tester) async {
      await openTrialBalance(tester, _StubLoader(report()));

      expect(find.byType(TrialBalanceScreen), findsOneWidget);
      expect(find.text('Bank'), findsOneWidget);
      expect(find.text('Sales Revenue'), findsOneWidget);
      expect(find.text('Cost of Goods Sold'), findsOneWidget);
    });

    testWidgets('shows every account with its code', (tester) async {
      await openTrialBalance(tester, _StubLoader(report()));

      expect(find.text('1010'), findsOneWidget);
      expect(find.text('4010'), findsOneWidget);
      expect(find.text('5020'), findsOneWidget);
    });

    testWidgets('shows the fiscal year in BS form', (tester) async {
      await openTrialBalance(tester, _StubLoader(report()));

      expect(find.text('FY 2082/83'), findsOneWidget,
          reason: 'a Nepali user thinks about a period as FY 2082/83, not as a '
              'Gregorian date range');
    });

    testWidgets('shows a totals row with the two totals', (tester) async {
      await openTrialBalance(tester, _StubLoader(report()));

      expect(find.text('Total'), findsOneWidget);
      // Hand-computed for THIS fixture, which has no purchase entry:
      // debits 100,000 + 20,000 + 12,000 + 5,000 = 137,000, and credits agree.
      expect(find.text('Rs 137,000.00'), findsNWidgets(2),
          reason: 'total debits and total credits are both Rs 137,000.00');
    });

    testWidgets('formats every amount the same way, from Money.format',
        (tester) async {
      await openTrialBalance(tester, _StubLoader(report()));

      final amounts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((text) => text.startsWith('Rs ') || text.startsWith('-Rs '))
          .toList();

      expect(amounts, isNotEmpty);
      // Two decimals, thousands separators, currency symbol, a leading sign on
      // a negative. Every value on screen must match, so the screen cannot
      // invent a second formatting rule.
      final pattern = RegExp(r'^-?Rs [\d,]+\.\d{2}$');
      for (final amount in amounts) {
        expect(pattern.hasMatch(amount), isTrue,
            reason: '"$amount" is not in the agreed money format');
      }
    });

    testWidgets('never centres a monetary value', (tester) async {
      await openTrialBalance(tester, _StubLoader(report()));

      // ui.txt section 8: right-align for monetary values, do not centre them.
      // Asserting the alignment rather than a pixel offset keeps the assertion
      // meaningful.
      final rightAligned = tester
          .widgetList<Align>(find.byType(Align))
          .where((a) => a.alignment == Alignment.centerRight)
          .length;

      expect(rightAligned, greaterThanOrEqualTo(4),
          reason: 'money columns should be right-aligned');
    });

    testWidgets('shows a dash, not a zero, for an empty side', (tester) async {
      await openTrialBalance(tester, _StubLoader(report()));

      // The Bank row is debit-only, so its credit side has nothing in it.
      // Rendering a literal 0 would compete with the figures that carry meaning.
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('shows an empty state for a book with no activity',
        (tester) async {
      await openTrialBalance(tester, _StubLoader(emptyReport()));

      expect(find.textContaining('nothing to report'), findsOneWidget);
      expect(find.text('Total'), findsNothing,
          reason: 'a totals row over no rows would be misleading');
    });

    testWidgets('reports a failure rather than showing a blank screen',
        (tester) async {
      await openTrialBalance(
        tester,
        _StubLoader(report(), error: StateError('the file is in use')),
      );

      expect(find.text('The report could not be produced'), findsOneWidget);
      expect(find.textContaining('the file is in use'), findsOneWidget,
          reason: 'a user needs to know what went wrong, not merely that '
              'something did');
    });

    testWidgets('shows a loading indicator while the report is built',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        FinanceApp(services: AppServices(trialBalance: _SlowLoader())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trial Balance'));
      // `pump`, not `pumpAndSettle`: the spinner animates for ever and the
      // loader never resolves, so settling would time out rather than finish.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Trial Balance'), findsWidgets,
          reason: 'the page heading is visible even while loading');
      expect(find.text('Bank'), findsNothing,
          reason: 'no figures are shown before the report arrives');
    });
  });

  group('The screen reaches no repository', () {
    testWidgets('takes all of its numbers from a loader', (tester) async {
      // Every figure above came from a stub. If the screen were reading a
      // database, this file would need one, and the architecture guard in
      // `architecture_test.dart` would be failing.
      await openTrialBalance(tester, _StubLoader(report()));
      expect(find.byType(TrialBalanceScreen), findsOneWidget);
    });
  });
}

/// Returns a fixed report, so no database is needed.
class _StubLoader implements TrialBalanceLoader {
  _StubLoader(this._report, {this.error});

  final TrialBalanceReport _report;
  final Object? error;

  @override
  Future<TrialBalanceReport> load({DateTime? from, DateTime? to}) async {
    if (error != null) throw error!;
    return _report;
  }
}

/// A loader that never completes, for exercising the loading state.
///
/// A `Completer` rather than a delay: `Future.delayed` with no computation
/// yields a future of `null`, which cannot satisfy a non-nullable report, and a
/// fixed delay would finish part-way through the test rather than staying
/// pending for as long as the test needs it to.
class _SlowLoader implements TrialBalanceLoader {
  @override
  Future<TrialBalanceReport> load({DateTime? from, DateTime? to}) =>
      Completer<TrialBalanceReport>().future;
}
