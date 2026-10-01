import 'dart:convert';
import 'dart:io';

/// The answer to one HTTP request, reduced to what this feature needs.
class TransportResponse {
  const TransportResponse({required this.statusCode, this.body = ''});

  final int statusCode;
  final String body;
}

/// Where a request is sent.
///
/// A seam, so the uploader's real behaviour — URL building, headers, multipart
/// encoding, status mapping — is exercised by tests without a server. Replacing
/// the transport rather than the HTTP client means nothing above it is faked.
abstract interface class HttpTransport {
  /// Sends one request.
  ///
  /// [body] is an **ordered list of byte segments**, not one buffer. A snapshot
  /// can be tens of megabytes, and concatenating every part into a single
  /// `Uint8List` would hold a second full-size copy of the file in memory for no
  /// benefit. The segments are written in order instead.
  Future<TransportResponse> send({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    List<List<int>> body = const <List<int>>[],
  });
}

/// The real transport, over `dart:io`.
///
/// `dart:io` rather than a package on purpose: it is part of the SDK, so the
/// upload gains no dependency at all. `docs/AI_RULES.md` requires every
/// dependency to be a deliberate, recorded choice, and the standard library is
/// the cheapest choice available.
class IoHttpTransport implements HttpTransport {
  IoHttpTransport({this.timeout = const Duration(seconds: 30)});

  /// A request that hangs must not hang the application.
  final Duration timeout;

  /// **One client for the whole transport, not one per request.**
  ///
  /// `HttpClient` owns the connection pool, so building one per request throws
  /// keep-alive away and forces a fresh TCP (and, over HTTPS, TLS) handshake for
  /// every call — and sending several fiscal years is two calls per year. The
  /// transport is built once in the composition root and lives as long as the
  /// application, so the pool is reused throughout.
  late final HttpClient _client = HttpClient()..connectionTimeout = timeout;

  @override
  Future<TransportResponse> send({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    List<List<int>> body = const <List<int>>[],
  }) async {
    final request = await _client.openUrl(method, url).timeout(timeout);
    headers.forEach(request.headers.set);

    if (body.isNotEmpty) {
      // Declared up front so the request is a normal length-delimited body
      // rather than chunked, which keeps the wire format the multipart parser on
      // the server already handles.
      request.contentLength =
          body.fold<int>(0, (total, part) => total + part.length);
      for (final part in body) {
        request.add(part);
      }
    }

    final response = await request.close().timeout(timeout);
    final text = await response.transform(utf8.decoder).join().timeout(timeout);
    return TransportResponse(statusCode: response.statusCode, body: text);
  }
}

/// A JSON request body, as the one-segment list the transport takes.
///
/// Sign-in and sign-out post JSON, so the encoding lives here rather than being
/// repeated at each call site.
List<List<int>> jsonBody(Map<String, Object?> fields) =>
    <List<int>>[utf8.encode(jsonEncode(fields))];
