import '../domain/shared/auth_service.dart';
import '../domain/shared/book_upload.dart';
import '../domain/shared/book_upload_service.dart';
import '../domain/shared/credential_store.dart';
import '../domain/shared/sign_in.dart';

/// The signed-in session, and everything that follows from it.
///
/// This is the one place that knows a user can be signed in. It coordinates the
/// two ports that matter -- [AuthActions] for talking to the server and
/// [CredentialStore] for remembering the result -- and keeps the current
/// [BackendSession] so the rest of the application can ask.
///
/// ## Offline is a normal state, not an error
///
/// The specification requires the desktop to work with the server unreachable,
/// so every failure here leaves the application exactly as it was. A failed
/// sign-in stores nothing, and a sign-out always clears the local session even
/// when the token cannot be revoked on the server.
class AccountSession {
  AccountSession({
    required AuthActions auth,
    required CredentialStore store,
    required UploadActions Function(BackendSession session) uploadBuilder,
    this.deviceName,
  })  : _auth = auth,
        _store = store,
        _uploadBuilder = uploadBuilder;

  final AuthActions _auth;
  final CredentialStore _store;
  final UploadActions Function(BackendSession session) _uploadBuilder;

  /// Which installation is signing in, so the server can name it. ADR 003 allows
  /// one active installation per account, which means the server has to be able to
  /// say *which* one is asking.
  final String? deviceName;

  BackendSession? _session;

  /// The current session, or null when nobody is signed in.
  BackendSession? get session => _session;

  bool get isSignedIn => _session?.isUsable ?? false;

  /// Who is signed in, for display. Never used to decide anything.
  String? get accountLabel => _session?.accountLabel;

  /// The uploader for the current session, or null when nobody is signed in.
  ///
  /// A **new** uploader per session, because the uploader takes its session in
  /// its constructor. That is deliberate: an uploader holding a stale token would
  /// keep failing with a sign-in error the user cannot fix by signing in.
  UploadActions? get upload {
    final current = _session;
    return current == null ? null : _uploadBuilder(current);
  }

  /// Reads any stored session, so a returning user stays signed in.
  ///
  /// Safe to call with no stored session, which is the normal first run, and safe
  /// when the store cannot be read at all -- a locked keyring, a corrupt value, a
  /// missing platform store. A store failure is treated as "no session", because
  /// signing in again is a workable answer and failing to start is not.
  Future<void> restore() async {
    try {
      _session = await _store.read();
    } catch (error) {
      _session = null;
    }
  }

  /// Signs in and, on success, remembers the session.
  ///
  /// The session is stored **only** after the server has issued a token, so a
  /// failure never leaves something behind that looks signed in.
  Future<SignInResult> signIn({
    required Uri serverBaseUrl,
    required String email,
    required String password,
  }) async {
    final result = await _auth.signIn(
      serverBaseUrl: serverBaseUrl,
      email: email,
      password: password,
      deviceName: deviceName,
    );

    final signedIn = result.session;
    if (result.isSuccess && signedIn != null) {
      _session = signedIn;
      try {
        await _store.write(signedIn);
      } catch (error) {
        // The session works for this run even if it cannot be remembered.
      }
    }

    return result;
  }

  /// Signs out, locally first.
  ///
  /// The stored session is cleared **before** the server is told, and the server
  /// call is best effort. The order matters: if the network hangs or fails, the
  /// user is still signed out on this machine, which is what they asked for. A
  /// token left on the server that this machine no longer holds is a much smaller
  /// problem than a sign-out that does not happen.
  ///
  /// Neither the clear nor the server call is allowed to throw. The
  /// [AuthActions.signOut] contract says it never does, but relying on that would
  /// make a future implementation's bug into a sign-out that does not happen.
  Future<void> signOut() async {
    final current = _session;
    _session = null;

    try {
      await _store.clear();
    } catch (error) {
      // Nothing can be done, and the in-memory session is already gone, so the
      // user is signed out for this run regardless.
    }

    if (current != null) {
      try {
        await _auth.signOut(current);
      } catch (error) {
        // The server keeps a token this machine no longer holds. Revocable later,
        // and far less bad than refusing to sign out.
      }
    }
  }
}
