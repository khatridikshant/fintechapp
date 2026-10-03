import 'package:flutter/material.dart';

import '../../application/transfer_cash.dart';
import '../../domain/accounting/account.dart';
import '../../domain/shared/money.dart';
import '../theme/app_theme.dart';

/// Moving money between the business's own bank and cash.
///
/// ## Why this screen is narrower than the Journal screen
///
/// The Journal screen will post any balanced entry, including one debiting
/// "Office Rent" against "Bank" — mechanically valid, balanced, and a completely
/// different event from moving money between two tills. **On a two-box form the
/// two look identical.**
///
/// So this screen offers only the two cash accounts, and `TransferCash` enforces
/// that as a rule rather than as advice. A transfer that lands on an expense is a
/// miscategorisation, and it should not be recordable here and look like
/// housekeeping.
///
/// ## Nothing is computed here
///
/// The entry is built and posted by [TransferCash], through the ordinary journal
/// engine. A transfer gets no special treatment that could make it behave
/// differently from the ledger it lands in.
class TransferScreen extends StatefulWidget {
  const TransferScreen({
    super.key,
    required this.transferCash,
    this.fiscalYearLabel,
  });

  final TransferCash transferCash;
  final String? fiscalYearLabel;

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  Account _from = TransferCash.defaultFrom;
  Account _to = TransferCash.defaultTo;
  final _amount = TextEditingController();
  final _reason = TextEditingController();

  bool _busy = false;
  String? _problem;
  String? _done;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    setState(() {
      _busy = true;
      _problem = null;
      _done = null;
    });

    try {
      final amount = Money.fromMajorUnits(
        num.tryParse(_amount.text.trim()) ?? 0,
        'NPR',
      );

      final outcome = await widget.transferCash.transfer(
        from: _from,
        to: _to,
        amount: amount,
        reason: _reason.text,
      );

      if (!mounted) return;
      setState(() {
        _busy = false;
        if (outcome is TransferRefused) {
          // **Shown verbatim.** The message says what to do instead, not only what
          // went wrong.
          _problem = outcome.message;
        } else if (outcome is TransferCompleted) {
          _done = 'Moved ${outcome.amount.format()} from '
              '${outcome.from.name} to ${outcome.to.name}.';
          _amount.clear();
          _reason.clear();
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = 'The transfer could not be recorded. $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: palette.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: <Widget>[
            Text('Transfer', style: textTheme.headlineLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Move money between your bank and cash. This does not record a '
              'payment or an expense — use the Journal screen for anything else.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_done != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _Banner(text: _done!, colour: palette.positive),
              ),
            _AccountChooser(
              label: 'From',
              value: _from,
              accounts: TransferCash.cashAccounts,
              enabled: !_busy,
              onChanged: (Account account) => setState(() => _from = account),
            ),
            const SizedBox(height: AppSpacing.md),
            _AccountChooser(
              label: 'To',
              value: _to,
              accounts: TransferCash.cashAccounts,
              enabled: !_busy,
              onChanged: (Account account) => setState(() => _to = account),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey<String>('transfer-amount-field'),
              controller: _amount,
              enabled: !_busy,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey<String>('transfer-reason-field'),
              controller: _reason,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Reason',
                helperText: 'Optional. Appears on the journal entry.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const ValueKey<String>('transfer-post-button'),
              onPressed: _busy ? null : _post,
              icon: _busy
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.swap_horiz_outlined, size: 18),
              label: const Text('Record transfer'),
            ),
            if (_problem != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: _Banner(text: _problem!, colour: palette.error),
              ),
          ],
        ),
      ),
    );
  }
}

/// Which cash account.
///
/// **Only [TransferCash.cashAccounts] are offered.** An expense account is simply
/// not selectable, which is the point: the mistake this screen exists to prevent
/// cannot be reached through it.
class _AccountChooser extends StatelessWidget {
  const _AccountChooser({
    required this.label,
    required this.value,
    required this.accounts,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final Account value;
  final List<Account> accounts;
  final bool enabled;
  final ValueChanged<Account> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Account>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: <DropdownMenuItem<Account>>[
        for (final account in accounts)
          DropdownMenuItem<Account>(
            value: account,
            child: Text('${account.code} — ${account.name}'),
          ),
      ],
      onChanged: enabled
          ? (Account? account) {
              if (account != null) onChanged(account);
            }
          : null,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.colour});

  final String text;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: colour),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Text(text, style: textTheme.bodyMedium?.copyWith(color: colour)),
    );
  }
}
