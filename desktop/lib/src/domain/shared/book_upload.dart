import 'book_backup.dart';

/// An authenticated desktop session against the backend.
///
/// The specification makes the backend authoritative for accounts, books, and
/// licensed installations, so the desktop has to know **which** book it is
/// uploading to and **who** it is. That is all this is: a server address, a
/// token, and a book id.
///
/// **It deliberately does not hold the account password.** A token is what the
/// server accepts, and keeping a password in memory for the life of the
/// application would be a liability with no benefit.
class BackendSession {
  const BackendSession({
    required this.serverBaseUrl,
    required this.token,
    required this.bookId,
    this.accountLabel,
    this.companyName,
    this.companyPan,
    this.vatRegistered,
  });

  /// The server root, for example `http://127.0.0.1:8000`. Requests are built
  /// from this, so it must not include a trailing `/api`.
  final Uri serverBaseUrl;

  /// The Sanctum token issued by `/api/auth/login`.
  ///
  /// The specification requires tokens to be kept in protected operating-system
  /// storage. That storage is not built yet, so today this arrives from
  /// configuration rather than from a sign-in screen. See `PROGRESS.md`.
  final String token;

  /// The book to upload to. `ADR 003` allows one book per account, and the
  /// server returns its id at registration and sign-in.
  final String bookId;

  /// Who is signed in, for display only. Never used to decide anything.
  final String? accountLabel;

  /// The registered business this session acts for.
  ///
  /// **Server-authoritative.** The PAN and the VAT registration now live in the
  /// server's `companies` table rather than only inside the uploaded SQLite, which
  /// means this is the value the server believes. It is carried for display and so
  /// a later screen need not fetch it again; nothing here decides anything from it.
  ///
  /// Null when the server sent no company, which an older server will not. Read as
  /// absent rather than as "not VAT registered" -- those are different claims.
  final String? companyName;

  /// The taxpayer's Permanent Account Number, from the server.
  final String? companyPan;

  /// Whether this business is registered for VAT, from the server.
  ///
  /// **Nullable on purpose.** A false here means "not registered"; null means the
  /// server did not say. Collapsing those would let an absent answer be read as a
  /// definite one, and a VAT-registered business charging no VAT is not a valid tax
  /// invoice.
  final bool? vatRegistered;

  /// True when this session can actually be used to send something.
  ///
  /// A session with no token is not a session, it is a placeholder that would
  /// produce a confusing 401. Checked before a request rather than after.
  bool get isUsable => token.trim().isNotEmpty && bookId.trim().isNotEmpty;

  @override
  String toString() => 'BackendSession($serverBaseUrl, book $bookId'
      '${accountLabel == null ? '' : ', $accountLabel'})';
}

/// What happened when one snapshot was sent to the server.
///
/// These are kept apart because they demand different things of the user:
/// `conflict` means someone else has already stored a revision, `rejected` means
/// the server refused the bytes, and `unreachable` means the answer is unknown
/// and the desktop should carry on working offline. Collapsing them into a
/// single "failed" would hide which of those happened.
enum UploadStatus {
  /// The server verified the snapshot and stored it.
  uploaded,

  /// The server refused it: a checksum, size, or database problem.
  rejected,

  /// The local snapshot no longer matches the checksum recorded when it was
  /// taken, so **nothing was sent**.
  ///
  /// This is a local refusal, not the server's. It exists because the recorded
  /// checksum is what proves the file is still the verified artifact: uploading
  /// a file whose bytes have changed since it was taken would store a damaged
  /// snapshot on the server and report it to the user as a trustworthy backup.
  /// Verifying locally is cheaper than discovering it at restore time.
  unverified,

  /// Someone else stored a revision first, so this one no longer follows.
  conflict,

  /// The server rejected the token: the session is no longer valid.
  ///
  /// **This used to be reported as [unreachable], and that was wrong once signing
  /// in exists.** The two look similar and are opposites in what they ask of the
  /// user. `unreachable` means try again later — the request never got a
  /// considered answer. A `401` means the server answered clearly and the answer
  /// was no, so retrying fails identically every time. Telling someone to try
  /// again later would send them round a loop they cannot escape; the only action
  /// that helps is signing in again.
  unauthenticated,

  /// The desktop could not get a usable answer from the server.
  ///
  /// Covers a connection that failed **and** a server that answered with an
  /// error status. They are one case for the user, because the response is the
  /// same in both: nothing was stored, the books are unchanged, and the sensible
  /// next step is to try again later. Neither is a statement about the snapshot
  /// itself, which is why neither is [rejected].
  unreachable,
}

/// The outcome of sending one snapshot.
class UploadResult {
  const UploadResult({
    required this.backup,
    required this.status,
    required this.message,
    this.remoteRevision,
  });

  /// The snapshot this is about. Never modified by an upload.
  final BookBackup backup;

  final UploadStatus status;

  /// What to tell the user. Written to be shown as-is.
  final String message;

  /// The revision the server assigned. Only set when [status] is
  /// [UploadStatus.uploaded].
  final int? remoteRevision;

  /// True only when the server confirmed it holds the bytes.
  bool get isSuccess => status == UploadStatus.uploaded;

  @override
  String toString() => 'UploadResult(${backup.fileName}, ${status.name})';
}

/// A snapshot the server confirmed it holds.
///
/// Kept so the screen can say when the last successful upload happened. This is
/// a **local note about a remote fact**, so it is written only after the server
/// has answered, never optimistically.
class UploadRecord {
  const UploadRecord({
    required this.fiscalYearLabel,
    required this.fileName,
    required this.uploadedAt,
    required this.remoteRevision,
    required this.checksum,
  });

  final String fiscalYearLabel;

  final String fileName;

  /// When the server confirmed it. Local time.
  final DateTime uploadedAt;

  /// The revision the server assigned.
  final int remoteRevision;

  /// The checksum the server verified, so a record can be traced to a snapshot.
  final String checksum;

  @override
  String toString() =>
      'UploadRecord($fiscalYearLabel revision $remoteRevision at $uploadedAt)';
}

/// Raised when an upload cannot be attempted at all.
///
/// Distinct from an [UploadStatus] result, which is a real answer from the
/// server. This is for the cases where no request could be made — no session, or
/// no snapshot — and calling it a "failed upload" would be misleading.
class UploadException implements Exception {
  UploadException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'UploadException: $message'
      : 'UploadException: $message (cause: $cause)';
}
