import '../domain/billing/customer_repository.dart';
import '../domain/billing/credit_note_repository.dart';
import '../domain/billing/issued_credit_note.dart';
import '../domain/billing/payment.dart';
import '../domain/billing/invoice_balance.dart';
import '../domain/billing/invoice_repository.dart';
import '../domain/billing/payment_repository.dart';
import '../domain/shared/money.dart';

/// Who owes what.
///
/// ## What "receivable" means here, precisely
///
/// **Money invoiced that has not been received**, per invoice, after credit notes.
///
/// Two things this deliberately does **not** call a receivable:
///
/// - **VAT.** The VAT on an unpaid invoice is owed to the tax authority, not by the
///   customer. Counting it as money owed to the business overstates the figure by
///   the tax, and a business chasing its own VAT from a customer is chasing the
///   wrong money.
/// - **A credit balance.** When credit notes exceed the invoice, the *customer*
///   is owed the difference ([InvoiceBalance.refundDue]). That is shown separately
///   rather than netted off, because a refund owed and a debt owed are different
///   conversations.
///
/// ## Where the figures come from
///
/// [InvoiceBalance] — the same helper the invoice screens use — so a balance shown
/// here is the same balance shown on the invoice, computed once. A second
/// implementation here would eventually disagree with the first, and the user would
/// be left deciding which is right.
abstract interface class ReceivablesLoader {
  Future<ReceivablesReport> load();
}

/// One customer's position.
class CustomerReceivable {
  const CustomerReceivable({
    required this.customerId,
    required this.customerName,
    required this.invoices,
    required this.refundsOwed,
  });

  final String customerId;
  final String customerName;

  /// This customer's open invoices, oldest first.
  final List<OpenInvoice> invoices;

  /// Money this business owes back, where credit notes exceed the invoices.
  ///
  /// **Kept separate from [outstanding] rather than netted.** A negative number
  /// labelled "outstanding" reads as a debt the customer does not owe.
  final Money refundsOwed;

  /// What the customer owes in total.
  Money get outstanding => Money.sum(
      invoices.map((OpenInvoice i) => i.balance), refundsOwed.currency);

  bool get isSettled => outstanding.isZero && refundsOwed.isZero;

  @override
  String toString() =>
      'CustomerReceivable($customerName, ${invoices.length} invoices, $outstanding)';
}

/// One invoice that is not fully settled.
class OpenInvoice {
  const OpenInvoice({
    required this.number,
    required this.issueDate,
    required this.balance,
  });

  final String number;
  final DateTime issueDate;

  /// What is still owed on this invoice, after payments and credit notes.
  final Money balance;

  /// How old the debt is, in days, measured from the invoice's issue date.
  ///
  /// **Age, not overdue.** `Invoice` records no due date, so calling this "days
  /// overdue" would be a claim the data cannot support. It is the age of the debt,
  /// which is what a reader can honestly be told.
  int ageInDays(DateTime asAt) => asAt.difference(issueDate).inDays;

  @override
  String toString() => 'OpenInvoice($number, $balance)';
}

/// The receivables position.
class ReceivablesReport {
  const ReceivablesReport({
    required this.customers,
    required this.currency,
    required this.asAt,
  });

  /// Customers with something outstanding, most owed first.
  final List<CustomerReceivable> customers;

  final String currency;

  /// The date the ageing is measured against.
  final DateTime asAt;

  /// Every open invoice across every customer, oldest first.
  List<OpenInvoice> get openInvoices => <OpenInvoice>[
        for (final customer in customers) ...customer.invoices,
      ]..sort(
          (OpenInvoice a, OpenInvoice b) => a.issueDate.compareTo(b.issueDate));

  /// Total owed by customers.
  Money get totalOutstanding => Money.sum(
      customers.map((CustomerReceivable c) => c.outstanding), currency);

  /// Total this business owes back.
  Money get totalRefundsOwed => Money.sum(
        customers.map((CustomerReceivable c) => c.refundsOwed),
        currency,
      );

  bool get isEmpty => customers.isEmpty;

  @override
  String toString() =>
      'ReceivablesReport(${customers.length} customers, $totalOutstanding)';
}

class BuildReceivables implements ReceivablesLoader {
  const BuildReceivables({
    required this.invoices,
    required this.payments,
    required this.creditNotes,
    required this.customers,
    this.currency = 'NPR',
    DateTime? asAt,
  }) : _asAt = asAt;

  final InvoiceRepository invoices;
  final PaymentRepository payments;
  final CreditNoteRepository creditNotes;
  final CustomerRepository customers;
  final String currency;

  /// Injected so ageing is deterministic in tests rather than depending on today.
  final DateTime? _asAt;

  @override
  Future<ReceivablesReport> load() async {
    final DateTime asAt = _asAt ?? DateTime.now();

    final issued = await invoices.all();
    final allPayments = await payments.all();
    final allCreditNotes = await creditNotes.all();
    final allCustomers = await customers.all();

    final names = <String, String>{
      for (final customer in allCustomers) customer.id: customer.name,
    };

    final byCustomer = <String, List<OpenInvoice>>{};
    final refunds = <String, Money>{};

    for (final record in issued) {
      final InvoiceBalance balance = InvoiceBalance.of(
        record.invoice,
        allPayments.where((Payment p) => p.invoiceId == record.invoice.id),
        // The repository yields IssuedCreditNote, a wrapper carrying the
        // allocated number; InvoiceBalance wants the note itself.
        creditNotes: allCreditNotes
            .where((IssuedCreditNote n) =>
                n.creditNote.invoiceId == record.invoice.id)
            .map((IssuedCreditNote n) => n.creditNote),
      );

      final String customerId = record.invoice.customerId;

      // **A refund is kept apart from a receivable**, because a negative
      // outstanding reads as a debt the customer does not owe.
      if (balance.refundDue.isPositive) {
        refunds[customerId] = (refunds[customerId] ?? Money.minor(0, currency))
            .add(balance.refundDue);
      } else if (!balance.outstanding.isZero) {
        byCustomer.putIfAbsent(customerId, () => <OpenInvoice>[]).add(
              OpenInvoice(
                number: record.number.value,
                issueDate: record.invoice.issueDate,
                balance: balance.outstanding,
              ),
            );
      }
    }

    final rows = <CustomerReceivable>[
      for (final entry in byCustomer.entries)
        CustomerReceivable(
          customerId: entry.key,
          // **Falls back to the id** rather than showing nothing. A receivable with
          // no name on it cannot be chased, so an unknown customer is at least
          // identifiable.
          customerName: names[entry.key] ?? entry.key,
          invoices: List<OpenInvoice>.unmodifiable(
            entry.value
              ..sort((OpenInvoice a, OpenInvoice b) =>
                  a.issueDate.compareTo(b.issueDate)),
          ),
          refundsOwed: refunds[entry.key] ?? Money.minor(0, currency),
        ),
      // A customer with only a refund and no receivable still needs to appear,
      // or the money owed back is invisible.
      for (final entry in refunds.entries)
        if (!byCustomer.containsKey(entry.key))
          CustomerReceivable(
            customerId: entry.key,
            customerName: names[entry.key] ?? entry.key,
            invoices: const <OpenInvoice>[],
            refundsOwed: entry.value,
          ),
    ]..sort(
        (CustomerReceivable a, CustomerReceivable b) =>
            b.outstanding.compareTo(a.outstanding),
      );

    return ReceivablesReport(
      customers: List<CustomerReceivable>.unmodifiable(rows),
      currency: currency,
      asAt: asAt,
    );
  }
}
