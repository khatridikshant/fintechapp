import 'package:drift/drift.dart' show OrderingTerm;

import '../../domain/billing/customer.dart';
import '../../domain/billing/customer_repository.dart';
import 'app_database.dart';
import 'mappers.dart';

class DriftCustomerRepository implements CustomerRepository {
  DriftCustomerRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> save(Customer customer) async {
    await _db
        .into(_db.customers)
        .insertOnConflictUpdate(customerToCompanion(customer));
  }

  @override
  Future<void> saveAll(Iterable<Customer> customers) async {
    final companions = customers.map(customerToCompanion).toList();
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.customers, companions);
    });
  }

  @override
  Future<Customer?> byId(String id) async {
    final row = await (_db.select(_db.customers)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : customerFromRow(row);
  }

  @override
  Future<List<Customer>> all() async {
    final rows = await (_db.select(_db.customers)
          ..orderBy([
            (t) => OrderingTerm(expression: t.name),
            (t) => OrderingTerm(expression: t.id),
          ]))
        .get();
    return rows.map(customerFromRow).toList();
  }
}
