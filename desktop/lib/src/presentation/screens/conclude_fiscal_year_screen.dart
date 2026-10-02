import 'package:flutter/material.dart';

import '../../application/conclude_fiscal_year.dart';
import '../theme/app_theme.dart';

/// The Conclude Fiscal Year screen.
///
/// ## This is the one screen that can lose a year
///
/// So it is deliberately the most cautious in the application. It states, before
/// anything is pressed:
///
/// - that **the archive must reach the server**, or the year cannot be closed;
/// - that **the current year stays open and writable if anything fails**;
/// - that the books are checked first, and an unbalanced entry stops everything.
///
/// Nothing here decides whether a close may proceed. That is [ConcludeFiscalYear]'s
/// judgement, and its reason is shown as written — a screen that approved a close
/// the domain had refused would be the worst place in the application for a
/// second opinion.
class ConcludeFiscalYearScreen extends StatefulWidget {
  const ConcludeFiscalYearScreen({super.key, required this.concludeYear});

  final ConcludeFiscalYear concludeYear;

  @override
  State<ConcludeFiscalYearScreen> createState() =>
      _ConcludeFiscalYearScreenState();
}

class _ConcludeFiscalYearScreenState extends State<ConcludeFiscalYearScreen> {
  bool _busy = false;
  bool _done = false;
  String? _message;
  bool _problem = false;

  Future<void> _conclude() async {
    setState(() {
      _busy = true;
      _done = false;
      _message = null;
    });

    final outcome = await widget.concludeYear();

    if (!mounted) return;
    switch (outcome) {
      case FiscalYearConcluded(:final closed, :final nextYear):
        final result = closed.result;
        setState(() {
          _busy = false;
          _done = true;
          _problem = false;
          _message = '${closed.fiscalYearLabel} is closed with a '
              '${result.isPositive ? 'profit' : 'loss'} of '
              '${result.format()}. ${nextYear.label} is now open.';
        });
      case FiscalYearNotConcluded(:final reason):
        setState(() {
          _busy = false;
          _done = false;
          _problem = true;
          _message = reason;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Text('Conclude fiscal year', style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Closes the books, archives them, and opens the next year.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),

        // **Stated before anything is pressed.** A user who does not read it must
        // still not be able to close a year without the archive.
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: palette.canvas,
            border: Border.all(color: palette.warning),
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Rule(
                icon: Icons.cloud_outlined,
                text: 'The year is archived to the server first. If that does '
                    'not succeed, the year is not closed.',
              ),
              _Rule(
                icon: Icons.lock_outline,
                text: 'Your books are checked for unbalanced entries before '
                    'anything is posted.',
              ),
              _Rule(
                icon: Icons.history,
                text: 'If anything fails, this year stays open and you can '
                    'keep trading in it.',
              ),
              _Rule(
                icon: Icons.account_balance_outlined,
                text: 'Balances carry forward into next year; income and '
                    'expenses are closed into equity.',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        FilledButton.icon(
          key: const ValueKey<String>('conclude-year-button'),
          onPressed: _busy || _done ? null : _conclude,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_clock_outlined, size: 18),
          label: Text(_done ? 'Fiscal year concluded' : 'Conclude fiscal year'),
        ),

        if (_message != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                _problem ? Icons.error_outline : Icons.check_circle_outline,
                size: 18,
                color: _problem ? palette.error : palette.positive,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _message!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: _problem ? palette.error : palette.positive,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One line of the "before you press this" list.
class _Rule extends StatelessWidget {
  const _Rule({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 15, color: context.palette.secondaryText),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      );
}
