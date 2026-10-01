import '../domain/accounting/chart_of_accounts.dart';
import '../domain/accounting/journal_entry.dart';
import '../domain/accounting/journal_line.dart';
import '../domain/accounting/journal_repository.dart';
import '../domain/billing/business_profile_repository.dart';
import '../domain/billing/customer_repository.dart';
import '../domain/billing/document_number.dart';
import '../domain/billing/document_number_sequence.dart';
import '../domain/billing/document_type.dart';
import '../domain/billing/invoice.dart';
import '../domain/billing/invoice_repository.dart';
import '../domain/billing/issued_invoice.dart';
import '../domain/fiscal/fiscal_year.dart';
import '../domain/shared/unit_of_work.dart';

/// The outcome of attempting to issue an invoice.
sealed class IssueInvoiceOutcome {
  const IssueInvoiceOutcome();
}

/// The invoice was issued, numbered, and posted.
final class InvoiceIssued extends IssueInvoiceOutcome {
  const InvoiceIssued({
    required this.invoice,
    required this.number,
    required this.journalEntry,
    required this.issued,
  });

  final Invoice invoice;

  /// The serial allocated at issuance. This is the first time the invoice has a
  /// number, because a draft does not consume one.
  final DocumentNumber number;

  final JournalEntry journalEntry;

  /// The stored document: the invoice together with its number and the id of the
  /// entry that records it.
  final IssuedInvoice issued;
}

/// The invoice was refused and nothing was written.
final class InvoiceRejected extends IssueInvoiceOutcome {
  const InvoiceRejected({
    required this.invoice,
    required this.reason,
    required this.fiscalYear,
  });

  final Invoice invoice;
  final IssueRejectionReason reason;
  final FiscalYear fiscalYear;

  String get message => switch (reason) {
        IssueRejectionReason.outsideFiscalYear =>
          'This invoice is dated outside ${fiscalYear.label} and cannot be '
              'issued into it.',
        IssueRejectionReason.unknownCustomer =>
          'There is no customer with id "${invoice.customerId}". A sale cannot '
              'be recorded as a receivable owed by nobody.',
      };
}

enum IssueRejectionReason {
  /// The invoice is dated outside the active fiscal year.
  outsideFiscalYear,

  /// The customer the invoice bills does not exist.
  unknownCustomer,
}

/// Issues a sales invoice: numbers it, accounts for it, and records it.
///
/// The whole operation runs inside a **single unit of work**. That is the point
/// of this use case, and it is what makes the failure behaviour correct:
///
/// - The serial is allocated only after the date has been validated, so a
///   refused invoice never consumes one.
/// - If the posting fails, the allocation rolls back with it. The sequence has
///   no gap, and the next attempt receives the same number.
///
/// A partly issued invoice — numbered but not posted, or posted without a number
/// — is impossible, because neither half can commit on its own.
///
/// The journal entry id is derived from the invoice id. That gives two things at
/// once: the entry is traceable back to the invoice that caused it, and
/// re-issuing an invoice id that has already been posted is refused by the
/// primary key rather than silently double-posting.
class IssueInvoice {
  const IssueInvoice({
    required this.fiscalYear,
    required this.customers,
    required this.numbers,
    required this.journal,
    required this.invoices,
    required this.unitOfWork,
    this.sellers,
  });

  /// The fiscal year currently open for writing.
  final FiscalYear fiscalYear;

  final CustomerRepository customers;

  final DocumentNumberSequence numbers;

  final JournalRepository journal;

  /// Where the issued invoice is recorded as a document.
  final InvoiceRepository invoices;

  final UnitOfWork unitOfWork;

  /// Where the business's own details come from.
  ///
  /// **Read by the use case rather than passed in by the caller**, so the snapshot
  /// cannot be forgotten: the printed invoice is the evidence in an audit, and a
  /// caller that remembered to stamp it only sometimes is worse than one that
  /// never can.
  ///
  /// Optional so the use case can be exercised without a database. **The
  /// application always supplies it**, and an invoice issued without a snapshot is
  /// reported by `InvoiceCompliance` rather than passing unnoticed.
  final BusinessProfileRepository? sellers;

  /// The journal entry id for an invoice.
  ///
  /// Delegates to [IssuedInvoice], which owns the rule, so there is one
  /// definition rather than two.
  static String journalEntryIdFor(Invoice invoice) =>
      IssuedInvoice.journalEntryIdFor(invoice);

  Future<IssueInvoiceOutcome> call(Invoice invoice) async {
    // Validate the date before opening anything. A refused invoice must leave no
    // trace at all, and the cheapest way to guarantee that is never to start.
    if (!fiscalYear.contains(invoice.issueDate)) {
      return InvoiceRejected(
        invoice: invoice,
        reason: IssueRejectionReason.outsideFiscalYear,
        fiscalYear: fiscalYear,
      );
    }

    return unitOfWork.run<IssueInvoiceOutcome>(() async {
      // The customer check runs inside the transaction, so the read that proves
      // the customer exists and the writes that reference them cannot be
      // separated by a change in between.
      final customer = await customers.byId(invoice.customerId);
      if (customer == null) {
        return InvoiceRejected(
          invoice: invoice,
          reason: IssueRejectionReason.unknownCustomer,
          fiscalYear: fiscalYear,
        );
      }

      final number = await numbers.allocateNext(
        type: DocumentType.invoice,
        fiscalYear: fiscalYear,
      );

      // The seller's details are copied onto the invoice **before** it is
      // recorded, so the stored document carries what was printed on it. Read
      // inside the transaction: the profile a customer was shown and the one
      // stamped must be the same.
      final seller = await sellers?.load();
      final stamped = seller == null
          ? invoice
          : invoice.stampedWithSeller(
              name: seller.name,
              pan: seller.panNumber,
            );

      final issued = IssuedInvoice(invoice: stamped, number: number);
      final entry = journalEntryFor(stamped, number);

      // The journal entry is written first, because the invoice record holds a
      // foreign key to it.
      await journal.append(entry);

      // The document record. All three writes commit together or none does, so a
      // numbered invoice always has a record and an entry behind it.
      await invoices.save(issued);

      return InvoiceIssued(
        invoice: stamped,
        number: number,
        journalEntry: entry,
        issued: issued,
      );
    });
  }

  /// The double entry for a sale.
  ///
  /// ```
  /// Dr  1030 Accounts Receivable   total including VAT
  /// Cr  4010 Sales Revenue         subtotal
  /// Cr  2020 VAT Payable           VAT amount
  /// ```
  ///
  /// The standard chart is referenced directly rather than injected, because its
  /// account ids are permanent: a sale always posts to Accounts Receivable,
  /// Sales Revenue, and VAT Payable, and those are fixed domain facts rather
  /// than configuration.
  ///
  /// A zero-rated invoice omits the VAT line entirely rather than posting a zero
  /// amount, because a journal line must carry a positive amount on one side.
  JournalEntry journalEntryFor(Invoice invoice, DocumentNumber number) {
    return JournalEntry(
      id: journalEntryIdFor(invoice),
      date: invoice.issueDate,
      description: 'Invoice ${number.value}',
      reference: number.value,
      lines: [
        JournalLine.debit(
          account: ChartOfAccounts.receivable,
          amount: invoice.total,
        ),
        JournalLine.credit(
          account: ChartOfAccounts.salesRevenue,
          amount: invoice.subtotal,
        ),
        if (!invoice.vat.isZero)
          JournalLine.credit(
            account: ChartOfAccounts.vatPayable,
            amount: invoice.vat,
          ),
      ],
    );
  }
}
