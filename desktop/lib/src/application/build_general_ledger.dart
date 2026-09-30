import '../domain/accounting/account.dart';
import '../domain/accounting/chart_of_accounts.dart';
import '../domain/accounting/journal_repository.dart';
import '../domain/fiscal/fiscal_year.dart';
import '../domain/reporting/general_ledger.dart';
import '../domain/shared/currency.dart';
import '../domain/shared/money.dart';

/// One account's ledger, with everything the screen needs to draw it.
class GeneralLedgerReport {
  const GeneralLedgerReport({
    required this.fiscalYear,
    required this.account,
    required this.openingBalance,
    required this.lines,
    required this.closingBalance,
    this.from,
    this.to,
  });

  final FiscalYear fiscalYear;

  final Account account;

  /// Balance brought forward from before the reporting range.
  ///
  /// **This must be shown.** If a range starts after the account's first
  /// posting and the opening balance is hidden, the running balance reads as
  /// though the account started at zero, and the closing figure silently
  /// disagrees with the trial balance for the same period. That is a
  /// reconciliation failure a user would have no way to detect.
  final Money openingBalance;

  /// Postings in date order, each with the balance after it.
  final List<GeneralLedgerLine> lines;

  /// Balance after the last posting in the range. Equals the account's balance
  /// on the trial balance, provided the range reaches the present.
  final Money closingBalance;

  final DateTime? from;
  final DateTime? to;

  bool get isEmpty => lines.isEmpty;

  /// True when money moved before the range, so there is something to bring
  /// forward even though no posting is listed.
  bool get hasOpeningBalance => !openingBalance.isZero;

  /// The heading, for example `Bank — FY 2082/83` or
  /// `Bank — FY 2082/83, 1 Jul 2026 to 30 Sep 2026`.
  String get periodLabel {
    final range = from != null && to != null
        ? ', ${_short(from!)} to ${_short(to!)}'
        : '';
    return '${account.name} — ${fiscalYear.label}$range';
  }

  static String _short(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

/// A report for a range of dates, built by a loader.
///
/// An interface, so a screen can be given a stub. This is what lets the widget
/// tests exercise the screen without a database.
abstract interface class GeneralLedgerLoader {
  /// The accounts the user may choose to view, in a sensible order.
  ///
  /// On the interface rather than only on the implementation, because choosing
  /// which account to show is something the screen needs and the use case is the
  /// only thing that knows what accounts exist.
  List<Account> selectableAccounts();

  Future<GeneralLedgerReport> load({
    required Account account,
    DateTime? from,
    DateTime? to,
  });
}

/// Builds the general ledger for one account.
class BuildGeneralLedger implements GeneralLedgerLoader {
  const BuildGeneralLedger({
    required this.fiscalYear,
    required this.journal,
    required this.chart,
    this.currency = bookCurrency,
  });

  final FiscalYear fiscalYear;

  final JournalRepository journal;

  /// Used to list the accounts the screen may choose from.
  final ChartOfAccounts chart;

  final String currency;

  @override
  List<Account> selectableAccounts() => chart.all;

  @override
  Future<GeneralLedgerReport> load({
    required Account account,
    DateTime? from,
    DateTime? to,
  }) async {
    final entries = await journal.all();

    final ledger = GeneralLedger.forAccount(
      account: account,
      entries: entries,
      currency: currency,
      from: from,
      to: to,
    );

    return GeneralLedgerReport(
      fiscalYear: fiscalYear,
      account: account,
      openingBalance: ledger.openingBalance,
      lines: ledger.lines,
      closingBalance: ledger.closingBalance,
      from: from,
      to: to,
    );
  }
}
