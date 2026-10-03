import 'package:flutter/material.dart';

import '../../application/load_chart_of_accounts.dart';
import '../theme/app_theme.dart';

/// The chart of accounts: every account the books use, grouped and ordered.
///
/// ## Why this screen matters
///
/// An account a business can post to but cannot see is how a chart stops being
/// trustworthy. Until this existed, **a user had no way to look at which accounts
/// their books use** — they could post to them, and nothing showed them.
///
/// ## Why the *stored* accounts
///
/// It reads the accounts in the open year rather than the built-in constant, so an
/// account the business added appears here. An account that exists but is hidden is
/// worse than one shown out of order.
///
/// ## Nothing is computed here
///
/// The grouping, the ordering and the headings all come from
/// [ChartOfAccountsLoader]. `docs/AI_RULES.md` forbids accounting logic in
/// presentation code, and this screen has none.
class ChartOfAccountsScreen extends StatefulWidget {
  const ChartOfAccountsScreen({
    super.key,
    required this.chartOfAccounts,
    this.fiscalYearLabel,
  });

  final ChartOfAccountsLoader chartOfAccounts;
  final String? fiscalYearLabel;

  @override
  State<ChartOfAccountsScreen> createState() => _ChartOfAccountsScreenState();
}

class _ChartOfAccountsScreenState extends State<ChartOfAccountsScreen> {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: palette.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Chart of Accounts', style: textTheme.headlineLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.fiscalYearLabel ?? 'Current fiscal year',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(height: AppSpacing.xl, thickness: 2),
            Expanded(
              child: FutureBuilder<ChartOfAccountsView>(
                future: widget.chartOfAccounts.load(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<ChartOfAccountsView> snapshot,
                ) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _ChartFailure(message: '${snapshot.error}');
                  }

                  final view = snapshot.data!;
                  if (view.total == 0) {
                    return const _ChartEmpty();
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      0,
                      AppSpacing.xl,
                      AppSpacing.xl,
                    ),
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Text(
                          '${view.total} accounts',
                          style: textTheme.bodySmall,
                        ),
                      ),
                      for (final group in view.groups) _GroupView(group: group),
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

class _GroupView extends StatelessWidget {
  const _GroupView({required this.group});

  final AccountGroup group;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(group.title, style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final account in group.accounts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: <Widget>[
                  // **A fixed-width code column.** Accounts are looked up by code,
                  // so the codes have to line up for a user scanning the list to
                  // find one — and a code that moves as the window resizes cannot
                  // be scanned at all.
                  SizedBox(
                    width: 64,
                    child: Text(
                      account.code,
                      style: textTheme.bodyMedium?.copyWith(
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(account.name, style: textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A year whose books hold no accounts.
///
/// Said plainly rather than left blank. A chart that renders empty is ambiguous —
/// it could mean "not loaded yet" or "no accounts", and the user cannot tell which.
class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'This year has no accounts yet. They are created when the year is '
            'opened, so an empty chart means the books have not been set up.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

class _ChartFailure extends StatelessWidget {
  const _ChartFailure({required this.message});

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
                      'The chart could not be loaded',
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
