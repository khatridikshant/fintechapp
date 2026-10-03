import '../domain/fiscal/fiscal_year.dart';
import '../domain/reporting/balance_sheet.dart';
import '../domain/reporting/profit_and_loss.dart';
import 'package:financeapp/src/domain/accounting/account.dart';
import 'package:financeapp/src/domain/accounting/journal_repository.dart';
import 'package:financeapp/src/domain/shared/currency.dart';

/// Builds the Profit and Loss statement.
///
/// ## Why a use case and not a screen
///
/// `docs/AI_RULES.md` forbids accounting logic in presentation code, and the
/// report types are pure functions over journal entries — so something has to
/// supply those entries and decide the period. That something is this, and it is
/// the same shape as `BuildTrialBalance` so the three reports behave alike.
abstract interface class ProfitAndLossLoader {
  Future<ProfitAndLoss> load({DateTime? from, DateTime? to});
}

/// Builds the Balance Sheet.
///
/// ## The one rule that matters
///
/// A balance sheet that does not balance is not a balance sheet, so this calls
/// [BalanceSheet.assertBalanced] before returning. A failure here is a real
/// defect in the books, and the screen shows it rather than rendering a statement
/// that looks authoritative and is wrong.
abstract interface class BalanceSheetLoader {
  Future<BalanceSheet> load({DateTime? to});
}

class BuildProfitAndLoss implements ProfitAndLossLoader {
  const BuildProfitAndLoss({
    required this.fiscalYear,
    required this.journal,
    this.chart = const <Account>[],
    this.currency = bookCurrency,
  });

  final FiscalYear fiscalYear;
  final JournalRepository journal;

  /// The chart, used to label lines that carry no account of their own.
  final List<Account> chart;

  final String currency;

  @override
  Future<ProfitAndLoss> load({DateTime? from, DateTime? to}) async {
    // **The period defaults to the fiscal year**, not to "everything". A report
    // with no bounds would silently include a prior year's entries if the books
    // ever held more than one, which is the class of bug that makes a statement
    // quietly wrong rather than obviously broken.
    return ProfitAndLoss.from(
      entries: await journal.all(),
      currency: currency,
      from: from ?? fiscalYear.startDate,
      to: to,
      chart: chart,
    );
  }
}

class BuildBalanceSheet implements BalanceSheetLoader {
  const BuildBalanceSheet({
    required this.fiscalYear,
    required this.journal,
    this.chart = const <Account>[],
    this.currency = bookCurrency,
  });

  final FiscalYear fiscalYear;
  final JournalRepository journal;
  final List<Account> chart;
  final String currency;

  @override
  Future<BalanceSheet> load({DateTime? to}) async {
    final sheet = BalanceSheet.from(
      entries: await journal.all(),
      currency: currency,
      to: to ?? fiscalYear.endDate,
      chart: chart,
    );

    // Throws rather than returning a statement that does not balance. There is
    // no "show it anyway": a balance sheet whose sides differ is worse than no
    // balance sheet, because it is trusted.
    sheet.assertBalanced();

    return sheet;
  }
}
