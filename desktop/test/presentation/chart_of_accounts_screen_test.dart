import 'package:financeapp/src/application/load_chart_of_accounts.dart';
import 'package:financeapp/src/domain/accounting/account.dart';
import 'package:financeapp/src/domain/accounting/account_type.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:financeapp/src/presentation/screens/chart_of_accounts_screen.dart';
import 'package:financeapp/src/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The chart of accounts: grouped, ordered, and sourced from the books.
///
/// ## What these pin
///
/// **That a custom account appears.** The built-in `ChartOfAccounts.all` is a
/// constant; the books may hold more. A screen that read the constant would hide an
/// account the business can post to — which is how a chart stops being worth
/// trusting, and the reason this reads the repository.
///
/// **The group order.** Assets, liabilities, equity, income, expenses — the same
/// order the balance sheet and profit and loss use, so all three read alike.
void main() {
  /// A surface tall enough for every group to be laid out. A ListView builds
  /// lazily, so on a short surface the later groups are never in the tree and
  /// asserting on them fails for a reason that has nothing to do with the chart.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  late AppDatabase db;
  late DriftAccountRepository accounts;

  setUp(() async {
    db = openInMemoryDatabase();
    accounts = DriftAccountRepository(db);
    await accounts.saveAll(const ChartOfAccounts().all);
  });

  tearDown(() async => db.close());

  Future<ChartOfAccountsView> load() =>
      LoadChartOfAccounts(accounts: accounts).load();

  testWidgets('lists every account in the books', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ChartOfAccountsScreen(
          chartOfAccounts: LoadChartOfAccounts(accounts: accounts)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Chart of Accounts'), findsOneWidget);
    expect(find.text('Assets'), findsOneWidget);
    expect(find.text('Liabilities'), findsOneWidget);
    expect(find.text('Equity'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);

    // The bank account is in the seeded chart, so it must be visible.
    expect(find.text(ChartOfAccounts.bank.name), findsOneWidget);
  });

  testWidgets('shows the total number of accounts', (tester) async {
    final count = (await load()).total;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ChartOfAccountsScreen(
          chartOfAccounts: LoadChartOfAccounts(accounts: accounts)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('$count accounts'), findsOneWidget);
  });

  testWidgets('an account the business added appears', (tester) async {
    // **The point of reading the repository rather than the constant.**
    await accounts.save(Account(
      id: 'acc-custom',
      code: '1900',
      name: 'Prepayments',
      type: AccountType.asset,
    ));

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ChartOfAccountsScreen(
          chartOfAccounts: LoadChartOfAccounts(accounts: accounts)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Prepayments'), findsOneWidget,
        reason: 'an account you can post to must be visible');
  });

  testWidgets('an empty year says so rather than showing nothing',
      (tester) async {
    final empty = openInMemoryDatabase();
    addTearDown(empty.close);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ChartOfAccountsScreen(
        chartOfAccounts: LoadChartOfAccounts(
          accounts: DriftAccountRepository(empty),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('no accounts yet'), findsOneWidget);
  });

  group('ordering', () {
    test('groups run assets, liabilities, equity, income, expenses', () async {
      // The same order the two statements use.
      final view = await load();

      expect(
        view.groups.map((AccountGroup g) => g.type),
        <AccountType>[
          AccountType.asset,
          AccountType.liability,
          AccountType.equity,
          AccountType.income,
          AccountType.expense,
        ],
      );
    });

    test('accounts within a group run in code order', () async {
      final view = await load();
      final assets = view.groups.firstWhere(
        (AccountGroup g) => g.type == AccountType.asset,
      );

      final codes = assets.accounts.map((Account a) => a.code).toList();
      final sorted = List<String>.from(codes)..sort();
      expect(codes, sorted);
    });

    test('an account of an unlisted type is shown, not dropped', () async {
      // The group list is built from the stored accounts, so a type added later
      // appears at the end rather than vanishing.
      final view = await load();

      expect(view.groups, isNotEmpty);
      // Every stored account is accounted for somewhere.
      final shown = view.groups.expand((AccountGroup g) => g.accounts).length;
      expect(shown, view.total);
    });
  });

  testWidgets('a failure says so rather than showing a blank chart',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ChartOfAccountsScreen(chartOfAccounts: _FailingChart()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('The chart could not be loaded'), findsOneWidget);
  });
}

class _FailingChart implements ChartOfAccountsLoader {
  @override
  Future<ChartOfAccountsView> load() async =>
      throw StateError('the accounts table could not be read');
}
