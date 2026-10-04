import 'package:flutter/material.dart';

import '../../application/build_reports.dart';
import '../../domain/reporting/financial_reports.dart';
import '../../domain/shared/money.dart';
import '../theme/app_theme.dart';

/// Which of the five reports to show.
///
/// An enum rather than five screens, because they share a layout, a period and a
/// set of money-formatting rules. Five near-identical screens would be five places
/// to fix a formatting bug later.
enum FinancialReport {
  cashFlow('Cash Flow'),
  sales('Sales'),
  inventory('Inventory'),
  byCategory('By Category'),
  tax('VAT');

  const FinancialReport(this.title);

  /// The heading, which is also the label in the chooser.
  final String title;
}

/// The five remaining financial reports.
///
/// ## Everything comes from a use case
///
/// This screen never touches a repository and never computes a figure. It is handed
/// the five use cases and renders what they return, so a report can only ever show
/// numbers the application layer derived.
///
/// ## A negative figure is shown as a negative figure
///
/// Sales in credit and a credit VAT position are real states, not errors. Rendering
/// them as a dash or a zero would hide a liability or a credit the business is
/// entitled to, so they appear in red with their sign intact.
class FinancialReportsScreen extends StatefulWidget {
  const FinancialReportsScreen({
    super.key,
    required this.cashFlow,
    required this.sales,
    required this.inventory,
    required this.categoryReport,
    required this.tax,
    this.fiscalYearLabel,
    this.from,
    this.to,
    this.initialReport = FinancialReport.cashFlow,
  });

  final BuildCashFlow cashFlow;
  final BuildSalesSummary sales;
  final BuildInventorySummary inventory;
  final BuildCategoryReport categoryReport;
  final BuildTaxSummary tax;

  /// Shown in the subtitle. The shell knows the year; the reports do not.
  final String? fiscalYearLabel;

  /// The period, if the caller has one. Null means the whole fiscal year.
  final DateTime? from;
  final DateTime? to;

  /// Which report to open on. **Cash flow is the default**, because a cash
  /// statement is the report that reconciles against the bank, so it is the one a
  /// user most often arrives to check.
  final FinancialReport initialReport;

  @override
  State<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends State<FinancialReportsScreen> {
  /// Set in [initState] from `widget.initialReport`, not at declaration, so the
  /// screen opens on the report the caller asked for.
  late FinancialReport _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialReport;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: palette.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selected.title, style: textTheme.headlineLarge),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        widget.fiscalYearLabel ?? 'Current fiscal year',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: AppSpacing.xl, thickness: 2),
          _ReportChooser(
            selected: _selected,
            onSelected: (report) => setState(() => _selected = report),
          ),
          const Divider(height: AppSpacing.lg),
          Expanded(
            child: _bodyFor(_selected),
          ),
        ],
      ),
    );
  }

  /// Each report gets its own loader, and the key forces a rebuild when the
  /// chooser changes so the previous report's figures cannot linger on screen.
  Widget _bodyFor(FinancialReport report) {
    switch (report) {
      case FinancialReport.cashFlow:
        return _CashFlowView(
          key: const ValueKey('cash-flow'),
          useCase: widget.cashFlow,
          from: widget.from,
          to: widget.to,
        );
      case FinancialReport.sales:
        return _SalesView(
          key: const ValueKey('sales'),
          useCase: widget.sales,
          from: widget.from,
          to: widget.to,
        );
      case FinancialReport.inventory:
        return _InventoryView(
          key: const ValueKey('inventory'),
          useCase: widget.inventory,
        );
      case FinancialReport.byCategory:
        return _CategoryView(
          key: const ValueKey('by-category'),
          useCase: widget.categoryReport,
        );
      case FinancialReport.tax:
        return _TaxView(
          key: const ValueKey('tax'),
          useCase: widget.tax,
          from: widget.from,
          to: widget.to,
        );
    }
  }
}

/// The tab strip, as buttons rather than a `TabBar`.
///
/// Buttons, because each report replaces the page rather than sitting beside the
/// others, and a `TabBar` would imply a swipe gesture that does not exist here.
class _ReportChooser extends StatelessWidget {
  const _ReportChooser({required this.selected, required this.onSelected});

  final FinancialReport selected;
  final ValueChanged<FinancialReport> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
      child: Row(
        children: [
          for (final report in FinancialReport.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _ChooserButton(
                key: _ChooserButton.keyFor(report),
                label: report.title,
                isSelected: report == selected,
                onPressed: () => onSelected(report),
                palette: palette,
                textTheme: textTheme,
              ),
            ),
        ],
      ),
    );
  }
}

