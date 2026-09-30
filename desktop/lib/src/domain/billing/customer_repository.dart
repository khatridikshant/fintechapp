import 'customer.dart';

/// Port for storing and retrieving customers.
///
/// This is an interface owned by the domain. The implementation lives in
/// `infrastructure/`.
abstract interface class CustomerRepository {
  /// Inserts or replaces [customer].
  Future<void> save(Customer customer);

  /// Inserts or replaces many customers in one atomic operation.
  Future<void> saveAll(Iterable<Customer> customers);

  /// Returns the customer with [id], or `null` if there is none.
  ///
  /// Returning `null` rather than throwing is deliberate: "this customer does
  /// not exist" is a normal answer that a use case turns into a refusal, not a
  /// malfunction.
  Future<Customer?> byId(String id);

  /// Every customer, ordered by name then id.
  Future<List<Customer>> all();
}
