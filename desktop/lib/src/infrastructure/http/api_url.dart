/// Builds an API URL from a server's base address.
///
/// ## Why this exists in one place
///
/// The server address is entered by a user, so it may or may not carry a trailing
/// slash, and it may be hosted under a sub-path — `https://host/finance` is a
/// normal way to deploy Laravel behind a reverse proxy.
///
/// **Two earlier mistakes, both recorded because they are easy to repeat:**
///
/// - `Uri.replace(path: ...)` **discards the base path entirely**, so a deployment
///   under a sub-path would send every request to the domain root and get a 404
///   that looks like a wiring fault.
/// - Concatenating without trimming puts `//api/...` after a trailing slash, which
///   some servers normalise and some do not.
///
/// Every request path in the desktop is now built here, so the desktop and the
/// Laravel routes cannot drift apart in how they are assembled.
Uri apiUrl(
  Uri serverBaseUrl,
  String path, [
  Map<String, String>? query,
]) {
  final base = serverBaseUrl.toString().replaceFirst(RegExp(r'/+$'), '');
  final suffix = path.startsWith('/') ? path : '/$path';

  // Built by appending rather than by `replace`, so a sub-path in the server
  // address survives.
  final built = Uri.parse('$base$suffix');

  if (query == null || query.isEmpty) return built;
  return built.replace(queryParameters: query);
}