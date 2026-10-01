import 'book_upload.dart';
import 'sign_in.dart';

/// Signing in and out against the server.
///
/// A port the domain owns, implemented in `infrastructure/`, for the same reason
/// the upload port is: the accounting application must not know what a socket is,
/// and must keep working when there is not one.
///
/// ## The rule that matters
///
/// **Signing in is the only part of this that needs the network, and signing out
/// must not.** The specification requires the desktop to operate with the server
/// unreachable, so a failed sign-in leaves the application exactly as it was, and
/// a sign-out always succeeds locally even when the token cannot be revoked on
/// the server. Being unable to sign out would be a worse failure than an
/// un-revoked token.
abstract interface class AuthActions {
  /// Exchanges credentials for a session.
  ///
  /// Never throws for an answer the server actually gave or failed to give; it
  /// returns a [SignInResult]. Throws [SignInException] only when the attempt
  /// could not be made at all, such as an address that is not a server address.
  Future<SignInResult> signIn({
    required Uri serverBaseUrl,
    required String email,
    required String password,
    String? deviceName,
  });

  /// Tells the server to revoke [session]'s token.
  ///
  /// **Best effort, and never throwing.** The local session is cleared by the
  /// caller regardless, because a user who wants to be signed out must be signed
  /// out even with the network down.
  Future<void> signOut(BackendSession session);
}
