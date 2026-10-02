import 'dart:io';

import 'package:path/path.dart' as p;

import '../../application/business_details.dart';
import '../../application/create_customer.dart';
import '../../application/issue_invoice.dart';
import '../../application/create_product.dart';
import '../../application/issue_credit_note.dart';
import '../../application/post_inventory_movement.dart';
import '../../application/post_journal_entry.dart';
import '../../application/record_payment.dart';
import '../../application/books_session.dart';
import '../../application/build_general_ledger.dart';
import '../../application/build_trial_balance.dart';
import '../../domain/accounting/chart_of_accounts.dart';
import '../../domain/fiscal/fiscal_year.dart';
import '../../domain/fiscal/nepali_fiscal_calendar.dart';
import '../../domain/shared/book_backup_service.dart';
import '../backup/file_book_backup_service.dart';
import 'app_database.dart';
import 'business_database.dart';
import 'drift_account_repository.dart';
import 'drift_customer_code_sequence.dart';
import 'drift_customer_repository.dart';
import 'drift_business_profile_repository.dart';
import 'drift_document_number_sequence.dart';
import 'drift_credit_note_repository.dart';
import 'drift_inventory_repository.dart';
import 'drift_invoice_repository.dart';
import 'drift_payment_repository.dart';
import 'drift_journal_repository.dart';
import 'drift_unit_of_work.dart';
import 'open_business_database.dart';
import 'sqlite_native.dart';

/// A [BooksSession] backed by the fiscal-year files in a folder.
///
/// One SQLite file per fiscal year, per ADR 002. Switching year closes the open
/// database and opens the chosen one, so exactly one set of books is ever open.
///
/// **A concluded year is opened read-only**, and the enforcement is at the
/// database rather than in the screens: `PRAGMA query_only` is set on every
/// connection. The specification requires historical years to be immutable, and
/// a rule that lives only in the UI is one that any future caller can walk past.
class FileBooksSession implements BooksSession {
  FileBooksSession._({
    required this.booksDirectory,
    required this.currentFiscalYearLabel,
    required List<OpenYear> years,
    required AppDatabase database,
    required OpenYear openYear,
    BackupActions? backup,
  })  : _years = years,
        _database = database,
        _openYear = openYear,
        _backup = backup;

  /// Opens the session on [startYear], or on the newest year present.
  ///
  /// [startYear] is what a fresh launch uses, normally the fiscal year today
  /// falls in. If its file does not exist it is created and seeded with the
  /// chart of accounts, because that is the year the business is trading in.
  static Future<FileBooksSession> openOn({
    required Directory booksDirectory,
    required FiscalYear startYear,
  }) async {
    await booksDirectory.create(recursive: true);

    // The year the business trades in is given, never read from the clock here.
    // A hidden clock dependency would make the read-only decision untestable and
    // could disagree with the year the caller asked for.
    final startLabel = startYear.label;
    var years = await _discover(booksDirectory, startLabel);
    if (!years.any((y) => y.fiscalYear.label == startLabel)) {
      // First run for this year: create it and seed the chart.
      final database = openFileDatabase(_fileFor(booksDirectory, startLabel));
      await DriftAccountRepository(database).saveAll(
        const ChartOfAccounts().all,
      );
      await database.close();
      years = await _discover(booksDirectory, startLabel);
    }

    final openYear = years.firstWhere(
      (y) => y.fiscalYear.label == startLabel,
      orElse: () => years.first,
    );
    final database = openFileDatabase(
      _fileFor(booksDirectory, openYear.fiscalYear.label),
      readOnly: openYear.isReadOnly,
    );

    return FileBooksSession._(
      booksDirectory: booksDirectory,
      currentFiscalYearLabel: startLabel,
      years: years,
      database: database,
      openYear: openYear,
    );
  }

  final Directory booksDirectory;

  /// The year the business is trading in, which is the only writable one.
  final String currentFiscalYearLabel;

  final List<OpenYear> _years;
  AppDatabase _database;

  /// The business-level database, separate from every year.
  ///
  /// Opened once and kept, because it is not per-year and there is nothing to
  /// swap when the user changes year.
  late final BusinessDatabase _businessDb =
      openBusinessDatabase(booksDirectory);
  OpenYear _openYear;
  BackupActions? _backup;

  @override
  List<OpenYear> get years => List.unmodifiable(_years);

  @override
  OpenYear get openYear => _openYear;

  @override
  TrialBalanceLoader get trialBalance => BuildTrialBalance(
        fiscalYear: _openYear.fiscalYear,
        journal: DriftJournalRepository(_database),
      );

  @override
  GeneralLedgerLoader get generalLedger => BuildGeneralLedger(
        fiscalYear: _openYear.fiscalYear,
        journal: DriftJournalRepository(_database),
        chart: const ChartOfAccounts(),
      );

  @override
  BackupActions get backup => _backup ??= _buildBackup();

  /// Rebuilt per open year, because a customer belongs to the books of the year
  /// they were added.
  @override
  CreateCustomer get createCustomer => CreateCustomer(
        customers: DriftCustomerRepository(_database),
        codes: DriftCustomerCodeSequence(_database),
        unitOfWork: DriftUnitOfWork(_database),
      );

  @override
  PostInventoryMovement get postMovement => PostInventoryMovement(
        fiscalYear: _openYear.fiscalYear,
        inventory: DriftInventoryRepository(_database),
        journal: DriftJournalRepository(_database),
        unitOfWork: DriftUnitOfWork(_database),
      );

