import '../application/account_session.dart';
import '../application/business_details.dart';
import '../application/create_customer.dart';
import '../application/issue_credit_note.dart';
import '../application/issue_invoice.dart';
import '../application/post_inventory_movement.dart';
import '../application/post_journal_entry.dart';
import '../application/create_product.dart';
import '../application/record_payment.dart';
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
    this.account,
    this.businessDetails,
    this.createCustomer,
    this.issueInvoice,
    this.recordPayment,
    this.createProduct,
    this.postMovement,
    this.issueCreditNote,
    this.postEntry,
  });

  /// The Trial Balance report. Null until the application assembles it.
  final TrialBalanceLoader? trialBalance;

  /// The General Ledger. Null until the application assembles it.
  final GeneralLedgerLoader? generalLedger;

  /// Taking and verifying backups.
  final BackupActions? backup;

  /// Sending a verified backup to the server.
  ///
  /// Null when the desktop is not signed in. Taking a backup works without this;
  /// it is the off-machine copy that needs a session, so its absence must never
  /// affect anything else.
  ///
  /// **Derived from [account] whenever there is one.** Signing in produces a fresh
  /// uploader, because an uploader holding a stale token would keep failing with a
  /// sign-in error the user cannot fix by signing in.
  final UploadActions? upload;

  /// Signing in and out. Null when the application has no account support.
  final AccountSession? account;

  /// This business's own details, and the means to save them.
  ///
  /// **Null is the normal first-run state**, not a fault: a fresh installation has
  /// no business name and no PAN, and the application must still start and still
  /// take backups. It simply cannot produce a valid tax invoice yet, and says so
  /// on the Settings screen.
  final BusinessDetails? businessDetails;

  /// Creating a customer. Null when the books expose no such use case, which is
  /// a test rather than a normal state.
  final CreateCustomer? createCustomer;

  /// Issuing an invoice. Null when the books expose no such use case, which is a
  /// test rather than a normal state.
  final IssueInvoice? issueInvoice;

  /// Recording a payment. Null when the books expose no such use case, which is a
  /// test rather than a normal state.
  final RecordPayment? recordPayment;

  /// Creating a product in the catalogue.
  final CreateProduct? createProduct;

  /// Recording a stock movement.
  final PostInventoryMovement? postMovement;

  /// Issuing a credit note.
  final IssueCreditNote? issueCreditNote;

  /// Posting a manual journal entry.
  final PostJournalEntry? postEntry;

  /// Which fiscal years exist and which is open, so the shell can offer a year
  /// switcher. Concluded years open **read-only**.
  final BooksSession? session;

  /// Every use case for the selected year, rebuilt from [session].
  ///
  /// The loaders all belong to one year's books, so switching year replaces all
  /// of them at once rather than patching any single one. The session is the
  /// single source of what is open.
  ///
  /// [upload] is re-derived from [account] when there is one, because
  /// signing in changes which session a snapshot would be sent with. With no
  /// account -- tests, and the developer environment-variable path -- the
  /// existing uploader is carried through untouched.
  AppServices forSession(BooksSession session) => AppServices(
        trialBalance: session.trialBalance,
        generalLedger: session.generalLedger,
        backup: session.backup,
        session: session,
        upload: account?.upload ?? upload,
        account: account,
        businessDetails: businessDetails,
        // From the open year: a customer belongs to the books of the year they
        // were added.
        createCustomer: session.createCustomer,
        issueInvoice: session.issueInvoice,
        recordPayment: session.recordPayment,
      );

  /// The same services, re-read after signing in or out.
  ///
  /// Signing in replaces the token a backup is sent with, and the uploader takes
  /// its session in its constructor, so the whole bundle is rebuilt -- the same
  /// reasoning as [forSession].
  AppServices forAccount() => AppServices(
        trialBalance: trialBalance,
        generalLedger: generalLedger,
        backup: backup,
        session: session,
        upload: account?.upload,
        account: account,
        businessDetails: businessDetails,
        createCustomer: createCustomer,
        issueInvoice: issueInvoice,
        recordPayment: recordPayment,
      );
}
