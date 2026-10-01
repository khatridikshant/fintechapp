// A live check of sign-in against a running backend.
//
// NOT part of the test suite: it is not named `*_test.dart`, so `flutter test`
// does not pick it up. It needs a running server.
//
//   cd backend && php artisan serve --port=8124
//   cd desktop && FINANCEAPP_SERVER=http://127.0.0.1:8124 \
//     flutter test tool/live_signin_check.dart
//
// Why this exists: the unit tests replace the transport with a fake, so nothing
// proves that the JSON this client sends is the JSON the server accepts, that a
// real issued token really reaches `/api/auth/me`, or that signing out actually
// revokes it. Those are exactly the things a fake would happily agree with.
//
// `SecureCredentialStore` is NOT exercised here: it needs the platform plugin,
// which does not exist under `flutter test`. Its behaviour is covered by the unit
// tests against a fake store, and the plugin itself only by a real build.

import 'dart:convert';
import 'dart:io';

import 'package:financeapp/src/domain/shared/book_upload.dart';
import 'package:financeapp/src/domain/shared/sign_in.dart';
import 'package:financeapp/src/infrastructure/auth/http_auth_client.dart';
import 'package:financeapp/src/infrastructure/http/http_transport.dart';
import 'package:flutter_test/flutter_test.dart';

/// The passphrase the check registers with. Long enough to satisfy the policy.
const _password = 'a-long-enough-passphrase';

void main() {
  final serverUrl = _serverFromEnvironment();

  if (serverUrl == null) {
    test('live sign-in check', () {}, skip: 'set FINANCEAPP_SERVER to run');
    return;
  }

  final server = Uri.parse(serverUrl);
  final transport = IoHttpTransport(timeout: const Duration(seconds: 10));
  final client = HttpAuthClient(transport);

  /// One account for the whole run.
  ///
  /// Registration is rate limited to six a minute per address, so creating a
  /// fresh account per test would hit the limit and fail for the wrong reason.
  /// The limit doing its job is not a fault in the code under test.
  late String email;

  setUpAll(() async {
    final response = await transport.send(
      method: 'POST',
      url: Uri.parse('$serverUrl/api/auth/register'),
      headers: const <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonBody(<String, Object?>{
        'name': 'Live Check',
        'email': 'live-signin-${DateTime.now().microsecondsSinceEpoch}'
            '@example.com',
        'password': _password,
        'password_confirmation': _password,
        'device_name': 'live-check',
      }),
    );

    if (response.statusCode == 429) {
      fail('registration is rate limited; wait a minute and run again');
    }
    expect(response.statusCode, 201, reason: response.body);
    email = (jsonDecode(response.body)['user']! as Map)['email']! as String;
  });

  Future<int> meStatus(BackendSession session) async {
    final response = await transport.send(
      method: 'GET',
      url: Uri.parse('$serverUrl/api/auth/me'),
      headers: <String, String>{
        'Authorization': 'Bearer ${session.token}',
        'Accept': 'application/json',
      },
    );
    return response.statusCode;
  }

  Future<SignInResult> signIn(String email, {String? password}) =>
      client.signIn(
        serverBaseUrl: server,
        email: email,
        password: password ?? _password,
        deviceName: 'live-check',
      );

  test('a real account can sign in and its token works', () async {
    final result = await signIn(email);

    expect(result.status, SignInStatus.signedIn, reason: result.message);
    final session = result.session!;
    expect(session.token, isNotEmpty);
    expect(session.bookId, isNotEmpty);

    // The token this client parsed is one the server actually accepts.
    expect(await meStatus(session), 200);

    // ignore: avoid_print
    print('  signed in as ${session.accountLabel}, book ${session.bookId}');
  });

  test('the wrong password is refused and issues no token', () async {
    final result = await signIn(email, password: 'not-the-password');

    expect(result.status, SignInStatus.rejected);
    expect(result.session, isNull);
    expect(result.message.toLowerCase(), isNot(contains('taken')),
        reason: 'the message must not reveal whether the address exists');
  });

  test('an unknown address is refused identically', () async {
    final unknown = await signIn(
      'nobody-${DateTime.now().microsecondsSinceEpoch}@example.com',
      password: 'not-the-password',
    );
    final wrongPassword = await signIn(email, password: 'not-the-password');

    // Same status, so a caller cannot use sign-in to discover which addresses
    // have accounts.
    expect(unknown.status, wrongPassword.status);
    expect(unknown.status, SignInStatus.rejected);
  });

  test('signing out really revokes the token', () async {
    final result = await signIn(email);
    expect(result.status, SignInStatus.signedIn, reason: result.message);
    final session = result.session!;

    expect(await meStatus(session), 200, reason: 'usable before signing out');

    await client.signOut(session);

    // **Proved, not assumed.** A sign-out that only forgot the local token would
    // leave a live credential on the server, which is the whole point of telling
    // the server.
    expect(await meStatus(session), 401,
        reason: 'the token must stop working once it has been revoked');
    // ignore: avoid_print
    print('  token rejected after sign-out');
  });

  test('signing out with no network still completes', () async {
    // Sign in fresh rather than reusing a session from another test: by this
    // point in the run the rate limit may have been reached, and a rate-limited
    // response correctly carries no session at all.
    final result = await signIn(email);
    if (result.status != SignInStatus.signedIn) {
      // ignore: avoid_print
      print('  skipped: sign-in was refused (${result.status.name})');
      return;
    }
    final session = result.session!;

    // A transport that cannot connect, pointed at the same account.
    final offline = HttpAuthClient(_OfflineTransport());
    await offline.signOut(session);

    // ignore: avoid_print
    print('  signed out with no server reachable, without throwing');
  });

  test('an unusable address is refused before any request', () async {
    final result = await client.signIn(
      serverBaseUrl: Uri.parse('http://books.example.com'),
      email: 'sita@example.com',
      password: _password,
    );

    expect(result.status, SignInStatus.invalidServer);
    // ignore: avoid_print
    print('  plaintext remote address refused without contacting it');
  });

  test('repeated attempts are rate limited by the server', () async {
    // The exact attempt at which the limit bites depends on how many requests this
    // address has already made, so this asserts only that it *does* bite.
    SignInResult? limited;
    for (var attempt = 0; attempt < 12; attempt++) {
      final result = await signIn(email, password: 'not-the-password');
      if (result.message.contains('Too many attempts')) {
        limited = result;
        break;
      }
    }

    expect(limited, isNotNull, reason: 'the public route must rate limit');
    expect(limited!.session, isNull);
    // ignore: avoid_print
    print('  rate limited: ${limited.message}');
  });
}

/// Read at **runtime**, not compile time.
///
/// `String.fromEnvironment` would be baked into the test binary, so setting the
/// variable while the test runs would have no effect and the check would always
/// skip.
String? _serverFromEnvironment() {
  final value = Platform.environment['FINANCEAPP_SERVER'];
  return (value == null || value.isEmpty) ? null : value;
}

/// A transport that never connects.
class _OfflineTransport implements HttpTransport {
  @override
  Future<TransportResponse> send({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    List<List<int>> body = const <List<int>>[],
  }) async {
    throw const _Unreachable();
  }
}

class _Unreachable implements Exception {
  const _Unreachable();
}
