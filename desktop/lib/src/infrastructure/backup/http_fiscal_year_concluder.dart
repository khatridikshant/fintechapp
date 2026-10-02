import '../../application/conclude_fiscal_year.dart';
import '../../domain/fiscal/fiscal_year.dart';
import '../../domain/shared/book_upload.dart';
import '../http/http_transport.dart';

/// Tells the server a fiscal year is concluded, so it can drop the duplicates.
///
/// ## The label goes in the body, not the path
///
/// Every fiscal year label contains a slash -- `FY 2082/83` -- and a slash inside
/// a URL path segment is a separator, so the router would never match a route
/// containing one. Percent-encoding does not help either, because the router
/// decodes before it matches. The request body has no such problem.
///
/// ## Nothing here can fail a close
///
/// Every path returns a [ConcludeOutcome] rather than throwing. The archive has
/// already been confirmed by the time this runs, and the extra copies cost disk
/// and nothing else, so a server that is down or refuses must not turn a
/// successful close into a failure.
class HttpFiscalYearConcluder implements FiscalYearConcluder {
  HttpFiscalYearConcluder({
    required HttpTransport transport,
    required BackendSession? Function() session,
  })  : _transport = transport,
        _session = session;

  final HttpTransport _transport;
  final BackendSession? Function() _session;

  @override
  Future<ConcludeOutcome> conclude(FiscalYear fiscalYear) async {
    final session = _session();

    // Not signed in, so there is no server to tell. Reported as unreachable
    // rather than refused, because from the desktop's point of view the request
    // never went anywhere.
    if (session == null) {
      return ConcludeOutcome.unreachable;
    }

    final TransportResponse response;
    try {
      response = await _transport.send(
        method: 'POST',
        url: _concludeUrl(session),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${session.token}',
        },
        body: jsonBody(<String, Object?>{
          'fiscal_year_label': fiscalYear.label,
        }),
      );
    } catch (_) {
      // No request could be made. The local close stands; the extra copies
      // remain and a later attempt can pick this up.
      return ConcludeOutcome.unreachable;
    }

    switch (response.statusCode) {
      case 200:
        return ConcludeOutcome.concluded;

      // The server understood and declined: the year has no stored snapshot, or
      // the copy it would keep could not be verified. Nothing was deleted, and
      // that is the correct outcome to report rather than a failure.
      case 422:
      case 409:
      case 410:
        return ConcludeOutcome.refused;

      // An expired session. Not retried: retrying a 401 fails identically, and
      // the user has to sign in again before anything else can work.
      case 401:
      case 403:
        return ConcludeOutcome.refused;

      default:
        return ConcludeOutcome.unreachable;
    }
  }

  /// The conclude endpoint, built from the server root.
  ///
  /// **No fiscal year in the path**, for the reason in the class docblock.
  Uri _concludeUrl(BackendSession session) {
    final root = session.serverBaseUrl;
    return Uri.parse('${root.origin}${root.path}/api/books/'
        '${session.bookId}/fiscal-years/conclude');
  }
}
