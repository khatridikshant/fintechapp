import 'package:flutter/material.dart';

import '../../application/load_chart_of_accounts.dart';
import '../../domain/accounting/account.dart';
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
///
/// The one thing added on top is the **filter**, and it is deliberately the
/// simplest thing that can work: it narrows the accounts the loader already
/// returned and changes no totals, because a chart of accounts has no totals to
/// change — every account is a line, not a figure.
///
/// ## The filter exists because the list outgrew scrolling
///
/// A seeded chart is around fifty accounts, which a user can scroll once. A
/// business that has added accounts of its own reaches a length where finding
/// `2100` by eye stops being reasonable, and a chart you cannot search is a chart
/// you stop trusting — the same failure this screen was built to fix. Searching by
/// code **or** name matters because a user looking for a liability often knows the
/// words and not the number, and vice versa.
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
  /// Loaded once, in [initState], rather than rebuilt by a `FutureBuilder` on
  /// every frame.
  ///
  /// Two reasons, and the second is the one that matters here: filtering must not
  /// refetch, and a `FutureBuilder` would rebuild its future whenever this widget
  /// rebuilt, so typing in the filter box would re-read the books on every
  /// keystroke. The Trial Balance screen loads the same way, for the same reason.
  late final Future<ChartOfAccountsView> _chart = widget.chartOfAccounts.load();

  String _query = '';

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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
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
            // The heavier rule under a page title, in the newspaper sense.
            const Divider(height: AppSpacing.lg, thickness: 2),
            Expanded(
              child: FutureBuilder<ChartOfAccountsView>(
                future: _chart,
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

                  final groups = _narrowed(view.groups);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          AppSpacing.lg,
                          AppSpacing.xl,
                          AppSpacing.md,
                        ),
                        child: _SummaryStrip(
                          total: _totalOf(groups),
                          groups: groups.length,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          0,
                          AppSpacing.xl,
                          AppSpacing.md,
                        ),
                        child: _ChartFilter(
                          query: _query,
                          onChanged: (value) => setState(() => _query = value),
                        ),
                      ),
                      Expanded(
                        child: groups.isEmpty
                            ? _NoMatches(query: _query)
                            : _ChartList(groups: groups),
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

  /// The groups left after the filter, with each group's accounts narrowed too.
  ///
  /// **A group whose accounts are all filtered out is dropped entirely** rather
  /// than left as a bare heading over nothing. An empty "Expenses" heading reads as
  /// a chart with no expenses, which is a different and wrong claim.
  List<AccountGroup> _narrowed(List<AccountGroup> groups) {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return groups;

    return <AccountGroup>[
      for (final group in groups)
        if (_matches(group.accounts, needle).isNotEmpty)
          AccountGroup(
            type: group.type,
            accounts: _matches(group.accounts, needle),
          ),
    ];
  }

  static List<Account> _matches(List<Account> accounts, String needle) =>
      accounts
          .where(
            (Account a) =>
                a.code.toLowerCase().contains(needle) ||
                a.name.toLowerCase().contains(needle),
          )
          .toList();

  /// How many accounts are on screen, which is the whole chart when no filter is
  /// applied.
  ///
  /// **Counted rather than read off the view** so the figure above the list always
  /// describes the list below it. A count that kept saying "45 accounts" above a
  /// three-row filtered list would be worse than no count.
  static int _totalOf(List<AccountGroup> groups) =>
      groups.fold<int>(0, (int sum, AccountGroup g) => sum + g.accounts.length);
}

/// The width of the account code column.
///
/// **Fixed, and the same width the Trial Balance uses.** Accounts are looked up by
/// code, so the codes have to line up for someone scanning the list to find one,
/// and a code that moves as the window resizes cannot be scanned at all. Matching
/// the other report also means the two screens look like the same application.
const double _codeColumnWidth = 90;

/// The width of the "normal side" column, which holds `Dr` or `Cr`.
const double _sideColumnWidth = 44;

/// Three figures stated once, the way a newspaper states a summary before its
/// tables.
///
/// **Deliberately counts only, and adds up nothing.** Every account is a line rather
/// than a value, so there is no total to report here — and a chart of accounts that
/// showed a sum of its accounts would be reporting a number with no meaning.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.total, required this.groups});

  final int total;
  final int groups;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      key: const ValueKey<String>('chart-summary'),
      color: palette.canvas,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: _SummaryFigure(
              figure: '$total',
              label: total == 1 ? 'account' : 'accounts',
            ),
          ),
          const _SummaryRule(),
          Expanded(
            child: _SummaryFigure(
              figure: '$groups',
              label: groups == 1 ? 'group' : 'groups',
            ),
          ),
        ],
      ),
    );
  }
}

