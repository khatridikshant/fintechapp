import 'package:flutter/material.dart';

import '../../application/create_customer.dart';
import '../theme/app_theme.dart';

/// The New Customer screen.
///
/// ## What the screen does and does not decide
///
/// **It decides nothing about the business.** It collects what a person typed and
/// hands it to [CreateCustomer]; the reference, the identifier, the PAN rules, and
/// the "is this allowed" decisions all belong to the use case and the domain.
/// The one thing the screen *does* own is the PAN box, because on a laptop or a
/// tablet you cannot type the hyphenated form, and a customer who gives `301-234-567`
/// means the same one as `301234567`.
///
/// ## After a save
///
/// The form is cleared and the new reference is shown, so the user can quote it
/// straight away — that is the whole point of giving customers a code.
class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key, required this.createCustomer});

  final CreateCustomer createCustomer;

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _pan = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _businessName = TextEditingController();

  bool _vatRegistered = false;
  bool _busy = false;
  String? _savedCode;
  String? _problem;

  @override
  void dispose() {
    _name.dispose();
    _pan.dispose();
    _phone.dispose();
    _address.dispose();
    _businessName.dispose();
    super.dispose();
  }

  /// What the customer typed, normalised the way a person would read it.
  ///
  /// **Digits only.** A PAN is nine digits whether it is written `301234567` or
  /// `301-234-567`, and on a soft keyboard the hyphens are a nuisance that would
  /// otherwise be silently part of the value.
  String get _panDigits => _pan.text.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _problem = null;
      _savedCode = null;
    });

    try {
      final created = await widget.createCustomer(
        name: _name.text.trim(),
        panNumber: _panDigits.isEmpty ? null : _panDigits,
        isVatRegistered: _vatRegistered,
        phone: _phone.text,
        address: _address.text,
        businessName: _businessName.text,
      );

      if (!mounted) return;
      setState(() {
        _busy = false;
        _savedCode = created.customer.code;
        // Cleared, so the next customer starts from a blank form rather than
        // silently duplicating the last one.
        _name.clear();
        _pan.clear();
        _phone.clear();
        _address.clear();
        _businessName.clear();
        _vatRegistered = false;
      });
    } on CustomerRejected catch (rejection) {
      // **The domain's own wording**, shown next to the form rather than
      // replaced by a second version that could drift from it.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = rejection.reason;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = 'The customer could not be saved. $error';
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
        Text('New customer', style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'A customer is someone you bill. Businesses get a reference such as '
          'C-0001 that you can quote; individuals do not need a PAN.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_savedCode != null)
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
                      'Saved as $_savedCode',
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
                key: const ValueKey<String>('customer-name-field'),
                controller: _name,
                enabled: !_busy,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  helperText: 'The person or trading name',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter a name'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey<String>('customer-business-name-field'),
                controller: _businessName,
                enabled: !_busy,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Registered business name (optional)',
                  helperText: 'If it differs from the contact name',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey<String>('customer-pan-field'),
                controller: _pan,
                enabled: !_busy,
                autocorrect: false,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'PAN (optional)',
                  helperText: 'Nine digits. Required to claim input credit.',
                ),
                // Checked here as well as in the domain, so an obvious typo is
                // caught while the user is still typing. The domain still has the
                // final say; this is a convenience, not the rule.
                validator: (value) {
                  final digits = _panDigits;
                  if (digits.isEmpty) return null;
                  if (digits.length != 9) {
                    return 'A PAN is nine digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey<String>('customer-phone-field'),
                controller: _phone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telephone'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey<String>('customer-address-field'),
                controller: _address,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: AppSpacing.md),
              // A checkbox, because there are only two states and the question is
              // "is this customer VAT-registered", not which band.
              CheckboxListTile(
                key: const ValueKey<String>('customer-vat-field'),
                value: _vatRegistered,
                onChanged: _busy
                    ? null
                    : (value) =>
                        setState(() => _vatRegistered = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('This customer is registered for VAT'),
                subtitle: Text(
                  'If ticked, their PAN must be given: a VAT number in Nepal is '
                  'the PAN with a registration flag.',
                  style: textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                key: const ValueKey<String>('customer-save-button'),
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Save customer'),
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
