import '../fiscal/fiscal_year.dart';
import 'document_number.dart';
import 'document_type.dart';

/// Port for allocating controlled document numbers.
///
/// This is an interface owned by the domain. The implementation lives in
/// `infrastructure/`.
///
/// **Allocation must happen inside a unit of work.** The whole point is that a
/// serial is consumed only if the document it belongs to is actually issued. If
/// the surrounding work fails, the allocation must roll back with it, so the
/// number is not burnt and the sequence has no unexplained gap.
abstract interface class DocumentNumberSequence {
  /// Consumes and returns the next number for [type] in [fiscalYear].
  ///
  /// This advances the stored sequence. Call it at the moment of issuance, never
  /// while a document is still a draft.
  ///
  /// Concurrent or repeated calls must never return the same number.
  Future<DocumentNumber> allocateNext({
    required DocumentType type,
    required FiscalYear fiscalYear,
  });

  /// Returns what the next number *would* be, without consuming it.
  ///
  /// Use this to show the user the number a draft will receive. Calling it any
  /// number of times must not advance the sequence, which is what makes
  /// "a draft does not consume a serial" true.
  Future<DocumentNumber> peekNext({
    required DocumentType type,
    required FiscalYear fiscalYear,
  });

  /// The highest sequence already allocated, or `0` if none has been.
  Future<int> lastAllocatedSequence({
    required DocumentType type,
    required FiscalYear fiscalYear,
  });
}
