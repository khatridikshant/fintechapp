import '../fiscal/fiscal_year.dart';
import 'document_type.dart';

/// A formatted, controlled document number such as `INV-2082-83-1042`.
///
/// The number is built from three independent facts, which is exactly why it is
/// auditable:
///
///   `INV`       the document type
///   `2082-83`   the fiscal year the document belongs to
///   `1042`      the position in that year's sequence for that type
///
/// ADR 005 governs the rules: numbers are sequential within a fiscal year and
/// document type, each sequence restarts at 1 in a new fiscal year, numbers are
/// never reused, and a serial is consumed at **issuance**, never when a draft is
/// created.
class DocumentNumber {
  const DocumentNumber._({
    required this.type,
    required this.fiscalYear,
    required this.sequence,
  });

  /// Builds a number. [sequence] starts at 1, because a sequence has no zero.
  factory DocumentNumber.of({
    required DocumentType type,
    required FiscalYear fiscalYear,
    required int sequence,
  }) {
    if (sequence < 1) {
      throw ArgumentError(
        'A document sequence starts at 1, got $sequence. Zero is not a valid '
        'document number, because it would read as though no serial had been '
        'allocated.',
      );
    }
    return DocumentNumber._(
      type: type,
      fiscalYear: fiscalYear,
      sequence: sequence,
    );
  }

  final DocumentType type;

  /// The fiscal year the document was issued into.
  final FiscalYear fiscalYear;

  /// The position in this type's sequence for this fiscal year, starting at 1.
  final int sequence;

  /// Digits the sequence is padded to. Numbers are not truncated past this.
  static const int sequenceDigits = 4;

  /// The full printable number, for example `INV-2082-83-1042`.
  String get value {
    final padding = sequence.toString().padLeft(sequenceDigits, '0');
    return '${type.prefix}-$_fiscalYearPart-$padding';
  }

  /// `FY 2082/83` becomes `2082-83`.
  ///
  /// The label is validated rather than sliced. A label that does not match
  /// would otherwise produce a malformed number that looks plausible, and a
  /// plausible-looking wrong document number is worse than a loud failure.
  String get _fiscalYearPart {
    final match = RegExp(r'^FY (\d{4})/(\d{2})$').firstMatch(fiscalYear.label);
    if (match == null) {
      throw ArgumentError(
        'Cannot build a document number from the fiscal year label '
        '"${fiscalYear.label}". Expected a label shaped like "FY 2082/83".',
      );
    }
    return '${match.group(1)}-${match.group(2)}';
  }

  @override
  bool operator ==(Object other) =>
      other is DocumentNumber &&
      other.type == type &&
      other.fiscalYear == fiscalYear &&
      other.sequence == sequence;

  @override
  int get hashCode => Object.hash(type, fiscalYear, sequence);

  @override
  String toString() => value;
}
