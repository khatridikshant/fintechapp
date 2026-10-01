import 'customer_code.dart';

/// Port for allocating customer business references.
///
/// **A separate sequence from [DocumentNumberSequence], on purpose.** Document
/// numbers restart each fiscal year; a customer code must be unique for the life of
/// the business. Sharing one counter would either make codes repeat across years
/// or make invoice numbers run continuously, and both are wrong.
///
/// **Allocation must happen inside a unit of work**, so a customer that is refused
/// never consumes a code. A gap in the customer sequence is harmless; a code
/// handed to two customers is not.
abstract interface class CustomerCodeSequence {
  /// Consumes and returns the next code.
  ///
  /// Advances the stored sequence. Call it at the moment the customer is created,
  /// never while the form is still being filled in.
  Future<CustomerCode> allocateNext();

  /// Returns what the next code *would* be, without consuming it.
  ///
  /// Use this to show the user the reference a new customer will get. Calling it
  /// any number of times must not advance the sequence.
  Future<CustomerCode> peekNext();

  /// The highest code already handed out, or `0` if none has been.
  Future<int> lastAllocated();
}
