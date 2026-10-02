import '../domain/fiscal/fiscal_year.dart';
import '../domain/shared/book_backup_service.dart';
import 'build_general_ledger.dart';
import 'build_trial_balance.dart';
import 'create_customer.dart';
import 'create_product.dart';
import 'issue_invoice.dart';
import 'record_payment.dart';

/// One fiscal year the application can open.
class OpenYear {
  const OpenYear({required this.fiscalYear, required this.isReadOnly});

  final FiscalYear fiscalYear;

  /// True for a concluded year.
  ///
  /// The specification is explicit: *"Historical years may be opened or
  /// downloaded for reporting and review, but they shall be opened in read-only
  /// mode."* A concluded year is therefore not merely one the screens do not
  /// offer to edit; its database refuses writes.
  final bool isReadOnly;

  @override
  String toString() =>
      'OpenYear(${fiscalYear.label}${isReadOnly ? ', read-only' : ''})';
}

/// Which fiscal years exist, and which one is open.
///
/// A business has one set of books per fiscal year, so switching year means
/// opening a different database and building the use cases against it. The shell
/// holds this and rebuilds what the screens see when the year changes.
///
/// The interface lives in the application layer, beside the other loaders a
/// screen is given, so the presentation layer never reaches for a database.
abstract interface class BooksSession {
  /// Every fiscal year found, newest first.
  List<OpenYear> get years;

  /// The year currently open.
  OpenYear get openYear;

  /// The use cases for the open year.
  TrialBalanceLoader get trialBalance;

  GeneralLedgerLoader get generalLedger;

  BackupActions get backup;

  /// Creating a customer.
  ///
  /// **The first thing a business must be able to do**, and it has to belong to a
  /// year: a customer is recorded in the books of the year they were added, so
  /// creating one while a concluded year is open would write to the wrong books.
  CreateCustomer get createCustomer;

  /// Issuing an invoice: numbering it, posting it, and recording it.
  ///
  /// Rebuilt per open year, because an invoice belongs to the books of the year it
  /// is dated in.
  IssueInvoice get issueInvoice;

  /// Recording a payment against an invoice. Rebuilt per open year, because a
  /// payment belongs to the books of the year it was received in.
  RecordPayment get recordPayment;

  /// Creating a product in the catalogue.
  CreateProduct get createProduct;

  /// Opens [fiscalYear], closing whatever was open, and builds its use cases.
  ///
  /// A concluded year is opened **read-only**, enforced by the database itself.
  Future<void> open(FiscalYear fiscalYear);
}
