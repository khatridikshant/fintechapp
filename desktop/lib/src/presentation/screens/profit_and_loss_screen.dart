import 'package:flutter/material.dart';

import '../../application/build_profit_and_loss.dart';
import '../../domain/reporting/balance_sheet.dart';
import '../../domain/reporting/profit_and_loss.dart';
import '../../domain/shared/money.dart';
import '../theme/app_theme.dart';

/// The Profit and Loss statement.
///
/// ## The one number that matters
///
/// [ProfitAndLoss.netResult] is shown last and emphasised, and a **loss is shown
/// as a loss** in the error colour. A statement that renders a negative figure in
/// the same weight as a positive one has communicated nothing, and leaves the
/// reader to notice the sign themselves.
///
/// ## Nothing is computed here
///
/// Every figure comes from [ProfitAndLossLoader]. `docs/AI_RULES.md` forbids
/// accounting logic in presentation code, and this screen has none.
class ProfitAndLossScreen extends StatefulWidget {
  const ProfitAndLossScreen({
    super.key,
    required this.profitAndLoss,
    this.fiscalYearLabel,
  });

  final ProfitAndLossLoader profitAndLoss;
  final String? fiscalYearLabel;

  @override
  State<ProfitAndLossScreen> createState() => _ProfitAndLossScreenState();
}

class _ProfitAndLossScreenState extends State<ProfitAndLossScreen> {
  @override
  Widget build(BuildContext context) {
    return _ReportScaffold(
      title: 'Profit & Loss',
      fiscalYearLabel: widget.fiscalYearLabel,
      load: () async {
        final ProfitAndLoss report = await widget.profitAndLoss.load();
        return _ReportBody(
          sections: <_Section>[
            _Section(
              title: 'Income',
              lines: _linesOf(
                report.income.map(
                  (ProfitAndLossLine l) => (l.account.name, l.balance),
                ),
              ),
              total: report.totalIncome,
            ),
            _Section(
              title: 'Expenses',
              lines: _linesOf(
                report.expenses.map(
                  (ProfitAndLossLine l) => (l.account.name, l.balance),
                ),
              ),
              total: report.totalExpenses,
            ),
          ],
          // Labelled by sign, because "Net result: Rs -15,000" reads worse than
          // "Net loss: Rs 15,000" and means exactly the same thing.
          resultLabel: report.netResult.isNegative ? 'Net loss' : 'Net profit',
          result: report.netResult,
        );
      },
    );
  }
}

/// The Balance Sheet.
///
/// ## Why this one is stricter
///
/// A balance sheet is where every wrong posting in the year surfaces, so the
/// check that the two sides agree runs inside [BalanceSheetLoader] — not here.
/// This screen renders a sheet that has already been asserted to balance, and
/// shows the failure plainly if it could not be produced at all.
///
/// ## Nothing is computed here
class BalanceSheetScreen extends StatefulWidget {
  const BalanceSheetScreen({
    super.key,
    required this.balanceSheet,
    this.fiscalYearLabel,
  });

  final BalanceSheetLoader balanceSheet;
  final String? fiscalYearLabel;

  @override
  State<BalanceSheetScreen> createState() => _BalanceSheetScreenState();
}

class _BalanceSheetScreenState extends State<BalanceSheetScreen> {
  @override
  Widget build(BuildContext context) {
    return _ReportScaffold(
      title: 'Balance Sheet',
      fiscalYearLabel: widget.fiscalYearLabel,
      load: () async {
        final BalanceSheet sheet = await widget.balanceSheet.load();
        return _ReportBody(
          sections: <_Section>[
            _Section(
              title: 'Assets',
              lines: _linesOf(
                sheet.assets.map(
                  (BalanceSheetLine l) => (l.account.name, l.balance),
                ),
              ),
              total: sheet.totalAssets,
            ),
            _Section(
              title: 'Liabilities',
              lines: _linesOf(
                sheet.liabilities.map(
                  (BalanceSheetLine l) => (l.account.name, l.balance),
                ),
              ),
              total: sheet.totalLiabilities,
            ),
            _Section(
              title: 'Equity',
              lines: _linesOf(
                sheet.equity.map(
                  (BalanceSheetLine l) => (l.account.name, l.balance),
                ),
              ),
              // Equity includes the year's result, because a result that is not
              // carried forward is not equity.
              total: sheet.totalEquity,
            ),
          ],
          // A balance sheet's result is the **current period's**, not the whole
          // year's, so it is labelled that way rather than "Net profit".
          resultLabel: 'Result for the period',
          result: sheet.currentResult,
        );
      },
    );
  }
}

