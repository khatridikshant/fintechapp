import '../domain/accounting/journal_repository.dart';
import '../domain/fiscal/fiscal_year.dart';
import '../domain/reporting/trial_balance.dart';
import '../domain/shared/currency.dart';

/// A trial balance together with the period it covers.
class TrialBalanceReport {
  const TrialBalanceReport({
    required this.fiscalYear,
    required this.trialBalance,
    this.from,
    this.to,
  });

  /// The fiscal year the report belongs to, labelled the way a Nepali business
  /// thinks about a period, for example `FY 2082/83`.
  final FiscalYear fiscalYear;

  final TrialBalance trialBalance;

  /// The start of the reporting period, when one was given.
  final DateTime? from;

  /// The end of the reporting period, when one was given.
  final DateTime? to;

  /// False means the journal does not balance, which is a defect rather than a
  /// business outcome. A screen must say so rather than render it quietly.
  bool get isBalanced => trialBalance.isBalanced;

  /// True when there is nothing to report, which is different from an unbalanced
  /// report: an empty book balances.
  bool get isEmpty => trialBalance.rows.isEmpty;

  /// The heading for this report, for example `FY 2082/83` or
  /// `FY 2082/83 — 1 Jul 2026 to 30 Sep 2026`.
  String get periodLabel {
    if (from == null || to == null) return fiscalYear.label;
    return '${fiscalYear.label} — ${_short(from!)} to ${_short(to!)}';
  }

  /// A difference between total debits and total credits, for diagnosis.
  String? get imbalanceDescription {
    if (isBalanced) return null;
    final difference = trialBalance.difference;
    return 'Total debits ${trialBalance.totalDebits.format()} do not equal '
        'total credits ${trialBalance.totalCredits.format()}, a difference of '
        '${difference.format()}.';
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

/// Produces a trial balance for a period.
///
/// An interface rather than a concrete class, so a screen can be given a stub in
/// a widget test without touching a database.
abstract interface class TrialBalanceLoader {
  Future<TrialBalanceReport> load({DateTime? from, DateTime? to});
}

/// Builds a trial balance from the journal.
///
/// This is a use case rather than something a screen does for itself, because a
/// screen that assembled its own report would be holding business logic in the
/// presentation layer, which `docs/AI_RULES.md` prohibits.
class BuildTrialBalance implements TrialBalanceLoader {
  const BuildTrialBalance({
    required this.fiscalYear,
    required this.journal,
    this.currency = bookCurrency,
  });

  final FiscalYear fiscalYear;

  final JournalRepository journal;

  final String currency;

  @override
  Future<TrialBalanceReport> load({DateTime? from, DateTime? to}) async {
    final entries = await journal.all();

    return TrialBalanceReport(
      fiscalYear: fiscalYear,
      trialBalance: TrialBalance.from(
        entries: entries,
        currency: currency,
        from: from,
        to: to,
      ),
      from: from,
      to: to,
    );
  }
}
