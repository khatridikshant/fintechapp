import '../domain/accounting/account.dart';
import '../domain/accounting/account_repository.dart';
import '../domain/accounting/account_type.dart';
import '../domain/accounting/chart_of_accounts.dart';
import '../domain/accounting/journal_entry.dart';
import '../domain/accounting/journal_line.dart';
import '../domain/accounting/journal_repository.dart';
import '../domain/billing/purchase_repository.dart';
import '../domain/billing/supplier_payment.dart';
import '../domain/billing/supplier_payment_repository.dart';
import '../domain/fiscal/fiscal_year.dart';
import '../domain/shared/unit_of_work.dart';

/// The outcome of attempting to record a payment to a supplier.
sealed class RecordSupplierPaymentOutcome {
  const RecordSupplierPaymentOutcome();
}

final class SupplierPaymentRecorded extends RecordSupplierPaymentOutcome {
  const SupplierPaymentRecorded({required this.payment, required this.entry});

  final SupplierPayment payment;
  final JournalEntry entry;
}

final class SupplierPaymentRejected extends RecordSupplierPaymentOutcome {
  const SupplierPaymentRejected({
    required this.reason,
    required this.fiscalYear,
    required this.accountId,
  });

  final RecordSupplierPaymentRejectionReason reason;
  final FiscalYear fiscalYear;

  /// Named so the message can point at the account that caused the refusal,
  /// rather than saying only that "the account" was wrong.
  final String accountId;

  String get message => switch (reason) {
        RecordSupplierPaymentRejectionReason.outsideFiscalYear =>
          'This payment is dated outside ${fiscalYear.label} and cannot be '
              'recorded into it.',
        RecordSupplierPaymentRejectionReason.unknownPurchase =>
          'No purchase with that id exists, so there is nothing to settle.',
        RecordSupplierPaymentRejectionReason.notATransferAccount =>
          'A payment to a supplier must come from an account the business holds '
              'money in, such as Bank or Cash. Paying out of "$accountId" would '
              'reduce an expense rather than move money.',
        RecordSupplierPaymentRejectionReason.exceedsOutstanding =>
          'This payment is more than the outstanding balance on that purchase.',
      };
}

enum RecordSupplierPaymentRejectionReason {
  outsideFiscalYear,
  unknownPurchase,

  /// The account the money came from is not a transfer account.
  notATransferAccount,

  /// The payment is larger than what is still owed on the purchase.
  exceedsOutstanding,
}

/// Records money paid to a supplier.
///
/// ## The entry
///
/// ```
/// Dr  2010 Accounts Payable   the amount paid
/// Cr  <Bank or Cash>          the same amount
/// ```
///
/// A payment **reduces a liability**. It posts no expense and touches no revenue:
/// the cost was recognised when the purchase was recorded, and paying for goods
/// this month does not make them an expense of this month.
///
/// ## The account check is stricter than on the sales side, deliberately
///
/// `RecordPayment` takes a resolved `Account` and does not re-check its type,
/// because a customer paying into an expense account would immediately break the
/// trial balance and be noticed. A supplier payment is the mirror image â€” money
/// leaving â€” and "leaving" an expense account is possible without any immediate
/// symptom, because the expense would simply shrink. So this resolves the account
/// and requires an **asset**, which is where money held by a business lives.
class RecordSupplierPayment {
  const RecordSupplierPayment({
    required this.fiscalYear,
    required this.purchases,
    required this.payments,
    required this.accounts,
    required this.journal,
    required this.unitOfWork,
  });

  final FiscalYear fiscalYear;
  final PurchaseRepository purchases;
  final SupplierPaymentRepository payments;

  /// Used to refuse a payment out of an income or expense account.
  final AccountRepository accounts;

  final JournalRepository journal;
  final UnitOfWork unitOfWork;

  /// The journal entry id for a payment.
  ///
  /// **Derived from the payment id**, so re-running is refused by the primary key
  /// rather than paying twice. This is the property that makes a retry safe.
  static String journalEntryIdFor(SupplierPayment payment) =>
      SupplierPayment.journalEntryIdFor(payment);

  Future<RecordSupplierPaymentOutcome> call(
    SupplierPayment payment,
  ) async {
    if (!fiscalYear.contains(payment.date)) {
      return SupplierPaymentRejected(
        reason: RecordSupplierPaymentRejectionReason.outsideFiscalYear,
        fiscalYear: fiscalYear,
        accountId: payment.accountId,
        );
    }

    return unitOfWork.run<RecordSupplierPaymentOutcome>(() async {
      final purchase = await purchases.byId(payment.purchaseId);
      if (purchase == null) {
        return SupplierPaymentRejected(
          reason: RecordSupplierPaymentRejectionReason.unknownPurchase,
          fiscalYear: fiscalYear,
          accountId: payment.accountId,
          );
      }

      // The account must be an asset, so that the credit reduces something the
      // business actually holds. Without this a payment could be "paid" out of
      // Office Rent, which would shrink the expense and post a debit to payables
      // with no money having moved â€” books that balance and are wrong.
      final account = await accounts.byId(payment.accountId);
      if (account == null || account.type != AccountType.asset) {
        return SupplierPaymentRejected(
          reason: RecordSupplierPaymentRejectionReason.notATransferAccount,
          fiscalYear: fiscalYear,
          accountId: payment.accountId,
        );
      }

      // Overpaying is refused rather than clamped.
      //
      // **Refused, not clamped, and the distinction matters.** A supplier payment
      // reduces a liability; accepting more than is owed would post a debit to
      // Accounts Payable that is not a liability reduction at all but a claim on
      // the supplier, and 2010 would then carry a negative balance for a different
      // reason. A refund is a separate document.
      final alreadyPaid = await payments.forPurchase(payment.purchaseId);
      final outstanding =
          purchase.purchase.total.minorUnits - alreadyPaid.fold<int>(
                0,
                (sum, existing) => sum + existing.amount.minorUnits,
              );
      if (payment.amount.minorUnits > outstanding) {
        return SupplierPaymentRejected(
          reason: RecordSupplierPaymentRejectionReason.exceedsOutstanding,
          fiscalYear: fiscalYear,
          accountId: payment.accountId,
          );
      }

      final entry = journalEntryFor(payment, account);

      await journal.append(entry);
      await payments.save(payment);

      return SupplierPaymentRecorded(payment: payment, entry: entry);
    });
  }

  /// The double entry for a supplier payment.
  JournalEntry journalEntryFor(SupplierPayment payment, Account from) {
    return JournalEntry(
      id: journalEntryIdFor(payment),
      date: payment.date,
      description: 'Payment to supplier for purchase ${payment.purchaseId}',
      reference: payment.id,
      lines: [
        JournalLine.debit(
          account: ChartOfAccounts.payable,
          amount: payment.amount,
        ),
        JournalLine.credit(account: from, amount: payment.amount),
      ],
    );
  }
}