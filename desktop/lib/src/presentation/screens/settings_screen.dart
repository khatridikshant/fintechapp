import 'package:flutter/material.dart';

import '../../application/account_session.dart';
import '../../application/business_details.dart';
import '../../domain/billing/business_profile.dart';
import '../theme/app_theme.dart';

/// The Settings screen.
///
/// Holds what the business tells the application about itself, and where it sends
/// its backups. **The account panel is all that exists so far**; currency,
/// rounding, and document numbering also belong here.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.account,
    required this.onAccountChanged,
    required this.businessDetails,
    required this.onBusinessSaved,
  });

  /// Null when the application has no account support, which is a test and a
  /// developer configuration rather than a normal state.
  final AccountSession? account;

  /// Called after signing in or out, so the shell can rebuild its services.
  /// Signing in changes which token a backup is sent with, so the whole bundle
  /// has to be re-read rather than one service patched.
  final Future<void> Function() onAccountChanged;

  /// Where this business's details are saved. Null disables the panel, which is a
  /// test rather than a normal state.
  final BusinessDetails? businessDetails;

  /// Saves the business details and rebuilds, so anything reading the profile
  /// sees the new one.
  final Future<void> Function(BusinessProfile profile) onBusinessSaved;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Text('Settings', style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xl),
        BusinessDetailsPanel(details: businessDetails),
        const SizedBox(height: AppSpacing.xl),
        Divider(height: 1, thickness: 1, color: palette.divider),
        const SizedBox(height: AppSpacing.xl),
        AccountPanel(account: account),
        const SizedBox(height: AppSpacing.xl),
        Divider(height: 1, thickness: 1, color: palette.divider),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Currency, tax, rounding and document numbering belong here too.',
          style: textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// One piece of the Settings screen: this business's own details.
///
/// **These are not preferences — they are what make an invoice legal.** Rule 17
/// requires the supplier's name, address, and PAN on every tax invoice, and a
/// bill without the supplier's PAN is not a valid tax bill. So the panel says so
/// plainly rather than presenting them as a form to fill in.
///
/// The VAT box is the one thing here that changes behaviour rather than merely
/// being printed: it decides whether invoices charge 13%. It is **stated, never
/// inferred**, because whether a business must register depends on an annual
/// turnover threshold the Finance Act resets every year.
class BusinessDetailsPanel extends StatefulWidget {
  const BusinessDetailsPanel({super.key, required this.details});

  /// Where the details live. Null disables the panel, which is a test rather than
  /// a normal state.
  final BusinessDetails? details;

  @override
  State<BusinessDetailsPanel> createState() => _BusinessDetailsPanelState();
}