  @override
  IssueCreditNote get issueCreditNote => IssueCreditNote(
        fiscalYear: _openYear.fiscalYear,
        invoices: DriftInvoiceRepository(_database),
        payments: DriftPaymentRepository(_database),
        creditNotes: DriftCreditNoteRepository(_database),
        numbers: DriftDocumentNumberSequence(_database),
        journal: DriftJournalRepository(_database),
        unitOfWork: DriftUnitOfWork(_database),
      );

  @override
  PostJournalEntry get postEntry => PostJournalEntry(
        fiscalYear: _openYear.fiscalYear,
        journal: DriftJournalRepository(_database),
        unitOfWork: DriftUnitOfWork(_database),
      );

  @override
  CreateProduct get createProduct => CreateProduct(
        inventory: DriftInventoryRepository(_database),
        unitOfWork: DriftUnitOfWork(_database),
      );

  @override
  RecordPayment get recordPayment => RecordPayment(
        fiscalYear: _openYear.fiscalYear,
        invoices: DriftInvoiceRepository(_database),
        payments: DriftPaymentRepository(_database),
        creditNotes: DriftCreditNoteRepository(_database),
        journal: DriftJournalRepository(_database),
        unitOfWork: DriftUnitOfWork(_database),
      );

  @override
  IssueInvoice get issueInvoice => IssueInvoice(
        fiscalYear: _openYear.fiscalYear,
        customers: DriftCustomerRepository(_database),
        numbers: DriftDocumentNumberSequence(_database),
        journal: DriftJournalRepository(_database),
        invoices: DriftInvoiceRepository(_database),
        unitOfWork: DriftUnitOfWork(_database),
        // The seller's details are stamped onto the invoice, so the stored
        // document carries what was printed on it.
        sellers: DriftBusinessProfileRepository(_businessDb),
      );

  /// This business's own details, in the **separate** `business.db`.
  ///
  /// ## Deliberately not in the open year's database
  ///
  /// Every fiscal year has its own file, so anything in one belongs to that year.
  /// The business profile does not: it is the name, address, PAN, and VAT status
  /// of the same business, and it changes rarely. Keeping it in the trading year's
  /// file meant a new fiscal year started with no business details, so the owner
  /// retyped them every Ashadh -- and an invoice risked printing without a PAN,
  /// which makes it invalid.
  ///
  /// **An invoice does not yet record what it used.** The intent was for each
  /// invoice to carry its own copy of the seller details, so changing the profile
  /// later would leave historical invoices exactly as issued. **`Invoice` has no
  /// seller fields today** — only `id`, `issueDate`, `customerId`, `lines`, and
  /// `vatRateBasisPoints` — so a historical invoice shows the business details
  /// *as they are now*, not as they were printed. Recorded as an open gap rather
  /// than a claim, because it is one.
  BusinessDetails get businessDetails =>
      BusinessDetails(repository: DriftBusinessProfileRepository(_businessDb));

  FileBookBackupService _buildBackup() => FileBookBackupService(
        currentDatabase: _database,
        booksDirectory: booksDirectory,
        backupDirectory: Directory(p.join(booksDirectory.path, 'backups')),
        currentFiscalYearLabel: _openYear.fiscalYear.label,
      );

  @override
  Future<void> open(FiscalYear fiscalYear) async {
    if (fiscalYear.label == _openYear.fiscalYear.label) return;

    final target = _years.firstWhere(
      (y) => y.fiscalYear.label == fiscalYear.label,
      orElse: () => throw ArgumentError(
        'There are no books for ${fiscalYear.label} in '
        '${booksDirectory.path}.',
      ),
    );

    await _database.close();

    _openYear = target;
    _database = openFileDatabase(
      _fileFor(booksDirectory, target.fiscalYear.label),
      readOnly: target.isReadOnly,
    );
    // The backup service holds the previous database, so it is rebuilt.
    _backup = null;
  }

  /// Closes the open books. Used on shutdown and by tests.
  Future<void> close() => _database.close();

  /// The database currently open, for wiring the backup service and for tests
  /// that need to assert on it.
  AppDatabase get database => _database;

  /// Every `accounting-FY-*.db` in the folder, newest year first.
  ///
  /// A year is read-only unless it is [currentLabel], the year the business is
  /// currently trading in. Concluded years are immutable per the specification.
  static Future<List<OpenYear>> _discover(
    Directory directory,
    String currentLabel,
  ) async {
    final pattern = RegExp(r'^accounting-FY-(\d{4})-(\d{2})\.db$');
    final years = <OpenYear>[];

    for (final entity in await directory.list().toList()) {
      if (entity is! File) continue;
      final match = pattern.firstMatch(p.basename(entity.path));
      if (match == null) continue;

      final label = 'FY ${match.group(1)}/${match.group(2)}';
      // The calendar decides the real start and end; the file name only says
      // which year it is.
      final startYear = int.parse(match.group(1)!);
      final calendar = const NepaliFiscalCalendar();
      final FiscalYear fiscalYear;
      try {
        fiscalYear = calendar.forBsYear(startYear);
      } catch (_) {
        // A year outside the calendar would be unreadable anyway; skip it
        // rather than failing the whole session.
        continue;
      }

      years.add(
        OpenYear(
          fiscalYear: fiscalYear,
          isReadOnly: label != currentLabel,
        ),
      );
    }

    years.sort(
      (a, b) => b.fiscalYear.label.compareTo(a.fiscalYear.label),
    );
    return years;
  }

  static File _fileFor(Directory directory, String label) => File(
        p.join(
          directory.path,
          'accounting-${label.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}.db',
        ),
      );
}
