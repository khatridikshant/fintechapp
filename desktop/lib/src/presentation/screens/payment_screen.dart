import 'package:flutter/material.dart';

import '../../application/record_payment.dart';
import '../../domain/accounting/account.dart';
import '../../domain/accounting/chart_of_accounts.dart';
import '../../domain/billing/payment.dart';
import '../../domain/shared/money.dart';
import '../theme/app_theme.dart';

/// The Receipt form: record money received against an invoice.
///
/// ## What the screen does and does not decide
///
/// **Nothing about the accounting.** It collects what was typed and hands it to
/// [RecordPayment]; the journal entry, the invoice's new balance, and the refusal
/// of an overpayment are all the use case's.
///
/// Two things in particular are *not* the screen's business, and both are why it
/// is written this way:
///
/// - **Whether the amount is too much.** Exactly the outstanding balance is
///   allowed and one paisa more is refused, accounting for credit notes already
///   issued. A screen that rounded or tidied the figure would turn a correct
///   refusal into an accepted overpayment.
/// - **Which account is debited.** The screen offers *bank* or *cash* because a
///   person has to choose where the money landed, and nothing more.
///
/// ## The amount is sent exactly as typed
///
/// `5000.50` becomes 500050 paisa and no more. The typing is a double, so a
/// fraction that cannot be represented exactly is rounded once here — and the
/// domain derives every total itself.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.recordPayment});

  final RecordPayment recordPayment;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoice = TextEditingController();
  final _amount = TextEditingController();

  /// Where the money landed. Bank is the common case for a business.
  Account _account = ChartOfAccounts.bank;

  bool _busy = false;
  String? _problem;
  Money? _settledTo;

  @override
  void dispose() {
    _invoice.dispose();
    _amount.dispose();
    super.dispose();
  }

  Money? _parseAmount(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null) return null;
    return Money.fromMajorUnits(value, 'NPR');
  }

  Future<void> _record() async {
    final problem = _validate();
    if (problem != null) {
      setState(() {
        _problem = problem;
        _settledTo = null;
      });
      return;
    }

    setState(() {
      _busy = true;
      _problem = null;
      _settledTo = null;
    });

    try {
      final outcome = await widget.recordPayment(_toPayment());
      if (!mounted) return;

      switch (outcome) {
        case PaymentRecorded(:final balance):
          setState(() {
            _busy = false;
            _settledTo = balance.outstanding;
            _clear();
          });
        case PaymentRejected(:final message):
          setState(() {
            _busy = false;
            // **The use case's own explanation**, not a second one written here.
            _problem = message;
            // The typed values are kept, so a refusal can be corrected.
          });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = 'The payment could not be recorded. $error';
      });
    }
  }

  /// The first thing wrong with the form, in the user's words.
  ///
  /// "You cannot press the button yet" rather than "the accountant refused this
  /// payment" — the use case answers the second.
  String? _validate() {
    if (_invoice.text.trim().isEmpty) {
      return 'Enter the invoice this payment settles.';
    }
    final amount = _parseAmount(_amount.text);
    if (amount == null) return 'Enter the amount received.';
    if (!amount.isPositive) return 'The amount must be more than zero.';
    return null;
  }

  Payment _toPayment() => Payment(
        // The screen does not choose an identifier for a document; the use case
        // keys the journal entry off it, so it only has to be unique enough.
        id: 'pay-${DateTime.now().microsecondsSinceEpoch}',
        invoiceId: _invoice.text.trim(),
        date: DateTime.now(),
        amount: _parseAmount(_amount.text)!,
        account: _account,
      );

  /// Empties the form without disposing anything: the live fields still reference
  /// these controllers until the rebuild completes.
  void _clear() {
    _invoice.clear();
    _amount.clear();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Text('Record a payment', style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Money received from a customer, against an invoice they were sent.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_settledTo != null)
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
                      _settledTo!.isZero
                          ? 'Recorded. The invoice is now fully settled.'
                          : 'Recorded. ${_settledTo!.format()} is still '
                              'outstanding on this invoice.',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                key: const ValueKey<String>('payment-invoice-field'),
                controller: _invoice,
                enabled: !_busy,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Invoice',
                  helperText:
                      'The invoice number, for example INV-2082-83-0001',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey<String>('payment-amount-field'),
                controller: _amount,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount received',
                  helperText:
                      'The exact amount owed is allowed; more is refused.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Text('Received into', style: textTheme.labelSmall),
              const SizedBox(height: AppSpacing.xs),
              // Bank or cash. A person has to say where the money landed; nothing
              // else about the entry is the screen's decision.
              Row(
                children: <Widget>[
                  ChoiceChip(
                    key: const ValueKey<String>('payment-method-bank'),
                    label: const Text('Bank'),
                    selected: _account == ChartOfAccounts.bank,
                    onSelected: _busy
                        ? null
                        : (_) => setState(
                              () => _account = ChartOfAccounts.bank,
                            ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ChoiceChip(
                    key: const ValueKey<String>('payment-method-cash'),
                    label: const Text('Cash'),
                    selected: _account == ChartOfAccounts.cash,
                    onSelected: _busy
                        ? null
                        : (_) => setState(
                              () => _account = ChartOfAccounts.cash,
                            ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              FilledButton.icon(
                key: const ValueKey<String>('payment-record-button'),
                onPressed: _busy ? null : _record,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.payments_outlined, size: 18),
                label: const Text('Record payment'),
              ),
            ],
          ),
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
