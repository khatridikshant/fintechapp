import 'book_upload.dart';

/// Where the signed-in session is kept between runs.
///
/// A port, so the application layer can persist a session without knowing
/// whether it lands in the operating system's protected store, a file, or
/// nothing at all in a test.
///
/// ## What this must never hold
///
/// **The account password.** Not hashed, not encrypted, not "temporarily". A
/// token is what the server accepts and what can be revoked; storing the password
/// would add a liability with no benefit, and it is the one thing a user cannot
/// rotate when a machine is lost. [BackendSession] has no password field, which is
/// what makes that structural rather than a rule someone has to remember.
abstract interface class CredentialStore {
  /// The stored session, or null when there is none.
  ///
  /// Returns null rather than throwing when the stored value is missing,
  /// unreadable, or malformed: a corrupted session is the same problem as no
  /// session, and the user's answer to both is to sign in again.
  Future<BackendSession?> read();

  /// Replaces whatever is stored with [session].
  Future<void> write(BackendSession session);

  /// Removes the stored session.
  ///
  /// Safe to call when nothing is stored, so signing out twice is not an error.
  Future<void> clear();
}
