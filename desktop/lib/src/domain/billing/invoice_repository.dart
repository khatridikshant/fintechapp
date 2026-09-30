import 'issued_invoice.dart';

/// Port for storing and retrieving issued invoices.
///
/// This is an interface owned by the domain. The implementation lives in
/// `infrastructure/`.
///
/// An issued invoice is a record, not just a journal entry. Storing it is what
/// makes an invoice listable, reprintable, and eventually markable as paid.
abstract interface class InvoiceRepository {
  /// Stores an issued invoice and all of its lines.
  ///
  /// Call this inside a unit of work. Either the invoice and every line are
  /// written, or nothing is: an invoice without its lines cannot be reprinted,
  /// and a line without its invoice is unreachable.
  ///
  /// Storing an invoice twice under the same id is refused rather than
  /// overwritten. An issued invoice is a legal document; replacing it silently
  /// would destroy the original.
  Future<void> save(IssuedInvoice issued);

  Future<IssuedInvoice?> byId(String id);

  /// Every issued invoice, ordered by issue date then number.
  Future<List<IssuedInvoice>> all();

  /// The invoices issued to one customer, in issue order.
  Future<List<IssuedInvoice>> forCustomer(String customerId);
}
