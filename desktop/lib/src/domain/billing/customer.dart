import 'nepali_pan.dart';

/// A customer the business invoices.
///
/// ## Two identifiers, because they answer different questions
///
/// | | |
/// | --- | --- |
/// | [id] | The **internal identity**. Random, permanent, never changes. |
/// | [code] | The **business reference** — `C-0001` — printed on invoices and quoted on the phone. |
///
/// Keeping them apart is what makes each safe. Invoice records and journal
/// entries reference the customer by [id], so an [id] that changed would repoint
/// historical sales at a different person; it is therefore never derived from
/// anything a person can type, and never reused. The [code] is the part people
/// see, and because it is **not** identity it may be re-sequenced or corrected
/// without touching a single historical sale.
///
/// A single sequential identifier would have been simpler and wrong: it ties the
/// internal identity to business numbering, so the two can never be separated
/// afterwards. See ADR 010.
///
/// ## Why the id is random rather than sequential
///
/// Ids must not collide **if two installations ever sync** — an open question in
/// `PROGRESS.md` 7.16. A random id cannot collide, so this closes that problem
/// now at no cost, whereas fixing it after data exists means a migration.
///
/// ## Names are attributes, not identity
///
/// Two customers called "Ram Bahadur" are ordinary in Nepal, and a name is
/// misspelled, transliterated differently, or changed on marriage. None of those
/// may repoint history. Duplicate *detection* is a separate concern, handled by
/// the PAN uniqueness constraint in the database — never by making the name a key.
class Customer {
  const Customer._({
    required this.id,
    required this.code,
    required this.name,
    required this.pan,
    required this.isVatRegistered,
    required this.phone,
    required this.address,
    required this.businessName,
  });

  /// Builds a customer.
  ///
  /// [panNumber] is validated rather than stored as typed. A PAN that is present
  /// but malformed is **worse** than an absent one: it appears on a printed bill,
  /// where it looks compliant and is not, and a purchase bill carrying an invalid
  /// vendor PAN can have its input credit disallowed at an audit.
  factory Customer({
    required String id,
    String? code,
    required String name,
    String? panNumber,
    bool isVatRegistered = false,
    String? phone,
    String? address,
    String? businessName,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('A customer needs an id.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError(
        'A customer needs a name. An unnamed customer cannot be identified on '
        'an invoice or a statement of account.',
      );
    }

    final pan = NepaliPan.tryParse(panNumber);
    if (panNumber != null && panNumber.trim().isNotEmpty && pan == null) {
      throw ArgumentError(
        '"$panNumber" is not a valid PAN. A PAN is ${NepaliPan.digitCount} '
        'digits; spaces and hyphens are allowed, other characters are not.',
      );
    }

    // In Nepal the VAT number *is* the PAN with a registration flag set, so a
    // VAT-registered party with no PAN is a contradiction rather than a gap.
    if (isVatRegistered && pan == null) {
      throw ArgumentError(
        'A VAT-registered customer must have a PAN: the VAT number is the PAN '
        'with the registration flag set, so there is nothing to register '
        'against.',
      );
    }

    return Customer._(
      id: id.trim(),
      code: _blankToNull(code),
      name: name.trim(),
      pan: pan,
      isVatRegistered: isVatRegistered,
      phone: _blankToNull(phone),
      address: _blankToNull(address),
      businessName: _blankToNull(businessName),
    );
  }

  /// The permanent internal identity. Random, and never changed.
  final String id;

  /// The business reference, such as `C-0001`. Null only for a customer created
  /// before codes existed.
  final String? code;

  /// The contact name.
  final String name;

  /// The tax identity. **Null is normal**: many customers are individuals with
  /// no business PAN.
  final NepaliPan? pan;

  /// Whether VAT registration is active for this customer.
  ///
  /// Stated rather than inferred: whether registration is *compulsory* depends on
  /// a threshold the sources report inconsistently (see `PROGRESS.md` 5.1), and
  /// guessing would produce confidently wrong compliance advice.
  final bool isVatRegistered;

  final String? phone;
  final String? address;

  /// The registered business name, where it differs from the contact name.
  final String? businessName;

  bool get hasPan => pan != null;

  /// The PAN as plain digits, which is the form stored in the database.
  ///
  /// It can only ever return a valid nine-digit string or null, because the only
  /// way to obtain a customer with a PAN is through the validating constructor.
  String? get panNumber => pan?.digits;

  /// Retained from before [pan] became a value type.
  @Deprecated('Use hasPan.')
  // ignore: deprecated_member_use_from_same_package
  bool get hasPanNumber => hasPan;

  /// The name to print on a bill: the registered business name if there is one.
  String get nameForBill => businessName ?? name;

  /// What a person would quote on the phone: the code if there is one, otherwise
  /// the name. Never the id, which is meaningless to anyone outside this system.
  String get displayReference => code ?? name;

  /// A blank optional field is stored as `null`, never as an empty string, so
  /// that "not provided" has exactly one representation. Storing both `null` and
  /// `''` would make every later query test two cases and eventually miss one.
  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Two customers are the same customer when they have the same identity.
  /// Name, phone, address, and code are attributes, not identity.
  @override
  bool operator ==(Object other) => other is Customer && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Customer($id, ${code ?? '-'}, $name${pan == null ? '' : ', $pan'})';
}
