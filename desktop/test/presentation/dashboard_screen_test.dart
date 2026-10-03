import 'package:financeapp/src/application/build_profit_and_loss.dart';
import 'package:financeapp/src/application/build_trial_balance.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:financeapp/src/presentation/screens/dashboard_screen.dart';
import 'package:financeapp/src/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The landing screen.
///
/// ## The figures, computed by hand
///
/// Capital Rs 100,000 · sales Rs 20,000 · rent Rs 5,000, all dated inside
/// FY 2082/83:
///
/// - Result for the period: **Rs 15,000** profit
/// - Total assets: **Rs 115,000**
/// - Debits posted: 100,000 + 20,000 + 5,000 = **Rs 125,000**
///
/// ## What these tests are actually for
///
/// A dashboard is the screen most likely to grow a "quick summary" figure that is
/// derived nowhere else and validated nowhere. **So the main assertion here is
/// negative**: the dashboard shows a figure it can source, and says so plainly when
/// it cannot, rather than showing a number that might be wrong.
void main() {
  const npr = 'NPR';
  final fiscalYear = const NepaliFiscalCalendar().forBsYear(2082);
  const chart = ChartOfAccounts();

  late AppDatabase db;
  late DriftJournalRepository journal;

  setUp(() async {
    db = openInMemoryDatabase();
    journal = DriftJournalRepository(db);
    await DriftAccountRepository(db).saveAll(chart.all);
  });

  tearDown(() async => db.close());

  Money rs(int majorUnits) => Money.minor(majorUnits * 100, npr);

  Future<void> seedYear() async {
    await journal.append(JournalEntry(
      id: 'OB',
      date: DateTime(2026, 3, 1),
      description: 'Opening capital',
      lines: <JournalLine>[
        JournalLine.debit(account: ChartOfAccounts.bank, amount: rs(100000)),
        JournalLine.credit(
            account: ChartOfAccounts.ownersEquity, amount: rs(100000)),
      ],
    ));
    await journal.append(JournalEntry(
      id: 'SA',
      date: DateTime(2026, 3, 5),
      description: 'Sale',
      lines: <JournalLine>[
        JournalLine.debit(account: ChartOfAccounts.bank, amount: rs(20000)),
        JournalLine.credit(
            account: ChartOfAccounts.salesRevenue, amount: rs(20000)),
      ],
    ));
    await journal.append(JournalEntry(
      id: 'EX',
      date: DateTime(2026, 3, 8),
      description: 'Rent',
      lines: <JournalLine>[
        JournalLine.debit(
            account: ChartOfAccounts.officeRent, amount: rs(5000)),
        JournalLine.credit(account: ChartOfAccounts.bank, amount: rs(5000)),
      ],
    ));
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: DashboardScreen(
        trialBalance: BuildTrialBalanceTotals(
          BuildTrialBalance(
            fiscalYear: fiscalYear,
            journal: journal,
          ),
        ),
        profitAndLoss: BuildProfitAndLoss(
          fiscalYear: fiscalYear,
          journal: journal,
          chart: chart.all,
        ),
        balanceSheet: BuildBalanceSheet(
          fiscalYear: fiscalYear,
          journal: journal,
          chart: chart.all,
        ),
        fiscalYearLabel: fiscalYear.label,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the result and total assets, from real reports',
      (tester) async {
    await seedYear();
    await pump(tester);

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Result for the period'), findsOneWidget);
    expect(find.text('Rs 15,000.00'), findsWidgets);
    expect(find.text('Total assets'), findsOneWidget);
    expect(find.text('Rs 115,000.00'), findsOneWidget);
  });

  testWidgets('shows one ledger figure, not two that must be equal',
      (tester) async {
    // Debits and credits are equal by construction. Showing both would be noise
    // that invites the reader to wonder whether they differ.
    await seedYear();
    await pump(tester);

    expect(find.text('Posted to the ledger'), findsOneWidget);
    expect(find.text('Rs 125,000.00'), findsOneWidget);
  });

  testWidgets('says which figures are not built rather than inventing them',
      (tester) async {
    // **The negative assertion that matters.** A dashboard is where it is most
    // tempting to add a "quick" figure derived nowhere else. This states that the
    // honest alternative is to say so.
    await seedYear();
    await pump(tester);

    expect(find.textContaining('deliberately does not show'), findsOneWidget);
  });

  testWidgets('an empty year reports zero, not an error', (tester) async {
    await pump(tester);

    expect(find.text('Result for the period'), findsOneWidget);
    expect(find.text('Rs 0.00'), findsWidgets);
  });

  testWidgets('one failing report does not take the dashboard down',
      (tester) async {
    // **Each tile loads independently.** A landing screen that shows nothing
    // because one report failed is worse than one showing two figures and one
    // honest failure.
    await seedYear();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: DashboardScreen(
        trialBalance: BuildTrialBalanceTotals(
          BuildTrialBalance(fiscalYear: fiscalYear, journal: journal),
        ),
        profitAndLoss: _FailingResult(),
        balanceSheet: BuildBalanceSheet(
          fiscalYear: fiscalYear,
          journal: journal,
          chart: chart.all,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Could not be produced'), findsOneWidget);
    // The balance sheet still rendered.
    expect(find.text('Total assets'), findsOneWidget);
    expect(find.text('Rs 115,000.00'), findsOneWidget);
  });
}

class _FailingResult implements ProfitAndLossLoader {
  @override
  Future<Never> load({DateTime? from, DateTime? to}) async =>
      throw StateError('the journal could not be read');
}
