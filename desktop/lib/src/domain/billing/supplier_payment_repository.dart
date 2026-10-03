import 'supplier_payment.dart';

/// Port for storing and retrieving payments made to suppliers.
///
/// Owned by the domain; implemented in `infrastructure/`. The mirror of
/// `PaymentRepository`.
abstract interface class SupplierPaymentRepository {
  /// Stores a payment. Call inside a unit of work.
  ///
  /// Storing the same payment id twice is refused rather than overwritten, so a
  /// retried operation cannot count one payment twice against a payable.
  Future<void> save(SupplierPayment payment);

  /// The payments recorded against one purchase, in date order.
  Future<List<SupplierPayment>> forPurchase(String purchaseId);

  /// Every payment, in date order.
  Future<List<SupplierPayment>> all();
}