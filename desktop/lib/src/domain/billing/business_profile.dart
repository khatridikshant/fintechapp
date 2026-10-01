import 'nepali_pan.dart';

/// This business: the seller named on every invoice it issues.
///
/// Rule 17 requires the supplier's name, address, and **PAN** on the tax invoice,
/// and a bill without the supplier's PAN is not a valid tax bill. So the profile
/// is not optional decoration — it is the first thing checked before an invoice
/// can be called compliant.
///
/// ## Nothing here is inferred
///
/// **Whether the business must register for VAT is not calculated.** The
/// registration thresholds are reported inconsistently across the sources (see
/// `PROGRESS.md` section 5.1), and the VAT number in Nepal *is* the PAN with the
/// registration flag set, so there is no separate number to hold. [isVatRegistered]
/// is therefore something the owner states, not something the application decides
/// from a turnover it does not reliably know.
///
/// A wrong answer changes what the invoice is, so it is asked once and recorded,
/// rather than guessed at every invoice.
class BusinessProfile {
  const BusinessProfile._({
    required this.name,
    required this.pan,
    required this.isVatRegistered,
    required this.address,
    required this.phone,
    required this.email,
    required this.bankDetails,
  });

  factory BusinessProfile({
    required String name,
    String? panNumber,
    bool isVatRegistered = false,
    String? address,
    String? phone,
    String? email,
    String? bankDetails,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError(
        'A business needs a name. It is printed on every invoice, and a bill '
        'naming nobody is not a valid tax bill.',
      );
    }

    // A PAN that was typed but is not a valid number is **rejected**, not
    // dropped. Keeping it would let an invalid PAN reach a printed bill, where it
    // looks compliant and is not — and this PAN appears on every single invoice.
    final pan = NepaliPan.tryParse(panNumber);
    if (panNumber != null && panNumber.trim().isNotEmpty && pan == null) {
      throw ArgumentError(
        '"$panNumber" is not a valid PAN. A PAN is ${NepaliPan.digitCount} '
        'digits; spaces and hyphens are allowed, other characters are not.',
      );
    }

    if (isVatRegistered && pan == null) {
      throw ArgumentError(
        'This business is marked VAT-registered but has no PAN. In Nepal the VAT '
        'number is the PAN with the registration flag set, so a '
        'VAT-registered business cannot exist without one.',
      );
    }

    return BusinessProfile._(
      name: name.trim(),
      pan: pan,
      isVatRegistered: isVatRegistered,
      address: _blankToNull(address),
      phone: _blankToNull(phone),
      email: _blankToNull(email),
      bankDetails: _blankToNull(bankDetails),
    );
  }

  /// The registered name, printed as the supplier on every invoice.
  final String name;

  /// The tax identity. **Required for a valid tax invoice.**
  final NepaliPan? pan;

  /// Stated by the owner; see the class documentation for why it is not derived.
  final bool isVatRegistered;

  /// The registered address, printed on every invoice.
  final String? address;

  final String? phone;
  final String? email;
  final String? bankDetails;

  bool get hasPan => pan != null;

  /// The PAN as plain digits, which is the form stored in the database.
  ///
  /// It can only ever return a valid nine-digit string or null, because the only
  /// way to obtain a profile with a PAN is through the validating constructor.
  String? get panNumber => pan?.digits;

  /// Whether the profile can produce a valid tax invoice at all.
  bool get canIssueValidTaxInvoice => hasPan;

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  @override
  String toString() =>
      'BusinessProfile($name${pan == null ? ', no PAN' : ', $pan'})';
}