class _ChooserButton extends StatelessWidget {
  const _ChooserButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onPressed,
    required this.palette,
    required this.textTheme,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;
  final AppPalette palette;
  final TextTheme textTheme;

  /// The key a test taps. **Needed because the navigation also contains a "Sales"
  /// entry**, so a finder on the label alone is ambiguous. Keyed by the enum's
  /// name, which is stable.
  static Key keyFor(FinancialReport report) =>
      ValueKey('report-tab-${report.name}');

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? palette.primaryText : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: isSelected ? palette.surface : palette.primaryText,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared layout for the four report bodies: a heading, a set of labelled totals,
/// then an optional breakdown table.
class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.totals,
    required this.lines,
    required this.notice,
    required this.empty,
  });

  final List<_TotalRow> totals;
  final List<_LineRow> lines;
  final String? notice;
  final String empty;

  /// Whether there is genuinely nothing to report.
  ///
  /// **Not simply "no detail lines".** Cash flow has no detail lines by design, so
  /// that test would hide its totals behind an "empty" message. The question is
  /// whether any *figure* is non-zero: a cash statement with an opening balance and
  /// no movement in the period is not an empty book, and a sales report at zero
  /// genuinely is.
  bool get _isEmpty =>
      lines.isEmpty && totals.every((total) => total.amount.isZero);

  @override
  Widget build(BuildContext context) {
    // **Totals first, and always.** A report whose only figures are totals must
    // still show them, so the empty case replaces the whole body rather than
    // hiding the summary above it.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final total in totals) _TotalLine(total: total),
          if (notice != null) _Notice(message: notice!),
          if (_isEmpty) Expanded(child: _EmptyMessage(message: empty)),
          if (lines.isNotEmpty) ...[
            const Divider(height: AppSpacing.lg, thickness: 2),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final line in lines) _LineWidget(line: line),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TotalRow {
  const _TotalRow({
    required this.label,
    required this.amount,
    this.emphasise = false,
  });

  final String label;
  final Money amount;

  /// The line the reader is looking for, drawn heavier.
  final bool emphasise;
}

class _LineRow {
  const _LineRow({required this.label, required this.amount});

  final String label;
  final Money amount;
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.total});

  final _TotalRow total;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    final style =
        total.emphasise ? textTheme.titleMedium : textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              total.label,
              style: style?.copyWith(
                fontWeight: total.emphasise ? FontWeight.w600 : null,
              ),
            ),
          ),
          _Amount(
            amount: total.amount,
            style: style,
            // Only a negative figure is an error-coloured one. A credit position
            // is a real figure the reader needs to see as a figure.
            colour: total.amount.isNegative ? palette.error : null,
          ),
        ],
      ),
    );
  }
}

class _LineWidget extends StatelessWidget {
  const _LineWidget({required this.line});

  final _LineRow line;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              line.label,
              style: textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _Amount(
            amount: line.amount,
            style: textTheme.bodyMedium,
            colour: line.amount.isNegative ? palette.error : null,
          ),
        ],
      ),
    );
  }
}

/// A money cell.
///
/// Always right-aligned and always through `Money.format`, per ui.txt section 8.
class _Amount extends StatelessWidget {
  const _Amount({required this.amount, required this.style, this.colour});

  final Money amount;
  final TextStyle? style;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          amount.format(),
          style: style?.copyWith(color: colour),
        ),
      ),
    );
  }
}

/// A caveat the reader must see, such as VAT on unrecorded purchases.
class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.canvas,
        border: Border.all(color: palette.divider),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: palette.secondaryText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

class _CashFlowView extends StatelessWidget {
  const _CashFlowView({
    super.key,
    required this.useCase,
    required this.from,
    required this.to,
  });

  final BuildCashFlow useCase;
  final DateTime? from;
  final DateTime? to;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CashFlow>(
      future: useCase.load(from: from, to: to),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ReportError(error: snapshot.error!);
        }

        final flow = snapshot.data!;
        return _ReportBody(
          totals: <_TotalRow>[
            _TotalRow(label: 'Opening cash', amount: flow.openingCash),
            _TotalRow(label: 'Received', amount: flow.received),
            _TotalRow(label: 'Paid', amount: flow.paid),
            _TotalRow(
              label: 'Closing cash',
              amount: flow.closingCash,
              // The figure the statement exists to deliver.
              emphasise: true,
            ),
          ],
          lines: const <_LineRow>[],
          // Stated, because a reader comparing this with the profit and loss will
          // otherwise assume one of them is wrong.
          notice: 'A cash statement. Sales on credit and payments of older '
              'invoices appear here on the day the cash moves, not on the day '
              'the sale was made.',
          empty: 'No cash has moved in this period.',
        );
      },
    );
  }
}