/// Converts either report's lines into the one shape both screens render.
List<_Line> _linesOf(Iterable<(String, Money)> source) =>
    <_Line>[for (final (String, Money) line in source) _Line(line.$1, line.$2)];

/// One account and its balance.
class _Line {
  const _Line(this.name, this.balance);

  final String name;
  final Money balance;
}

/// A named group of accounts with its total.
class _Section {
  const _Section({
    required this.title,
    required this.lines,
    required this.total,
  });

  final String title;
  final List<_Line> lines;
  final Money total;
}

/// Both reports, once loaded.
class _ReportBody {
  const _ReportBody({
    required this.sections,
    required this.resultLabel,
    required this.result,
  });

  final List<_Section> sections;
  final String resultLabel;
  final Money result;
}

/// The chrome both screens share: title, loading, and failure.
class _ReportScaffold extends StatelessWidget {
  const _ReportScaffold({
    required this.title,
    required this.fiscalYearLabel,
    required this.load,
  });

  final String title;
  final String? fiscalYearLabel;
  final Future<_ReportBody> Function() load;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: context.palette.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: textTheme.headlineLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    fiscalYearLabel ?? 'Current fiscal year',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(height: AppSpacing.xl, thickness: 2),
            Expanded(
              child: FutureBuilder<_ReportBody>(
                future: load(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<_ReportBody> snapshot,
                ) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _ReportFailure(message: '${snapshot.error}');
                  }
                  final body = snapshot.data!;
                  return ListView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    children: <Widget>[
                      for (final section in body.sections) ...<Widget>[
                        _SectionView(section: section),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                      _TotalRow(
                        label: body.resultLabel,
                        amount: body.result,
                        emphasise: true,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({required this.section});

  final _Section section;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(section.title, style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (section.lines.isEmpty)
          // Said rather than left blank: an empty section otherwise reads as an
          // oversight rather than as "nothing in this category".
          Text('Nothing recorded', style: textTheme.bodySmall),
        for (final line in section.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: <Widget>[
                Expanded(child: Text(line.name, style: textTheme.bodyMedium)),
                _AmountCell(amount: line.balance),
              ],
            ),
          ),
        const Divider(height: AppSpacing.md),
        _TotalRow(
          label: 'Total ${section.title.toLowerCase()}',
          amount: section.total,
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.amount,
    this.emphasise = false,
  });

  final String label;
  final Money amount;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = emphasise ? textTheme.titleMedium : textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: style?.copyWith(
                fontWeight: emphasise ? FontWeight.w600 : null,
              ),
            ),
          ),
          _AmountCell(amount: amount, style: style),
        ],
      ),
    );
  }
}

/// A money cell.
///
/// Always right-aligned and always through [Money.format], per `ui.txt` section 8.
/// **A negative figure is red** — only a negative one, so an ordinary total never
/// shouts and a loss cannot be missed.
class _AmountCell extends StatelessWidget {
  const _AmountCell({required this.amount, this.style});

  final Money amount;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      width: 170,
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          amount.format(),
          style: style?.copyWith(
            color: amount.isNegative ? palette.error : null,
          ),
        ),
      ),
    );
  }
}

/// A report that could not be produced.
///
/// The wording is plain on purpose. A balance sheet that does not balance is the
/// one failure a user must not dismiss, so this says what happened rather than
/// offering a retry that would produce the same result.
class _ReportFailure extends StatelessWidget {
  const _ReportFailure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.error_outline, color: palette.error, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'This report could not be produced',
                      style: textTheme.titleMedium?.copyWith(
                        color: palette.error,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(message, style: textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
