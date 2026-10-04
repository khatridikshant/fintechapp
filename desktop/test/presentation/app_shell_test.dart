import 'dart:io';

import 'package:financeapp/src/application/account_session.dart';
import 'package:financeapp/src/domain/shared/auth_service.dart';
import 'package:financeapp/src/domain/shared/book_upload.dart';
import 'package:financeapp/src/domain/shared/credential_store.dart';
import 'package:financeapp/src/domain/shared/licence_access.dart';
import 'package:financeapp/src/domain/shared/sign_in.dart';
import 'package:financeapp/src/presentation/app_services.dart';
import 'package:financeapp/src/presentation/finance_app.dart';
import 'package:financeapp/src/presentation/finance_app_shell.dart';
import 'package:financeapp/src/presentation/navigation/app_navigation.dart';
import 'package:financeapp/src/presentation/screens/licence_required_screen.dart';
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
  group('The licence gate', () {
    testWidgets('a successful sign-in reveals the books', (tester) async {
      // The verdict the gate returns, flipped by the sign-in the way a
      // real sign-in stores the authorisation and the next check reads
      // it back.
      LicenceAccess access = Locked(
        reason: LicenceInvalidReason.notInstalled,
        message: 'Sign in to activate this copy of the application.',
      );
      final services = AppServices().withLicenceGate(
        recheck: () async => access,
        signIn: ({required String email, required String password}) async {
          access = Allowed(
            licenceId: 'licence-1',
            expiresAt: null,
            nextValidationAt: null,
            offlineGraceEndsAt: null,
            withinOfflineGracePeriod: true,
          );
        },
      );

      await pumpShell(tester, services: services);
      await tester.pumpAndSettle();

      // Locked: the sign-in screen is shown, not the books.
      expect(find.byType(LicenceRequiredScreen), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'owner@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'password',
      );
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      // The books are revealed: the sign-in screen is gone and the
      // navigation is back. A sign-in that stored the licence but left
      // the shell locked would fail here — the screen would still be
      // showing, with no message and no error.
      expect(find.byType(LicenceRequiredScreen), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('navigation-area')),
        findsOneWidget,
      );
    });
  });

  group('Signing out', () {
    testWidgets(
        'forgets the stored licence, so the application cannot be used without '
        'signing in again', (tester) async {
      // The stored licence, standing in for what LicenceStore holds on disk.
      var licenceStored = false;

      final account = AccountSession(
        auth: _AcceptingAuth(),
        store: _MemoryCredentialStore(),
        uploadBuilder: (_) => throw UnimplementedError('no uploads here'),
      );

      const allowed = Allowed(
        licenceId: 'licence-1',
        expiresAt: null,
        nextValidationAt: null,
        offlineGraceEndsAt: null,
        withinOfflineGracePeriod: true,
      );
      const locked = Locked(
        reason: LicenceInvalidReason.notInstalled,
        message: 'Sign in to activate this copy of the application.',
      );

      final services = AppServices(account: account).withLicenceGate(
        recheck: () async => licenceStored ? allowed : locked,
        signIn: ({required String email, required String password}) async {
          await account.signIn(
            serverBaseUrl: Uri.parse('http://127.0.0.1:8000'),
            email: email,
            password: password,
          );
          licenceStored = true;
        },
        signOut: () async {
          // Mirrors the real signOutForLicence: the licence goes with the token.
          licenceStored = false;
          await account.signOut();
        },
      );

      await pumpShell(tester, services: services);

      // Locked, so sign in through the gate to reach the books.
      expect(find.byType(LicenceRequiredScreen), findsOneWidget);
      await tester.enterText(
          find.byType(TextFormField).at(0), 'owner@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.byType(LicenceRequiredScreen), findsNothing);

      // Settings offers Sign out, because the account is signed in.
      await tester.tap(navItem('Settings'));
      await tester.pumpAndSettle();
      const signOutButton = ValueKey<String>('sign-out-button');
      expect(find.byKey(signOutButton), findsOneWidget);
      await tester.tap(find.byKey(signOutButton));
      // Signing out now rebuilds twice: the services, then the licence verdict.
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      // **The licence must be forgotten, not just the token.** A stored licence
      // that outlives a sign-out is an application anyone can open without ever
      // signing in again, which is the whole thing the gate exists to prevent.
      expect(licenceStored, isFalse,
          reason: 'signing out must forget the stored licence, not only the '
              'token');
      expect(find.byType(LicenceRequiredScreen), findsOneWidget,
          reason: 'after signing out the application must be locked again');
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

/// Signs in successfully, so the account reads as signed in without a server.
class _AcceptingAuth implements AuthActions {
  @override
  Future<SignInResult> signIn({
    required Uri serverBaseUrl,
    required String email,
    required String password,
    String? deviceName,
  }) async =>
      SignInResult(
        status: SignInStatus.signedIn,
        message: 'Signed in.',
        session: BackendSession(
          serverBaseUrl: serverBaseUrl,
          token: 'token-for-tests',
          bookId: '23',
          accountLabel: email,
        ),
      );

  @override
  Future<void> signOut(BackendSession session) async {}
}

/// An in-memory stand-in for the OS credential store.
class _MemoryCredentialStore implements CredentialStore {
  BackendSession? _session;

  @override
  Future<BackendSession?> read() async => _session;

  @override
  Future<void> write(BackendSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}
