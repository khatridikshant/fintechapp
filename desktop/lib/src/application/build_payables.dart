import '../domain/billing/purchase_balance.dart';
import '../domain/billing/purchase_repository.dart';
import '../domain/billing/supplier_payment.dart';
import '../domain/billing/supplier_payment_repository.dart';
import '../domain/billing/supplier_repository.dart';
import '../domain/shared/money.dart';

/// What this business owes its suppliers.
///
/// ## The exact mirror of `ReceivablesLoader`
///
/// Same shape, same derivation, opposite side of the balance sheet — deliberately,
/// because a payables report computed any differently from the receivables report
/// would eventually disagree with it, and the user would be left deciding which of
/// the two is right.
///
/// ## What is deliberately *not* excluded here
///
/// `ReceivablesLoader` leaves VAT out of a receivable, because VAT on an unpaid
/// invoice is owed to the authority rather than by the customer.
///
/// A payable is different: **the VAT on an unpaid purchase bill genuinely is owed
/// to the supplier**, who charged it and has not been paid. Excluding it would
/// understate what the business owes by exactly the recoverable tax, and would
/// make the total disagree with the balance of `2010 Accounts Payable`, which is
/// credited gross. So the figure here is gross and must match the account.
abstract interface class PayablesLoader {
  Future<PayablesReport> load();
}

/// One supplier's position.
class SupplierPayable {
  const SupplierPayable({
    required this.supplierId,
    required this.supplierName,
    required this.purchases,
  });

  final String supplierId;
  final String supplierName;

  /// This supplier's open bills, oldest first.
  final List<OpenPurchase> purchases;

  /// What this business owes in total.
  Money get outstanding => Money.sum(
        purchases.map((OpenPurchase p) => p.balance),
        purchases.isEmpty ? 'NPR' : purchases.first.balance.currency,
      );

  bool get isSettled => outstanding.isZero;

  @override
  String toString() =>
      'SupplierPayable($supplierName, ${purchases.length} bills, $outstanding)';
}

/// One purchase bill that is not fully settled.
class OpenPurchase {
  const OpenPurchase({
    required this.number,
    required this.issueDate,
    required this.balance,
    required this.inputVat,
    required this.inputVatClaimable,
  });

  final String number;
  final DateTime issueDate;

  /// What is still owed on this bill, after payments.
  ///
  /// **Gross, including VAT** — see the class docblock.
  final Money balance;

  /// The VAT charged on this bill, still unpaid.
  final Money inputVat;

  /// The part of [inputVat] that is claimable, which is the part from a supplier
  /// carrying a PAN.
  final Money inputVatClaimable;

  /// How old the debt is, in days.
  ///
  /// **Age, not overdue**, exactly as `OpenInvoice.ageInDays`: no purchase records
  /// a due date, so "days overdue" would be a claim the data cannot support.
  int ageInDays(DateTime asAt) => asAt.difference(issueDate).inDays;

  @override
  String toString() => 'OpenPurchase($number, $balance)';
}

/// The payables position.
class PayablesReport {
  const PayablesReport({
    required this.suppliers,
    required this.currency,
    required this.asAt,
  });

  /// Suppliers with something outstanding, most owed first.
  final List<SupplierPayable> suppliers;

  final String currency;
  final DateTime asAt;

  /// Every open bill across every supplier, oldest first.
  List<OpenPurchase> get openPurchases => <OpenPurchase>[
        for (final supplier in suppliers) ...supplier.purchases,
      ]..sort(
          (OpenPurchase a, OpenPurchase b) => a.issueDate.compareTo(b.issueDate));

  /// Total owed to suppliers.
  Money get totalOutstanding => Money.sum(
        suppliers.map((SupplierPayable s) => s.outstanding),
        currency,
      );

  /// Total recoverable VAT still unpaid across the open bills.
  Money get totalInputVat => Money.sum(
        openPurchases.map((OpenPurchase p) => p.inputVat),
        currency,
      );

  /// Total claimable recoverable VAT across the open bills.
  Money get totalInputVatClaimable => Money.sum(
        openPurchases.map((OpenPurchase p) => p.inputVatClaimable),
        currency,
      );

  bool get isEmpty => suppliers.isEmpty;

  @override
  String toString() =>
      'PayablesReport(${suppliers.length} suppliers, $totalOutstanding)';
}

class BuildPayables implements PayablesLoader {
  const BuildPayables({
    required this.purchases,
    required this.payments,
    required this.suppliers,
    this.currency = 'NPR',
    DateTime? asAt,
  }) : _asAt = asAt;

  final PurchaseRepository purchases;
  final SupplierPaymentRepository payments;
  final SupplierRepository suppliers;
  final String currency;

  /// Injected so ageing is deterministic in tests rather than depending on today.
  final DateTime? _asAt;

  @override
  Future<PayablesReport> load() async {
    final DateTime asAt = _asAt ?? DateTime.now();

    final issued = await purchases.all();
    final allPayments = await payments.all();
    final allSuppliers = await suppliers.all();

    final names = <String, String>{
      for (final supplier in allSuppliers) supplier.id: supplier.name,
    };
    final panPresent = <String, bool>{
      for (final supplier in allSuppliers)
        supplier.id: supplier.canSupportInputCredit,
    };

    final bySupplier = <String, List<OpenPurchase>>{};

    for (final record in issued) {
      final balance = PurchaseBalance.of(
        record.purchase,
        allPayments
            .where((SupplierPayment p) => p.purchaseId == record.purchase.id),
      );

      // **A fully settled bill is not a payable**, so it is omitted. A supplier
      // with only settled bills therefore does not appear at all — which is the
      // point of a payable report.
      if (balance.outstanding.isZero) continue;

      bySupplier
          .putIfAbsent(record.purchase.supplierId, () => <OpenPurchase>[])
          .add(
            OpenPurchase(
              number: record.number.value,
              issueDate: record.purchase.issueDate,
              balance: balance.outstanding,
              inputVat: record.purchase.vat,
              // Unknown supplier is treated as **not** claimable, matching the VAT
              // return: a claim that cannot be substantiated is not a claim.
              inputVatClaimable: (panPresent[record.purchase.supplierId] ?? false)
                  ? record.purchase.vat
                  : Money.minor(0, currency),
            ),
          );
    }

    final rows = <SupplierPayable>[
      for (final entry in bySupplier.entries)
        SupplierPayable(
          supplierId: entry.key,
          // Falls back to the id rather than showing nothing: a payable with no
          // name cannot be chased, so an unknown supplier is at least identifiable.
          supplierName: names[entry.key] ?? entry.key,
          purchases: List<OpenPurchase>.unmodifiable(
            entry.value
              ..sort(
                (OpenPurchase a, OpenPurchase b) =>
                    a.issueDate.compareTo(b.issueDate),
              ),
          ),
        ),
    ]..sort(
        (SupplierPayable a, SupplierPayable b) =>
            b.outstanding.compareTo(a.outstanding),
      );

    return PayablesReport(
      suppliers: List<SupplierPayable>.unmodifiable(rows),
      currency: currency,
      asAt: asAt,
    );
  }
}