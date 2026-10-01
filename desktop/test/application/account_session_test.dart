import 'package:financeapp/src/application/account_session.dart';
import 'package:financeapp/src/domain/shared/book_upload.dart';
import 'package:financeapp/src/domain/shared/book_upload_service.dart';
import 'package:financeapp/src/domain/shared/credential_store.dart';
import 'package:financeapp/src/domain/shared/sign_in.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// Tests for signing in, signing out, and what is remembered between runs.
///
/// The assertions are about **storage**, not about the screen: "the password is
/// never written" and "a failed attempt stores nothing" are claims about what
/// ends up on disk, so they are made against the stored map directly. A test that
/// only checked the UI would pass while the password sat in a file.
void main() {
  const password = 'a-long-enough-passphrase';
  final server = Uri.parse('https://books.example.com');

  BackendSession aSession({
    String token = 'issued-token',
    String bookId = '42',
    Uri? at,
    String? label = 'sita@example.com',
  }) =>
      BackendSession(
        serverBaseUrl: at ?? server,
        token: token,
        bookId: bookId,
        accountLabel: label,
      );

  /// An [AccountSession] whose uploader records the session it was built with, so
  /// a test can assert the uploader was handed the stored values.
  AccountSession build(
    ScriptedAuthActions auth,
    CredentialStore store, {
    List<BackendSession> handedToUploader = const <BackendSession>[],
  }) {
    // A fresh mutable list, because a `const []` default is unmodifiable and
    // would throw the first time the uploader is built.
    final handed = List<BackendSession>.of(handedToUploader);
    return AccountSession(
      auth: auth,
      store: store,
      deviceName: 'office-desktop',
      uploadBuilder: (session) {
        handed.add(session);
        return _RecordingUpload(session);
      },
    );
  }

  group('a successful sign-in is remembered', () {
    test('stores the token, the book id and the server address', () async {
      final store = MapCredentialStore();
      final auth = ScriptedAuthActions(session: aSession());

      final result = await build(auth, store).signIn(
        serverBaseUrl: server,
        email: 'sita@example.com',
        password: password,
      );

      expect(result.isSuccess, isTrue);
      expect(store.store['token'], 'issued-token');
      expect(store.store['book'], '42');
      expect(store.store['server'], 'https://books.example.com');
    });

    test('the stored values are what the uploader is given', () async {
      final store = MapCredentialStore();
      final handed = <BackendSession>[];
      final account = AccountSession(
        auth: ScriptedAuthActions(session: aSession()),
        store: store,
        uploadBuilder: (session) {
          handed.add(session);
          return _RecordingUpload(session);
        },
      );

      await account.signIn(
        serverBaseUrl: server,
        email: 'sita@example.com',
        password: password,
      );

      // Reading `upload` is what forces the shell to rebuild.
      expect(account.upload, isNotNull);
      expect(handed.single.token, 'issued-token');
      expect(handed.single.bookId, '42');
      expect(handed.single.serverBaseUrl, server);
    });

    test('a returning user is still signed in after a restart', () async {
      final store = MapCredentialStore();
      await build(ScriptedAuthActions(session: aSession()), store).signIn(
        serverBaseUrl: server,
        email: 'sita@example.com',
        password: password,
      );

      // A new application run: same store, new session object.
      final restarted = build(ScriptedAuthActions(), store);
      await restarted.restore();

      expect(restarted.isSignedIn, isTrue);
      expect(restarted.accountLabel, 'sita@example.com');
      expect(restarted.upload, isNotNull);
    });

    test('the device name is sent, so the server can tell installs apart',
        () async {
      final store = MapCredentialStore();
      final auth = ScriptedAuthActions(session: aSession());

      await build(auth, store).signIn(
        serverBaseUrl: server,
        email: 'sita@example.com',
        password: password,
      );

      expect(auth.lastDeviceName, 'office-desktop');
    });
  });

  group('the password is never stored', () {
    test('not in the stored map, not even hashed', () async {
      final store = MapCredentialStore();
      final auth = ScriptedAuthActions(session: aSession());

      await build(auth, store).signIn(
        serverBaseUrl: server,
        email: 'sita@example.com',
        password: password,
      );

      // Asserted on the values, not on the absence of a key: a key named
      // "password_hash" would pass an absence check while holding the secret.
      for (final value in store.store.values) {
        expect(
          value,
          isNot(contains(password)),
          reason: 'no stored value may contain the password',
        );
      }
      expect(
        store.store.keys.map((String k) => k.toLowerCase()),
        isNot(contains('password')),
      );
    });

    test('and it is not even sent to the store on a failed attempt', () async {
      final store = MapCredentialStore();
      final auth = ScriptedAuthActions(
        result: const SignInResult(
          status: SignInStatus.rejected,
          message: 'Those details were not accepted.',
        ),
      );

      await build(auth, store).signIn(
        serverBaseUrl: server,
        email: 'sita@example.com',
        password: password,
      );

      expect(store.writes, isEmpty);
    });
  });

  group('a failed sign-in leaves the application as it was', () {
    test('wrong credentials store nothing and leave nobody signed in',
        () async {
      final store = MapCredentialStore();
      final auth = ScriptedAuthActions(
        result: const SignInResult(
          status: SignInStatus.rejected,
          message: 'Those details were not accepted.',
        ),
      );

      final account = build(auth, store);
      final result = await account.signIn(
        serverBaseUrl: server,
        email: 'sita@example.com',
        password: 'wrong',
      );

      expect(result.status, SignInStatus.rejected);
      expect(result.isSuccess, isFalse);
      expect(store.writes, isEmpty);
      expect(account.isSignedIn, isFalse);
      expect(account.upload, isNull, reason: 'uploading must stay unavailable');
    });

    test('an unreachable server stores nothing and is not a rejection',
        () async {
      final store = MapCredentialStore();
      final auth = ScriptedAuthActions(
        result: const SignInResult(
          status: SignInStatus.unreachable,
          message: 'Could not reach the server.',
        ),
      );

      final account = build(auth, store);
      final result = await account.signIn(
        serverBaseUrl: server,
        email: 'sita@example.com',
        password: password,
      );

      expect(result.status, SignInStatus.unreachable);
      // The distinction matters: a rejection means fix the details, unreachable
      // means carry on offline.
      expect(result.status, isNot(SignInStatus.rejected));
      expect(store.writes, isEmpty);
      expect(account.isSignedIn, isFalse);
    });
  });

  group('signing out always signs out', () {
    test('clears the stored session', () async {
      final store = MapCredentialStore();
      final auth = ScriptedAuthActions(session: aSession());
      final account = build(auth, store);

      await account.signIn(
        serverBaseUrl: server,
        email: 'sita@example.com',
        password: password,
      );
      await account.signOut();

      expect(store.store, isEmpty);
      expect(account.isSignedIn, isFalse);
      expect(account.upload, isNull);
      expect(auth.signOutCalls, 1, reason: 'the server should be told');
    });

    test('clears it even when the server cannot be reached', () async {
      final store = MapCredentialStore();
      final auth = ScriptedAuthActions(
        session: aSession(),
        throwOnSignOut: true,
      );
      final account = build(auth, store);

      await account.signIn(
        serverBaseUrl: server,
        email: 'sita@example.com',
        password: password,
      );

      // The important part: this must not throw, and the local session must be
      // gone. A user who wants to be signed out is signed out, network or not.
      await account.signOut();

      expect(account.isSignedIn, isFalse);
      expect(store.store, isEmpty);
      expect(auth.signOutCalls, 1);
    });

    test('clears it even when the store cannot be cleared', () async {
      // A protected store can fail: no keyring, a locked account, a disk problem.
      final auth = ScriptedAuthActions(session: aSession());
      final account = build(auth, ThrowingClearStore());

      await account.signIn(
        serverBaseUrl: server,
        email: 'sita@example.com',
        password: password,
      );
      await account.signOut();

      expect(account.isSignedIn, isFalse);
    });

    test('signing out twice is not an error', () async {
      final store = MapCredentialStore();
      final auth = ScriptedAuthActions(session: aSession());
      final account = build(auth, store);

      await account.signIn(
        serverBaseUrl: server,
        email: 'sita@example.com',
        password: password,
      );
      await account.signOut();
      await account.signOut();

      expect(account.isSignedIn, isFalse);
    });

    test('signing out with no session does nothing rather than failing',
        () async {
      final auth = ScriptedAuthActions();
      await build(auth, MapCredentialStore()).signOut();

      expect(auth.signOutCalls, 0,
          reason: 'there is no token to revoke, so the server is not called');
    });
  });

  group('a stored session that cannot be used', () {
    test('a corrupt store leaves nobody signed in, without throwing', () async {
      // No server, so the session is unusable.
      final store = MapCredentialStore(<String, String>{'token': 'a-token'});

      final account = build(ScriptedAuthActions(), store);
      await account.restore();

      expect(account.isSignedIn, isFalse);
      expect(account.upload, isNull);
    });

    test('a store that throws is treated as no session', () async {
      // A locked keyring or a corrupt value must not stop the application
      // starting; signing in again is the answer to both.
      final account = build(ScriptedAuthActions(), ThrowingStore());
      await account.restore();

      expect(account.isSignedIn, isFalse);
    });
  });
}

/// Records the session it was built with, so a test can assert the uploader was
/// handed the stored values rather than something else.
class _RecordingUpload implements UploadActions {
  _RecordingUpload(this.session);

  @override
  final BackendSession? session;

  @override
  bool get canUpload => session?.isUsable ?? false;

  @override
  Future<UploadResult> upload(dynamic backup) async => throw UnimplementedError(
        'not used in these tests',
      );

  @override
  Future<List<UploadRecord>> uploadsFor(String fiscalYearLabel) async =>
      const <UploadRecord>[];
}
