/// A Permanent Account Number as issued by Nepal's Inland Revenue Department.
///
/// ## Why this is a type and not a `String`
///
/// A PAN is the tax identity of a business or a person, and an invoice is only a
/// valid tax bill when **both** parties' PANs are on it. A purchase bill missing
/// the vendor's PAN may be disallowed as input credit in an audit — a real cash
/// cost, not a formality.
///
/// So a PAN cannot be a string that is sometimes right. Two things follow:
///
/// - It cannot be stored invalid. A number that is present but malformed is
///   worse than one that is absent, because it looks compliant and is not.
/// - An absent PAN is a **legitimate, supported state**: many customers are
///   individuals with no business PAN. So absence is modelled as `null`, never as
///   an empty string, giving "not provided" exactly one representation.
///
/// ## The format
///
/// PANs are commonly written in groups of three, for example `301-234-567` or
/// `301234567`. Both are accepted, and digits are the only thing accepted, so a
/// PAN copied out of a PDF cannot smuggle in stray punctuation.
class NepaliPan {
  const NepaliPan._(this.digits);

  /// Parses a PAN, returning null when it is absent or not a valid number.
  ///
  /// Returns null rather than throwing, because "this customer has no PAN" is an
  /// ordinary fact about a customer, not an error in the caller.
  static NepaliPan? tryParse(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'[\s-]'), '');
    if (digits.isEmpty) return null;
    if (!RegExp(r'^\d+$').hasMatch(digits)) return null;
    // Nine digits. Rejecting a wrong length here is what stops a mistyped PAN
    // from reaching an invoice and looking valid.
    if (digits.length != digitCount) return null;
    return NepaliPan._(digits);
  }

  /// The number of digits in a PAN.
  static const int digitCount = 9;

  /// The digits, without separators.
  final String digits;

  /// The grouped form used on printed invoices, for example `301-234-567`.
  ///
  /// Grouping is a presentation choice, so it is produced on demand rather than
  /// stored — two representations of one PAN would drift.
  String get grouped {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write('-');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  String toString() => digits;

  @override
  bool operator ==(Object other) =>
      other is NepaliPan && other.digits == digits;

  @override
  int get hashCode => digits.hashCode;
}
