import 'package:financeapp/src/infrastructure/http/api_url.dart';
import 'package:financeapp/src/infrastructure/http/http_licence_authorisation_client.dart';
import 'package:financeapp/src/infrastructure/http/http_transport.dart';
import 'package:flutter_test/flutter_test.dart';

/// A transport that records the request and replays a scripted answer.
class _RecordingTransport implements HttpTransport {
  _RecordingTransport({String? replyBody}) : replyBody = replyBody ?? '{}';

  /// Kept mutable so a test can script the failure **after** the client is built,
  /// which is what lets one setUp serve every case.
  int statusCode = 200;
  String replyBody;
  Uri? lastUrl;
  Map<String, String>? lastHeaders;

  @override
  Future<TransportResponse> send({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    List<List<int>> body = const <List<int>>[],
  }) async {
    lastUrl = url;
    lastHeaders = headers;
    return TransportResponse(statusCode: statusCode, body: replyBody);
  }
}

/// The desktop must speak the **same URLs the Laravel routes declare**, or
/// licensing fails at runtime in a way that looks like a server fault.
void main() {
  const installationId = '3f2a1b4c-5d6e-4f70-8192-a3b4c5d6e7f8';

  late _RecordingTransport transport;
  late HttpLicenceAuthorisationClient client;

  setUp(() {
    transport = _RecordingTransport(replyBody: '{"claims":"a","signature":"b"}');
    client = HttpLicenceAuthorisationClient(transport);
  });

  Future<LicenceFetchResult> fetch(Uri server) => client.fetch(
        serverBaseUrl: server,
        token: 'test-token',
        bookId: '7',
        installationId: installationId,
      );

  group('The request matches the Laravel route', () {
    test('the path is exactly api/books/{book}/licence-authorisation', () async {
      // **Pinned to `php artisan route:list`.** If the backend route changes and
      // this does not, the request 404s and the user is told the licence could not
      // be obtained — with no hint that the desktop is calling the wrong address.
      await fetch(Uri.parse('https://example.test'));

      expect(transport.lastUrl!.path, '/api/books/7/licence-authorisation');
    });

    test('the installation is sent as installation_id, as the backend names it',
        () async {
      // The controller validates `installation_id`; a differently named parameter
      // is simply absent, so it fails as "required" with no explanation.
      await fetch(Uri.parse('https://example.test'));

      expect(
        transport.lastUrl!.queryParameters['installation_id'],
        installationId,
      );
    });

    test('the device name is sent only when there is one', () async {
      await client.fetch(
        serverBaseUrl: Uri.parse('https://example.test'),
        token: 'test-token',
        bookId: '7',
        installationId: installationId,
      );
      expect(transport.lastUrl!.queryParameters.containsKey('device_name'), isFalse);

      await client.fetch(
        serverBaseUrl: Uri.parse('https://example.test'),
        token: 'test-token',
        bookId: '7',
        installationId: installationId,
        deviceName: 'Front desk',
      );
      expect(transport.lastUrl!.queryParameters['device_name'], 'Front desk');
    });

    test('the bearer token is sent', () async {
      await fetch(Uri.parse('https://example.test'));
      expect(transport.lastHeaders!['Authorization'], 'Bearer test-token');
    });
  });

  group('The server address is the user\'s, so it is handled as one', () {
    test('a trailing slash does not produce a double slash', () async {
      await fetch(Uri.parse('https://example.test/'));

      expect(
        transport.lastUrl!.toString(),
        startsWith('https://example.test/api/books/7/licence-authorisation'),
      );
    });

    test('several trailing slashes are handled too', () async {
      await fetch(Uri.parse('https://example.test///'));

      expect(
        transport.lastUrl!.toString(),
        'https://example.test/api/books/7/licence-authorisation'
            '?installation_id=$installationId',
      );
    });

    test('a server hosted under a sub-path keeps that sub-path', () async {
      // **The bug this prevents.** `Uri.replace(path: ...)` discards the base path,
      // so a deployment at https://host/finance would have sent every request to
      // https://host/api/... and got a 404 that reads as a wiring fault.
      await fetch(Uri.parse('https://host.test/finance'));

      expect(transport.lastUrl!.path, '/finance/api/books/7/licence-authorisation');
    });

    test('a port is preserved', () async {
      await fetch(Uri.parse('http://127.0.0.1:8123'));

      expect(transport.lastUrl!.port, 8123);
      expect(transport.lastUrl!.path, '/api/books/7/licence-authorisation');
    });
  });

  group('A reply that is not a licence is refused, never trusted', () {
    test('a 422 is reported rather than treated as a licence', () async {
      // **What a non-UUID installation id produces.** The backend's `uuid` rule
      // rejects it, and treating the error body as an authorisation would be worse
      // than useless.
      transport.statusCode = 422;
      transport.replyBody = '{"message":"The installation id field must be a valid UUID."}';

      final result = await fetch(Uri.parse('https://example.test'));

      expect(result.isGranted, isFalse);
      expect(result.authorisation, isNull);
    });

    test('a 404 is reported as no licence, without leaking whether one exists',
        () async {
      transport.statusCode = 404;

      final result = await fetch(Uri.parse('https://example.test'));

      expect(result.failure, LicenceFetchFailure.refused);
      expect(result.message, contains('No licence'));
    });

    test('a 500 is reported as a server problem, not a refusal', () async {
      // **A different remedy.** A refusal means contact your supplier; a 500 means
      // try later. Reporting a 500 as a refusal would send the user to cancel a
      // licence the server simply failed to answer about.
      transport.statusCode = 500;

      final result = await fetch(Uri.parse('https://example.test'));

      expect(result.failure, LicenceFetchFailure.unreachable);
      expect(result.message, contains('Try again shortly'));
    });

    test('a 200 with no signature is refused, not half-accepted', () async {
      transport.replyBody = '{"claims":"a=b"}';

      final result = await fetch(Uri.parse('https://example.test'));

      expect(result.isGranted, isFalse);
      expect(result.failure, LicenceFetchFailure.malformed);
    });

    test('a 200 with no claims is refused', () async {
      transport.replyBody = '{"signature":"b"}';

      final result = await fetch(Uri.parse('https://example.test'));

      expect(result.isGranted, isFalse);
      expect(result.failure, LicenceFetchFailure.malformed);
    });

    test('a 200 that is not JSON is refused', () async {
      transport.replyBody = '<html>maintenance</html>';

      final result = await fetch(Uri.parse('https://example.test'));

      expect(result.isGranted, isFalse);
      expect(result.failure, LicenceFetchFailure.malformed);
    });

    test('an unreachable server is reported as unreachable', () async {
      final offline = HttpLicenceAuthorisationClient(_ThrowingTransport());

      final result = await offline.fetch(
        serverBaseUrl: Uri.parse('https://example.test'),
        token: 'test-token',
        bookId: '7',
        installationId: installationId,
      );

      expect(result.failure, LicenceFetchFailure.unreachable);
      expect(result.message, contains('not been changed'),
          reason: 'the user must be told their books are intact');
    });

    test('a complete reply is accepted', () async {
      final result = await fetch(Uri.parse('https://example.test'));

      expect(result.isGranted, isTrue);
      expect(result.authorisation!.claims, 'a');
      expect(result.authorisation!.signature, 'b');
    });
  });

  group('apiUrl', () {
    test('appends a path without doubling the separator', () {
      expect(
        apiUrl(Uri.parse('https://a.test'), '/api/x').toString(),
        'https://a.test/api/x',
      );
      expect(
        apiUrl(Uri.parse('https://a.test/'), '/api/x').toString(),
        'https://a.test/api/x',
      );
    });

    test('tolerates a missing leading slash on the path', () {
      expect(
        apiUrl(Uri.parse('https://a.test'), 'api/x').toString(),
        'https://a.test/api/x',
      );
    });

    test('keeps a sub-path on the server address', () {
      expect(
        apiUrl(Uri.parse('https://a.test/finance'), '/api/x').toString(),
        'https://a.test/finance/api/x',
      );
    });

    test('adds query parameters only when given some', () {
      expect(
        apiUrl(Uri.parse('https://a.test'), '/api/x').queryParameters,
        isEmpty,
      );
      expect(
        apiUrl(Uri.parse('https://a.test'), '/api/x', const {})
            .queryParameters,
        isEmpty,
      );
    });
  });
}

/// A transport that always fails, standing in for a dead socket.
class _ThrowingTransport implements HttpTransport {
  @override
  Future<TransportResponse> send({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    List<List<int>> body = const <List<int>>[],
  }) =>
      throw const SocketishException();
}

class SocketishException implements Exception {
  const SocketishException();
}