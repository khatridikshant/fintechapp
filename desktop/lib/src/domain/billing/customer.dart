/// A customer the business invoices.
///
/// The id must be **permanent and chosen by the caller**, for the same reason
/// account ids are: invoice records and journal entries reference the customer
/// by id, so an id that changed would repoint historical sales at a different
/// person. Never derive an id from the name, and never reuse one.
///
/// How a new customer's id is generated is not decided yet. It matters because
/// ids must not collide if two installations ever sync, so it needs its own
/// decision before the UI can create a customer. For now the caller supplies it.
class Customer {
  const Customer._({
    required this.id,
    required this.name,
    required this.panNumber,
    required this.phone,
    required this.address,
  });

  factory Customer({
    required String id,
    required String name,
    String? panNumber,
    String? phone,
    String? address,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('A customer needs an id.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError(
        'A customer needs a name. An unnamed customer cannot be identified on '
        'an invoice or on a statement of account.',
      );
    }
    return Customer._(
      id: id.trim(),
      name: name.trim(),
      panNumber: _blankToNull(panNumber),
      phone: _blankToNull(phone),
      address: _blankToNull(address),
    );
  }

  final String id;

  final String name;

  /// Permanent Account Number, for customers who have one. Optional.
  final String? panNumber;

  final String? phone;

  final String? address;

  /// Whether this customer has a PAN recorded.
  bool get hasPanNumber => panNumber != null;

  /// A blank optional field is stored as `null`, never as an empty string, so
  /// that "not provided" has exactly one representation. Storing both `null` and
  /// `''` would make every later query test two cases and eventually miss one.
  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Two customers are the same customer when they have the same identity.
  /// Name, phone, and address are attributes, not identity.
  @override
  bool operator ==(Object other) => other is Customer && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Customer($id, $name)';
}