class _BusinessDetailsPanelState extends State<BusinessDetailsPanel> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _pan = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _bank = TextEditingController();

  bool _vatRegistered = false;
  bool _busy = false;
  bool _loading = true;
  bool _setUp = false;
  String? _message;
  bool _messageIsProblem = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _pan.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _bank.dispose();
    super.dispose();
  }

  /// Reads the saved profile.
  ///
  /// **Loading here rather than in the shell** keeps a `Future` of a row out of
  /// `AppServices` and out of the navigation builder, which is synchronous. The
  /// panel owns its own data because it is the only thing that shows it.
  Future<void> _load() async {
    final details = widget.details;
    if (details == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final existing = await details.load();
      if (!mounted) return;
      setState(() {
        if (existing != null) {
          _name.text = existing.name;
          _pan.text = existing.panNumber ?? '';
          _address.text = existing.address ?? '';
          _phone.text = existing.phone ?? '';
          _email.text = existing.email ?? '';
          _bank.text = existing.bankDetails ?? '';
          _vatRegistered = existing.isVatRegistered;
        }
        _setUp = existing != null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'The saved business details could not be read: $error';
        _messageIsProblem = true;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      // The domain validates the PAN and refuses a VAT-registered business with
      // none, so the screen does not re-implement either rule.
      final profile = BusinessProfile(
        name: _name.text,
        panNumber: _pan.text,
        isVatRegistered: _vatRegistered,
        address: _address.text,
        phone: _phone.text,
        email: _email.text,
        bankDetails: _bank.text,
      );
      await widget.details!.save(profile);
      if (!mounted) return;
      setState(() {
        _busy = false;
        // Now set up, whatever the previous state was.
        _setUp = true;
        _message = 'Business details saved.';
        _messageIsProblem = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // The message is the domain's own wording, which says *why*.
        _message = error.toString().replaceFirst('Invalid argument(s): ', '');
        _messageIsProblem = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'THIS BUSINESS',
          style: textTheme.labelSmall?.copyWith(
            color: palette.secondaryText,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Details printed on your invoices', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Nepali law requires your name, address and PAN on every tax invoice. '
          'An invoice without your PAN is not a valid tax bill.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        if (!_setUp)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: palette.canvas,
                border: Border.all(color: palette.warning),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.warning_amber_outlined,
                      size: 18, color: palette.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Not set up yet. Until this is filled in, the application '
                      'cannot produce a valid tax invoice.',
                      style: textTheme.bodySmall,
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
                key: const ValueKey<String>('business-name-field'),
                controller: _name,
                enabled: !_busy,
                decoration: const InputDecoration(
                    labelText: 'Registered business name'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter the registered business name'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey<String>('business-pan-field'),
                controller: _pan,
                enabled: !_busy,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'PAN (optional)',
                  helperText: 'Nine digits. Required for a valid tax invoice.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey<String>('business-address-field'),
                controller: _address,
                enabled: !_busy,
                decoration:
                    const InputDecoration(labelText: 'Registered address'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey<String>('business-phone-field'),
                controller: _phone,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Telephone'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey<String>('business-email-field'),
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey<String>('business-bank-field'),
                controller: _bank,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Bank details'),
              ),
              const SizedBox(height: AppSpacing.md),
              // A checkbox rather than a dropdown: there are only two states, and
              // the question is whether the business is registered, not which band.
              CheckboxListTile(
                key: const ValueKey<String>('business-vat-field'),
                value: _vatRegistered,
                onChanged: _busy
                    ? null
                    : (value) =>
                        setState(() => _vatRegistered = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('This business is registered for VAT'),
                subtitle: Text(
                  'Tick this if you are registered. Invoices will then charge '
                  'VAT at the standard rate. Leave it unticked for a business '
                  'below the registration threshold.',
                  style: textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                key: const ValueKey<String>('business-save-button'),
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: const Text('Save business details'),
              ),
            ],
          ),
        ),
        if (_message != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            _message!,
            style: textTheme.bodyMedium?.copyWith(
              color: _messageIsProblem ? palette.error : palette.positive,
            ),
          ),
        ],
      ],
    );
  }
}

/// One piece of the Settings screen: the account panel.
///
/// ## What it deliberately does not do
///
/// **It never shows the password, and never keeps it.** The field is obscured, it
/// is cleared as soon as the attempt finishes, and the resulting session holds a
/// token only. Storing the password would add a liability a token does not have:
/// a token can be revoked, a password cannot be recovered.
class AccountPanel extends StatefulWidget {
  const AccountPanel({super.key, required this.account});

  /// Null when the application has no account support, which is a test and a
  /// developer configuration rather than a normal state.
  final AccountSession? account;

  @override
  State<AccountPanel> createState() => _AccountPanelState();
}

class _AccountPanelState extends State<AccountPanel> {
  final _formKey = GlobalKey<FormState>();
  final _server = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  String? _message;
  bool _messageIsProblem = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill the server from a stored session, so a returning user types only
    // their password.
    _server.text = widget.account?.session?.serverBaseUrl.toString() ?? '';
  }

  @override
  void dispose() {
    _server.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    final server = Uri.tryParse(_server.text.trim());
    if (server == null) {
      setState(() {
        _message = 'That is not a usable server address.';
        _messageIsProblem = true;
      });
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    final result = await widget.account!.signIn(
      serverBaseUrl: server,
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;

    // The password is dropped whether the attempt worked or not. There is no
    // reason to hold it a moment longer, and keeping it would make it visible to
    // anything that later reads the widget tree.
    _password.clear();

    setState(() {
      _busy = false;
      _message = result.message;
      _messageIsProblem = !result.isSuccess;
    });
  }

  Future<void> _signOut() async {
    setState(() {
      _busy = true;
      _message = null;
    });

    await widget.account?.signOut();
    if (!mounted) return;

    setState(() {
      _busy = false;
      _message = 'Signed out on this computer.';
      _messageIsProblem = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    final account = widget.account;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'ACCOUNT',
          style: textTheme.labelSmall?.copyWith(
            color: palette.secondaryText,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Send a backup to a server',
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Signing in is only needed to copy a backup off this computer. '
          'Everything else works without it, including with no connection at all.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        if (account == null)
          Text(
            'This application has no account support configured.',
            style: textTheme.bodyMedium,
          )
        else if (account.isSignedIn) ...<Widget>[
          _SignedInSummary(
            accountLabel: account.accountLabel,
            serverBaseUrl: account.session?.serverBaseUrl,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            key: const ValueKey<String>('sign-out-button'),
            onPressed: _busy ? null : _signOut,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
          ),
        ] else
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextFormField(
                  key: const ValueKey<String>('server-field'),
                  controller: _server,
                  enabled: !_busy,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Server address',
                    helperText: 'For example https://books.example.com',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter the server address'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const ValueKey<String>('email-field'),
                  controller: _email,
                  enabled: !_busy,
                  autocorrect: false,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter the email address'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const ValueKey<String>('password-field'),
                  controller: _password,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Enter the password'
                      : null,
                  onFieldSubmitted: (_) => _signIn(),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  key: const ValueKey<String>('sign-in-button'),
                  onPressed: _busy ? null : _signIn,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login, size: 18),
                  label: const Text('Sign in'),
                ),
              ],
            ),
          ),
        if (_message != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            _message!,
            style: textTheme.bodyMedium?.copyWith(
              color: _messageIsProblem ? palette.error : palette.positive,
            ),
          ),
        ],
      ],
    );
  }
}

/// The signed-in state, stated plainly.
///
/// The server address is shown because a user deciding whether their books are
/// safe needs to know *where* the copy goes, and a stored token for a forgotten
/// server is worse than useless.
class _SignedInSummary extends StatelessWidget {
  const _SignedInSummary(
      {required this.accountLabel, required this.serverBaseUrl});

  final String? accountLabel;
  final Uri? serverBaseUrl;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.canvas,
        border: Border.all(color: palette.divider),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.check_circle_outline, size: 18, color: palette.positive),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Signed in as ${accountLabel ?? 'this installation'}',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (serverBaseUrl != null)
                  Text(
                    'Backups are sent to $serverBaseUrl',
                    style: textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
