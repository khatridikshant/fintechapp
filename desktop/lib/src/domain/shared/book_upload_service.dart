import 'book_backup.dart';
import 'book_upload.dart';

/// Port for sending a verified snapshot to the server.
///
/// This is an interface the **domain** owns, like `BackupActions`. The
/// implementation lives in `infrastructure/`, because it deals with HTTP and the
/// filesystem, and neither of those belongs in the domain.
///
/// ## The one rule
///
/// **A failed upload never claims success, and never touches the local backup.**
/// The local snapshot is the fallback until the server has confirmed it holds the
/// bytes, so an upload is strictly additive: it may add a remote copy, and it may
/// report a failure, but it must never delete, move, or rewrite the local file.
/// A "successful" upload that lost the local copy would be the worst possible
/// outcome of the whole feature.
///
/// ## Why this is separate from taking a backup
///
/// Taking a backup works with no network at all, which the specification
/// requires. Uploading is the one part that needs a server. Keeping them as
/// separate interfaces means a screen that only takes backups cannot reach a
/// network call by accident.
abstract interface class UploadActions {
  /// The session to upload with, or null when the desktop is not signed in.
  ///
  /// Never guessed and never defaulted to something usable: an absent session is
  /// reported as such rather than producing a confusing authentication failure.
  BackendSession? get session;

  /// True when an upload could be attempted at all.
  ///
  /// False when there is no session, or the session is missing a token or a book
  /// id. A screen uses this to decide whether to offer the button.
  bool get canUpload;

  /// Sends [backup] to the server.
  ///
  /// Returns a result rather than throwing for every outcome that the server
  /// actually answered, including a refusal or a conflict: those are normal
  /// answers, not exceptional ones, and each needs a different message.
  ///
  /// Throws [UploadException] only when no request could be made at all.
  Future<UploadResult> upload(BookBackup backup);

  /// The successful uploads of [fiscalYearLabel], newest first.
  ///
  /// Used to tell the user when this year's books were last sent, which is the
  /// only way to know whether the off-machine copy is current.
  Future<List<UploadRecord>> uploadsFor(String fiscalYearLabel);
}
