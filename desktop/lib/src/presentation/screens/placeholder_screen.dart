import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shown for a section that the design specifies but that has not been built.
///
/// It says so plainly. A blank panel would look like a bug, and a crash would be
/// worse, and neither tells the user anything true.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.surface,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: AppSpacing.md),
            // The heavier rule under a page title, in the newspaper sense.
            const Divider(height: AppSpacing.xl, thickness: 2),
            Text(
              'Not built yet',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: palette.warning),
            ),
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                'This screen is part of the design in ui.txt but has not been '
                'implemented. The accounting and reporting logic behind much of '
                'it already exists and is tested; there is no user interface for '
                'it yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
