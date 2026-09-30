import 'issued_credit_note.dart';

/// Port for storing and retrieving credit notes.
///
/// This is an interface owned by the domain. The implementation lives in
/// `infrastructure/`.
abstract interface class CreditNoteRepository {
  /// Stores an issued credit note and all of its lines.
  ///
  /// Call this inside a unit of work. Either the credit note and every line are
  /// written, or nothing is.
  ///
  /// Storing a credit note twice under the same id is refused rather than
  /// overwritten. It is a financial record, and it is the only legal way a
  /// posted invoice can be corrected.
  Future<void> save(IssuedCreditNote issued);

  Future<IssuedCreditNote?> byId(String id);

  /// Every credit note issued against one invoice, in date order.
  ///
  /// Used to work out how much of the invoice is still uncredited, which is what
  /// bounds the next credit note.
  Future<List<IssuedCreditNote>> forInvoice(String invoiceId);

  /// Every credit note, in date order.
  Future<List<IssuedCreditNote>> all();
}
