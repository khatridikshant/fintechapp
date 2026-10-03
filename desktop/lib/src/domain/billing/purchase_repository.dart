import 'issued_purchase.dart';

/// Port for storing and retrieving issued purchases.
///
/// Owned by the domain; the implementation lives in `infrastructure/`. The exact
/// mirror of `InvoiceRepository`, because a purchase is the same kind of thing: a
/// stored legal document rather than only a journal entry.
///
/// Without this, `2010 Accounts Payable` is a balance credited by hand with no
/// record of what was bought or from whom, and neither input VAT nor a payable
/// ageing can be derived. ADR 012 is what this port exists for.
abstract interface class PurchaseRepository {
  /// Stores an issued purchase and all of its lines.
  ///
  /// Call inside a unit of work. Either the bill and every line are written, or
  /// nothing is.
  ///
  /// Storing a purchase twice under the same id is refused rather than
  /// overwritten. A posted bill is a legal document and the evidence of an input
  /// VAT claim; replacing it silently would destroy the original.
  Future<void> save(IssuedPurchase issued);

  Future<IssuedPurchase?> byId(String id);

  /// Every issued purchase, ordered by issue date then number.
  Future<List<IssuedPurchase>> all();

  /// The purchases billed by one supplier, in issue order.
  Future<List<IssuedPurchase>> forSupplier(String supplierId);
}