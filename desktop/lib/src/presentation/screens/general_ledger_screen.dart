import 'package:flutter/material.dart';

import '../../application/build_general_ledger.dart';
import '../../domain/accounting/account.dart';
import '../../domain/reporting/general_ledger.dart';
import '../../domain/shared/money.dart';
import '../theme/app_theme.dart';

/// Width of a money column. Fixed, for the same reason as the Trial Balance
/// screen: figures line up, and the row cannot overflow.
const double _moneyColumnWidth = 150;

/// The general ledger for one account.
///
/// The screen chooses **which** account to show. Choosing is a presentation
/// concern; the use case answers only for the account it is given.
class GeneralLedgerScreen extends StatefulWidget {
  const GeneralLedgerScreen({super.key, required this.loader});

  final GeneralLedgerLoader loader;

  @override
  State<GeneralLedgerScreen> createState() => _GeneralLedgerScreenState();
}

class _GeneralLedgerScreenState extends State<GeneralLedgerScreen> {
  List<Account> _accounts = const [];
  Account? _selected;
  Future<GeneralLedgerReport>? _report;

  @override
  void initState() {
    super.initState();
    // Accounts come from the loader, so the screen never reaches for a chart or
    // a repository.
    _accounts = widget.loader.selectableAccounts();
    if (_accounts.isNotEmpty) {
      _select(_accounts.first);
    }
  }

  void _select(Account account) {
    setState(() {
      _selected = account;
      _report = widget.loader.load(account: account);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: palette.surface,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('General Ledger', style: textTheme.headlineLarge),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: AppSpacing.lg, thickness: 2),
            if (_accounts.isEmpty)
              const _EmptyState(
                message: 'No accounts are available to show a ledger for.',
              )
            else ...<Widget>[
              _AccountPicker(
                accounts: _accounts,
                selected: _selected,
                onSelected: _select,
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: FutureBuilder<GeneralLedgerReport>(
                  future: _report,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _ErrorState(error: snapshot.error!);
                    }
                    return _LedgerView(report: snapshot.data!);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountPicker extends StatelessWidget {
  const _AccountPicker({
    required this.accounts,
    required this.selected,
    required this.onSelected,
  });

  final List<Account> accounts;
  final Account? selected;
  final ValueChanged<Account> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final account in accounts)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text('${account.code}  ${account.name}'),
                selected: account.id == selected?.id,
                onSelected: (_) => onSelected(account),
                showCheckmark: false,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                side: BorderSide(
                  color: account.id == selected?.id
                      ? context.palette.accent
                      : context.palette.divider,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LedgerView extends StatelessWidget {
  const _LedgerView({required this.report});

  final GeneralLedgerReport report;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(report.periodLabel, style: textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        _HeaderRow(textTheme: textTheme),
        const Divider(height: AppSpacing.lg),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The opening balance is always shown when money moved before
                // the range. Without it the running balance would appear to
                // start at zero and the closing figure would not tie back to the
                // trial balance.
                if (report.hasOpeningBalance)
                  _OpeningBalanceRow(
                    opening: report.openingBalance,
                    textTheme: textTheme,
                  ),
                if (report.isEmpty && !report.hasOpeningBalance)
                  const _EmptyState(
                    message: 'No postings for this account in the period.',
                  )
                else
                  for (final line in report.lines) _PostingRow(line: line),
              ],
            ),
          ),
        ),
        const Divider(height: AppSpacing.lg, thickness: 2),
        _ClosingBalanceRow(
          closing: report.closingBalance,
          textTheme: textTheme,
        ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: context.palette.canvas,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 110,
            child: _Cell(
              align: _Align.left,
              child: Text('Date', style: textTheme.labelSmall),
            ),
          ),
          Expanded(
            child: _Cell(
              align: _Align.left,
              child: Text('Description', style: textTheme.labelSmall),
            ),
          ),
          _MoneyCell(child: Text('Debit', style: textTheme.labelSmall)),
          _MoneyCell(child: Text('Credit', style: textTheme.labelSmall)),
          _MoneyCell(child: Text('Balance', style: textTheme.labelSmall)),
        ],
      ),
    );
  }
}

class _OpeningBalanceRow extends StatelessWidget {
  const _OpeningBalanceRow({required this.opening, required this.textTheme});

  final Money opening;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return _BorderedRow(
      bold: true,
      cells: <Widget>[
        const SizedBox(width: 110, child: SizedBox()),
        _Cell(
          align: _Align.left,
          child: Text('Opening balance', style: textTheme.titleSmall),
        ),
        const _MoneyCell(child: SizedBox()),
        const _MoneyCell(child: SizedBox()),
        _MoneyCell(
          child: Text(opening.format(), style: textTheme.titleSmall),
        ),
      ],
    );
  }
}

class _PostingRow extends StatelessWidget {
  const _PostingRow({required this.line});

  final GeneralLedgerLine line;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // `movement` is the domain's own signed figure, so the screen does not
    // re-derive the side from the journal line.
    final debit = line.movement.isPositive ? line.movement : null;
    final credit = line.movement.isNegative ? line.movement.negated() : null;

    return _BorderedRow(
      cells: <Widget>[
        SizedBox(
          width: 110,
          child: _Cell(
            align: _Align.left,
            child: Text(
              '${line.entry.date.day}/${line.entry.date.month}/'
              '${line.entry.date.year}',
              style: textTheme.bodyMedium,
            ),
          ),
        ),
        Expanded(
          child: _Cell(
            align: _Align.left,
            child: Text(
              line.entry.description,
              style: textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        _MoneyCell(
          child: Text(debit?.format() ?? '—', style: textTheme.bodyMedium),
        ),
        _MoneyCell(
          child: Text(credit?.format() ?? '—', style: textTheme.bodyMedium),
        ),
        _MoneyCell(
          child: Text(
            line.runningBalance.format(),
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClosingBalanceRow extends StatelessWidget {
  const _ClosingBalanceRow({required this.closing, required this.textTheme});

  final Money closing;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 110),
          Expanded(
            child: _Cell(
              align: _Align.left,
              child: Text('Closing balance', style: textTheme.titleMedium),
            ),
          ),
          const _MoneyCell(child: SizedBox()),
          const _MoneyCell(child: SizedBox()),
          _MoneyCell(
            child: Text(closing.format(), style: textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}

/// A row with the standard bottom rule. Borders, not shadows, per ui.txt.
class _BorderedRow extends StatelessWidget {
  const _BorderedRow({required this.cells, this.bold = false});

  final List<Widget> cells;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.palette.divider)),
      ),
      padding: bold
          ? const EdgeInsets.symmetric(vertical: AppSpacing.sm)
          : EdgeInsets.zero,
      child: Row(children: cells),
    );
  }
}

enum _Align { left, right }

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
        // Right-aligned, never centred, per ui.txt section 8.
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
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
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.error_outline, color: palette.error, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'The ledger could not be produced',
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
