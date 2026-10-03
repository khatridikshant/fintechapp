import 'package:flutter/material.dart';

import '../application/books_session.dart';
import 'app_services.dart';
import '../domain/shared/licence_access.dart';
import 'navigation/app_navigation.dart';
import 'screens/licence_required_screen.dart';
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
  late AppServices _services = widget.services;
  late List<NavigationGroup> _groups = _navigationFor(widget.services);

  /// The licence verdict, or null until it has been read.
  ///
  /// **Null means "not yet known", not "allowed".** While null the shell shows
  /// nothing at all rather than assuming permission, so the books are never
  /// briefly visible before the licence has been checked. A build with no licence
  /// service Ã¢â‚¬â€ a widget test, or the developer stopgap Ã¢â‚¬â€ leaves this null forever
  /// and is therefore always unlocked, which is the only case that bypasses.
  LicenceAccess? _access;

  @override
  void initState() {
    super.initState();
    // Read once at construction. The result arriving late replaces the blank with
    // either the shell or the sign-in screen.
    _loadLicence();
  }

  Future<void> _loadLicence() async {
    final recheck = _services.recheckLicence;
    if (recheck == null) return;
    final access = await recheck();
    if (mounted) setState(() => _access = access);
  }

  /// While the verdict is unknown, show nothing rather than the books.
  ///
  /// A brief flash of a fully populated shell before the licence is checked is the
  /// exact thing a gate exists to prevent.
  bool get _awaitingLicence => _access == null && _services.recheckLicence != null;
  late NavigationItem _selected = _groups.first.sections.first;

  List<NavigationGroup> _navigationFor(AppServices services) =>
      buildNavigation(services, onAccountChanged: refreshAccount);

  @override
  void didUpdateWidget(FinanceAppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.services != widget.services) {
      setState(() {
        _services = widget.services;
        _groups = _navigationFor(_services);
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

  /// Re-reads the services after the account changed.
  ///
  /// Signing in replaces the token a backup is sent with, and the uploader takes
  /// its session in its constructor, so the whole bundle is rebuilt -- the same
  /// reasoning as [selectYear]. Without this the Backup screen keeps reporting
  /// that nobody is signed in after a successful sign-in.
  Future<void> refreshAccount() async {
    if (!mounted) return;
    setState(() {
      _services = _services.forAccount();
      _groups = _navigationFor(_services);
    });
  }

  /// Selects a navigation item.
  ///
  /// Exposed so a test, and later a deep link, can drive navigation without
  /// reaching into private state.
  void select(NavigationItem item) => setState(() => _selected = item);

  /// Re-evaluates the licence, and reveals the books if it now permits operation.
  ///
  /// Called after a successful sign-in, because signing in is what fetches and
  /// stores the authorisation. **Until this returns the shell stays locked**, so
  /// there is no window in which the books are briefly visible before the licence
  /// has been checked.
  ///
  /// The verdict lives in this widget rather than in [AppServices] deliberately:
  /// `AppServices` is an immutable bundle whose copy methods enumerate every
  /// capability, and adding one more that must survive every one of them is how a
  /// capability silently goes missing Ã¢â‚¬â€ the defect 4.30 already records for
  /// `forAccount`.
  Future<void> refreshLicence() async {
    final recheck = _services.recheckLicence;
    if (recheck == null) return;

    final access = await recheck();
    if (!mounted) return;
    setState(() => _access = access);
  }

  /// Placeholder for a build with no licence wiring at all.
  ///
  /// **Fails loudly rather than opening the books.** A build that quietly skipped
  /// the gate would be indistinguishable from one that passed it, and the second
  /// is the one worth being able to claim.
  static Future<void> _refuseSignIn({
    required String serverUrl,
    required String email,
    required String password,
  }) async {
    throw StateError(
      'This build has no licence service configured, so signing in cannot be '
      'completed. Refusing rather than opening the books without a licence.',
    );
  }

  /// Re-evaluates the licence and, if it now permits operation, reveals the books.
  ///
  /// Called after a successful sign-in, because signing in is what fetches and
  /// stores the authorisation. **Until this completes the shell stays locked**, so
  /// there is no window in which the books are briefly visible before the licence
  /// has been checked.
  /// Switches the open fiscal year.
  ///
  /// Every use case belongs to one year's books, so the whole service bundle is
  /// replaced rather than any single loader being patched. A concluded year is
  /// opened **read-only** by the session, and the shell says so.
  Future<void> selectYear(int index) async {
    final session = _services.session;
    if (session == null) return;

    await session.open(session.years[index].fiscalYear);
    if (!mounted) return;

    setState(() {
      _services = _services.forSession(session);
      _groups = _navigationFor(_services);
      // The open screen belongs to the old year. Return to the first section so
      // nothing is showing another year's figures.
      _selected = _groups.first.sections.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

// **The gate is checked before the shell is built at all.**
    //
    // A licence problem must not be a dialog *over* the books Ã¢â‚¬â€ the screens behind
    // it would still be mounted and reachable, which locks nothing. The
    // specification requires the application to be locked, and the only way to
    // guarantee that is never to construct the navigation in the first place.
    //
    // While locked, this widget holds no screen references: there is nothing to
    // reach, and nothing that could write to the accounting database.
    final access = _access;
    if (_awaitingLicence) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (access != null && !access.mayOperate) {
      return LicenceRequiredScreen(
        access: access,
        onSignIn: _services.signInForLicence ?? _refuseSignIn,
        onSignOut: _services.signOutForLicence == null ? null : () async {
          await _services.signOutForLicence!();
          await refreshLicence();
        },
      );
    }

    return Scaffold(
      backgroundColor: palette.canvas,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NavigationArea(
            groups: _groups,
            selected: _selected,
            onSelected: select,
            session: _services.session,
            onYearSelected: selectYear,
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
    required this.session,
    required this.onYearSelected,
  });

  final List<NavigationGroup> groups;
  final NavigationItem selected;
  final ValueChanged<NavigationItem> onSelected;
  final BooksSession? session;
  final Future<void> Function(int index) onYearSelected;

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
            if (session != null)
              _FiscalYearSelector(
                session: session!,
                onSelected: onYearSelected,
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text(
                  'No fiscal year is open.',
                  style: textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The fiscal year selector.
///
/// One SQLite file per year, so switching year opens different books. A
/// concluded year is opened **read-only**, and the selector says so rather than
/// leaving the user to discover it when a screen refuses to save.
class _FiscalYearSelector extends StatelessWidget {
  const _FiscalYearSelector({required this.session, required this.onSelected});

  final BooksSession session;
  final Future<void> Function(int index) onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final open = session.openYear;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'FISCAL YEAR',
            style: textTheme.labelSmall?.copyWith(
              color: palette.secondaryText,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          DropdownButton<int>(
            key: const ValueKey<String>('fiscal-year-selector'),
            isExpanded: true,
            value: session.years.indexWhere(
              (y) => y.fiscalYear.label == open.fiscalYear.label,
            ),
            underline: const SizedBox.shrink(),
            items: <DropdownMenuItem<int>>[
              for (var i = 0; i < session.years.length; i++)
                DropdownMenuItem<int>(
                  value: i,
                  child: Text(
                    session.years[i].fiscalYear.label,
                    style: textTheme.bodyMedium,
                  ),
                ),
            ],
            onChanged: (index) {
              if (index != null) onSelected(index);
            },
          ),
          if (open.isReadOnly) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            // Stated, not discovered later. A concluded year refuses writes, so
            // the user should know before they try to make one.
            Row(
              children: <Widget>[
                Icon(Icons.lock_outline, size: 13, color: palette.warning),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Concluded year, read-only',
                    style: textTheme.labelSmall?.copyWith(
                      color: palette.warning,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
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
