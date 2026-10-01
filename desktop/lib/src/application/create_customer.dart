import 'dart:math';

import '../domain/billing/customer.dart';
import '../domain/billing/customer_code_sequence.dart';
import '../domain/billing/customer_repository.dart';
import '../domain/shared/unit_of_work.dart';

/// The outcome of attempting to create a customer.
sealed class CreateCustomerOutcome {
  const CreateCustomerOutcome();
}

/// The customer was created, with the reference it was given.
final class CustomerCreated extends CreateCustomerOutcome {
  const CustomerCreated(this.customer);

  final Customer customer;
}

/// The customer could not be created, and **nothing was written**.
///
/// A distinct type rather than a generic failure, because the caller has to tell
/// the user *which* rule refused it and show the reason next to the field that
/// caused it.
final class CustomerRejected implements Exception {
  CustomerRejected(this.reason);

  /// The domain's own wording, so the screen does not invent a second one.
  final String reason;

  @override
  String toString() => 'CustomerRejected: $reason';
}

/// Creates a customer: gives it an id and a business reference, and saves it.
///
/// ## The whole thing runs inside one unit of work
///
/// The reference is allocated and the customer written together, so a customer
/// that cannot be created does not burn a code. A gap in the sequence would be
/// harmless; two customers sharing a reference would not be.
///
/// ## The id is random
///
/// Invoices reference a customer by id, so an id that changed would repoint
/// historical sales at a different person. It is therefore never derived from
/// anything a person types, and random so ids cannot collide if two installations
/// ever sync (ADR 010).
class CreateCustomer {
  CreateCustomer({
    required this.customers,
    required this.codes,
    required this.unitOfWork,
  }) : _random = Random();

  final CustomerRepository customers;
  final CustomerCodeSequence codes;
  final UnitOfWork unitOfWork;

  final Random _random;

  Future<CustomerCreated> call({
    required String name,
    String? panNumber,
    bool isVatRegistered = false,
    String? phone,
    String? address,
    String? businessName,
  }) async {
    // Validated before a transaction is opened, so a rejected customer leaves no
    // trace at all. The domain constructor is the authority on every rule here.
    final Customer draft;
    try {
      draft = Customer(
        id: _newId(),
        name: name,
        panNumber: panNumber,
        isVatRegistered: isVatRegistered,
        phone: phone,
        address: address,
        businessName: businessName,
      );
    } on ArgumentError catch (error) {
      throw CustomerRejected(error.message);
    }

    return unitOfWork.run<CustomerCreated>(() async {
      // Inside the transaction, so a failure below does not consume the code.
      final code = await codes.allocateNext();
      final created = Customer(
        id: draft.id,
        code: code.value,
        name: draft.name,
        panNumber: draft.panNumber,
        isVatRegistered: draft.isVatRegistered,
        phone: draft.phone,
        address: draft.address,
        businessName: draft.businessName,
      );
      await customers.save(created);
      return CustomerCreated(created);
    });
  }

  /// A random, collision-resistant identifier.
  ///
  /// A timestamp plus randomness: the timestamp alone would collide for two
  /// customers created in the same microsecond, and a bare counter would collide
  /// across installations.
  String _newId() {
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final noise =
        List<int>.generate(8, (_) => _random.nextInt(36)).map(_digit).join();
    return 'cus-$stamp-$noise';
  }

  static const String _alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';
  static String _digit(int value) => _alphabet[value % _alphabet.length];
}
