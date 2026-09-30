import 'package:drift/drift.dart' show OrderingTerm;

import '../../domain/accounting/account.dart';
import '../../domain/accounting/account_repository.dart';
import 'app_database.dart';
import 'mappers.dart';

class DriftAccountRepository implements AccountRepository {
  DriftAccountRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> save(Account account) async {
    await _db
        .into(_db.accounts)
        .insertOnConflictUpdate(accountToCompanion(account));
  }

  @override
  Future<void> saveAll(Iterable<Account> accounts) async {
    final companions = accounts.map(accountToCompanion).toList();
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.accounts, companions);
    });
  }

  @override
  Future<Account?> byId(String id) async {
    final row = await (_db.select(_db.accounts)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : accountFromRow(row);
  }

  @override
  Future<Account?> byCode(String code) async {
    final row = await (_db.select(_db.accounts)
          ..where((t) => t.code.equals(code)))
        .getSingleOrNull();
    return row == null ? null : accountFromRow(row);
  }

  @override
  Future<List<Account>> all() async {
    final rows = await (_db.select(_db.accounts)
          ..orderBy([(t) => OrderingTerm(expression: t.code)]))
        .get();
    return rows.map(accountFromRow).toList();
  }
}
