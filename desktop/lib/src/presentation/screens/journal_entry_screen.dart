import 'package:flutter/material.dart';

import '../../application/post_journal_entry.dart';
import '../../domain/accounting/account.dart';
import '../../domain/accounting/chart_of_accounts.dart';
import '../../domain/accounting/journal_entry.dart';
import '../../domain/accounting/journal_line.dart';
import '../../domain/shared/money.dart';
import '../theme/app_theme.dart';

/// The Journal Entry screen: a manual entry straight into the accounts.
///
/// ## The one rule this screen enforces visibly
///
/// **Debits must equal credits.** That is what makes double-entry double-entry,
/// and `JournalEntry` refuses an unbalanced entry. So rather than let the user
/// press the button and be told afterwards, the screen shows the difference as
/// they type. The check is **not duplicated logic**: it shows the running totals
/// so the mismatch is visible, while the decision stays with the domain.
///
/// ## Why the accounts are a fixed list
///
/// Only accounts that exist in the chart can be chosen, so the screen offers the
/// standard chart rather than free text. An account that is not in the chart is a
/// bookkeeping decision this version has no place to record, and a free-text field
/// would let a typo become an account.
class JournalEntryScreen extends StatefulWidget {
  const JournalEntryScreen({super.key, required this.postEntry});

  final PostJournalEntry postEntry;

  @override
  State<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends State<JournalEntryScreen> {
  final _description = TextEditingController();
  final _debitAccount = TextEditingController();
  final _debitAmount = TextEditingController();
  final _creditAccount = TextEditingController();
  final _creditAmount = TextEditingController();

  bool _busy = false;
  String? _done;
  String? _problem;

  @override
  void dispose() {
    _description.dispose();
    _debitAccount.dispose();
    _debitAmount.dispose();
    _creditAccount.dispose();
    _creditAmount.dispose();
    super.dispose();
  }

  /// Every account in the standard chart, as a number the domain accepts.
  static final List<Account> _accounts = <Account>[
    ChartOfAccounts.bank,
    ChartOfAccounts.cash,
    ChartOfAccounts.receivable,
    ChartOfAccounts.payable,
    ChartOfAccounts.inventory,
    ChartOfAccounts.officeEquipment,
    ChartOfAccounts.vatPayable,
    ChartOfAccounts.loansPayable,
    ChartOfAccounts.ownersEquity,
    ChartOfAccounts.drawings,
    ChartOfAccounts.retainedEarnings,
    ChartOfAccounts.salesRevenue,
    ChartOfAccounts.otherIncome,
    ChartOfAccounts.officeRent,
    ChartOfAccounts.costOfGoodsSold,
    ChartOfAccounts.salariesAndWages,
    ChartOfAccounts.utilities,
    ChartOfAccounts.officeSupplies,
    ChartOfAccounts.bankCharges,
    ChartOfAccounts.inventoryAdjustments,
  ];

  /// The typed amount, or zero for a blank field.
  Money _amount(TextEditingController field) {
    final value = num.tryParse(field.text.trim()) ?? 0;
    return Money.fromMajorUnits(value, 'NPR');
  }

  Account _accountFor(String id) => _accounts.firstWhere(
        (Account a) => a.id == id,
        orElse: () => ChartOfAccounts.bank,
      );

  /// The running difference, so a mismatch is visible before pressing anything.
  Money get _difference =>
      _amount(_debitAmount).subtract(_amount(_creditAmount));

  Future<void> _post() async {
    if (_description.text.trim().isEmpty) {
      setState(() => _problem = 'Say what this entry is for.');
      return;
    }
    if (!_difference.isZero) {
      setState(() => _problem = 'Debits and credits must be equal.');
      return;
    }

    setState(() {
      _busy = true;
      _problem = null;
      _done = null;
    });

    try {
      final entry = JournalEntry(
        id: 'JE-${DateTime.now().microsecondsSinceEpoch}',
        date: DateTime.now(),
        description: _description.text.trim(),
        lines: <JournalLine>[
          JournalLine.debit(
            account: _accountFor(_debitAccount.text),
            amount: _amount(_debitAmount),
          ),
          JournalLine.credit(
            account: _accountFor(_creditAccount.text),
            amount: _amount(_creditAmount),
          ),
        ],
      );

      final outcome = await widget.postEntry(entry);
      if (!mounted) return;

      switch (outcome) {
        case JournalEntryPosted():
          setState(() {
            _busy = false;
            _done = 'Posted to the accounts.';
            // Cleared in place: the fields still reference these controllers.
            _description.clear();
            _debitAmount.clear();
            _creditAmount.clear();
          });
        case JournalEntryRejected(:final message):
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
        _problem = 'The entry could not be posted. $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final difference = _difference;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Text('Journal entry', style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'A manual entry straight into the accounts. Debits must equal credits.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),

        if (_done != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(_done!, style: textTheme.bodyMedium),
          ),

        TextField(
          key: const ValueKey<String>('entry-description-field'),
          controller: _description,
          enabled: !_busy,
          decoration: const InputDecoration(
            labelText: 'What is this for',
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        Text('Debit', style: textTheme.labelSmall),
        const SizedBox(height: AppSpacing.xs),
        _accountPicker('entry-debit-account-field', _debitAccount),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const ValueKey<String>('entry-debit-amount-field'),
          controller: _debitAmount,
          enabled: !_busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Debit amount'),
        ),
        const SizedBox(height: AppSpacing.md),

        Text('Credit', style: textTheme.labelSmall),
        const SizedBox(height: AppSpacing.xs),
        _accountPicker('entry-credit-account-field', _creditAccount),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const ValueKey<String>('entry-credit-amount-field'),
          controller: _creditAmount,
          enabled: !_busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Credit amount'),
        ),
        const SizedBox(height: AppSpacing.md),

        // **The difference, shown as they type.** Not a rule -- a prompt. The
        // domain still decides whether the entry may be posted.
        Row(
          children: <Widget>[
            Icon(
              difference.isZero
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              size: 18,
              color: difference.isZero ? palette.positive : palette.warning,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              difference.isZero
                  ? 'Debits and credits are equal.'
                  : 'Difference: ${difference.format()}',
              style: textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        FilledButton.icon(
          key: const ValueKey<String>('entry-post-button'),
          onPressed: _busy ? null : _post,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.post_add, size: 18),
          label: const Text('Post entry'),
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

  /// A picker over the standard chart, so no typo can become an account.
  Widget _accountPicker(String key, TextEditingController controller) =>
      DropdownButtonFormField<String>(
        key: ValueKey<String>(key),
        initialValue: _accounts.any((Account a) => a.id == controller.text)
            ? controller.text
            : _accounts.first.id,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Account'),
        items: <DropdownMenuItem<String>>[
          for (final account in _accounts)
            DropdownMenuItem<String>(
              value: account.id,
              child: Text('${account.code} ${account.name}'.trim()),
            ),
        ],
        onChanged: _busy
            ? null
            : (value) {
                controller.text = value ?? '';
                setState(() {});
              },
      );
}
