import 'book_upload.dart';

/// What happened when someone tried to sign in.
///
/// Kept apart because each one asks something different of the user: a wrong
/// password means check the details, an unreachable server means the business can
/// carry on offline and try later, and a bad address means the address is wrong
/// rather than the credentials.
enum SignInStatus {
  /// The server accepted the credentials and issued a token.
  signedIn,

  /// The server refused the credentials.
  rejected,

  /// The address is not a usable server address.
  ///
  /// Caught before any request, so a typo does not look like a network problem.
  invalidServer,

  /// No usable answer came back: the server is down, unreachable, or broken.
  unreachable,
}

/// The outcome of a sign-in attempt.
class SignInResult {
  const SignInResult(
      {required this.status, required this.message, this.session});

  final SignInStatus status;

  /// What to tell the user. Written to be shown as-is.
  final String message;

  /// The session that was established. Set only when [status] is
  /// [SignInStatus.signedIn].
  final BackendSession? session;

  bool get isSuccess => status == SignInStatus.signedIn;

  /// True when the address was refused before any request was made.
  bool get isAddressProblem => status == SignInStatus.invalidServer;

  @override
  String toString() => 'SignInResult(${status.name})';
}

/// Raised when a sign-in cannot be attempted at all.
class SignInException implements Exception {
  SignInException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'SignInException: $message'
      : 'SignInException: $message (cause: $cause)';
}
