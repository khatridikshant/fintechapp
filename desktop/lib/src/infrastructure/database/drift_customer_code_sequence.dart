import 'package:drift/drift.dart' show Value;

import '../../domain/billing/customer_code.dart';
import '../../domain/billing/customer_code_sequence.dart';
import 'app_database.dart';

/// Allocates customer business references from a lifetime counter.
///
/// The row is created on first use, so a fresh installation needs no seeding and a
/// database migrated from an earlier version starts at `C-0001`.
class DriftCustomerCodeSequence implements CustomerCodeSequence {
  DriftCustomerCodeSequence(this.db);

  final AppDatabase db;

  /// The one counter, by design.
  static const String singletonKey = 'singleton';

  @override
  Future<CustomerCode> allocateNext() async {
    // Read-then-write rather than a SQL increment, so the value returned is
    // exactly the value stored. The whole call is expected to run inside a unit
    // of work, so a caller that fails afterwards does not consume the code.
    final current = await lastAllocated();
    final next = current + 1;
    await _write(next);
    return CustomerCode(next);
  }

  @override
  Future<CustomerCode> peekNext() async =>
      CustomerCode((await lastAllocated()) + 1);

  @override
  Future<int> lastAllocated() async {
    final row = await (db.select(db.customerCodeSequences)
          ..where((t) => t.id.equals(singletonKey)))
        .getSingleOrNull();
    return row?.lastAllocated ?? 0;
  }

  Future<void> _write(int sequence) async {
    await db.into(db.customerCodeSequences).insertOnConflictUpdate(
          CustomerCodeSequencesCompanion.insert(
            id: singletonKey,
            lastAllocated: Value(sequence),
          ),
        );
  }
}
