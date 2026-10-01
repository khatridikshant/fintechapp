import 'package:flutter/material.dart';

import '../../application/issue_invoice.dart';
import '../../domain/billing/invoice.dart';
import '../../domain/billing/invoice_line.dart';
import '../../domain/shared/money.dart';
import '../theme/app_theme.dart';

/// The Invoice form: type a bill, and the system posts it to the accounts.
///
/// ## What the screen does and does not decide
///
/// **Nothing about the invoice.** Not the totals, not the VAT, not the number,
/// not the journal. It collects what a person typed and renders exactly what
/// [IssueInvoice] returned. If the screen computed a total, the figure on the bill
/// and the figure in the ledger could disagree, and only one of them would be
/// wrong in a way nobody would notice.
///
/// The one thing it checks is whether each line is *fillable in* — a description,
/// a quantity of at least one, a positive price — so the user is told before a
/// round trip. Whether a line is *acceptable* remains the domain's decision, and
/// its wording is shown as-is when it refuses.
///
/// ## The date
///
/// Today, because an invoice is normally raised now. The use case still checks it
/// against the open fiscal year, and refuses an invoice dated outside it — which is
/// why the screen never has to decide whether the date is valid.
class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key, required this.issueInvoice});

  final IssueInvoice issueInvoice;

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final _customer = TextEditingController();
  final List<_LineDraft> _lines = <_LineDraft>[_LineDraft()];

  bool _busy = false;
  String? _issuedNumber;
  String? _problem;

  @override
  void dispose() {
    _customer.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _addLine() => setState(() => _lines.add(_LineDraft()));

  void _removeLine(int index) => setState(() {
        _lines.removeAt(index).dispose();
        // A form with no rows cannot be submitted, so one is always left.
        if (_lines.isEmpty) _lines.add(_LineDraft());
      });

  Future<void> _issue() async {
    final problem = _validate();
    if (problem != null) {
      setState(() {
        _problem = problem;
        _issuedNumber = null;
      });
      return;
    }

    setState(() {
      _busy = true;
      _problem = null;
      _issuedNumber = null;
    });

    try {
      final outcome = await widget.issueInvoice(_toInvoice());
      if (!mounted) return;

      switch (outcome) {
        case InvoiceIssued(:final number):
          setState(() {
            _busy = false;
            _issuedNumber = number.value;
            _clear();
          });
        case InvoiceRejected(:final message):
          setState(() {
            _busy = false;
            // **The use case's own explanation**, not a second one written here.
            _problem = message;
            // The typed lines are deliberately kept, so a refusal can be corrected
            // rather than retyped.
          });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = 'The invoice could not be issued. $error';
      });
    }
  }

  /// The first thing wrong with the form, in the user's words.
  ///
  /// Kept separate from [IssueInvoice] on purpose: this is "you cannot press the
  /// button yet", which is not the same as "the accountant refused this invoice".
  String? _validate() {
    if (_customer.text.trim().isEmpty) {
      return 'Choose a customer.';
    }
    if (_lines.isEmpty) return 'An invoice needs at least one line.';

    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      final where = 'Line ${i + 1}';
      if (line.description.text.trim().isEmpty) {
        return '$where needs a description.';
      }
      final quantity = int.tryParse(line.quantity.text.trim());
      if (quantity == null) return '$where needs a quantity.';
      if (quantity < 1) {
        return '$where must be at least 1. Use a credit note to reverse a sale.';
      }
      final parsed = _parsePrice(line.price.text);
      if (parsed == null) return '$where needs a price.';
      if (!parsed.isPositive) return '$where must have a price above zero.';
    }
    return null;
  }

  /// Parses a typed price in major units, or null when it is not a number.
  ///
  /// **Rounded to whole paisa here, and re-derived by the domain afterwards.** A
  /// price typed as `10.005` cannot be represented exactly in binary floating
  /// point, so it is rounded once on the way in rather than being allowed to
  /// drift through every total.
  Money? _parsePrice(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null) return null;
    return Money.fromMajorUnits(value, 'NPR');
  }

  Invoice _toInvoice() {
    final lines = <InvoiceLine>[];
    for (final draft in _lines) {
      lines.add(
        InvoiceLine(
          description: draft.description.text.trim(),
          quantity: int.parse(draft.quantity.text.trim()),
          unitPrice: _parsePrice(draft.price.text)!,
        ),
      );
    }

    return Invoice(
      // The screen does not choose an identifier for a document; the use case
      // numbers it. A draft id only has to be unique enough to key the work.
      id: 'draft-${DateTime.now().microsecondsSinceEpoch}',
      issueDate: DateTime.now(),
      customerId: _customer.text.trim(),
      lines: lines,
    );
  }

  /// Empties the form after an issue, **without disposing anything.**
  ///
  /// Disposing the controllers and building new ones would throw: the live
  /// `TextFormField`s still reference them until the rebuild completes, and a
  /// controller disposed out from under a field takes the frame down with it.
  /// Clearing in place is also what the user sees, rather than new fields that
  /// merely look empty.
  void _clear() {
    _customer.clear();
    for (final line in _lines) {
      line.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Text('New invoice', style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Dated today and charged to the open fiscal year. The number is given '
          'by the system when the invoice is issued.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_issuedNumber != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: palette.canvas,
                border: Border.all(color: palette.positive),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.check_circle_outline,
                      size: 18, color: palette.positive),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Issued as $_issuedNumber and posted to the accounts.',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        TextFormField(
          key: const ValueKey<String>('invoice-customer-field'),
          controller: _customer,
          enabled: !_busy,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Customer reference',
            helperText: 'For example C-0001',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < _lines.length; i++) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                flex: 4,
                child: TextFormField(
                  key: ValueKey<String>('line-description-$i'),
                  controller: _lines[i].description,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'What'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextFormField(
                  key: ValueKey<String>('line-quantity-$i'),
                  controller: _lines[i].quantity,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Qty'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextFormField(
                  key: ValueKey<String>('line-price-$i'),
                  controller: _lines[i].price,
                  enabled: !_busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Price'),
                ),
              ),
              if (_lines.length > 1)
                IconButton(
                  key: ValueKey<String>('remove-line-$i'),
                  onPressed: _busy ? null : () => _removeLine(i),
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  tooltip: 'Remove this line',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        OutlinedButton.icon(
          key: const ValueKey<String>('add-line-button'),
          onPressed: _busy ? null : _addLine,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add a line'),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          key: const ValueKey<String>('invoice-issue-button'),
          onPressed: _busy ? null : _issue,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.receipt_long, size: 18),
          label: const Text('Issue invoice'),
        ),
        if (_problem != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            _problem!,
            style: textTheme.bodyMedium?.copyWith(color: palette.error),
          ),
        ],
      ],
    );
  }
}

/// One editable row.
class _LineDraft {
  final TextEditingController description = TextEditingController();
  final TextEditingController quantity = TextEditingController(text: '1');
  final TextEditingController price = TextEditingController();

  void clear() {
    description.clear();
    quantity.text = '1';
    price.clear();
  }

  void dispose() {
    description.dispose();
    quantity.dispose();
    price.dispose();
  }
}
