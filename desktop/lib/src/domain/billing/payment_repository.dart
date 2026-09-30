import 'payment.dart';

/// Port for storing and retrieving payments received.
///
/// This is an interface owned by the domain. The implementation lives in
/// `infrastructure/`.
abstract interface class PaymentRepository {
  /// Records a payment.
  ///
  /// Call this inside a unit of work. This is a plain insert, not an upsert: a
  /// recorded payment is a financial record, and silently replacing one would
  /// change what a customer is owed.
  Future<void> save(Payment payment);

  Future<Payment?> byId(String id);

  /// Every payment recorded against one invoice, in date order.
  ///
  /// Used to derive the outstanding balance and to check an overpayment.
  Future<List<Payment>> forInvoice(String invoiceId);

  /// Every payment, in date order.
  Future<List<Payment>> all();
}
