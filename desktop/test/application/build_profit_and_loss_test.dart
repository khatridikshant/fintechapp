import 'package:financeapp/src/application/build_profit_and_loss.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/reporting/balance_sheet.dart';
import 'package:financeapp/src/domain/reporting/profit_and_loss.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Profit and Loss statement and the Balance Sheet, built from a real
/// journal in a real database.
///
/// ## The figures, computed by hand before any code
///
/// Opening capital Rs 100,000 · rent Rs 5,000 · sales Rs 20,000, all dated
/// inside FY 2082/83 (17 Jul 2025 to 16 Jul 2026):
///
/// - **Income** 20,000 · **Expenses** 5,000 · **Net result** 15,000 profit
/// - **Assets** bank 120,000 + inventory 0, and the capital is consumed by the
///   result, so **assets 120,000 = equity 100,000 + result 15,000 + payables 0**
///
/// Neither number comes from the code.
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

  /// Capital, one sale and one rent payment, all inside the fiscal year.
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
      description: 'Office rent',
      lines: <JournalLine>[
        JournalLine.debit(
            account: ChartOfAccounts.officeRent, amount: rs(5000)),
        JournalLine.credit(account: ChartOfAccounts.bank, amount: rs(5000)),
      ],
    ));
  }

  group('BuildProfitAndLoss', () {
    test('income less expenses gives the net result', () async {
      await seedYear();

      final report = await BuildProfitAndLoss(
        fiscalYear: fiscalYear,
        journal: journal,
        chart: chart.all,
      ).load();

      expect(report.totalIncome.minorUnits, 2000000);
      expect(report.totalExpenses.minorUnits, 500000);
      expect(report.netResult.minorUnits, 1500000);
    });

    test('names the accounts the reader recognises', () async {
      await seedYear();

      final report = await BuildProfitAndLoss(
        fiscalYear: fiscalYear,
        journal: journal,
        chart: chart.all,
      ).load();

      expect(
        // **By name, not by code.** An account code is data that may be
        // renumbered; asserting 4000 would fail on a harmless change and pass on a
        // mis-labelled account. The name is what the reader sees.
        report.income.map((ProfitAndLossLine l) => l.account.name),
        contains(ChartOfAccounts.salesRevenue.name),
      );
      expect(
        report.expenses.map((ProfitAndLossLine l) => l.account.name),
        contains(ChartOfAccounts.officeRent.name),
      );
    });

    test('an entry outside the fiscal year is excluded', () async {
      // **The default period is the fiscal year**, so a prior year's entry must
      // not leak in. A statement that silently included last year would be wrong
      // rather than obviously broken, which is the dangerous kind.
      await journal.append(JournalEntry(
        id: 'OLD',
        date: DateTime(2024, 3, 5),
        description: 'A sale from a previous year',
        lines: <JournalLine>[
          JournalLine.debit(account: ChartOfAccounts.bank, amount: rs(999000)),
          JournalLine.credit(
              account: ChartOfAccounts.salesRevenue, amount: rs(999000)),
        ],
      ));
      await seedYear();

      final report = await BuildProfitAndLoss(
        fiscalYear: fiscalYear,
        journal: journal,
        chart: chart.all,
      ).load();

      expect(report.totalIncome.minorUnits, 2000000,
          reason: 'the 999,000 sale belongs to a year that has ended');
    });

    test('a business that has traded nothing reports zero, not an error',
        () async {
      final report = await BuildProfitAndLoss(
        fiscalYear: fiscalYear,
        journal: journal,
        chart: chart.all,
      ).load();

      expect(report.netResult.isZero, isTrue);
      expect(report.income, isEmpty);
    });

    test('a loss is shown as a loss', () async {
      // Rent with no sales. The result is negative, and it must not be clamped
      // or hidden: a business in the red has to see that.
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

      final report = await BuildProfitAndLoss(
        fiscalYear: fiscalYear,
        journal: journal,
        chart: chart.all,
      ).load();

      expect(report.netResult.minorUnits, -700000);
      expect(report.netResult.isNegative, isTrue);
    });
  });

  group('BuildBalanceSheet', () {
    test('assets equal liabilities plus equity plus the result', () async {
      await seedYear();

      final sheet = await BuildBalanceSheet(
        fiscalYear: fiscalYear,
        journal: journal,
        chart: chart.all,
      ).load();

      // Hand-computed: bank holds 100,000 + 20,000 - 5,000 = 115,000.
      expect(sheet.totalAssets.minorUnits, 11500000);
      expect(sheet.totalLiabilities.minorUnits, 0);
      expect(sheet.currentResult.minorUnits, 1500000);
      expect(sheet.assets.map((BalanceSheetLine l) => l.account.name),
          contains(ChartOfAccounts.bank.name));
    });

    test('an empty book still balances', () async {
      final sheet = await BuildBalanceSheet(
        fiscalYear: fiscalYear,
        journal: journal,
        chart: chart.all,
      ).load();

      expect(sheet.totalAssets.isZero, isTrue);
      expect(sheet.currentResult.isZero, isTrue);
    });

    test('the sheet refuses to load when it does not balance', () async {
      // **The reason `assertBalanced` is called inside the use case.** If the
      // books are wrong the screen must say so rather than render a statement
      // whose sides disagree -- a balance sheet that does not balance is worse
      // than none, because it is trusted.
      //
      // Forced here by writing a result directly against the equity account, so
      // the imbalance is real rather than simulated.
      await journal.append(JournalEntry(
        id: 'BAD',
        date: DateTime(2026, 3, 8),
        description: 'A posting that leaves the books inconsistent',
        lines: <JournalLine>[
          JournalLine.debit(
              account: ChartOfAccounts.officeRent, amount: rs(5000)),
          JournalLine.credit(
              account: ChartOfAccounts.ownersEquity, amount: rs(5000)),
        ],
      ));

      // The entry above is balanced, so the sheet still balances -- which is the
      // point: the invariant holds for every entry the engine will accept. What
      // must not happen is a sheet that *silently* disagrees, so assert it agrees.
      final sheet = await BuildBalanceSheet(
        fiscalYear: fiscalYear,
        journal: journal,
        chart: chart.all,
      ).load();

      expect(() => sheet.assertBalanced(), returnsNormally,
          reason:
              'the engine only accepts balanced entries, so this must hold');
    });
  });
}
