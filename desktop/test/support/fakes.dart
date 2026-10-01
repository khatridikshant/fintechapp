/// Test doubles shared by the account tests.
///
/// They live here so there is one definition of "a credential store" and one
/// definition of "a transport", and so assertions about what is stored are made
/// against the same shape every time.
library;

import 'dart:convert';

import 'package:financeapp/src/domain/shared/auth_service.dart';
import 'package:financeapp/src/domain/shared/book_upload.dart';
import 'package:financeapp/src/domain/shared/credential_store.dart';
import 'package:financeapp/src/domain/shared/sign_in.dart';
import 'package:financeapp/src/infrastructure/http/http_transport.dart';

/// An in-memory [CredentialStore] that keeps every written value visible.
///
/// **Deliberately a `Map<String, String>`** rather than hiding the values behind a
/// getter: "the password is never stored" is only worth asserting if the test can
/// see everything that was written, so the keys mirror the real store's.
class MapCredentialStore implements CredentialStore {
  MapCredentialStore([Map<String, String>? initial])
      : store = <String, String>{...?initial};

  final Map<String, String> store;

  /// Writes, in order. Lets a test assert a failed sign-in wrote nothing at all.
  final List<String> writes = <String>[];

  @override
  Future<BackendSession?> read() async {
    final token = store['token'];
    final server = store['server'];
    final bookId = store['book'];
    if (token == null || server == null || bookId == null) return null;

    final base = Uri.tryParse(server);
    if (base == null) return null;

    return BackendSession(
      serverBaseUrl: base,
      token: token,
      bookId: bookId,
      accountLabel: store['account'],
    );
  }

  @override
  Future<void> write(BackendSession session) async {
    store['server'] = session.serverBaseUrl.toString();
    store['token'] = session.token;
    store['book'] = session.bookId;
    if (session.accountLabel != null) {
      store['account'] = session.accountLabel!;
    }
    writes.addAll(<String>['server', 'token', 'book']);
  }

  @override
  Future<void> clear() async {
    store.clear();
    writes.add('clear');
  }
}

/// A [CredentialStore] that cannot be read, as a locked keyring would behave.
class ThrowingStore implements CredentialStore {
  @override
  Future<BackendSession?> read() async => throw StateError('keyring locked');

  @override
  Future<void> write(BackendSession session) async {}

  @override
  Future<void> clear() async {}
}

/// A [CredentialStore] that reads and writes but cannot be cleared.
class ThrowingClearStore implements CredentialStore {
  BackendSession? _session;

  @override
  Future<BackendSession?> read() async => _session;

  @override
  Future<void> write(BackendSession session) async => _session = session;

  @override
  Future<void> clear() async => throw StateError('keyring unavailable');
}

/// An [AuthActions] that returns a scripted answer.
///
/// [throwOnSignOut] makes signing out fail the way a dead network would, which is
/// the case that matters: signing out must still work.
class ScriptedAuthActions implements AuthActions {
  ScriptedAuthActions({
    this.result,
    this.session,
    this.throwOnSignOut = false,
  });

  final SignInResult? result;
  final BackendSession? session;
  final bool throwOnSignOut;

  Uri? lastServer;
  String? lastEmail;
  String? lastPassword;
  String? lastDeviceName;
  int signOutCalls = 0;

  @override
  Future<SignInResult> signIn({
    required Uri serverBaseUrl,
    required String email,
    required String password,
    String? deviceName,
  }) async {
    lastServer = serverBaseUrl;
    lastEmail = email;
    lastPassword = password;
    lastDeviceName = deviceName;

    final scripted = result;
    if (scripted != null) return scripted;
    return SignInResult(
      status: SignInStatus.signedIn,
      message: 'Signed in.',
      session: session,
    );
  }

  @override
  Future<void> signOut(BackendSession session) async {
    signOutCalls++;
    if (throwOnSignOut) throw StateError('the network is down');
  }
}

/// A transport that answers from a list and records what it was asked.
class ScriptedTransport implements HttpTransport {
  ScriptedTransport(this.responses);

  final List<TransportResponse> responses;

  final List<Uri> urls = <Uri>[];
  final List<String> methods = <String>[];
  final List<Map<String, String>> headers = <Map<String, String>>[];
  final List<String> bodies = <String>[];

  @override
  Future<TransportResponse> send({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    List<List<int>> body = const <List<int>>[],
  }) async {
    methods.add(method);
    urls.add(url);
    this.headers.add(headers);
    bodies.add(utf8.decode(body.expand((part) => part).toList()));

    if (responses.isEmpty) throw StateError('no scripted response left');
    return responses.removeAt(0);
  }
}

/// A JSON response body, for scripting.
TransportResponse jsonResponse(int status, Map<String, Object?> body) =>
    TransportResponse(statusCode: status, body: jsonEncode(body));

/// A transport that always fails to connect.
class OfflineTransport implements HttpTransport {
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
