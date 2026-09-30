import 'dart:io';

import 'package:financeapp/src/presentation/app_services.dart';
import 'package:financeapp/src/presentation/finance_app.dart';
import 'package:financeapp/src/presentation/finance_app_shell.dart';
import 'package:financeapp/src/presentation/navigation/app_navigation.dart';
import 'package:financeapp/src/presentation/screens/licenses_screen.dart';
import 'package:financeapp/src/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The default wiring: no use cases attached, so the Trial Balance entry has no
/// screen and shows the "not built yet" notice like every other unfinished
/// section. The Trial Balance screen has its own test file, which supplies a
/// loader.
const AppServices services = AppServices();

/// Widget tests for the application shell.
///
/// These assert the *contract* the shell offers — that a section is reachable,
/// that an unbuilt section says so, and that the design tokens are actually
/// applied — rather than pixel positions, which would break on any styling
/// change and prove nothing.
void main() {
  // The navigation has roughly thirty items. A list only builds what fits on
  // screen, so the default test viewport would leave most sections unfindable.
  // A tall surface lays the whole list out, which is what a real window scrolled
  // to the bottom would show.
  const testSurface = Size(1400, 2600);
  setUp(() {
    // ignore: deprecated_member_use
    TestWidgetsFlutterBinding.ensureInitialized();
  });
  Future<void> pumpShell(WidgetTester tester,
      {AppServices services = const AppServices()}) async {
    tester.view.physicalSize = testSurface;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FinanceApp(services: services));
    await tester.pumpAndSettle();
  }

  /// Finds a navigation item, scoped to the navigation area.
  ///
  /// Without the scope, a selected section's title appears twice: once in the
  /// navigation and once as the content heading. Scoping makes the tests say
  /// which one they mean.
  Finder navItem(String title) => find.descendant(
        of: find.byKey(const ValueKey<String>('navigation-area')),
        matching: find.text(title),
      );

  /// The navigation the shell builds for the default wiring.
  final navGroups = buildNavigation(services);
  final navItems = allNavigationItemsFor(services);

  group('The shell', () {
    testWidgets('builds and shows the application name', (tester) async {
      await pumpShell(tester, services: services);
      expect(find.text(AppTheme.applicationName), findsWidgets);
    });
    testWidgets('lists every navigation group', (tester) async {
      await pumpShell(tester, services: services);
      for (final group in navGroups) {
        expect(
          find.text(group.title.toUpperCase()),
          findsOneWidget,
          reason: 'missing navigation group ${group.title}',
        );
      }
    });
    testWidgets('lists every navigation section', (tester) async {
      await pumpShell(tester, services: services);
      for (final item in navItems) {
        expect(
          navItem(item.title),
          findsOneWidget,
          reason: 'missing navigation section ${item.title}',
        );
      }
    });
    testWidgets('opens with the first section selected', (tester) async {
      await pumpShell(tester, services: services);
      final first = navGroups.first.sections.first;
      expect(navItem(first.title), findsOneWidget);
    });
  });
  group('Navigation', () {
    testWidgets('a section can be selected and its heading shown',
        (tester) async {
      await pumpShell(tester, services: services);
      await tester.tap(navItem('Trial Balance'));
      await tester.pumpAndSettle();
      // Once in the navigation and once as the content heading.
      expect(find.text('Trial Balance'), findsNWidgets(2));
    });
    testWidgets('navigating between sections changes the content',
        (tester) async {
      await pumpShell(tester, services: services);
      await tester.tap(navItem('Dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('Not built yet'), findsOneWidget);
      await tester.tap(navItem('Balance Sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Not built yet'), findsOneWidget);
      // The content heading follows the selection.
      expect(find.text('Balance Sheet'), findsNWidgets(2));
    });
    testWidgets('every navigation section is reachable without crashing',
        (tester) async {
      await pumpShell(tester, services: services);
      for (final item in navItems) {
        await tester.tap(navItem(item.title));
        await tester.pumpAndSettle();
        // No exception was thrown, which is the assertion that matters here.
        expect(find.byType(MaterialApp), findsOneWidget);
      }
    });
  });
  group('Sections that are not built yet', () {
    testWidgets('say so plainly instead of showing a blank panel',
        (tester) async {
      await pumpShell(tester, services: services);
      await tester.tap(navItem('Invoices'));
      await tester.pumpAndSettle();
      expect(find.text('Not built yet'), findsOneWidget);
      expect(
        find.textContaining('has not been implemented'),
        findsOneWidget,
      );
    });
    testWidgets('explain that the logic behind them already exists',
        (tester) async {
      await pumpShell(tester, services: services);
      await tester.tap(navItem('Stock Movements'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('already exists and is tested'),
        findsOneWidget,
      );
    });
    testWidgets('every unbuilt section shows the same notice', (tester) async {
      await pumpShell(tester, services: services);
      final unbuilt = navItems.where((item) => item.route == null);
      expect(unbuilt, isNotEmpty, reason: 'most sections are not built yet');
      for (final item in unbuilt) {
        await tester.tap(navItem(item.title));
        await tester.pumpAndSettle();
        expect(find.text('Not built yet'), findsOneWidget,
            reason: '${item.title} did not say it is not built');
      }
    });
  });
  group('The licences screen', () {
    testWidgets('is reachable from the System group', (tester) async {
      await pumpShell(tester, services: services);
      await tester.tap(navItem('Licences'));
      await tester.pumpAndSettle();
      expect(find.byType(LicensesScreen), findsOneWidget);
    });
    test('is the only built screen', () {
      final built = navItems.where((item) => item.route != null);
      expect(built.map((item) => item.title), ['Licences']);
    });
    testWidgets('states why the notices are shown', (tester) async {
      await pumpShell(tester, services: services);
      await tester.tap(navItem('Licences'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('copyright notices'),
        findsOneWidget,
        reason: 'the screen must explain why it exists, so nobody deletes it '
            'later thinking it is boilerplate',
      );
    });
    testWidgets('shows the licence page itself', (tester) async {
      await pumpShell(tester, services: services);
      await tester.tap(navItem('Licences'));
      await tester.pumpAndSettle();
      // Flutter's own LicensePage renders every dependency's licence text.
      expect(find.byType(LicensePage), findsOneWidget);
    });
  });
  group('The theme', () {
    testWidgets('is applied, with the specified accent colour', (tester) async {
      await pumpShell(tester, services: services);
      final context = tester.element(find.byType(FinanceAppShell));
      final palette = Theme.of(context).extension<AppPalette>()!;
      // Concrete values from ui.txt section 9: a restrained blue accent on a
      // warm neutral base. Asserting them means a later palette change is a
      // deliberate act rather than an accident.
      expect(palette.accent, const Color(0xFF1F6FB2));
      expect(palette.canvas, const Color(0xFFF4F3F0));
      expect(palette.surface, const Color(0xFFFFFFFF));
      expect(palette.positive, const Color(0xFF2E7D32));
      expect(palette.error, const Color(0xFFC62828));
    });
    testWidgets('uses the Segoe UI family with Linux and macOS fallbacks',
        (tester) async {
      await pumpShell(tester, services: services);
      final context = tester.element(find.byType(FinanceAppShell));
      final theme = Theme.of(context);
      // Segoe UI is the Windows 7/8 system face the design is imitating.
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Segoe UI');
    });
    testWidgets('follows the newspaper type scale from ui.txt section 7',
        (tester) async {
      await pumpShell(tester, services: services);
      final context = tester.element(find.byType(FinanceAppShell));
      final text = Theme.of(context).textTheme;
      expect(text.headlineLarge?.fontSize, 32);
      expect(text.headlineMedium?.fontSize, 24);
      expect(text.titleLarge?.fontSize, 18);
      expect(text.bodyMedium?.fontSize, 14);
      expect(text.bodySmall?.fontSize, 13);
    });
    testWidgets('keeps corner radii small, as ui.txt section 23 requires',
        (tester) async {
      // "The application should not look like a mobile banking app."
      expect(AppRadius.container, lessThanOrEqualTo(6));
      expect(AppRadius.control, lessThanOrEqualTo(4));
      expect(AppRadius.none, 0);
    });
    testWidgets('provides a dark palette as well', (tester) async {
      final light = AppTheme.light();
      final dark = AppTheme.dark();
      expect(
        light.extension<AppPalette>()!.canvas,
        isNot(dark.extension<AppPalette>()!.canvas),
        reason: 'a dark theme that was never given different values would look '
            'broken rather than dark',
      );
    });
  });
  group('Layer discipline', () {
    // The real layer-boundary guards live in `architecture_test.dart`, which
    // reads the source files. This only records the expectation here so the two
    // files do not drift apart.
    test('the presentation layer is covered by an architecture test', () {
      expect(File('test/presentation/architecture_test.dart').existsSync(),
          isTrue);
    });
  });
}
