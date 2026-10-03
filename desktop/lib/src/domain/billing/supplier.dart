import 'nepali_pan.dart';

/// A supplier: the other side of a purchase.
///
/// ## This mirrors `Customer`, deliberately
///
/// `ADR 012` adopts `ADR 010`'s identity decision unchanged, and the reasoning is
/// the same on this side:
///
/// - **`id` is random and permanent.** Purchases reference a supplier by `id`, so
///   an `id` that changed would repoint historical payables at a different
///   business. Random ids also cannot collide if two installations ever sync.
/// - **`code` is the business reference** -- `S-0001` -- quoted on a purchase order
///   and printed on the bill. It is not identity, so it may be re-sequenced
///   without touching history.
/// - **`name` is not a key.** Nepali names repeat and are mutable. A unique index on
///   a name would reject legitimate suppliers or turn a spelling correction into a
///   lost record.
///
/// ## Why it is not a customer with a flag
///
/// The two sides mean different things. A customer owes this business money and
/// appears in receivables; a supplier is owed by this business money and appears in
/// payables. A purchase bill is also **evidence of input credit**, which a sales
/// invoice never is -- and `NEPALI_BILLING.md` records that a bill missing the
/// vendor's PAN may be disallowed as input credit in an audit. Sharing one table
/// would put a discriminator on every sales query to keep that apart.
class Supplier {
  const Supplier._({
    required this.id,
    required this.name,
    this.code,
    this.pan,
    this.isVatRegistered = false,
    this.phone,
    this.address,
    this.businessName,
  });

  factory Supplier({
    required String id,
    required String name,
    String? code,
    String? pan,
    bool isVatRegistered = false,
    String? phone,
    String? address,
    String? businessName,
  }) {
    return Supplier._(
      id: _requireText(id, 'A supplier needs an id.'),
      name: _requireText(name, 'A supplier needs a name.'),
      code: _blankToNull(code),
      pan: _panOf(pan),
      isVatRegistered: isVatRegistered,
      phone: _blankToNull(phone),
      address: _blankToNull(address),
      businessName: _blankToNull(businessName),
    );
  }

  /// Random, permanent, never reused. See the class docblock.
  final String id;

  /// The business reference, `S-0001`.
  final String? code;

  /// The name as it appears on the bill. **Not a key** -- see the class docblock.
  final String name;

  /// The supplier's PAN, where it has one.
  ///
  /// **Nullable because many suppliers are individuals who have none.** Its
  /// absence is a recorded fact with a consequence, not an error: `NEPALI_BILLING.md`
  /// records that a purchase bill lacking the vendor's PAN may be disallowed as
  /// input credit, so a caller must be able to see that this supplier cannot
  /// support a credit claim.
  final NepaliPan? pan;

  /// Whether this supplier is VAT-registered.
  ///
  /// **Entered, never inferred.** `NEPALI_BILLING.md` records that the
  /// registration thresholds are disputed between sources, and that the application
  /// deliberately implements no threshold. Inferring one here would produce
  /// confidently wrong compliance advice.
  final bool isVatRegistered;

  final String? phone;
  final String? address;

  /// The registered business name, where the supplier trades under one.
  ///
  /// **Separate from [name] for the same reason a customer's is** (`ADR 010`): the
  /// name is what a person says and changes; the registered name is what appears on
  /// a tax bill.
  final String? businessName;

  /// Whether a bill from this supplier can be expected to support input credit.
  ///
  /// **A prediction, not a rule.** `NEPALI_BILLING.md` says a bill missing the
  /// vendor's PAN *may* be disallowed -- so this returns false when the PAN is
  /// absent, and a caller must still treat the answer as something to show the
  /// user rather than something to act on.
  bool get canSupportInputCredit => pan != null;

  /// A copy with different details. [id] cannot change -- see the class docblock.
  Supplier copyWith({
    String? code,
    String? name,
    String? pan,
    bool? isVatRegistered,
    String? phone,
    String? address,
    String? businessName,
  }) {
    return Supplier(
      id: id,
      name: name ?? this.name,
      code: code ?? this.code,
      // **Round-tripped through the digits**, because the parameter is the raw
      // text a user typed and the field is a parsed PAN. `NepaliPan.toString` is
      // the digits, so an unchanged PAN re-parses to itself.
      pan: pan ?? this.pan?.toString(),
      isVatRegistered: isVatRegistered ?? this.isVatRegistered,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      businessName: businessName ?? this.businessName,
    );
  }

  @override
  String toString() => 'Supplier($code ?? id, $name)';

  static String _requireText(String value, String message) {
    if (value.trim().isEmpty) throw ArgumentError(message);
    return value.trim();
  }

  /// Blank means absent.
  ///
  /// So that `''` and `null` cannot become two spellings of the same fact -- which
  /// matters here because `pan` and `code` carry unique indexes, and a blank
  /// string would satisfy neither the "present" meaning nor the "absent" one.
  static String? _blankToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Parses a PAN, **treating a blank as absent rather than invalid**.
  ///
  /// The distinction matters: a supplier with no PAN is an ordinary fact, while a
  /// supplier with a *malformed* PAN is a data-entry error the user must fix.
  static NepaliPan? _panOf(String? value) {
    final blank = _blankToNull(value);
    if (blank == null) return null;
    final parsed = NepaliPan.tryParse(blank);
    if (parsed == null) {
      // **A malformed PAN is an error, not an absence.** The distinction is the whole
      // point: a supplier with no PAN is an ordinary fact, while a supplier with a
      // nine-digit string that is not one is a data-entry error the user must fix
      // before their input credit is at risk.
      throw ArgumentError.value(
        blank,
        'pan',
        'That is not a valid PAN. A supplier may have no PAN (leave it blank), '
            'but a PAN that is present has to be a well-formed one.',
      );
    }
    return parsed;
  }
}
