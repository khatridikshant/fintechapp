import 'package:drift/drift.dart' show OrderingTerm;

import '../../domain/billing/supplier_payment.dart';
import '../../domain/billing/supplier_payment_repository.dart';
import '../../domain/shared/money.dart';
import 'app_database.dart';

/// Stores payments made to suppliers.
///
/// The exact mirror of `DriftPaymentRepository`, because it settles the same kind
/// of balance on the other side of the business.
class DriftSupplierPaymentRepository implements SupplierPaymentRepository {
  DriftSupplierPaymentRepository(this.db);

  final AppDatabase db;

  @override
  Future<void> save(SupplierPayment payment) async {
    // A plain insert, not an upsert. **A supplier payment is a financial record**:
    // replacing one silently would let a retried operation change how much was
    // paid without any trace, and the payable would stop reconciling with the
    // documents that produced it. Reusing an id is refused by the primary key.
    await db.into(db.supplierPayments).insert(
          SupplierPaymentsCompanion.insert(
            id: payment.id,
            purchaseId: payment.purchaseId,
            date: payment.date,
            amountMinorUnits: payment.amount.minorUnits,
            currency: payment.amount.currency,
            accountId: payment.accountId,
          ),
        );
  }

  @override
  Future<List<SupplierPayment>> forPurchase(String purchaseId) async {
    final rows = await (db.select(db.supplierPayments)
          ..where((t) => t.purchaseId.equals(purchaseId))
          // Date then id: two payments on one day must still order deterministically,
          // or a reloaded balance could differ from the in-memory one for no
          // visible reason.
          ..orderBy([
            (t) => OrderingTerm(expression: t.date),
            (t) => OrderingTerm(expression: t.id),
          ]))
        .get();
    return rows.map(_paymentOf).toList();
  }

  @override
  Future<List<SupplierPayment>> all() async {
    final rows = await (db.select(db.supplierPayments)
          ..orderBy([
            (t) => OrderingTerm(expression: t.date),
            (t) => OrderingTerm(expression: t.id),
          ]))
        .get();
    return rows.map(_paymentOf).toList();
  }

  SupplierPayment _paymentOf(SupplierPaymentRow row) => SupplierPayment(
        id: row.id,
        purchaseId: row.purchaseId,
        date: row.date,
        amount: Money.minor(row.amountMinorUnits, row.currency),
        accountId: row.accountId,
      );
}