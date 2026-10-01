import 'dart:convert';

import 'package:crossvault/crossvault.dart';

import '../../domain/shared/book_upload.dart';
import '../../domain/shared/credential_store.dart';

/// Keeps the signed-in session in the operating system's protected store.
///
/// `crossvault` is MIT and approved in `docs/AI_RULES.md`. On **Windows** it
/// stores the value in the **Windows Credential Manager**, whose cryptography is
/// DPAPI and CNG (`wincred.h`, `ncrypt.h`, `bcrypt.h`) — all standard Windows SDK
/// headers, so there is **no additional toolchain requirement** to build this
/// application. On macOS it is the Keychain.
///
/// ## Why this package and not `flutter_secure_storage`
///
/// The obvious choice was `flutter_secure_storage`, which does the same job. Its
/// Windows C++ implementation contains a single `#include <atlstr.h>`, which
/// requires Visual Studio's **optional** C++ ATL component. That is not an
/// acceptable prerequisite for a desktop application: it is not published for
/// every toolset, and the generic component name installs the *wrong* toolset's
/// copy without saying so. See `PROGRESS.md` section 4.32.
///
/// ## Known limitation
///
/// **No Linux implementation.** On Linux the token lives in memory for the
/// session and the user signs in again after a restart. Because
/// [CredentialStore] is an interface, adding Linux later touches only this file.
///
/// ## What is stored
///
/// **One JSON object**, not four keys, so a crash mid-write cannot leave half a
/// session behind — a store with three of four fields restored is worse than no
/// session, because it looks signed in and fails at the first upload.
///
/// **The password is never written**, and cannot be: [BackendSession] has no field
/// for it, which makes that structural rather than a rule someone has to remember.
class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore([Crossvault? vault]) : _vault = vault ?? Crossvault();

  final Crossvault _vault;

  /// The one key the session lives under. Namespaced so it cannot collide with
  /// anything else the application ever stores.
  static const _key = 'financeapp.account.session';

  /// A fixed version field, so a future change of shape is detected rather than
  /// misread.
  static const _version = 1;

  @override
  Future<BackendSession?> read() async {
    try {
      final raw = await _vault.getValue(_key);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      if (decoded['v'] != _version) return null;

      final token = decoded['token'];
      final server = decoded['server'];
      final bookId = decoded['book'];

      // **Every field or nothing.** A partial session is worse than none: it would
      // look signed in and then fail at the first upload, with no obvious reason.
      if (token is! String ||
          token.isEmpty ||
          server is! String ||
          server.isEmpty ||
          bookId is! String ||
          bookId.isEmpty) {
        return null;
      }

      final base = Uri.tryParse(server);
      if (base == null) return null;

      final label = decoded['account'];

      return BackendSession(
        serverBaseUrl: base,
        token: token,
        bookId: bookId,
        accountLabel: label is String && label.isNotEmpty ? label : null,
      );
    } catch (error) {
      // A corrupt or unreadable store is the same problem as no store: signing in
      // again is the answer, and failing to start is not.
      return null;
    }
  }

  @override
  Future<void> write(BackendSession session) async {
    try {
      await _vault.setValue(
        _key,
        jsonEncode(<String, Object?>{
          'v': _version,
          'server': session.serverBaseUrl.toString(),
          'token': session.token,
          'book': session.bookId,
          'account': session.accountLabel,
        }),
      );
    } catch (error) {
      // A store that cannot be written leaves the in-memory session working for
      // this run. Failing here would leave the user unable to sign in at all,
      // which is worse than not remembering them next time.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _vault.deleteValue(_key);
    } catch (error) {
      // Ignored on purpose: signing out must not fail because the store could not
      // be reached. The caller's in-memory session is already gone.
    }
  }
}
