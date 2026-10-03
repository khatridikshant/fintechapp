import 'supplier.dart';

/// Port for storing and retrieving suppliers.
///
/// Owned by the domain; implemented in `infrastructure/`. The mirror of
/// `CustomerRepository`.
///
/// **Separate from customers, not a flag on them.** A customer owes this business
/// money; a supplier is owed by it. A purchase bill is also *evidence of input
/// credit*, which a sales invoice never is — so sharing one table would put a
/// discriminator on every sales query just to keep the two apart. ADR 012.
abstract interface class SupplierRepository {
  /// Stores a new supplier.
  ///
  /// Refuses a duplicate id. A supplier id is the identity every purchase
  /// references, so replacing one silently would repoint historical payables at a
  /// different business.
  Future<void> save(Supplier supplier);

  Future<Supplier?> byId(String id);

  Future<List<Supplier>> all();

  /// Every supplier, in code order where a code exists, then by name.
  ///
  /// Ordered rather than unordered because a supplier picker with no order is
  /// unusable, and the ordering has to live in one place or two lists will differ.
  Future<List<Supplier>> allOrdered();

  /// Suppliers whose PAN matches, for duplicate detection.
  ///
  /// **Why PAN and not name** (`ADR 010`, `ADR 012`): two businesses cannot share
  /// a PAN, so a PAN match is a real duplicate, whereas a name match is often two
  /// different people with the same name.
  Future<List<Supplier>> withPan(String pan);
}