/// A vertical hairline between two figures, in the newspaper sense.
///
/// **Fixed height, and deliberately so.** A `Row` gives its children an unbounded
/// height, so a stretched rule would ask for one that never arrives. The height is
/// matched to the two lines beside it -- a figure over its label -- so the rule
/// spans the block rather than hanging in the middle of the band.
class _SummaryRule extends StatelessWidget {
  const _SummaryRule();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 36,
        color: context.palette.divider,
      );
}

class _SummaryFigure extends StatelessWidget {
  const _SummaryFigure({required this.figure, required this.label});

  final String figure;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // `tabularFigures` so a changing figure does not shift the label beneath
        // it as the filter narrows the chart.
        Text(
          figure,
          style: textTheme.titleLarge?.copyWith(
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label.toUpperCase(),
          style: textTheme.labelSmall?.copyWith(
            color: context.palette.secondaryText,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// The search field.
///
/// A plain text field with a clear button, because `ui.txt` section 3 asks for
/// familiar desktop controls rather than a custom search widget.
class _ChartFilter extends StatelessWidget {
  const _ChartFilter({required this.query, required this.onChanged});

  final String query;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return TextField(
      onChanged: onChanged,
      // Not a form field: it filters as it is typed, so it must not take part in
      // validation or be submitted.
      style: textTheme.bodyMedium,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search code or name',
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: palette.secondaryText,
        ),
        prefixIcon: Icon(Icons.search, size: 18, color: palette.secondaryText),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close, size: 18, color: palette.secondaryText),
                tooltip: 'Clear the search',
                onPressed: () => onChanged(''),
              ),
        filled: true,
        fillColor: palette.canvas,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: palette.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: palette.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: palette.accent),
        ),
      ),
    );
  }
}

/// The grouped list of accounts.
class _ChartList extends StatelessWidget {
  const _ChartList({required this.groups});

  final List<AccountGroup> groups;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      // Every row is built rather than only the visible ones, so a filtered list
      // is short and a search result is never a partially-built tree. The chart
      // is tens of rows, not thousands, so laziness would buy nothing here.
      itemCount: groups.length,
      itemBuilder: (BuildContext context, int index) =>
          _GroupView(group: groups[index]),
    );
  }
}

class _GroupView extends StatelessWidget {
  const _GroupView({required this.group});

  final AccountGroup group;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _GroupHeading(group: group),
          const SizedBox(height: AppSpacing.xs),
          Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: palette.divider),
                right: BorderSide(color: palette.divider),
              ),
            ),
            child: Column(
              children: <Widget>[
                for (final account in group.accounts)
                  // **The `Dr`/`Cr` column is passed in from the group**, not read
                  // per row. Every account in a group shares a type and therefore a
                  // normal side, so asking each row would ask one question fifty
                  // times to get the same answer, and it would put the wording back
                  // on the domain enum that `AccountGroup.title` keeps it off.
                  _AccountRow(
                    account: account,
                    normalSide: group.normalSideLabel,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The band above a group: its title, how many accounts it holds, and which
/// statement those accounts belong to.
///
/// **The statement is read from [AccountType.isBalanceSheet], not worked out
/// here.** Which side of the statements an account appears on is an accounting
/// fact, and it is already stated on the domain type; a screen that re-derived it
/// would be a second place for the two statements and the chart to disagree.
class _GroupHeading extends StatelessWidget {
  const _GroupHeading({required this.group});

  final AccountGroup group;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final statement = group.statementLabel;

    return Container(
      color: palette.canvas,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              group.title,
              style: textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${group.accounts.length}',
            style: textTheme.bodySmall?.copyWith(
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            statement,
            style: textTheme.labelSmall?.copyWith(
              color: palette.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

/// One account: its code, its name, and the side that increases it.
///
/// **The `Dr`/`Cr` column is the addition that earns the space.** A code and a
/// name are not enough to post correctly — knowing an account increases on the
/// debit side is what stops a user guessing, and it is already stated by the
/// domain, so it is shown rather than left in the code.
class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.normalSide});

  final Account account;

  /// `Dr` or `Cr`, supplied by the group this account belongs to.
  final String normalSide;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.divider)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: _codeColumnWidth,
            child: Text(
              account.code,
              style: textTheme.bodyMedium?.copyWith(
                color: palette.secondaryText,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
          ),
          Expanded(
            child: Text(
              account.name,
              style: textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: _sideColumnWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                normalSide,
                style: textTheme.labelSmall?.copyWith(
                  color: palette.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when a search matches nothing.
///
/// Distinct from [_ChartEmpty], which means the books hold no accounts at all. A
/// search that found nothing is a statement about the search, not about the books,
/// and the two must not read the same.
class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'No account matches "$query". Accounts are searched by code and by '
            'name, so a shorter search usually finds it.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium,
          ),
        ),
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
