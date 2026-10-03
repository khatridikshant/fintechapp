import 'dart:convert';

import '../../domain/shared/auth_service.dart';
import '../../domain/shared/book_upload.dart';
import '../../domain/shared/sign_in.dart';
import '../http/api_url.dart';
import '../http/http_transport.dart';

/// Signs in and out over HTTP.
///
/// Every outcome is a returned [SignInResult], never a thrown error, because "no
/// answer" and "no" are the two things a person needs to be told apart and both
/// are ordinary conditions for a desktop application. The one thing that throws
/// is an address that is not a usable server address, which is caught before any
/// request.
class HttpAuthClient implements AuthActions {
  HttpAuthClient(this._transport);

  final HttpTransport _transport;

  @override
  Future<SignInResult> signIn({
    required Uri serverBaseUrl,
    required String email,
    required String password,
    String? deviceName,
  }) async {
    if (!_isUsable(serverBaseUrl)) {
      return const SignInResult(
        status: SignInStatus.invalidServer,
        message: 'That is not a usable server address. It needs to be a web '
            'address such as https://books.example.com, and plaintext http is '
            'only accepted for this computer.',
      );
    }

    final TransportResponse response;
    try {
      response = await _transport.send(
        method: 'POST',
        url: _apiUrl(serverBaseUrl, '/api/auth/login'),
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonBody(<String, Object?>{
          'email': email,
          'password': password,
          if (deviceName != null) 'device_name': deviceName,
        }),
      );
    } catch (error) {
      // Offline is normal for this product. Nothing was stored, and the books are
      // untouched, so the application carries on working locally.
      return const SignInResult(
        status: SignInStatus.unreachable,
        message: 'Could not reach the server. You can keep working offline; '
            'sign in again when you have a connection.',
      );
    }

    return _interpret(response, serverBaseUrl, deviceName);
  }

  /// Turns a server answer into a result, without ever inventing a sign-in.
  SignInResult _interpret(
    TransportResponse response,
    Uri serverBaseUrl,
    String? deviceName,
  ) {
    switch (response.statusCode) {
      case 200:
        final decoded = _decode(response.body);
        if (decoded == null) {
          return const SignInResult(
            status: SignInStatus.unreachable,
            message: 'The server answered in a way this application does not '
                'understand, so you have not been signed in.',
          );
        }

        final token = decoded['token'];
        final book = decoded['book'];
        final bookId = book is Map ? book['id'] : null;
        final user = decoded['user'];
        final company = decoded['company'];

        // A token without a book id is not a usable session: the upload endpoint
        // is keyed by book, so there would be nothing to send to. Refusing it is
        // better than storing a session that silently cannot work.
        if (token is! String || token.isEmpty || bookId == null) {
          return const SignInResult(
            status: SignInStatus.unreachable,
            message: 'The server did not return a usable session, so you have '
                'not been signed in.',
          );
        }

        // The company the session acts for. Optional, because an older server
        // sends no `company` and refusing to sign in over it would break every
        // desktop already deployed against one.
        final companyName = company is Map ? company['name'] : null;
        final companyPan = company is Map ? company['pan'] : null;
        final vatRegistered = company is Map ? company['vat_registered'] : null;

        // Shown where the account is described: the registered business first,
        // because that is what distinguishes one account from another, then the
        // sign-in address, and only then the device.
        final label = companyName is String && companyName.isNotEmpty
            ? companyName
            : (user is Map && user['email'] is String
                ? user['email'] as String
                : (deviceName ?? 'signed in'));

        return SignInResult(
          status: SignInStatus.signedIn,
          message: 'Signed in.',
          session: BackendSession(
            serverBaseUrl: serverBaseUrl,
            token: token,
            bookId: '$bookId',
            accountLabel: label,
            companyName: companyName is String && companyName.isNotEmpty
                ? companyName
                : null,
            companyPan: companyPan is String && companyPan.isNotEmpty
                ? companyPan
                : null,
            // **Only a real boolean counts.** The string "0" is truthy in Dart, so
            // a loose cast would report an unregistered business as registered.
            vatRegistered: vatRegistered is bool ? vatRegistered : null,
          ),
        );

      case 422:
        // The server deliberately refuses an unknown email and a wrong password
        // with the same message, so this wording does not reveal which it was.
        return const SignInResult(
          status: SignInStatus.rejected,
          message: 'Those details were not accepted. Check the email address '
              'and the password, and try again.',
        );

      case 429:
        return const SignInResult(
          status: SignInStatus.rejected,
          message: 'Too many attempts. Wait a minute and try again.',
        );

      default:
        return SignInResult(
          status: SignInStatus.unreachable,
          message: 'The server answered with ${response.statusCode}, so you '
              'have not been signed in. You can keep working offline.',
        );
    }
  }

  @override
  Future<void> signOut(BackendSession session) async {
    // Best effort, and never throwing. The local session is cleared by the caller
    // whatever happens here: being unable to sign out would be a worse failure
    // than leaving a token on the server that this machine no longer holds.
    try {
      await _transport.send(
        method: 'POST',
        url: _apiUrl(session.serverBaseUrl, '/api/auth/logout'),
        headers: <String, String>{
          'Authorization': 'Bearer ${session.token}',
          'Accept': 'application/json',
        },
        body: jsonBody(const <String, Object?>{}),
      );
    } catch (error) {
      // Deliberately ignored. See the doc comment.
    }
  }

  /// Whether an address may be sent the books.
  ///
  /// HTTPS, or plain `http` only to this machine. The same rule the composition
  /// root applies, so a bad address is refused before a password is sent rather
  /// than after.
  static bool _isUsable(Uri server) {
    if (server.scheme == 'https') return true;
    if (server.scheme != 'http') return false;

    const loopback = <String>{'localhost', '127.0.0.1', '::1', '[::1]'};
    return loopback.contains(server.host);
  }

  static Uri _apiUrl(Uri server, String path) => apiUrl(server, path);

  static Map<String, Object?>? _decode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, Object?> ? decoded : null;
    } catch (error) {
      return null;
    }
  }
}
