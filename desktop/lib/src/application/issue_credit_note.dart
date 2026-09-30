import '../domain/accounting/chart_of_accounts.dart';
import '../domain/accounting/journal_entry.dart';
import '../domain/accounting/journal_line.dart';
import '../domain/accounting/journal_repository.dart';
import '../domain/billing/credit_note.dart';
import '../domain/billing/credit_note_repository.dart';
import '../domain/billing/document_number.dart';
import '../domain/billing/document_number_sequence.dart';
import '../domain/billing/document_type.dart';
import '../domain/billing/invoice_balance.dart';
import '../domain/billing/invoice_repository.dart';
import '../domain/billing/issued_credit_note.dart';
import '../domain/billing/payment_repository.dart';
import '../domain/fiscal/fiscal_year.dart';
import '../domain/shared/money.dart';
import '../domain/shared/unit_of_work.dart';

/// The outcome of attempting to issue a credit note.
sealed class IssueCreditNoteOutcome {
  const IssueCreditNoteOutcome();
}

/// The credit note was issued, numbered, and posted.
final class CreditNoteIssued extends IssueCreditNoteOutcome {
  const CreditNoteIssued({
    required this.creditNote,
    required this.number,
    required this.journalEntry,
    required this.balance,
  });

  final CreditNote creditNote;
  final DocumentNumber number;
  final JournalEntry journalEntry;

  /// The invoice's balance **after** this credit note.
  final InvoiceBalance balance;
}

/// The credit note was refused and nothing was written.
final class CreditNoteRejected extends IssueCreditNoteOutcome {
  const CreditNoteRejected({
    required this.creditNote,
    required this.reason,
    required this.fiscalYear,
    this.uncredited,
  });

  final CreditNote creditNote;
  final CreditNoteRejectionReason reason;
  final FiscalYear fiscalYear;

  /// How much of the invoice was still uncredited, when the reason is that the
  /// credit was too large.
  final Money? uncredited;

  String get message => switch (reason) {
        CreditNoteRejectionReason.outsideFiscalYear =>
          'This credit note is dated outside ${fiscalYear.label} and cannot be '
              'issued into it.',
        CreditNoteRejectionReason.unknownInvoice =>
          'There is no invoice with id "${creditNote.invoiceId}" to credit.',
        CreditNoteRejectionReason.exceedsUncredited =>
          'This credit note of ${creditNote.total.format()} is more than the '
              '${uncredited?.format() ?? 'amount'} still uncredited on invoice '
              '"${creditNote.invoiceId}". An invoice cannot be credited for more '
              'than it was issued for.',
      };
}

enum CreditNoteRejectionReason {
  /// The credit note is dated outside the active fiscal year.
  outsideFiscalYear,

  /// The invoice being credited does not exist.
  unknownInvoice,

  /// The credit note is larger than the invoice's uncredited amount.
  exceedsUncredited,
}

/// Issues a credit note, which is how a posted invoice is corrected.
///
/// ADR 005 forbids editing or deleting an issued invoice, and requires
/// corrections to go through credit notes. This is the only supported correction
/// path.
///
/// The double entry reverses the sale:
///
/// ```
/// Dr  4010 Sales Revenue         credited subtotal
/// Dr  2020 VAT Payable           credited VAT
/// Cr  1030 Accounts Receivable   credited total
/// ```
///
/// The whole operation is one unit of work, and the uncredited amount is read
/// inside the transaction that writes the credit note, so two credit notes
/// cannot both be validated against an amount that only one of them should have
/// been allowed to consume.
///
/// **The ceiling is the uncredited amount, not the outstanding balance.**
/// Deliberately: a fully paid invoice can still be credited, in which case the
/// business owes the customer a refund. Bounding the credit note by what is
/// still *owed* would make that ordinary case impossible.
class IssueCreditNote {
  const IssueCreditNote({
    required this.fiscalYear,
    required this.invoices,
    required this.payments,
    required this.creditNotes,
    required this.numbers,
    required this.journal,
    required this.unitOfWork,
  });

  final FiscalYear fiscalYear;

  final InvoiceRepository invoices;

  final PaymentRepository payments;

  final CreditNoteRepository creditNotes;

  final DocumentNumberSequence numbers;

  final JournalRepository journal;

  final UnitOfWork unitOfWork;

  Future<IssueCreditNoteOutcome> call(CreditNote creditNote) async {
    if (!fiscalYear.contains(creditNote.date)) {
      return CreditNoteRejected(
        creditNote: creditNote,
        reason: CreditNoteRejectionReason.outsideFiscalYear,
        fiscalYear: fiscalYear,
      );
    }

    return unitOfWork.run<IssueCreditNoteOutcome>(() async {
      final invoice = await invoices.byId(creditNote.invoiceId);
      if (invoice == null) {
        return CreditNoteRejected(
          creditNote: creditNote,
          reason: CreditNoteRejectionReason.unknownInvoice,
          fiscalYear: fiscalYear,
        );
      }

      final alreadyIssued = await creditNotes.forInvoice(creditNote.invoiceId);
      final alreadyPaid = await payments.forInvoice(creditNote.invoiceId);

      final current = InvoiceBalance.of(
        invoice.invoice,
        alreadyPaid,
        creditNotes: alreadyIssued.map((issued) => issued.creditNote),
      );

      // Exactly the uncredited amount is allowed. One paisa more is not.
      if (creditNote.total > current.uncredited) {
        return CreditNoteRejected(
          creditNote: creditNote,
          reason: CreditNoteRejectionReason.exceedsUncredited,
          fiscalYear: fiscalYear,
          uncredited: current.uncredited,
        );
      }

      final number = await numbers.allocateNext(
        type: DocumentType.creditNote,
        fiscalYear: fiscalYear,
      );

      final issued = IssuedCreditNote(creditNote: creditNote, number: number);
      final entry = journalEntryFor(creditNote, number);

      // The journal entry first, because the credit note holds a foreign key
      // to it.
      await journal.append(entry);
      await creditNotes.save(issued);

      return CreditNoteIssued(
        creditNote: creditNote,
        number: number,
        journalEntry: entry,
        balance: InvoiceBalance.of(
          invoice.invoice,
          alreadyPaid,
          creditNotes: [
            ...alreadyIssued.map((issued) => issued.creditNote),
            creditNote,
          ],
        ),
      );
    });
  }

  /// The reversal entry for a credit note.
  ///
  /// A zero-rated credit note omits the VAT line rather than posting a zero
  /// amount, because a journal line must carry a positive amount on one side.
  JournalEntry journalEntryFor(CreditNote creditNote, DocumentNumber number) {
    return JournalEntry(
      id: IssuedCreditNote.journalEntryIdFor(creditNote),
      date: creditNote.date,
      description: 'Credit note ${number.value}',
      reference: number.value,
      lines: [
        JournalLine.debit(
          account: ChartOfAccounts.salesRevenue,
          amount: creditNote.subtotal,
        ),
        if (!creditNote.vat.isZero)
          JournalLine.debit(
            account: ChartOfAccounts.vatPayable,
            amount: creditNote.vat,
          ),
        JournalLine.credit(
          account: ChartOfAccounts.receivable,
          amount: creditNote.total,
        ),
      ],
    );
  }
}
