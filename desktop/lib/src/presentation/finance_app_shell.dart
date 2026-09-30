import 'package:flutter/material.dart';

import 'app_services.dart';
import 'navigation/app_navigation.dart';
import 'theme/app_theme.dart';

/// The application window.
///
/// A left navigation rail and a content area, which is the layout `ui.txt`
/// sections 3 and 12 describe: Windows 7 desktop structure, Windows 8
/// rectangular navigation items and large section labels, and newspaper rules
/// rather than shadows.
///
/// The shell is deliberately **free of data access**. It does not import
/// `domain/` or `infrastructure/`. Screens call use cases, which arrive through
/// [services]; the shell only decides what is on screen.
class FinanceAppShell extends StatefulWidget {
  const FinanceAppShell({super.key, this.services = const AppServices()});

  final AppServices services;

  @override
  State<FinanceAppShell> createState() => FinanceAppShellState();
}

class FinanceAppShellState extends State<FinanceAppShell> {
  late List<NavigationGroup> _groups = buildNavigation(widget.services);
  late NavigationItem _selected = _groups.first.sections.first;

  @override
  void didUpdateWidget(FinanceAppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.services != widget.services) {
      setState(() {
        _groups = buildNavigation(widget.services);
        // The previously selected section may no longer have a screen, so fall
        // back to the first rather than showing a stale screen.
        if (_groups
            .expand((g) => g.sections)
            .every((s) => s.title != _selected.title)) {
          _selected = _groups.first.sections.first;
        }
      });
    }
  }

  /// Selects a navigation item.
  ///
  /// Exposed so a test, and later a deep link, can drive navigation without
  /// reaching into private state.
  void select(NavigationItem item) => setState(() => _selected = item);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.canvas,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NavigationArea(
            groups: _groups,
            selected: _selected,
            onSelected: select,
          ),
          Expanded(child: _contentFor(_selected)),
        ],
      ),
    );
  }

  Widget _contentFor(NavigationItem item) {
    final route = item.route;
    // A section with a real screen shows it; everything else says plainly that
    // it has not been built, rather than showing a blank panel.
    return route != null ? route(context) : placeholderFor(item.title);
  }
}

class _NavigationArea extends StatelessWidget {
  const _NavigationArea({
    required this.groups,
    required this.selected,
    required this.onSelected,
  });

  final List<NavigationGroup> groups;
  final NavigationItem selected;
  final ValueChanged<NavigationItem> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      key: const ValueKey<String>('navigation-area'),
      width: 232,
      // The colour lives in the decoration: Flutter refuses a Container that is
      // given both a `color` and a `decoration`.
      decoration: BoxDecoration(
        color: palette.surface,
        // A vertical rule, not a shadow. ui.txt section 22 prefers borders.
        border: Border(right: BorderSide(color: palette.divider)),
      ),
      child: SafeArea(
        right: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.sm,
                bottom: AppSpacing.lg,
              ),
              child: Text(
                AppTheme.applicationName,
                style: textTheme.headlineMedium?.copyWith(letterSpacing: -0.4),
              ),
            ),
            for (final group in groups) ...<Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                child: Text(
                  group.title.toUpperCase(),
                  style: textTheme.labelSmall?.copyWith(
                    color: palette.secondaryText,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final section in group.sections)
                _NavigationTile(
                  item: section,
                  isSelected: section.title == selected.title,
                  onTap: () => onSelected(section),
                ),
            ],
            const SizedBox(height: AppSpacing.xl),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                'FY 2082/83 — not built yet',
                style: textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final NavigationItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: isSelected ? palette.accent.withValues(alpha: 0.10) : null,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: Container(
            decoration: BoxDecoration(
              // A left bar marks the selection, in the newspaper manner.
              border: Border(
                left: BorderSide(
                  color: isSelected ? palette.accent : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: isSelected ? palette.accent : palette.secondaryText,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    item.title,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color:
                              isSelected ? palette.accent : palette.primaryText,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
