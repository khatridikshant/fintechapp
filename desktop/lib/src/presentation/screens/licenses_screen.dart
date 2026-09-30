import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The licence notices for every library this application depends on.
///
/// ## Why this screen has to exist
///
/// MIT and BSD-3 both grant permission to use, copy, and modify the code
/// **on the condition that the copyright notice is retained**. For a shipped
/// desktop application, "retained" means the user can reach it inside the
/// product.
///
/// This is not a formality that can be skipped. Without the notice, the
/// permission being relied on was never actually granted, and the application is
/// shipping without the right to use code it is built on. Every commercial
/// Flutter application has an equivalent screen.
///
/// The data is supplied by Flutter itself: `showLicensePage` reads the licence
/// file bundled with every package at build time and renders them all, including
/// the Flutter SDK's own. Nothing here needs maintaining, and nothing needs
/// adding when a dependency changes.
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  static const String routeName = '/licences';

  /// The contents of the pane. Kept as a function so a test can assert on the
  /// real page rather than a stand-in.
  static Widget route(BuildContext context) => const LicensesScreen();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Licences',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(height: AppSpacing.lg, thickness: 2),
                const SizedBox(height: AppSpacing.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Text(
                    'This application is built on open-source libraries. Their '
                    'licences permit this commercial use on the condition that '
                    'their copyright notices are shown here.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    _Legend(colour: palette.positive, label: 'Permissive'),
                    _Legend(colour: palette.neutral, label: 'Notice required'),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: LicensePage(
              applicationName: AppTheme.applicationName,
              applicationLegalese:
                  'Licence texts for every open-source library this '
                  'application is built on.',
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.colour, required this.label});

  final Color colour;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(width: 10, height: 10, color: colour),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
