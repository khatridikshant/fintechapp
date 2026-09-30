import 'account_type.dart';

/// A single line in the chart of accounts.
///
/// An account does not store a balance. The balance is derived from posted
/// journal lines by [Ledger]. Storing a balance as an independently editable
/// field would create a second source of truth that can silently disagree with
/// the journal, which the architecture prohibits.
class Account {
  const Account({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
  });

  /// Stable identity. This is what journal lines and the database reference.
  final String id;

  /// Human-facing chart-of-accounts code, for example `1010` for Bank.
  final String code;

  final String name;

  final AccountType type;

  /// The side that increases this account.
  NormalBalance get normalBalance => type.normalBalance;

  /// Two accounts are the same account when they have the same identity.
  ///
  /// Name and code are attributes of an account, not part of its identity, so
  /// renaming an account must not break existing journal references.
  @override
  bool operator ==(Object other) => other is Account && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Account($code $name)';
}
