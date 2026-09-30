import '../application/books_session.dart';
import '../application/build_general_ledger.dart';
import '../application/build_trial_balance.dart';
import '../domain/shared/book_backup_service.dart';
import '../domain/shared/book_upload_service.dart';

/// What the presentation layer is allowed to reach.
///
/// Held in one place so the wiring is visible in a single file rather than
/// scattered through widgets. A use case that is absent here has no screen, and
/// its navigation entry says so.
///
/// This is the only thing the presentation layer is given. It is how the shell
/// stays free of database and repository knowledge.
class AppServices {
  const AppServices({
    this.trialBalance,
    this.generalLedger,
    this.backup,
    this.session,
    this.upload,
  });

  /// The Trial Balance report. Null until the application assembles it.
  final TrialBalanceLoader? trialBalance;

  /// The General Ledger. Null until the application assembles it.
  final GeneralLedgerLoader? generalLedger;

  /// Taking and verifying backups.
  final BackupActions? backup;

  /// Which fiscal years exist and which is open, so the shell can offer a year
  /// switcher. Concluded years open **read-only**.
  final BooksSession? session;

  /// Sending a verified backup to the server.
  ///
  /// Null when the desktop is not signed in. Taking a backup works without this;
  /// it is the off-machine copy that needs a session, so its absence must never
  /// affect anything else.
  final UploadActions? upload;

  /// Every use case for the selected year, rebuilt from [session].
  ///
  /// The loaders all belong to one year's books, so switching year replaces all
  /// of them at once rather than patching any single one. The session is the
  /// single source of what is open.
  ///
  /// [upload] is carried through unchanged: it is about a session with the
  /// server, not about which year's books are open.
  AppServices forSession(BooksSession session) => AppServices(
        trialBalance: session.trialBalance,
        generalLedger: session.generalLedger,
        backup: session.backup,
        session: session,
        upload: upload,
      );
}
