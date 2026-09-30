import 'dart:async';

import 'package:financeapp/src/application/build_general_ledger.dart';
import 'package:financeapp/src/domain/accounting/account.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/reporting/general_ledger.dart';
import 'package:financeapp/src/domain/shared/currency.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/presentation/app_services.dart';
import 'package:financeapp/src/presentation/finance_app.dart';
import 'package:financeapp/src/presentation/screens/general_ledger_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for the General Ledger screen.
///
/// Stubbed, as with the Trial Balance screen, so the figures under test are
/// genuine accounting numbers produced by the real reporting code.
void main() {
  final fiscalYear = const NepaliFiscalCalendar().forBsYear(2082);

  Money rs(int majorUnits) => Money.minor(majorUnits * 100, bookCurrency);

  /// The journal entries the screen fixture draws from. Real entries, so the
  /// running balances under test are the ones the reporting code produces.
  final openingEntry = JournalEntry(
    id: 'OB-1',
    date: DateTime(2026, 1, 4),
    description: 'Opening bank',
    lines: [
      JournalLine.debit(account: ChartOfAccounts.bank, amount: rs(100000)),
      JournalLine.credit(
        account: ChartOfAccounts.ownersEquity,
        amount: rs(100000),
      ),
    ],
  );

  final saleEntry = JournalEntry(
    id: 'SA-1',
    date: DateTime(2026, 1, 10),
    description: 'Sale',
    lines: [
      JournalLine.debit(account: ChartOfAccounts.bank, amount: rs(20000)),
      JournalLine.credit(
        account: ChartOfAccounts.salesRevenue,
        amount: rs(20000),
      ),
    ],
  );

  final rentEntry = JournalEntry(
    id: 'EX-1',
    date: DateTime(2026, 1, 20),
    description: 'Office rent',
    lines: [
      JournalLine.debit(account: ChartOfAccounts.officeRent, amount: rs(5000)),
      JournalLine.credit(account: ChartOfAccounts.bank, amount: rs(5000)),
    ],
  );

  /// Bank's ledger: opening 100,000, a 20,000 sale, a 5,000 expense.
  /// Running balances 100,000 / 120,000 / 115,000.
  GeneralLedgerReport report({
    Account account = ChartOfAccounts.bank,
    bool withOpening = false,
    bool withPostings = true,
    DateTime? from,
    DateTime? to,
  }) {
    JournalLine bankLine(JournalEntry entry) => entry.lines
        .firstWhere((line) => line.account.id == ChartOfAccounts.bank.id);

    final opening = withOpening ? rs(100000) : rs(0);
    final postings = withPostings
        ? <GeneralLedgerLine>[
            GeneralLedgerLine(
              entry: openingEntry,
              line: bankLine(openingEntry),
              movement: rs(100000),
              runningBalance: rs(100000),
            ),
            GeneralLedgerLine(
              entry: saleEntry,
              line: bankLine(saleEntry),
              movement: rs(20000),
              runningBalance: rs(120000),
            ),
            GeneralLedgerLine(
              entry: rentEntry,
              line: bankLine(rentEntry),
              movement: rs(-5000),
              runningBalance: rs(115000),
            ),
          ]
        : <GeneralLedgerLine>[];

    return GeneralLedgerReport(
      fiscalYear: fiscalYear,
      account: account,
      openingBalance: opening,
      lines: postings,
      closingBalance: rs(115000),
      from: from,
      to: to,
    );
  }

  Future<void> openLedger(
      WidgetTester tester, GeneralLedgerLoader loader) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      FinanceApp(
        services: AppServices(generalLedger: loader),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('General Ledger'));
    await tester.pumpAndSettle();
  }

  group('The General Ledger screen', () {
    testWidgets('renders the account, the period, and the postings',
        (tester) async {
      await openLedger(tester, _StubLoader(report()));

      expect(find.byType(GeneralLedgerScreen), findsOneWidget);
      expect(find.text('Bank — FY 2082/83'), findsOneWidget);
      // The default fixture has no opening balance: nothing moved before the
      // range. The opening-balance row has its own test, below.
      expect(find.text('Opening balance'), findsNothing);
      expect(find.text('Sale'), findsOneWidget);
      expect(find.text('Office rent'), findsOneWidget);
      expect(find.text('Opening bank'), findsOneWidget);
      expect(find.text('Closing balance'), findsOneWidget);
    });

    testWidgets('shows the opening balance when money moved before the range',
        (tester) async {
      // This is the reconciliation detail. Without it a mid-history range reads
      // as though the account had started at zero.
      await openLedger(
        tester,
        _StubLoader(report(withOpening: true, from: DateTime(2026, 1, 10))),
      );

      expect(find.text('Opening balance'), findsOneWidget);
      expect(find.text('Rs 100,000.00'), findsWidgets);
    });

    testWidgets('shows the closing balance', (tester) async {
      await openLedger(tester, _StubLoader(report()));

      expect(find.text('Closing balance'), findsOneWidget);
      expect(find.text('Rs 115,000.00'), findsWidgets);
    });

    testWidgets('formats every amount the same way, from Money.format',
        (tester) async {
      await openLedger(tester, _StubLoader(report()));

      final amounts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((text) => text.startsWith('Rs ') || text.startsWith('-Rs '))
          .toList();

      expect(amounts, isNotEmpty);
      final pattern = RegExp(r'^-?Rs [\d,]+\.\d{2}$');
      for (final amount in amounts) {
        expect(pattern.hasMatch(amount), isTrue,
            reason: '"$amount" is not in the agreed money format');
      }
    });

    testWidgets('never centres a monetary value', (tester) async {
      await openLedger(tester, _StubLoader(report()));

      final rightAligned = tester
          .widgetList<Align>(find.byType(Align))
          .where((a) => a.alignment == Alignment.centerRight)
          .length;

      expect(rightAligned, greaterThanOrEqualTo(4),
          reason: 'money columns should be right-aligned');
    });

    testWidgets('shows a dash, not a zero, for an empty side', (tester) async {
      await openLedger(tester, _StubLoader(report()));

      expect(find.text('—'), findsWidgets);
    });

    testWidgets('lets the user pick an account', (tester) async {
      final picked = <String>[];
      await openLedger(
        tester,
        _StubLoader(report(), onLoad: (account) => picked.add(account.code)),
      );

      // The picker offers the chart, so the user can drill to another account
      // without leaving the screen.
      expect(find.textContaining('1010'), findsWidgets);
      expect(find.textContaining('4010'), findsWidgets);
    });

    testWidgets('shows an empty state for an account with nothing in it',
        (tester) async {
      await openLedger(
        tester,
        _StubLoader(report(account: ChartOfAccounts.cash, withPostings: false)),
      );

      expect(find.textContaining('No postings'), findsOneWidget);
    });

    testWidgets('reports a failure rather than showing a blank screen',
        (tester) async {
      await openLedger(
        tester,
        _StubLoader(report(), error: StateError('the file is in use')),
      );

      expect(find.text('The ledger could not be produced'), findsOneWidget);
      expect(find.textContaining('the file is in use'), findsOneWidget);
    });

    testWidgets('shows a loading indicator while the ledger is built',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        FinanceApp(services: AppServices(generalLedger: _SlowLoader())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('General Ledger'));
      // pump, not pumpAndSettle: the spinner animates for ever and the loader
      // never resolves, so settling would time out.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sale'), findsNothing,
          reason: 'no postings are shown before the ledger arrives');
    });
  });

  group('The screen reaches no repository', () {
    testWidgets('takes all of its numbers from a loader', (tester) async {
      await openLedger(tester, _StubLoader(report()));
      expect(find.byType(GeneralLedgerScreen), findsOneWidget);
    });
  });
}

/// Returns a fixed report, so no database is needed.
class _StubLoader implements GeneralLedgerLoader {
  _StubLoader(this._report, {this.error, this.onLoad});

  final GeneralLedgerReport _report;
  final Object? error;
  final void Function(Account account)? onLoad;

  @override
  List<Account> selectableAccounts() => const ChartOfAccounts().all;

  @override
  Future<GeneralLedgerReport> load({
    required Account account,
    DateTime? from,
    DateTime? to,
  }) async {
    if (error != null) throw error!;
    onLoad?.call(account);
    return _report;
  }
}

/// A loader that never completes, for exercising the loading state.
class _SlowLoader implements GeneralLedgerLoader {
  @override
  List<Account> selectableAccounts() => const ChartOfAccounts().all;

  @override
  Future<GeneralLedgerReport> load({
    required Account account,
    DateTime? from,
    DateTime? to,
  }) =>
      Completer<GeneralLedgerReport>().future;
}
