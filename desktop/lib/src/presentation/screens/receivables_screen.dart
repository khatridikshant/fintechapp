import 'package:flutter/material.dart';

import '../../application/build_receivables.dart';
import '../../domain/shared/money.dart';
import '../theme/app_theme.dart';

/// Who owes what.
///
/// ## The one failure that matters
///
/// **A report that could not be read must never render as "nothing owed."** A user
/// who sees an empty receivables list concludes the business is paid up, and acts
/// on it. So the failure state is explicit, and there is a test asserting the word
/// "nothing" never appears when loading failed.
///
/// ## Why VAT is inside the figure
///
/// The customer owes the whole invoice, tax included. **But the tax is owed to the
/// authority, not by the customer** — which is why this screen shows the invoice
/// total and not the net, and why it does not describe the figure as "money owed to
/// the business". See [BuildReceivables] for the full rule.
///
/// ## Age, not overdue
///
/// [Invoice] records no due date, so this says how old each debt is rather than
/// how late it is. "Overdue" would be a claim the data cannot support.
class ReceivablesScreen extends StatefulWidget {
  const ReceivablesScreen({
    super.key,
    required this.receivables,
    this.asAt,
  });

  final ReceivablesLoader receivables;

  /// The date ageing is measured against, for tests. Null means today.
  final DateTime? asAt;

  @override
  State<ReceivablesScreen> createState() => _ReceivablesScreenState();
}

class _ReceivablesScreenState extends State<ReceivablesScreen> {
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
                  Text('Receivables', style: textTheme.headlineLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'What customers owe, after payments and credit notes.',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(height: AppSpacing.xl, thickness: 2),
            Expanded(
              child: FutureBuilder<ReceivablesReport>(
                future: widget.receivables.load(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<ReceivablesReport> snapshot,
                ) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _Failure(message: '${snapshot.error}');
                  }

                  final report = snapshot.data!;
                  final DateTime asAt = widget.asAt ?? report.asAt;

                  if (report.isEmpty) {
                    return const _NothingOwed();
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      0,
                      AppSpacing.xl,
                      AppSpacing.xl,
                    ),
                    children: <Widget>[
                      _Totals(report: report),
                      const SizedBox(height: AppSpacing.xl),
                      for (final customer in report.customers)
                        _CustomerCard(customer: customer, asAt: asAt),
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

class _Totals extends StatelessWidget {
  const _Totals({required this.report});

  final ReceivablesReport report;

  @override
  Widget build(BuildContext context) {
    return _TotalRow(
      label: 'Total owed by customers',
      amount: report.totalOutstanding,
      emphasise: true,
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer, required this.asAt});

  final CustomerReceivable customer;
  final DateTime asAt;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child:
                    Text(customer.customerName, style: textTheme.titleMedium),
              ),
              _AmountCell(amount: customer.outstanding),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final invoice in customer.invoices)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 170,
                      child: Text(invoice.number, style: textTheme.bodyMedium),
                    ),
                    Expanded(
                      child: Text(
                        '${invoice.ageInDays(asAt)} days old',
                        style: textTheme.bodySmall,
                      ),
                    ),
                    _AmountCell(amount: invoice.balance),
                  ],
                ),
              ),
            ),
          // **Shown only when it exists.** A refund is money this business owes
          // back, which is a different conversation from money owed to it, so it is
          // never netted into the figure above.
          if (customer.refundsOwed.isPositive)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Refund owed back to this customer',
                      style: textTheme.bodySmall
                          ?.copyWith(color: palette.secondaryText),
                    ),
                  ),
                  _AmountCell(amount: customer.refundsOwed),
                ],
              ),
            ),
        ],
      ),
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

    return Row(
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
    );
  }
}

/// A money cell.
///
/// Always right-aligned and always through [Money.format], per `ui.txt` section 8.
/// **A negative figure is red** — only a negative one.
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

/// Everything is paid up.
///
/// Only ever reached when the report **loaded successfully and found nothing** —
/// the failure path below is separate, which is the whole point of testing it.
class _NothingOwed extends StatelessWidget {
  const _NothingOwed();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'Nothing is owed. Every invoice has been paid or credited in full.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message});

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
                      // **Never "Nothing is owed."** See the class docblock.
                      'This report could not be produced, so what customers owe is '
                      'unknown. Do not treat this as an empty list.',
                      style:
                          textTheme.titleMedium?.copyWith(color: palette.error),
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
