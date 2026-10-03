import 'dart:convert';

import '../http/http_transport.dart';
import 'api_url.dart';

/// A licence authorisation as the server issued it.
class LicenceAuthorisation {
  const LicenceAuthorisation({required this.claims, required this.signature});

  /// The canonical signed payload, **exactly as signed**.
  ///
  /// Never re-serialised. The signature covers these specific bytes, so rebuilding
  /// the claim map and encoding it again would risk producing different bytes, and
  /// a genuine licence would fail to verify.
  final String claims;

  final String signature;
}

/// Why a licence authorisation could not be obtained.
///
/// Distinct because the user's next action differs: an expired licence needs a
/// renewal, a refusal needs a support call, and an unreachable server needs
/// patience. Reporting them all as "sign-in failed" tells the user nothing they can
/// act on.
enum LicenceFetchFailure {
  /// The server refused: no licence, revoked, suspended, or not this book.
  refused,

  /// The server could not be reached.
  unreachable,

  /// The reply was not the shape this application expects.
  ///
  /// **Reported separately rather than trusted.** A malformed body that was
  /// accepted as a licence would be a licence nobody signed.
  malformed,
}

/// Obtained, or a reason it was not.
class LicenceFetchResult {
  const LicenceFetchResult.granted(this.authorisation)
      : failure = null,
        message = null;

  const LicenceFetchResult.refused(LicenceFetchFailure this.failure, this.message)
      : authorisation = null;

  final LicenceAuthorisation? authorisation;
  final LicenceFetchFailure? failure;

  /// A sentence for the user, written as-is.
  final String? message;

  bool get isGranted => authorisation != null;
}

/// Fetches the signed licence authorisation.
///
/// The one place in the desktop that reaches the network **for licensing**, and it
/// is called only when signing in or revalidating — never on a launch whose stored
/// authorisation is still inside its offline window. That is what makes the
/// specification's *"shall be capable of operating normally without an active
/// internet connection"* true rather than aspirational.
class HttpLicenceAuthorisationClient {
  const HttpLicenceAuthorisationClient(this._transport);

  final HttpTransport _transport;

  /// Obtains an authorisation for one book on this installation.
  Future<LicenceFetchResult> fetch({
    required Uri serverBaseUrl,
    required String token,
    required String bookId,
    required String installationId,
    String? deviceName,
  }) async {
    final uri = apiUrl(
      serverBaseUrl,
      // **The route exactly as Laravel registers it** (`php artisan route:list`):
      // `GET api/books/{book}/licence-authorisation`. It is spelled here rather
      // than assembled from segments so a change to the route is a one-line diff
      // that fails the test below, instead of a mismatch discovered at runtime.
      '/api/books/$bookId/licence-authorisation',
      // The installation travels as a **query parameter**, because this is a GET
      // and a GET has no body. The backend validates `installation_id` as a
      // `uuid`, which is why `_installationId` produces a real UUID rather than an
      // arbitrary string — an unparseable value is a 422, not a licence.
      {
        'installation_id': installationId,
        if (deviceName != null) 'device_name': deviceName,
      },
    );

    final TransportResponse response;
    try {
      response = await _transport.send(
        method: 'GET',
        url: uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } on Object {
      // **No distinction from a dead socket.** For the user they are one thing, and
      // a partial one ("the server is being difficult") would be a guess.
      return const LicenceFetchResult.refused(
        LicenceFetchFailure.unreachable,
        'Could not reach the server. Check your internet connection and try '
            'again. Your accounting data has not been changed.',
      );
    }

    if (response.statusCode == 404 || response.statusCode == 403) {
      // **The same wording as an unknown book**, matching the server: confirming
      // which businesses hold a licence is itself a disclosure.
      return const LicenceFetchResult.refused(
        LicenceFetchFailure.refused,
        'No licence was found for this account. Contact your supplier.',
      );
    }

    if (response.statusCode != 200) {
      return const LicenceFetchResult.refused(
        LicenceFetchFailure.unreachable,
        'The server could not issue a licence right now. Try again shortly.',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const LicenceFetchResult.refused(
          LicenceFetchFailure.malformed,
          'The licence the server sent could not be read. Sign in again.',
        );
      }

      final claims = decoded['claims'];
      final signature = decoded['signature'];

      if (claims is! String || signature is! String) {
        // **Refused rather than verified-and-hoped-for.** A body without both
        // halves cannot be checked, and accepting it would mean running on a
        // licence nobody verified.
        return const LicenceFetchResult.refused(
          LicenceFetchFailure.malformed,
          'The licence the server sent was incomplete. Sign in again.',
        );
      }

      return LicenceFetchResult.granted(
        LicenceAuthorisation(claims: claims, signature: signature),
      );
    } on FormatException {
      return const LicenceFetchResult.refused(
        LicenceFetchFailure.malformed,
        'The licence the server sent could not be read. Sign in again.',
      );
    }
  }
}