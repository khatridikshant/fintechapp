// Imported whole rather than with `show`: `leftOuterJoin` is a drift helper and a
// restricted import would hide it.
import 'package:drift/drift.dart';

import '../../domain/billing/customer.dart';
import '../../domain/billing/customer_repository.dart';
import 'app_database.dart';

/// Stores customers and their tax details.
///
/// The two live in **separate tables** — `customers` for identity, and
/// `customer_details` for the code, VAT registration, and registered business
/// name. That split is deliberate and is explained in ADR 010: adding columns to
/// `customers` would have changed the shape that `createTable` produces for every
/// pre-v3 database, and broke 21 migration tests.
///
/// **A left outer join, not an inner one.** A customer recorded before v10, or one
/// saved with no code at all, has no detail row. An inner join would silently drop
/// them from the customer list — which for an accounting application means a
/// customer who cannot be found and an invoice that cannot be billed.
class DriftCustomerRepository implements CustomerRepository {
  DriftCustomerRepository(this.db);

  final AppDatabase db;

  @override
  Future<void> save(Customer customer) async {
    // Both tables in one transaction, because a customer row without its details
    // would be exactly the half-stored state this design exists to avoid.
    await db.transaction(() async {
      await db
          .into(db.customers)
          .insertOnConflictUpdate(_customersCompanion(customer));
      await db
          .into(db.customerDetails)
          .insertOnConflictUpdate(_detailsCompanion(customer));
    });
  }

  @override
  Future<void> saveAll(Iterable<Customer> customers) async {
    final all = customers.toList();
    if (all.isEmpty) return;

    await db.transaction(() async {
      await db.batch((batch) {
        batch.insertAllOnConflictUpdate(
          db.customers,
          all.map(_customersCompanion).toList(),
        );
      });
      await db.batch((batch) {
        batch.insertAllOnConflictUpdate(
          db.customerDetails,
          all.map(_detailsCompanion).toList(),
        );
      });
    });
  }

  @override
  Future<Customer?> byId(String id) async {
    final query = db.select(db.customers).join([
      // Nullable on the right: a customer may have no detail row.
      leftOuterJoin(
        db.customerDetails,
        db.customerDetails.customerId.equalsExp(db.customers.id),
      ),
    ])
      ..where(db.customers.id.equals(id));

    final rows = await query.get();
    return rows.isEmpty ? null : _customerOf(rows.first);
  }

  @override
  Future<List<Customer>> all() async {
    final query = db.select(db.customers).join([
      leftOuterJoin(
        db.customerDetails,
        db.customerDetails.customerId.equalsExp(db.customers.id),
      ),
    ])
      ..orderBy([
        OrderingTerm(expression: db.customers.name),
        OrderingTerm(expression: db.customers.id),
      ]);

    final rows = await query.get();
    return rows.map(_customerOf).toList();
  }

  /// Builds the domain customer from a joined row.
  Customer _customerOf(TypedResult row) {
    final customer = row.readTable(db.customers);
    final details = row.readTableOrNull(db.customerDetails);

    return Customer(
      id: customer.id,
      name: customer.name,
      panNumber: customer.panNumber,
      phone: customer.phone,
      address: customer.address,
      code: details?.code,
      // A customer with no detail row predates v10, so their VAT status is
      // genuinely unknown. `false` is the only safe assumption: it makes the
      // application ask for a PAN rather than assume none is needed.
      isVatRegistered: details?.isVatRegistered ?? false,
      businessName: details?.businessName,
    );
  }

  CustomersCompanion _customersCompanion(Customer customer) =>
      CustomersCompanion.insert(
        id: customer.id,
        name: customer.name,
        panNumber: Value(customer.panNumber),
        phone: Value(customer.phone),
        address: Value(customer.address),
      );

  CustomerDetailsCompanion _detailsCompanion(Customer customer) =>
      CustomerDetailsCompanion.insert(
        customerId: customer.id,
        code: Value(customer.code),
        isVatRegistered: Value(customer.isVatRegistered),
        businessName: Value(customer.businessName),
      );
}
