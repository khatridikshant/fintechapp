import 'package:flutter/material.dart';

import '../../application/build_profit_and_loss.dart';
import '../../application/build_trial_balance.dart';
import '../../domain/shared/money.dart';
import '../theme/app_theme.dart';

/// Where a user starts.
///
/// ## Why the figures on it come from use cases and not from the journal
///
/// A dashboard is where it is most tempting to compute something "just for the
/// summary" — cash in hand, this month's sales, overdue invoices. **`docs/AI_RULES.md`
/// forbids accounting logic in presentation code**, and a figure computed only for a
/// summary is a figure nothing else validates: it will drift from the statement it
/// was derived from, and nothing will say so.
///
/// So every number here is read from a report that already exists and is already
/// tested. **Where a figure is not built, this screen does not invent it.** The
/// "not built yet" row below is the honest alternative to showing a number that
/// might be wrong.
///
/// ## Nothing is stored
///
/// The dashboard holds no state and writes nothing. It is a window onto the books,
/// not a place the books are kept.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.trialBalance,
    required this.profitAndLoss,
    required this.balanceSheet,
    this.fiscalYearLabel,
  });

  final TrialBalanceTotals trialBalance;
  final ProfitAndLossLoader profitAndLoss;
  final BalanceSheetLoader balanceSheet;
  final String? fiscalYearLabel;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: context.palette.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: <Widget>[
            Text('Dashboard', style: textTheme.headlineLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.fiscalYearLabel ?? 'Current fiscal year',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            _ResultTile(
              title: 'Result for the period',
              loader: () async => (await widget.profitAndLoss.load()).netResult,
              caption: 'Profit or loss, from the profit and loss statement',
            ),
            const SizedBox(height: AppSpacing.md),
            _ResultTile(
              title: 'Total assets',
              loader: () async =>
                  (await widget.balanceSheet.load()).totalAssets,
              caption: 'From the balance sheet',
            ),
            const SizedBox(height: AppSpacing.md),
            _ResultTile(
              title: 'Posted to the ledger',
              loader: _ledgerTotals,
              caption: 'Total debits, which equal total credits',
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Where to go', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            const _NotBuilt(
              'Receivables, Purchases, Transfers and Sync have no screens yet, so '
              'this dashboard deliberately does not show figures from them. A '
              'number shown only here would be derived nowhere else and checked '
              'nowhere.',
            ),
          ],
        ),
      ),
    );
  }

  /// Debits and credits as one figure.
  ///
  /// **They are equal by construction** — every entry balances — so showing both
  /// would be noise. The caption says so rather than leaving the reader to wonder
  /// whether one is missing.
  Future<Money> _ledgerTotals() async {
    await widget.trialBalance.loadTotalDebits();
    return widget.trialBalance.loadTotalCredits();
  }
}

/// One figure, loaded on its own.
///
/// **Each tile loads independently**, so a balance sheet that cannot be produced
/// does not take the whole dashboard down with it. A landing screen that shows
/// nothing because one report failed is worse than one that shows three figures and
/// one honest failure.
class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.title,
    required this.loader,
    required this.caption,
  });

  final String title;
  final Future<Money> Function() loader;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.canvas,
        border: Border.all(color: palette.divider),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          FutureBuilder<Money>(
            future: loader(),
            builder: (BuildContext context, AsyncSnapshot<Money> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              if (snapshot.hasError) {
                // **Said, not hidden.** A missing figure on a landing screen is
                // exactly the thing a user needs to be told about.
                return Text(
                  'Could not be produced',
                  style: textTheme.titleMedium?.copyWith(color: palette.error),
                );
              }
              final Money amount = snapshot.data!;
              return Text(
                amount.format(),
                style: textTheme.headlineSmall?.copyWith(
                  // A loss is red. Only a negative figure, so an ordinary total
                  // never shouts.
                  color: amount.isNegative ? palette.error : null,
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(caption, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// An honest note about what the dashboard does not show.
class _NotBuilt extends StatelessWidget {
  const _NotBuilt(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: palette.divider),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, size: 18, color: palette.secondaryText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: textTheme.bodySmall)),
        ],
      ),
    );
  }
}
