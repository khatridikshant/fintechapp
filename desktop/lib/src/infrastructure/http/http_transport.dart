import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// The answer to one HTTP request, reduced to what this feature needs.
class TransportResponse {
  const TransportResponse({
    required this.statusCode,
    this.body = '',
    this.bodyBytes,
    this.headers = const <String, String>{},
  });

  final int statusCode;

  /// The body as text, for JSON responses.
  ///
  /// **Empty when [bodyBytes] is used.** A downloaded SQLite file is not text, and
  /// decoding it as UTF-8 would corrupt every byte above `0x7F` — which is most of
  /// a database. That is why a download reads [bodyBytes] instead.
  final String body;

  /// The body as raw bytes, for a file download.
  ///
  /// Null for a text response, so a caller cannot silently accept bytes where text
  /// was meant.
  final Uint8List? bodyBytes;

  /// The response headers, lower-cased keys.
  ///
  /// A download reads its checksum from `X-Backup-Checksum`, which only exists
  /// here because the transport, not the downloader, is what sees the headers.
  final Map<String, String> headers;

  /// The body as bytes, accepting either form.
  ///
  /// Used where a file may arrive either way, so the two representations cannot
  /// produce different results for the same request.
  Uint8List? get binaryBody =>
      bodyBytes ??
      (body.isEmpty ? null : Uint8List.fromList(utf8.encode(body)));
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

    // Headers are collected because a download's checksum travels in one of them.
    final responseHeaders = <String, String>{};
    response.headers.forEach((String name, List<String> values) {
      responseHeaders[name.toLowerCase()] = values.join(', ');
    });

    // A binary response is kept as bytes; **never decoded as text**, because a
    // SQLite file is not UTF-8 and the decode would silently corrupt it.
    final contentType = responseHeaders['content-type'] ?? '';
    if (contentType.contains('application/json')) {
      final text =
          await response.transform(utf8.decoder).join().timeout(timeout);
      return TransportResponse(
        statusCode: response.statusCode,
        body: text,
        headers: responseHeaders,
      );
    }

    final bytes = await collectBytes(response).timeout(timeout);
    return TransportResponse(
      statusCode: response.statusCode,
      bodyBytes: bytes,
      headers: responseHeaders,
    );
  }
}

/// Collects a response body as bytes.
///
/// Collected as a list and concatenated rather than gathered, so a download does
/// not depend on the chunk boundaries the server happened to use.
Future<Uint8List> collectBytes(Stream<List<int>> stream) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

/// A JSON request body, as the one-segment list the transport takes.
///
/// Sign-in and sign-out post JSON, so the encoding lives here rather than being
/// repeated at each call site.
List<List<int>> jsonBody(Map<String, Object?> fields) =>
    <List<int>>[utf8.encode(jsonEncode(fields))];
