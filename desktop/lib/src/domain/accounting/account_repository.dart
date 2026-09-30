import 'account.dart';

/// Port for storing and retrieving accounts.
///
/// This is an interface owned by the domain. The implementation lives in
/// `infrastructure/`. The domain must not know that SQLite, drift, or a
/// database at all exists, so it depends on this contract only.
abstract interface class AccountRepository {
  /// Inserts or replaces [account].
  Future<void> save(Account account);

  /// Inserts or replaces many accounts in one atomic operation.
  Future<void> saveAll(Iterable<Account> accounts);

  Future<Account?> byId(String id);

  Future<Account?> byCode(String code);

  Future<List<Account>> all();
}
