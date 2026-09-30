/// Runs a group of operations as one atomic unit.
///
/// This is the boundary that makes a *business operation* atomic, rather than
/// each individual write being atomic on its own.
///
/// The architecture requires that issuing an invoice either creates the invoice,
/// its lines, the receivable, the revenue journal, the inventory movement, and
/// the COGS journal, **or creates none of them**. Any partial application -- an
/// invoice with no journal, a stock movement with no accounting entry -- is a
/// corruption of the books that cannot be repaired by hand.
///
/// Per-repository transactions are not sufficient for that. Several repositories
/// must be able to participate in one transaction, which is what this port
/// provides. A use case wraps its work in [run] and receives a guarantee that
/// the work either completes in full or leaves no trace.
///
/// This is an interface owned by the domain. The implementation lives in
/// `infrastructure/`, so the application layer can express the boundary without
/// importing a database driver.
abstract interface class UnitOfWork {
  /// Runs [work] inside a single database transaction.
  ///
  /// If [work] completes, its writes are committed. If it throws, every write it
  /// performed, in any repository, is rolled back and the error is rethrown to
  /// the caller.
  ///
  /// Implementations may be nested. Nested calls join the outer transaction
  /// rather than committing independently, so a use case may safely call
  /// another use case that also uses a unit of work, and a failure anywhere
  /// still rolls back the whole operation.
  Future<T> run<T>(Future<T> Function() work);
}
