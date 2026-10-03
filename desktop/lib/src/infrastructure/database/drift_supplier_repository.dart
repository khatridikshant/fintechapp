// Imported whole rather than with `show`: `leftOuterJoin` is a drift helper and a
// restricted import would hide it.
import 'package:drift/drift.dart';

import '../../domain/billing/supplier.dart';
import '../../domain/billing/supplier_repository.dart';
import 'app_database.dart';

/// Stores suppliers and their tax details.
///
/// The two live in **separate tables** — `suppliers` for identity and
/// `supplier_details` for the code, VAT registration, and registered business
/// name — for exactly the reason ADR 010 records for customers, and ADR 012
/// adopts unchanged: adding columns to an existing table changes the shape that
/// `createTable` produces for every database older than that table's version.
///
/// **A left outer join, not an inner one.** A supplier has no detail row when it
/// was saved with no code, and an inner join would silently drop them from the
/// supplier list — which means a supplier who cannot be picked and a purchase that
/// cannot be recorded against anybody.
class DriftSupplierRepository implements SupplierRepository {
  DriftSupplierRepository(this.db);

  final AppDatabase db;

  @override
  Future<void> save(Supplier supplier) async {
    // Both tables in one transaction, because a supplier row without its details is
    // exactly the half-stored state this split exists to avoid.
    await db.transaction(() async {
      // An upsert, matching `DriftCustomerRepository`. **Correct here even though
      // purchase bills are immutable**: this is the *supplier's own record*, which
      // a business legitimately corrects — a mistyped phone number, or adding the
      // PAN that was missing when the supplier was first entered. It is not a
      // financial document, and the domain forbids changing a supplier's `id`, which
      // is the field purchases reference.
      await db
          .into(db.suppliers)
          .insertOnConflictUpdate(_suppliersCompanion(supplier));
      await db
          .into(db.supplierDetails)
          .insertOnConflictUpdate(_detailsCompanion(supplier));
    });
  }

  @override
  Future<Supplier?> byId(String id) async {
    final query = db.select(db.suppliers).join([
      // Nullable on the right: a supplier may have no detail row.
      leftOuterJoin(
        db.supplierDetails,
        db.supplierDetails.supplierId.equalsExp(db.suppliers.id),
      ),
    ])
      ..where(db.suppliers.id.equals(id));

    final rows = await query.get();
    return rows.isEmpty ? null : _supplierOf(rows.first);
  }

  @override
  Future<List<Supplier>> all() => allOrdered();

  @override
  Future<List<Supplier>> allOrdered() async {
    final query = db.select(db.suppliers).join([
      leftOuterJoin(
        db.supplierDetails,
        db.supplierDetails.supplierId.equalsExp(db.suppliers.id),
      ),
    ])
      ..orderBy([
        // A supplier with **no code sorts last**, not first.
        //
        // SQLite orders NULLs first by default, which would put the
        // least-identified suppliers at the top of a picker — the ones nobody has
        // a business reference for. Ordering on the null-ness first (false = 0
        // before true = 1) pushes them to the bottom while keeping the code order
        // itself ascending, so `S-0001` still precedes `S-0002`.
        OrderingTerm(expression: db.supplierDetails.code.isNull()),
        OrderingTerm(expression: db.supplierDetails.code),
        OrderingTerm(expression: db.suppliers.name),
        OrderingTerm(expression: db.suppliers.id),
      ]);

    final rows = await query.get();
    return rows.map(_supplierOf).toList();
  }

  @override
  Future<List<Supplier>> withPan(String pan) async {
    // **The duplicate-detection query, and it is a PAN match on purpose**
    // (`ADR 010`, `ADR 012`): two businesses cannot share a PAN, so this cannot
    // report a false collision, whereas a name match often can.
    final rows = await (db.select(db.suppliers)
          ..where((t) => t.panNumber.equals(pan)))
        .get();

    if (rows.isEmpty) return const [];
    return allOrdered()
        .then((all) {
      final ids = rows.map((r) => r.id).toSet();
      return all.where((s) => ids.contains(s.id)).toList();
    });
  }

  /// Builds the domain supplier from a joined row.
  Supplier _supplierOf(TypedResult row) {
    final supplier = row.readTable(db.suppliers);
    final details = row.readTableOrNull(db.supplierDetails);

    return Supplier(
      id: supplier.id,
      name: supplier.name,
      // Round-tripped through the digits, because the column is text while the
      // domain field is a parsed PAN.
      pan: supplier.panNumber,
      phone: supplier.phone,
      address: supplier.address,
      code: details?.code,
      // No detail row means the supplier predates the split, so their VAT status
      // is genuinely unknown. `false` is the safe reading: the bill then asks for a
      // PAN rather than assuming none is needed.
      isVatRegistered: details?.isVatRegistered ?? false,
      businessName: details?.businessName,
    );
  }

  SuppliersCompanion _suppliersCompanion(Supplier supplier) =>
      SuppliersCompanion.insert(
        id: supplier.id,
        name: supplier.name,
        // Absent means `null`, never an empty string: two spellings of "no PAN"
        // would make the duplicate-detection query test both cases and miss one.
        panNumber: Value(supplier.pan?.toString()),
        phone: Value(supplier.phone),
        address: Value(supplier.address),
      );

  SupplierDetailsCompanion _detailsCompanion(Supplier supplier) =>
      SupplierDetailsCompanion.insert(
        supplierId: supplier.id,
        code: Value(supplier.code),
        isVatRegistered: Value(supplier.isVatRegistered),
        businessName: Value(supplier.businessName),
      );
}