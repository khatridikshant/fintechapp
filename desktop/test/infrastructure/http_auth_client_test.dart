import 'package:financeapp/src/domain/shared/book_upload.dart';
import 'package:financeapp/src/domain/shared/sign_in.dart';
import 'package:financeapp/src/infrastructure/auth/http_auth_client.dart';
import 'package:financeapp/src/infrastructure/http/http_transport.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// Tests for signing in over HTTP.
///
/// The point of this layer is turning three very different answers into three
/// very different results, so most of these are about refusal and about not
/// inventing a success.
void main() {
  final server = Uri.parse('https://books.example.com');

  Future<SignInResult> signIn(
    HttpAuthClient client, {
    String password = 'a-long-enough-passphrase',
    Uri? at,
  }) =>
      client.signIn(
        serverBaseUrl: at ?? server,
        email: 'sita@example.com',
        password: password,
        deviceName: 'office-desktop',
      );

  /// A well-formed success, so a test changes only the one thing it is checking.
  TransportResponse accepted({
    String token = 'issued-token',
    int bookId = 42,
    String email = 'sita@example.com',
  }) =>
      jsonResponse(200, <String, Object?>{
        'token': token,
        'user': <String, Object?>{
          'id': 1,
          'name': 'Sita Sharma',
          'email': email
        },
        'book': <String, Object?>{'id': bookId, 'name': 'Primary'},
      });

  group('a successful sign-in', () {
    test('returns a session with the token and the book', () async {
      final result = await signIn(
        HttpAuthClient(ScriptedTransport(<TransportResponse>[accepted()])),
      );

      expect(result.status, SignInStatus.signedIn);
      expect(result.isSuccess, isTrue);
      expect(result.session?.token, 'issued-token');
      expect(result.session?.bookId, '42');
      expect(result.session?.serverBaseUrl, server);
      expect(result.session?.accountLabel, 'sita@example.com');
    });

    test('posts to the login endpoint with the credentials', () async {
      final transport = ScriptedTransport(<TransportResponse>[accepted()]);
      await signIn(HttpAuthClient(transport), password: 'the-password');

      expect(
        transport.urls.single,
        Uri.parse('https://books.example.com/api/auth/login'),
      );
      expect(transport.methods.single, 'POST');
      expect(transport.bodies.single, contains('sita@example.com'));
      expect(transport.bodies.single, contains('the-password'));
      expect(transport.bodies.single, contains('office-desktop'));
    });

    test('sends no bearer credential on the way in', () async {
      final transport = ScriptedTransport(<TransportResponse>[accepted()]);
      await signIn(HttpAuthClient(transport));

      // There is nothing to authenticate yet; a bearer header here would be a
      // stale token from a previous session leaking into a sign-in request.
      expect(transport.headers.single.containsKey('Authorization'), isFalse);
    });
  });

  group('refusals', () {
    test('a 422 is wrong credentials, and says nothing more', () async {
      final result = await signIn(
        HttpAuthClient(
          ScriptedTransport(<TransportResponse>[
            const TransportResponse(
              statusCode: 422,
              body:
                  '{"errors":{"email":["These credentials do not match our records."]}}',
            ),
          ]),
        ),
      );

      expect(result.status, SignInStatus.rejected);
      expect(result.isSuccess, isFalse);
      expect(result.session, isNull);
      expect(result.message.toLowerCase(), isNot(contains('taken')),
          reason: 'the message must not reveal whether the address exists');
    });

    test('a 429 says to wait, and is not a credentials problem', () async {
      final result = await signIn(
        HttpAuthClient(
          ScriptedTransport(<TransportResponse>[
            const TransportResponse(statusCode: 429),
          ]),
        ),
      );

      expect(result.status, SignInStatus.rejected);
      expect(result.message, contains('Too many attempts'));
    });

    test('a 500 is not a rejection and not a success', () async {
      final result = await signIn(
        HttpAuthClient(
          ScriptedTransport(<TransportResponse>[
            const TransportResponse(statusCode: 500, body: 'boom'),
          ]),
        ),
      );

      expect(result.isSuccess, isFalse);
      expect(result.session, isNull);
      expect(result.status, SignInStatus.unreachable);
    });
  });

  group('the three offline shapes', () {
    test('a refused connection is unreachable, not a rejection', () async {
      final result = await signIn(HttpAuthClient(OfflineTransport()));

      expect(result.status, SignInStatus.unreachable);
      expect(result.isSuccess, isFalse);
      expect(result.session, isNull);
      expect(result.message, contains('offline'),
          reason: 'the user needs to know they can keep working');
    });

    test('an unreadable 200 is not a sign-in', () async {
      final result = await signIn(
        HttpAuthClient(
          ScriptedTransport(<TransportResponse>[
            const TransportResponse(statusCode: 200, body: 'not json at all'),
          ]),
        ),
      );

      expect(result.isSuccess, isFalse);
      expect(result.session, isNull);
    });

    test('a 200 with no token is not a sign-in', () async {
      final result = await signIn(
        HttpAuthClient(
          ScriptedTransport(<TransportResponse>[
            jsonResponse(200, <String, Object?>{'user': <String, Object?>{}}),
          ]),
        ),
      );

      expect(result.isSuccess, isFalse);
      expect(result.session, isNull);
    });

    test('a token with no book id is refused, because uploads need one',
        () async {
      // Storing a session that cannot address an upload endpoint would produce a
      // sign-in that looks successful and fails at the first send.
      final result = await signIn(
        HttpAuthClient(
          ScriptedTransport(<TransportResponse>[
            jsonResponse(200, <String, Object?>{'token': 'issued-token'}),
          ]),
        ),
      );

      expect(result.isSuccess, isFalse);
      expect(result.session, isNull);
    });
  });

  group('a bad server address is caught before any request', () {
    test('plaintext to a remote host is refused, and no request is made',
        () async {
      final transport = ScriptedTransport(<TransportResponse>[accepted()]);
      final result = await signIn(
        HttpAuthClient(transport),
        at: Uri.parse('http://books.example.com'),
      );

      expect(result.status, SignInStatus.invalidServer);
      expect(result.isAddressProblem, isTrue);
      expect(transport.urls, isEmpty,
          reason: 'no credentials may be sent over clear text');
    });

    test('plaintext to this machine is allowed, for development', () async {
      final result = await signIn(
        HttpAuthClient(ScriptedTransport(<TransportResponse>[accepted()])),
        at: Uri.parse('http://127.0.0.1:8123'),
      );

      expect(result.status, SignInStatus.signedIn);
    });

    test('a scheme that is not http or https is refused', () async {
      final transport = ScriptedTransport(<TransportResponse>[accepted()]);
      final result = await signIn(
        HttpAuthClient(transport),
        at: Uri.parse('ftp://books.example.com'),
      );

      expect(result.status, SignInStatus.invalidServer);
      expect(transport.urls, isEmpty);
    });
  });

  group('signing out', () {
    BackendSession aSession() => BackendSession(
          serverBaseUrl: Uri.parse('https://books.example.com'),
          token: 'issued-token',
          bookId: '42',
        );

    test('tells the server, with the token', () async {
      final transport = ScriptedTransport(<TransportResponse>[
        const TransportResponse(statusCode: 200),
      ]);

      await HttpAuthClient(transport).signOut(aSession());

      expect(transport.methods.single, 'POST');
      expect(
        transport.urls.single,
        Uri.parse('https://books.example.com/api/auth/logout'),
      );
      expect(transport.headers.single['Authorization'], 'Bearer issued-token');
    });

    test('never throws, even when the server cannot be reached', () async {
      // The caller clears the local session regardless, and a throw here would
      // turn "you are signed out" into an error dialog.
      await HttpAuthClient(OfflineTransport()).signOut(aSession());
    });

    test('never throws on an error status either', () async {
      await HttpAuthClient(
        ScriptedTransport(<TransportResponse>[
          const TransportResponse(statusCode: 500),
        ]),
      ).signOut(aSession());
    });
  });
}
