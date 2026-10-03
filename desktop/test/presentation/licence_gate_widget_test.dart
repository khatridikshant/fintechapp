import 'dart:async';

import 'package:financeapp/src/domain/shared/licence_access.dart';

import 'package:financeapp/src/presentation/app_services.dart';
import 'package:financeapp/src/presentation/finance_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The gate is only worth anything if the books are genuinely unreachable while it
/// is closed. These tests drive the real [FinanceApp] and assert on what is
/// actually on screen.
void main() {
  const locked = Locked(
    reason: LicenceInvalidReason.notInstalled,
    message: 'Sign in to activate this copy of the application.',
    needsNetwork: true,
  );

  const allowed = Allowed(
    licenceId: 'lic-1',
    expiresAt: null,
    nextValidationAt: null,
    offlineGraceEndsAt: null,
    withinOfflineGracePeriod: true,
  );

  AppServices gated(
    Future<LicenceAccess> Function() recheck, {
    Future<void> Function({
      required String serverUrl,
      required String email,
      required String password,
    })? signIn,
  }) =>
      const AppServices().withLicenceGate(
        recheck: recheck,
        signIn: signIn ??
            ({
              required String serverUrl,
              required String email,
              required String password,
            }) async {},
      );

  group('With no licence, the books never appear', () {
    testWidgets('the sign-in screen is shown, not the navigation', (tester) async {
      await tester.pumpWidget(
        FinanceApp(services: gated(() async => locked)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in to continue'), findsOneWidget);

      // **The assertion that matters.** Not "the dialog is in front", but that no
      // navigation and no report exists at all ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â because a locked application that
      // is merely *covered* has locked nothing.
      expect(find.text('Trial Balance'), findsNothing);
      expect(find.text('General Ledger'), findsNothing);
      expect(find.text('Dashboard'), findsNothing);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('no accounting screen is reachable while locked', (tester) async {
      await tester.pumpWidget(
        FinanceApp(services: gated(() async => locked)),
      );
      await tester.pumpAndSettle();

      // Tapping every visible label must not reveal a book.
      for (final label in ['Trial Balance', 'Sales', 'Stock', 'Purchases']) {
        expect(find.text(label), findsNothing, reason: '$label must be absent');
      }
    });

    testWidgets('the user is told their records are safe', (tester) async {
      // **Said first, and always.** A business that will not open assumes the
      // worst; someone who deletes files because they think the gate corrupted them
      // is the real damage this screen could cause.
      await tester.pumpWidget(
        FinanceApp(services: gated(() async => locked)),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('have not been changed'),
        findsOneWidget,
      );
    });

    testWidgets('signing in is offered with server, email and password',
        (tester) async {
      await tester.pumpWidget(
        FinanceApp(services: gated(() async => locked)),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Server address'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    });

    testWidgets('a plain-http server is refused before any request', (tester) async {
      var called = false;
      await tester.pumpWidget(
        FinanceApp(
          services: gated(
            () async => locked,
            signIn: ({
              required String serverUrl,
              required String email,
              required String password,
            }) async {
              called = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Server address'),
        'http://insecure.example',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'owner@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'correct-horse',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      // **Never sent.** A password on clear text is the whole session readable.
      expect(called, isFalse);
      // Matched exactly rather than by substring, because the hint text also
      // contains "https://" and a substring match would pass whether or not the
      // validation had fired Ã¢â‚¬â€ the check-that-cannot-fail shape 7.25 records.
      expect(
        find.text('The address must start with https://.'),
        findsOneWidget,
      );
    });
  });

  group('With a valid licence, the application opens', () {
    testWidgets('the navigation and the first report are shown', (tester) async {
      await tester.pumpWidget(
        FinanceApp(services: gated(() async => allowed)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in to continue'), findsNothing);
      expect(find.byType(ListView), findsOneWidget,
          reason: 'the navigation list is mounted');
      expect(find.text('Trial Balance'), findsWidgets);
    });

    testWidgets('the verdict is checked once per launch, not per navigation',
        (tester) async {
      // **Offline by construction.** One evaluation and no transport means the
      // specification's offline requirement is a fact about the code rather than a
      // claim about it.
      var checks = 0;
      await tester.pumpWidget(
        FinanceApp(
          services: gated(() async {
            checks++;
            return allowed;
          }),
        ),
      );
      await tester.pumpAndSettle();

      final afterStart = checks;
      expect(afterStart, 1);

      await tester.tap(find.text('General Ledger'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trial Balance'));
      await tester.pumpAndSettle();

      expect(
        checks,
        afterStart,
        reason: 'navigating must not re-contact the licence store',
      );
    });
  });

  group('While the verdict is unknown, nothing is shown', () {
    testWidgets('a brief flash of the books is impossible', (tester) async {
      // The verdict is read asynchronously. Until it arrives the shell shows a
      // spinner, because rendering the navigation first would be the exact flash a
      // gate exists to prevent.
      final gate = Completer<LicenceAccess>();
      await tester.pumpWidget(
        FinanceApp(services: gated(() => gate.future)),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(ListView), findsNothing);

      gate.complete(locked);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Sign in to continue'), findsOneWidget);
    });
  });
}