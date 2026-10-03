import 'package:financeapp/src/application/build_profit_and_loss.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:financeapp/src/presentation/screens/profit_and_loss_screen.dart';
import 'package:financeapp/src/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two report screens, driven through the real use cases and a real database.
///
/// The figures are the same hand-computed ones as the use-case tests: capital
/// Rs 100,000, sales Rs 20,000, rent Rs 5,000 — net profit Rs 15,000, assets
/// Rs 115,000.
///
/// What these add is that the **screen** tells the user the truth: a loss is
/// labelled a loss, a negative figure is coloured, and a report that cannot be
/// produced says so instead of rendering nothing.
void main() {
  const npr = 'NPR';
  final fiscalYear = const NepaliFiscalCalendar().forBsYear(2082);

  late AppDatabase db;
  late DriftJournalRepository journal;

  setUp(() async {
    db = openInMemoryDatabase();
    journal = DriftJournalRepository(db);
    await DriftAccountRepository(db).saveAll(const ChartOfAccounts().all);
  });

  tearDown(() async => db.close());

  Money rs(int majorUnits) => Money.minor(majorUnits * 100, npr);

  Future<void> seedProfit() async {
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
      description: 'Cash sale',
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

  Widget app(Widget child) => MaterialApp(
        theme: AppTheme.light(),
        home: child,
      );

  testWidgets('profit and loss shows income, expenses and the result',
      (tester) async {
    await seedProfit();

    await tester.pumpWidget(app(ProfitAndLossScreen(
      profitAndLoss: BuildProfitAndLoss(
        fiscalYear: fiscalYear,
        journal: journal,
        chart: const ChartOfAccounts().all,
      ),
      fiscalYearLabel: fiscalYear.label,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Profit & Loss'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Net profit'), findsOneWidget);
    expect(find.text('Rs 20,000.00'), findsWidgets);
    expect(find.text('Rs 5,000.00'), findsWidgets);
    expect(find.text('Rs 15,000.00'), findsOneWidget);
  });

  testWidgets('a loss is labelled a loss, not a negative "net profit"',
      (tester) async {
    // **The point of this test.** A figure of Rs -7,000 labelled "Net profit" is
    // contradictory, and a reader who scans only the label believes the opposite
    // of the truth.
    await journal.append(JournalEntry(
      id: 'RENT',
      date: DateTime(2026, 3, 8),
      description: 'Rent and nothing else',
      lines: <JournalLine>[
        JournalLine.debit(
            account: ChartOfAccounts.officeRent, amount: rs(7000)),
        JournalLine.credit(account: ChartOfAccounts.bank, amount: rs(7000)),
      ],
    ));

    await tester.pumpWidget(app(ProfitAndLossScreen(
      profitAndLoss: BuildProfitAndLoss(
        fiscalYear: fiscalYear,
        journal: journal,
        chart: const ChartOfAccounts().all,
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Net loss'), findsOneWidget);
    expect(find.text('Net profit'), findsNothing);
  });

  testWidgets('an empty year says so rather than showing a blank page',
      (tester) async {
    await tester.pumpWidget(app(ProfitAndLossScreen(
      profitAndLoss: BuildProfitAndLoss(
        fiscalYear: fiscalYear,
        journal: journal,
        chart: const ChartOfAccounts().all,
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Net profit'), findsOneWidget);
    expect(find.text('Nothing recorded'), findsNWidgets(2),
        reason: 'both income and expenses are empty, and both should say so');
  });

  testWidgets('balance sheet shows both sides and the result', (tester) async {
    await seedProfit();

    await tester.pumpWidget(app(BalanceSheetScreen(
      balanceSheet: BuildBalanceSheet(
        fiscalYear: fiscalYear,
        journal: journal,
        chart: const ChartOfAccounts().all,
      ),
      fiscalYearLabel: fiscalYear.label,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Balance Sheet'), findsOneWidget);
    expect(find.text('Assets'), findsOneWidget);
    expect(find.text('Liabilities'), findsOneWidget);
    expect(find.text('Equity'), findsOneWidget);
    expect(find.text('Result for the period'), findsOneWidget);
    // Hand-computed: bank holds 100,000 + 20,000 - 5,000.
    // **Not indsOneWidget.** With a single asset the bank line and the assets
    // total show the same figure, and that duplication is correct -- asserting one
    // would have made this test fail on a perfectly good statement.
    expect(find.text('Rs 115,000.00'), findsWidgets);
    expect(find.text('Rs 15,000.00'), findsWidgets);
  });

  testWidgets('a balance sheet that cannot be produced says why',
      (tester) async {
    // The failure path a user must never dismiss. Rendered as plain text rather
    // than a blank page or a spinner that never resolves.
    await tester.pumpWidget(app(BalanceSheetScreen(
      balanceSheet: _FailingBalanceSheet(),
    )));
    await tester.pumpAndSettle();

    expect(find.text('This report could not be produced'), findsOneWidget);
    expect(find.textContaining('does not balance'), findsOneWidget);
  });
}

/// A balance sheet that cannot balance, standing in for the real failure.
class _FailingBalanceSheet implements BalanceSheetLoader {
  @override
  Future<Never> load({DateTime? to}) async =>
      throw StateError('Assets Rs 115,000.00 does not balance against '
          'liabilities and equity of Rs 100,000.00');
}
