/// A customer's business reference, such as `C-0001`.
///
/// ## Why this is not a [DocumentNumber]
///
/// Invoice and credit-note numbers restart every fiscal year, which is correct for
/// documents. **A customer code must not**, because it names a party rather than a
/// transaction: if `C-0001` were issued again next year, two different customers
/// would share a reference and every old invoice would become ambiguous. So it has
/// its own lifetime counter (ADR 010).
///
/// The number is zero-padded so references sort the way they are read, and read
/// the same way aloud over the phone.
class CustomerCode {
  const CustomerCode(this.sequence)
      : assert(sequence >= 0, 'A customer sequence cannot be negative');

  /// The position in the lifetime sequence. 1 is the first customer.
  final int sequence;

  /// The reference as printed, for example `C-0042`.
  String get value => 'C-${sequence.toString().padLeft(4, '0')}';

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      other is CustomerCode && other.sequence == sequence;

  @override
  int get hashCode => sequence.hashCode;
}
