import 'package:flutter/material.dart';

import '../../application/issue_credit_note.dart';
import '../../domain/billing/credit_note.dart';
import '../../domain/billing/invoice_line.dart';
import '../../domain/shared/money.dart';
import '../theme/app_theme.dart';

/// The Credit Note screen: reducing an invoice a customer has already been sent.
///
/// ## Why this screen does so little
///
/// A credit note is the correction to a **sale that already happened**, so it
/// must name the invoice it corrects and what is being credited. It does not
/// choose the amount to credit — that is what the user types, and the use case
/// checks it against what is still outstanding, accounting for payments already
/// received. A screen that computed the creditable amount would be a second
/// source of truth for money, which is where the mistakes that survive audits come
/// from.
class CreditNoteScreen extends StatefulWidget {
  const CreditNoteScreen({super.key, required this.issueCreditNote});

  final IssueCreditNote issueCreditNote;

  @override
  State<CreditNoteScreen> createState() => _CreditNoteScreenState();
}

class _CreditNoteScreenState extends State<CreditNoteScreen> {
  final _invoice = TextEditingController();
  final _reason = TextEditingController();
  final _amount = TextEditingController();
  final _vat = TextEditingController();

  bool _busy = false;
  String? _issuedNumber;
  String? _problem;

  @override
  void dispose() {
    _invoice.dispose();
    _reason.dispose();
    _amount.dispose();
    _vat.dispose();
    super.dispose();
  }

  Future<void> _issue() async {
    if (_invoice.text.trim().isEmpty) {
      setState(() => _problem = 'Enter the invoice being credited.');
      return;
    }
    if (_amount.text.trim().isEmpty) {
      setState(() => _problem = 'Enter the amount credited.');
      return;
    }

    setState(() {
      _busy = true;
      _problem = null;
      _issuedNumber = null;
    });

    try {
      final note = CreditNote(
        id: 'cn-${DateTime.now().microsecondsSinceEpoch}',
        invoiceId: _invoice.text.trim(),
        date: DateTime.now(),
        vatRateBasisPoints: _vat.text.trim().isEmpty ? 0 : 1300,
        lines: <InvoiceLine>[
          InvoiceLine(
            description:
                _reason.text.trim().isEmpty ? 'Credit' : _reason.text.trim(),
            quantity: 1,
            // Reverses the sale, so the value is what is being credited.
            unitPrice: Money.minor(_minorUnits(_amount.text), 'NPR'),
          ),
        ],
      );

      final outcome = await widget.issueCreditNote(note);
      if (!mounted) return;

      switch (outcome) {
        case CreditNoteIssued(:final number):
          setState(() {
            _busy = false;
            _issuedNumber = number.value;
            // Cleared in place: the fields still reference these controllers.
            _reason.clear();
            _amount.clear();
            _vat.clear();
          });
        case CreditNoteRejected(:final message):
          setState(() {
            _busy = false;
            // The use case's own wording.
            _problem = message;
          });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = 'The credit note could not be issued. $error';
      });
    }
  }

  /// Typed rupees to whole paisa, or zero for a blank field.
  int _minorUnits(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return 0;
    final value = num.tryParse(text) ?? 0;
    return (value * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Text('Issue a credit note', style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Reduces an invoice a customer has already been sent.',
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
                      'Issued as $_issuedNumber.',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        TextField(
          key: const ValueKey<String>('credit-invoice-field'),
          controller: _invoice,
          enabled: !_busy,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Invoice being credited',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const ValueKey<String>('credit-amount-field'),
          controller: _amount,
          enabled: !_busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount credited'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const ValueKey<String>('credit-vat-field'),
          controller: _vat,
          enabled: !_busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'VAT on the credit (optional)',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const ValueKey<String>('credit-reason-field'),
          controller: _reason,
          enabled: !_busy,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            helperText: 'For the customer\'s records.',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          key: const ValueKey<String>('credit-issue-button'),
          onPressed: _busy ? null : _issue,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.receipt_long_outlined, size: 18),
          label: const Text('Issue credit note'),
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
