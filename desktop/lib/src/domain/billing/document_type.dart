/// The kinds of document that carry a controlled serial number.
///
/// Each type has its **own independent sequence**, as ADR 005 requires. An
/// invoice must never share a counter with a credit note, or the numbering
/// becomes impossible to audit.
///
/// The name of each value is persisted, so **renaming a value is a schema
/// migration**. Add new types rather than renaming existing ones.
enum DocumentType {
  invoice(prefix: 'INV', label: 'Invoice'),
  creditNote(prefix: 'CRN', label: 'Credit Note'),
  debitNote(prefix: 'DBN', label: 'Debit Note'),

  /// A purchase bill. **Its own sequence**, per ADR 005 and ADR 012.
  ///
  /// A purchase must never share a counter with a sale. Mixing them would make
  /// both numbering streams unauditable, and the purchase side carries the input
  /// VAT claim, so its numbers are evidence rather than convenience.
  purchase(prefix: 'PUR', label: 'Purchase'),

  /// A purchase return — goods sent back to a supplier.
  ///
  /// **A separate type, not a negative purchase.** A return is a different
  /// document with a different VAT consequence: it reduces input VAT rather than
  /// output VAT. Giving it its own sequence keeps a return identifiable in an
  /// audit and keeps the purchase sequence gap-free, which is the property CBMS
  /// certification actually checks (`NEPALI_BILLING.md`).
  purchaseReturn(prefix: 'PUN', label: 'Purchase Return');

  const DocumentType({required this.prefix, required this.label});

  /// The letters that begin a document number, for example `INV`.
  final String prefix;

  /// Human-facing name, for example `Credit Note`.
  final String label;

  /// Resolves a persisted name back to a type.
  ///
  /// Returns `null` rather than throwing, so a damaged row can be reported
  /// rather than crashing a report.
  static DocumentType? fromName(String name) {
    for (final type in DocumentType.values) {
      if (type.name == name) return type;
    }
    return null;
  }

  /// Resolves a document number's prefix back to a type, for example `INV`.
  ///
  /// Returns `null` rather than throwing, so an unreadable number can be
  /// reported rather than crashing a report.
  static DocumentType? fromPrefix(String prefix) {
    for (final type in DocumentType.values) {
      if (type.prefix == prefix) return type;
    }
    return null;
  }
}