class _SalesView extends StatelessWidget {
  const _SalesView({
    super.key,
    required this.useCase,
    required this.from,
    required this.to,
  });

  final BuildSalesSummary useCase;
  final DateTime? from;
  final DateTime? to;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SalesSummary>(
      future: useCase.load(from: from, to: to),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ReportError(error: snapshot.error!);
        }

        final summary = snapshot.data!;
        return _ReportBody(
          totals: <_TotalRow>[
            _TotalRow(label: 'Invoiced', amount: summary.grossSales),
            _TotalRow(label: 'Credited back', amount: summary.credits),
            _TotalRow(
              label: 'Net sales',
              amount: summary.netSales,
              emphasise: true,
            ),
          ],
          lines: <_LineRow>[
            for (final product in summary.byProduct)
              _LineRow(label: product.label, amount: product.amount),
          ],
          notice: null,
          empty: 'Nothing has been invoiced in this period.',
        );
      },
    );
  }
}

class _InventoryView extends StatelessWidget {
  const _InventoryView({super.key, required this.useCase});

  final BuildInventorySummary useCase;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InventorySummary>(
      future: useCase.load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ReportError(error: snapshot.error!);
        }

        final summary = snapshot.data!;
        return _ReportBody(
          totals: <_TotalRow>[
            _TotalRow(
              label: 'Total stock value',
              amount: summary.totalValue,
              emphasise: true,
            ),
          ],
          lines: <_LineRow>[
            for (final line in summary.lines)
              _LineRow(label: line.label, amount: line.amount),
          ],
          notice: null,
          empty: 'No stock has been recorded.',
        );
      },
    );
  }
}

class _CategoryView extends StatelessWidget {
  const _CategoryView({super.key, required this.useCase});

  final BuildCategoryReport useCase;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CategorySummary>(
      future: useCase.load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ReportError(error: snapshot.error!);
        }

        final summary = snapshot.data!;
        return _ReportBody(
          totals: <_TotalRow>[
            _TotalRow(
              label: 'Total stock value',
              amount: summary.totalValue,
              emphasise: true,
            ),
          ],
          lines: <_LineRow>[
            for (final line in summary.lines)
              _LineRow(label: line.label, amount: line.amount),
          ],
          notice: null,
          empty: 'No stock has been recorded.',
        );
      },
    );
  }
}

class _TaxView extends StatelessWidget {
  const _TaxView({
    super.key,
    required this.useCase,
    required this.from,
    required this.to,
  });

  final BuildTaxSummary useCase;
  final DateTime? from;
  final DateTime? to;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TaxSummary>(
      future: useCase.load(from: from, to: to),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ReportError(error: snapshot.error!);
        }

        final tax = snapshot.data!;

        // The rate is in basis points, and it is shown because a VAT figure read
        // without its rate is meaningless.
        final rate = (tax.rateBasisPoints / 100)
            .toStringAsFixed(tax.rateBasisPoints % 100 == 0 ? 0 : 2);

        return _ReportBody(
          totals: <_TotalRow>[
            _TotalRow(
                label: 'Sales excluding VAT ($rate%)',
                amount: tax.taxableSales),
            _TotalRow(label: 'Output VAT', amount: tax.outputVat),
            _TotalRow(label: 'Input VAT', amount: tax.inputVat),
            _TotalRow(label: 'Sales credited back', amount: tax.credits),
            _TotalRow(
              label: tax.netVatPayable.isNegative
                  ? 'VAT refund due'
                  : 'Net VAT payable',
              amount: tax.netVatPayable,
              emphasise: true,
            ),
          ],
          lines: const <_LineRow>[],
          notice: 'Output VAT is on invoices issued, not on cash received. '
              'Input VAT is zero because no purchases have been recorded yet, so '
              'this figure is not yet a complete return.',
          empty: 'No sales in this period, so there is no VAT to declare.',
        );
      },
    );
  }
}

class _ReportError extends StatelessWidget {
  const _ReportError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: palette.error, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'The report could not be produced',
                      style:
                          textTheme.titleMedium?.copyWith(color: palette.error),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('$error', style: textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
