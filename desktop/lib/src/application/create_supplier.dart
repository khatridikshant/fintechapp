import 'dart:math';

import '../domain/billing/supplier.dart';
import '../domain/billing/supplier_repository.dart';
import '../domain/shared/unit_of_work.dart';

/// The outcome of attempting to create a supplier.
sealed class CreateSupplierOutcome {
  const CreateSupplierOutcome();
}

final class SupplierCreated extends CreateSupplierOutcome {
  const SupplierCreated(this.supplier);

  final Supplier supplier;
}

/// The supplier could not be created, and **nothing was written**.
final class SupplierRejected implements Exception {
  SupplierRejected(this.reason);

  /// The domain's own wording, so the screen does not invent a second one.
  final String reason;

  @override
  String toString() => 'SupplierRejected: $reason';
}

/// Creates a supplier: gives it an id and a business reference, and saves it.
///
/// ## The mirror of `CreateCustomer`
///
/// Same structure and same reasoning, because ADR 012 adopts ADR 010's identity
/// decision for suppliers unchanged. A supplier is referenced by purchases, so the
/// id is random and permanent; the reference is `S-0001`; the name is not a key.
///
/// ## One difference from a customer: the PAN is checked for duplicates
///
/// A duplicate PAN on a **customer** is an inconvenience. A duplicate PAN on a
/// **supplier** is worse: it means two businesses share a tax identity, and every
/// purchase input VAT claim made against it could be questioned. It is refused
/// rather than warned about.
class CreateSupplier {
  CreateSupplier({
    required this.suppliers,
    required this.unitOfWork,
    Random? random,
  }) : _random = random ?? Random();

  final SupplierRepository suppliers;
  final UnitOfWork unitOfWork;

  final Random _random;

  Future<SupplierCreated> call({
    required String name,
    String? pan,
    bool isVatRegistered = false,
    String? phone,
    String? address,
    String? businessName,
    String? code,
  }) async {
    // Validated before a transaction is opened, so a rejected supplier leaves no
    // trace at all. The domain constructor is the authority on every rule here.
    final Supplier draft;
    try {
      draft = Supplier(
        id: _newId(),
        name: name,
        pan: pan,
        isVatRegistered: isVatRegistered,
        phone: phone,
        address: address,
        businessName: businessName,
        code: code,
      );
    } on ArgumentError catch (error) {
      throw SupplierRejected(error.message);
    }

    return unitOfWork.run<SupplierCreated>(() async {
      // Checked inside the transaction, so the duplicate check and the write cannot
      // be separated by another insert arriving in between.
      final existing = await suppliers.withPan(draft.pan!.toString());
      if (existing.isNotEmpty) {
        throw SupplierRejected(
          'A supplier with PAN ${draft.pan} already exists '
          '(${existing.first.name}). Two businesses cannot share a PAN, and '
          'input VAT claimed against a shared tax identity can be disallowed.',
        );
      }

      await suppliers.save(draft);
      return SupplierCreated(draft);
    });
  }

  /// A random, collision-resistant identifier.
  ///
  /// **Random, not sequential.** Purchases reference a supplier by this, so an id
  /// that changed would repoint historical payables at a different business. It is
  /// also random so ids cannot collide if two installations ever sync.
  String _newId() {
    final buffer = StringBuffer('sup-');
    for (var i = 0; i < 16; i++) {
      buffer.write(_random.nextInt(16).toRadixString(16));
    }
    return buffer.toString();
  }
}