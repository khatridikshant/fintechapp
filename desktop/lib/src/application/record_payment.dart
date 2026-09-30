import '../domain/accounting/chart_of_accounts.dart';
import '../domain/accounting/journal_entry.dart';
import '../domain/accounting/journal_line.dart';
import '../domain/accounting/journal_repository.dart';
import '../domain/billing/credit_note_repository.dart';
import '../domain/billing/invoice_balance.dart';
import '../domain/billing/invoice_repository.dart';
import '../domain/billing/payment.dart';
import '../domain/billing/payment_repository.dart';
import '../domain/fiscal/fiscal_year.dart';
import '../domain/shared/money.dart';
import '../domain/shared/unit_of_work.dart';

/// The outcome of attempting to record a payment.
sealed class RecordPaymentOutcome {
  const RecordPaymentOutcome();
}

/// The payment was recorded and posted.
final class PaymentRecorded extends RecordPaymentOutcome {
  const PaymentRecorded({
    required this.payment,
    required this.journalEntry,
    required this.balance,
  });

  final Payment payment;

  final JournalEntry journalEntry;

  /// The invoice's balance **after** this payment.
  final InvoiceBalance balance;
}

/// The payment was refused and nothing was written.
final class PaymentRejected extends RecordPaymentOutcome {
  const PaymentRejected({
    required this.payment,
    required this.reason,
    required this.fiscalYear,
    this.outstanding,
  });

  final Payment payment;
  final RecordPaymentRejectionReason reason;
  final FiscalYear fiscalYear;

  /// How much was actually owed, when the reason is an overpayment.
  final Money? outstanding;

  String get message => switch (reason) {
        RecordPaymentRejectionReason.outsideFiscalYear =>
          'This payment is dated outside ${fiscalYear.label} and cannot be '
              'recorded against it.',
        RecordPaymentRejectionReason.unknownInvoice =>
          'There is no invoice with id "${payment.invoiceId}" to settle.',
        RecordPaymentRejectionReason.exceedsOutstanding =>
          'This payment of ${payment.amount.format()} is more than the '
              '${outstanding?.format() ?? 'amount'} still owed on invoice '
              '"${payment.invoiceId}". A customer cannot pay more than they '
              'owe; record the correct amount, or issue a credit note.',
      };
}

enum RecordPaymentRejectionReason {
  /// The payment is dated outside the active fiscal year.
  outsideFiscalYear,

  /// The invoice being settled does not exist.
  unknownInvoice,

  /// The payment is larger than the invoice's outstanding balance.
  exceedsOutstanding,
}

/// Records money received from a customer against an invoice.
///
/// This is what finally settles a receivable. Until a payment is recorded, an
/// issued invoice leaves the receivable outstanding forever.
///
/// The double entry:
///
/// ```
/// Dr  <bank or cash>             amount received
/// Cr  1030 Accounts Receivable   amount received
/// ```
///
/// The whole operation is one unit of work. The outstanding balance is read
/// inside the transaction and the payment is written inside the same
/// transaction, so two payments cannot both be validated against a balance that
/// only one of them should have been allowed to consume. That closes the
/// overpayment race rather than merely making it unlikely.
class RecordPayment {
  const RecordPayment({
    required this.fiscalYear,
    required this.invoices,
    required this.payments,
    required this.creditNotes,
    required this.journal,
    required this.unitOfWork,
  });

  /// The fiscal year currently open for writing.
  final FiscalYear fiscalYear;

  final InvoiceRepository invoices;

  final PaymentRepository payments;

  /// Needed so the overpayment check accounts for credit notes. Without it a
  /// customer could pay the full original amount after the invoice had been
  /// partly credited, and the payment would be accepted even though it exceeds
  /// what is actually owed.
  final CreditNoteRepository creditNotes;

  final JournalRepository journal;

  final UnitOfWork unitOfWork;

  /// The journal entry id for a payment.
  ///
  /// Derived from the payment id, so recording the same payment twice is refused
  /// by the primary key rather than double-counted against the invoice.
  static String journalEntryIdFor(Payment payment) => 'JE-PAY-${payment.id}';

  Future<RecordPaymentOutcome> call(Payment payment) async {
    // Validate the date before opening anything, so a refusal leaves no trace.
    if (!fiscalYear.contains(payment.date)) {
      return PaymentRejected(
        payment: payment,
        reason: RecordPaymentRejectionReason.outsideFiscalYear,
        fiscalYear: fiscalYear,
      );
    }

    return unitOfWork.run<RecordPaymentOutcome>(() async {
      final invoice = await invoices.byId(payment.invoiceId);
      if (invoice == null) {
        return PaymentRejected(
          payment: payment,
          reason: RecordPaymentRejectionReason.unknownInvoice,
          fiscalYear: fiscalYear,
        );
      }

      final alreadyReceived = await payments.forInvoice(payment.invoiceId);
      final alreadyIssued = await creditNotes.forInvoice(payment.invoiceId);
      final current = InvoiceBalance.of(
        invoice.invoice,
        alreadyReceived,
        creditNotes: alreadyIssued.map((issued) => issued.creditNote),
      );

      // Exactly the outstanding amount is allowed. One paisa more is not.
      if (payment.amount > current.outstanding) {
        return PaymentRejected(
          payment: payment,
          reason: RecordPaymentRejectionReason.exceedsOutstanding,
          fiscalYear: fiscalYear,
          outstanding: current.outstanding,
        );
      }

      final entry = journalEntryFor(payment);
      await journal.append(entry);
      await payments.save(payment);

      return PaymentRecorded(
        payment: payment,
        journalEntry: entry,
        balance: InvoiceBalance.of(
          invoice.invoice,
          [...alreadyReceived, payment],
          creditNotes: alreadyIssued.map((issued) => issued.creditNote),
        ),
      );
    });
  }

  /// The double entry for money received.
  JournalEntry journalEntryFor(Payment payment) {
    return JournalEntry(
      id: journalEntryIdFor(payment),
      date: payment.date,
      description: 'Payment received for invoice ${payment.invoiceId}',
      reference: payment.invoiceId,
      lines: [
        JournalLine.debit(account: payment.account, amount: payment.amount),
        JournalLine.credit(
          account: ChartOfAccounts.receivable,
          amount: payment.amount,
        ),
      ],
    );
  }
}
