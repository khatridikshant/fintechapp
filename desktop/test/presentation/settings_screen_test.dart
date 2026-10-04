import 'package:financeapp/src/application/account_session.dart';
import 'package:financeapp/src/domain/shared/book_backup.dart';
import 'package:financeapp/src/domain/shared/book_upload.dart';
import 'package:financeapp/src/domain/shared/book_upload_service.dart';
import 'package:financeapp/src/domain/shared/credential_store.dart';
import 'package:financeapp/src/domain/shared/sign_in.dart';
import 'package:financeapp/src/presentation/app_services.dart';
import 'package:financeapp/src/presentation/finance_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// Widget tests for the account panel.
///
/// What matters on this screen is that the user is told three things: the app
/// works without signing in, a refused attempt says why, and the password is
/// cleared rather than left sitting in a field.
void main() {
  const password = 'a-long-enough-passphrase';

  Future<void> openSettings(
    WidgetTester tester, {
    required AccountSession account,
  }) async {
    tester.view.physicalSize = const Size(1600, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester
        .pumpWidget(FinanceApp(services: AppServices(account: account)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
  }

  AccountSession anAccount(
    ScriptedAuthActions auth, {
    CredentialStore? store,
  }) =>
      AccountSession(
        auth: auth,
        store: store ?? MapCredentialStore(),
        deviceName: 'office-desktop',
        uploadBuilder: (session) => const _RefusingUploads(),
      );

  group('before signing in', () {
    testWidgets('offers the three fields and a sign-in button', (tester) async {
      await openSettings(
        tester,
        account: anAccount(ScriptedAuthActions()),
      );

      expect(
          find.byKey(const ValueKey<String>('server-field')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('email-field')), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('password-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('sign-in-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('sign-out-button')),
        findsNothing,
      );
    });

    testWidgets('the password field hides what is typed into it',
        (tester) async {
      await openSettings(tester, account: anAccount(ScriptedAuthActions()));

      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('password-field')),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.obscureText, isTrue);
    });

    testWidgets('says signing in is optional, and what it is for',
        (tester) async {
      await openSettings(tester, account: anAccount(ScriptedAuthActions()));

      expect(
        find.textContaining('only needed to copy a backup'),
        findsOneWidget,
      );
      expect(find.textContaining('works without it'), findsOneWidget);
    });

    testWidgets('will not submit while the fields are empty', (tester) async {
      final auth = ScriptedAuthActions();
      await openSettings(tester, account: anAccount(auth));

      await tester.tap(find.byKey(const ValueKey<String>('sign-in-button')));
      await tester.pumpAndSettle();

      expect(auth.lastEmail, isNull, reason: 'no attempt should be made');
      expect(find.text('Enter the email address'), findsOneWidget);
    });
  });

  group('a successful sign-in', () {
    testWidgets('sends what was typed and then shows the account',
        (tester) async {
      // The stub must hand back a **session**: `AccountSession` deliberately does
      // not treat a token-less "success" as signed in, because there would be
      // nothing to store or send with.
      final auth = ScriptedAuthActions(
        session: BackendSession(
          serverBaseUrl: Uri.parse('https://books.example.com'),
          token: 'issued-token',
          bookId: '42',
          accountLabel: 'sita@example.com',
        ),
      );
      await openSettings(tester, account: anAccount(auth));

      await tester.enterText(
        find.byKey(const ValueKey<String>('server-field')),
        'https://books.example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('email-field')),
        'sita@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('password-field')),
        password,
      );
      await tester.tap(find.byKey(const ValueKey<String>('sign-in-button')));
      await tester.pumpAndSettle();

      expect(auth.lastEmail, 'sita@example.com');
      expect(auth.lastPassword, password);
      expect(auth.lastServer, Uri.parse('https://books.example.com'));

      // The form is replaced by the signed-in summary rather than sitting there
      // full of a password that has already been used.
      expect(
        find.textContaining('Signed in as'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('password-field')),
        findsNothing,
      );
    });

    testWidgets('clears the password field, so it is not left on screen',
        (tester) async {
      await openSettings(tester, account: anAccount(ScriptedAuthActions()));

      await tester.enterText(
        find.byKey(const ValueKey<String>('server-field')),
        'https://books.example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('email-field')),
        'sita@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('password-field')),
        'mistyped',
      );
      await tester.tap(find.byKey(const ValueKey<String>('sign-in-button')));
      await tester.pumpAndSettle();

      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('password-field')),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.controller.text, isEmpty);
    });
  });

  group('a refused sign-in', () {
    testWidgets('shows the reason and does not pretend to be signed in',
        (tester) async {
      await openSettings(
        tester,
        account: anAccount(
          ScriptedAuthActions(
            result: const SignInResult(
              status: SignInStatus.rejected,
              message: 'Those details were not accepted.',
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('server-field')),
        'https://books.example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('email-field')),
        'sita@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('password-field')),
        'wrong',
      );
      await tester.tap(find.byKey(const ValueKey<String>('sign-in-button')));
      await tester.pumpAndSettle();

      expect(find.text('Those details were not accepted.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('sign-out-button')),
        findsNothing,
      );
    });

    testWidgets('an unreachable server says work can continue offline',
        (tester) async {
      await openSettings(
        tester,
        account: anAccount(
          ScriptedAuthActions(
            result: const SignInResult(
              status: SignInStatus.unreachable,
              message: 'Could not reach the server. You can keep working '
                  'offline; sign in again when you have a connection.',
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('server-field')),
        'https://books.example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('email-field')),
        'sita@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('password-field')),
        password,
      );
      await tester.tap(find.byKey(const ValueKey<String>('sign-in-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('keep working offline'), findsOneWidget);
    });
  });

  group('while signed in', () {
    Future<void> openSignedIn(
        WidgetTester tester, ScriptedAuthActions auth) async {
      final account = anAccount(
        auth,
        store: MapCredentialStore(<String, String>{
          'server': 'https://books.example.com',
          'token': 'stored-token',
          'book': '42',
          'account': 'sita@example.com',
        }),
      );
      await account.restore();
      await openSettings(tester, account: account);
    }

    testWidgets('shows the account and where backups are being sent',
        (tester) async {
      await openSignedIn(tester, ScriptedAuthActions());

      expect(
          find.textContaining('Signed in as sita@example.com'), findsOneWidget);
      expect(
        find.textContaining('https://books.example.com'),
        findsWidgets,
        reason: 'a user deciding whether their books are safe needs to know '
            'where the copy goes',
      );
      expect(
        find.byKey(const ValueKey<String>('sign-out-button')),
        findsOneWidget,
      );
      expect(
          find.byKey(const ValueKey<String>('sign-in-button')), findsNothing);
    });

    testWidgets('signing out works even when the server does not answer',
        (tester) async {
      // The one outcome that must never happen is a sign-out that fails.
      final auth = ScriptedAuthActions(throwOnSignOut: true);
      await openSignedIn(tester, auth);

      await tester.tap(find.byKey(const ValueKey<String>('sign-out-button')));
      await tester.pumpAndSettle();

      expect(find.text('Signed out on this computer.'), findsOneWidget);
      expect(auth.signOutCalls, 1);
    });
  });
}

/// An uploader that sends nothing.
///
/// A builder that **threw** used to be enough for these tests, because signing in
/// never re-read `AccountSession.upload`. It does now: a successful sign-in tells
/// the shell to re-read its services, so the licence verdict and the token are
/// re-read together, and that reads the uploader. Throwing would fail the
/// sign-in test for a reason that has nothing to do with what it asserts.
class _RefusingUploads implements UploadActions {
  const _RefusingUploads();

  @override
  BackendSession? get session => null;

  @override
  bool get canUpload => false;

  @override
  Future<UploadResult> upload(BookBackup backup) async =>
      throw UnimplementedError('this test uploads nothing');

  @override
  Future<List<UploadRecord>> uploadsFor(String fiscalYearLabel) async =>
      const <UploadRecord>[];
}
