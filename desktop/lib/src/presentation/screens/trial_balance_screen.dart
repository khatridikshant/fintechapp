import 'package:flutter/material.dart';

import '../../application/build_trial_balance.dart';
import '../../domain/shared/money.dart';
import '../theme/app_theme.dart';

/// The Trial Balance report.
///
/// Every amount comes from `Money.format`, so the screen cannot invent a second
/// formatting rule and drift from the ledger's own.
class TrialBalanceScreen extends StatefulWidget {
  const TrialBalanceScreen({super.key, required this.loader});

  /// The use case that produces the report. The screen never reads a repository.
  final TrialBalanceLoader loader;

  @override
  State<TrialBalanceScreen> createState() => _TrialBalanceScreenState();
}

class _TrialBalanceScreenState extends State<TrialBalanceScreen> {
  late Future<TrialBalanceReport> _report;

  @override
  void initState() {
    super.initState();
    // Loaded once. There is no database behind the loader, so refetching on
    // every frame would rebuild the same figures.
    _report = widget.loader.load();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.surface,
      body: FutureBuilder<TrialBalanceReport>(
        future: _report,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error!);
          }

          final report = snapshot.data!;
          return _ReportView(report: report);
        },
      ),
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.report});

  final TrialBalanceReport report;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trial Balance', style: textTheme.headlineLarge),
                    const SizedBox(height: AppSpacing.xs),
                    // The fiscal year in BS form, because that is how a Nepali
                    // business thinks about a period.
                    Text(report.periodLabel, style: textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          // The heavier rule under a page title, in the newspaper sense.
          const Divider(height: AppSpacing.xl, thickness: 2),
          if (!report.isBalanced) _UnbalancedNotice(report: report),
          if (report.isEmpty)
            const _EmptyState()
          else
            Expanded(child: _TrialBalanceTable(report: report)),
        ],
      ),
    );
  }
}

class _TrialBalanceTable extends StatelessWidget {
  const _TrialBalanceTable({required this.report});

  final TrialBalanceReport report;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row.
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          color: palette.canvas,
          child: Row(
            children: [
              SizedBox(
                width: _codeColumnWidth,
                child: _Cell(
                    align: _Align.left,
                    child: Text('Code', style: textTheme.labelSmall)),
              ),
              Expanded(
                child: _Cell(
                    align: _Align.left,
                    child: Text('Account', style: textTheme.labelSmall)),
              ),
              _MoneyCell(child: Text('Debit', style: textTheme.labelSmall)),
              _MoneyCell(child: Text('Credit', style: textTheme.labelSmall)),
              _MoneyCell(child: Text('Balance', style: textTheme.labelSmall)),
            ],
          ),
        ),
        const Divider(height: AppSpacing.lg),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final row in report.trialBalance.rows)
                  _ReportRow(
                    code: row.account.code,
                    name: row.account.name,
                    // A zero side is shown as an em dash rather than a zero, so
                    // the eye goes to the numbers that carry the balance.
                    debit: row.debitTotal.isZero ? null : row.debitTotal,
                    credit: row.creditTotal.isZero ? null : row.creditTotal,
                    balance: row.balance,
                  ),
              ],
            ),
          ),
        ),
        const Divider(height: AppSpacing.lg, thickness: 2),
        // Totals row.
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              const SizedBox(width: _codeColumnWidth),
              Expanded(
                child: _Cell(
                    align: _Align.left,
                    child: Text('Total', style: textTheme.titleMedium)),
              ),
              _MoneyCell(
                child: Text(
                  report.trialBalance.totalDebits.format(),
                  style: textTheme.titleMedium,
                ),
              ),
              _MoneyCell(
                child: Text(
                  report.trialBalance.totalCredits.format(),
                  style: textTheme.titleMedium,
                ),
              ),
              const _MoneyCell(child: SizedBox()),
            ],
          ),
        ),
      ],
    );
  }
}

/// The width of a money column.
///
/// Fixed rather than shrink-wrapped, for two reasons. The figures line up down
/// the page, which is what makes a column scannable. And the row cannot overflow
/// its container, which it did when every column was sized to its content.
const double _moneyColumnWidth = 150;

/// The width of the account code column.
const double _codeColumnWidth = 90;

enum _Align { left, right }

/// A fixed-width, right-aligned money column.
class _MoneyCell extends StatelessWidget {
  const _MoneyCell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _moneyColumnWidth,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        // Monetary values are right-aligned and never centred, per ui.txt
        // section 8.
        child: Align(alignment: Alignment.centerRight, child: child),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.align, required this.child});

  final _Align align;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: align == _Align.right
          ? Align(alignment: Alignment.centerRight, child: child)
          : Align(alignment: Alignment.centerLeft, child: child),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.code,
    required this.name,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  final String code;
  final String name;
  final Money? debit;
  final Money? credit;
  final Money balance;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    final balanceColour = balance.isNegative
        ? palette.error
        : (balance.isZero ? palette.secondaryText : palette.primaryText);

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _codeColumnWidth,
            child: _Cell(
              align: _Align.left,
              child: Text(code, style: textTheme.bodyMedium),
            ),
          ),
          Expanded(
            child: _Cell(
              align: _Align.left,
              child: Text(
                name,
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          _MoneyCell(
            child: Text(
              debit?.format() ?? '—',
              style: textTheme.bodyMedium,
            ),
          ),
          _MoneyCell(
            child: Text(
              credit?.format() ?? '—',
              style: textTheme.bodyMedium,
            ),
          ),
          _MoneyCell(
            child: Text(
              balance.format(),
              style: textTheme.bodyMedium?.copyWith(
                color: balanceColour,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the report does not balance.
///
/// This is a defect, not a business outcome, so it is stated plainly rather than
/// rendered as a table the user might skim past. `ui.txt` section 9 assigns
/// red to errors, and this is one.
class _UnbalancedNotice extends StatelessWidget {
  const _UnbalancedNotice({required this.report});

  final TrialBalanceReport report;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.error.withValues(alpha: 0.08),
        border: Border.all(color: palette.error),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: palette.error, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This report does not balance',
                  style: textTheme.titleSmall?.copyWith(color: palette.error),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  report.imbalanceDescription!,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the book has no activity.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            'There is nothing to report for this period. No journal entries have '
            'been posted in the current fiscal year yet.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

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
                  // Expanded, or a long error message overflows the row.
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
