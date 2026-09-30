import '../../domain/shared/unit_of_work.dart';
import 'app_database.dart';

/// A [UnitOfWork] backed by a drift transaction.
///
/// drift's `transaction` already provides the nesting semantics the port
/// requires: an inner transaction joins the outer one instead of committing on
/// its own. That matters because individual repositories open their own
/// transactions for self-contained operations, and those must *compose* rather
/// than break the outer boundary.
///
/// All repositories sharing this `AppDatabase` instance therefore participate in
/// the same transaction, which is what makes a multi-repository business
/// operation atomic.
class DriftUnitOfWork implements UnitOfWork {
  DriftUnitOfWork(this._db);

  final AppDatabase _db;

  @override
  Future<T> run<T>(Future<T> Function() work) => _db.transaction(work);
}
