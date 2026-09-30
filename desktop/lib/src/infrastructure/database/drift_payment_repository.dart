import 'package:drift/drift.dart' show OrderingTerm;

import '../../domain/billing/payment.dart';
import '../../domain/billing/payment_repository.dart';
import '../../domain/shared/money.dart';
import 'app_database.dart';
import 'mappers.dart';

class DriftPaymentRepository implements PaymentRepository {
  DriftPaymentRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> save(Payment payment) async {
    // A plain insert, not an upsert. A recorded payment is a financial record;
    // silently replacing one would change what a customer is owed.
    await _db.into(_db.payments).insert(
          PaymentsCompanion.insert(
            id: payment.id,
            invoiceId: payment.invoiceId,
            date: payment.date,
            amountMinorUnits: payment.amount.minorUnits,
            currency: payment.currency,
            accountId: payment.account.id,
          ),
        );
  }

  @override
  Future<Payment?> byId(String id) async {
    final row = await (_db.select(_db.payments)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return (await _rebuildAll([row])).single;
  }

  @override
  Future<List<Payment>> forInvoice(String invoiceId) async {
    final rows = await (_db.select(_db.payments)
          ..where((t) => t.invoiceId.equals(invoiceId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.date),
            (t) => OrderingTerm(expression: t.id),
          ]))
        .get();
    return _rebuildAll(rows);
  }

  @override
  Future<List<Payment>> all() async {
    final rows = await (_db.select(_db.payments)
          ..orderBy([
            (t) => OrderingTerm(expression: t.date),
            (t) => OrderingTerm(expression: t.id),
          ]))
        .get();
    return _rebuildAll(rows);
  }

  /// Rebuilds payments, resolving the accounts they arrived in.
  ///
  /// The accounts are loaded once and looked up, rather than assumed. A payment
  /// into a closed or mistyped account must fail loudly instead of silently
  /// becoming a payment into Bank.
  Future<List<Payment>> _rebuildAll(List<PaymentRow> rows) async {
    if (rows.isEmpty) return const [];

    final accountRows = await _db.select(_db.accounts).get();
    final accounts = {
      for (final row in accountRows) row.id: accountFromRow(row),
    };

    return rows.map((row) {
      final account = accounts[row.accountId];
      if (account == null) {
        throw StateError(
          'Payment ${row.id} references unknown account ${row.accountId}.',
        );
      }
      return Payment(
        id: row.id,
        invoiceId: row.invoiceId,
        date: row.date,
        amount: Money.minor(row.amountMinorUnits, row.currency),
        account: account,
      );
    }).toList();
  }
}
