import 'package:flutter/material.dart';

import '../../domain/shared/licence_access.dart';

/// The screen shown when the application may not open its books.
///
/// ## Why this is a full screen and not a dialog
///
/// The specification requires that when a licence has expired *"the application
/// shall lock the application"*, and that *"financial business operations shall not
/// contain licensing logic"*. A dialog over the shell would leave the shell Ã¢â‚¬â€ and
/// therefore every screen behind it Ã¢â‚¬â€ mounted and reachable, which locks nothing.
///
/// ## What it must never do
///
/// **It never mentions or touches the books.** The specification is explicit that
/// *"license enforcement shall not delete, corrupt, or modify the user's
/// accounting data"*, and it *"shall protect the business data"* while locked. So
/// there is no "start anyway", no "continue read-only", and no destructive action
/// of any kind here Ã¢â‚¬â€ the data is untouched and still there when access returns,
/// which the message says plainly so the user is not afraid to switch the machine
/// off.
class LicenceRequiredScreen extends StatefulWidget {
  const LicenceRequiredScreen({
    super.key,
    required this.access,
    required this.onSignIn,
    this.onSignOut,
  });

  /// Why the application is locked, and what to tell the user.
  final LicenceAccess access;

  /// Called when the user asks to sign in. Supplied by the caller, because signing
  /// in needs a transport and a server address and this screen owns neither.
  final Future<void> Function({
    required String serverUrl,
    required String email,
    required String password,
  }) onSignIn;

  /// Shown when there is something to sign out of. Null on a first run.
  final Future<void> Function()? onSignOut;

  @override
  State<LicenceRequiredScreen> createState() => _LicenceRequiredScreenState();
}

class _LicenceRequiredScreenState extends State<LicenceRequiredScreen> {
  final _serverController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _serverController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.onSignIn(
        serverUrl: _serverController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // On success the parent replaces this screen with the shell, so there is
      // nothing to do here beyond stopping the spinner.
    } on Object catch (error) {
      // **Shown, not swallowed.** A user who cannot sign in must be able to see
      // why; a blank form with a disabled button is indistinguishable from a
      // frozen application.
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locked = widget.access as Locked;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Sign in to continue',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(locked.message, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                // **Said every time, and said first.**
                //
                // A user whose business will not open assumes the worst. Stating
                // that the records are intact and untouched is not reassurance for
                // its own sake Ã¢â‚¬â€ it is the difference between someone who waits and
                // someone who starts deleting files.
                Text(
                  'Your accounting records are safe and have not been changed.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _serverController,
                        decoration: const InputDecoration(
                          labelText: 'Server address',
                          hintText: 'https://your-server.example',
                        ),
                        keyboardType: TextInputType.url,
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty) return 'Enter the server address.';
                          if (!text.startsWith('https://')) {
                            // **Refused here rather than at the request.** Sending a
                            // password over plain http is not a warning, it is the
                            // whole session being readable.
                            return 'The address must start with https://.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter your email address.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(labelText: 'Password'),
                        obscureText: true,
                        validator: (value) => (value ?? '').isEmpty
                            ? 'Enter your password.'
                            : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Sign in'),
                      ),
                    ],
                  ),
                ),
                if (widget.onSignOut != null) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy ? null : widget.onSignOut,
                    child: const Text('Sign out'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}