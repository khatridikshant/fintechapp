/// The Harmonised System tariff code for a good.
///
/// The 46th amendment to the VAT Rules added the **HS code** to the tax invoice
/// for goods, taken as declared with customs. It is a goods concept: a service
/// invoice has none, so this is nullable on a line rather than required.
///
/// ## Why validate the digits rather than store a string
///
/// The code is used on returns and matched against customs declarations, so a
/// typo is not cosmetic. It is stored as digits with any formatting removed, and
/// validated, so a bill cannot carry `123-45` that a filing would reject. The
/// first four digits are the heading; the full code is up to eight.
class HsCode {
  const HsCode._(this.digits);

  /// Parses an HS code, returning null when absent or malformed.
  ///
  /// Null rather than throwing, because an optional field on a service line has
  /// no code at all, and that is not an error.
  static HsCode? tryParse(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'[\s.\-]'), '');
    if (digits.isEmpty) return null;
    if (!RegExp(r'^\d+$').hasMatch(digits)) return null;
    if (digits.length < headingDigits || digits.length > maxDigits) return null;
    return HsCode._(digits);
  }

  /// The heading: the first four digits, which is what the amendment requires on
  /// the invoice.
  static const int headingDigits = 4;

  /// The longest code in common use.
  static const int maxDigits = 8;

  final String digits;

  /// The four-digit heading as printed on the invoice.
  String get heading => digits.substring(0, headingDigits);

  @override
  String toString() => digits;

  @override
  bool operator ==(Object other) => other is HsCode && other.digits == digits;

  @override
  int get hashCode => digits.hashCode;
}
