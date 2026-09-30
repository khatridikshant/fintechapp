import 'package:drift/drift.dart' show Value;

import '../../domain/accounting/account.dart';
import '../../domain/billing/customer.dart';
import 'app_database.dart';

/// Translates between the domain `Account` and its storage row.
///
/// Kept in one place so the mapping is not duplicated across repositories.
Account accountFromRow(AccountRow row) => Account(
      id: row.id,
      code: row.code,
      name: row.name,
      type: row.type,
    );

AccountsCompanion accountToCompanion(Account account) =>
    AccountsCompanion.insert(
      id: account.id,
      code: account.code,
      name: account.name,
      type: account.type,
    );

/// Translates between the domain `Customer` and its storage row.
///
/// A blank optional field is stored as `null`, so "not provided" has exactly one
/// representation in the database.
Customer customerFromRow(CustomerRow row) => Customer(
      id: row.id,
      name: row.name,
      panNumber: row.panNumber,
      phone: row.phone,
      address: row.address,
    );

CustomersCompanion customerToCompanion(Customer customer) =>
    CustomersCompanion.insert(
      id: customer.id,
      name: customer.name,
      panNumber: Value(customer.panNumber),
      phone: Value(customer.phone),
      address: Value(customer.address),
    );
