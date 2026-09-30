import 'package:drift/drift.dart';

import '../../domain/billing/document_number.dart';
import '../../domain/billing/document_number_sequence.dart';
import '../../domain/billing/document_type.dart';
import '../../domain/fiscal/fiscal_year.dart';
import 'app_database.dart';

/// Stores controlled document sequences in SQLite.
///
/// The sequence is keyed by document type **and** fiscal year, so an invoice
/// sequence and a credit note sequence never share a counter, and each fiscal
/// year restarts at 1, as ADR 005 requires.
class DriftDocumentNumberSequence implements DocumentNumberSequence {
  DriftDocumentNumberSequence(this._db);

  final AppDatabase _db;

  @override
  Future<DocumentNumber> allocateNext({
    required DocumentType type,
    required FiscalYear fiscalYear,
  }) {
    // Read and write inside one transaction, so a number can never be handed out
    // twice even if two allocations interleave.
    //
    // This nests inside a caller's unit of work rather than committing on its
    // own. That is the behaviour that matters: if the document this number
    // belongs to is never issued, the allocation rolls back with it and the
    // serial is not burnt.
    return _db.transaction(() async {
      final next = await _lastAllocated(type, fiscalYear) + 1;

      await _db.into(_db.documentSequences).insertOnConflictUpdate(
            DocumentSequencesCompanion.insert(
              documentType: type.name,
              fiscalYearLabel: fiscalYear.label,
              lastSequence: Value(next),
            ),
          );

      return DocumentNumber.of(
        type: type,
        fiscalYear: fiscalYear,
        sequence: next,
      );
    });
  }

  @override
  Future<DocumentNumber> peekNext({
    required DocumentType type,
    required FiscalYear fiscalYear,
  }) async {
    // Deliberately does not write. Showing a draft what number it will receive
    // must not consume it, or every abandoned draft would leave a gap.
    final next = await _lastAllocated(type, fiscalYear) + 1;
    return DocumentNumber.of(
      type: type,
      fiscalYear: fiscalYear,
      sequence: next,
    );
  }

  @override
  Future<int> lastAllocatedSequence({
    required DocumentType type,
    required FiscalYear fiscalYear,
  }) =>
      _lastAllocated(type, fiscalYear);

  Future<int> _lastAllocated(DocumentType type, FiscalYear fiscalYear) async {
    final row = await (_db.select(_db.documentSequences)
          ..where((t) =>
              t.documentType.equals(type.name) &
              t.fiscalYearLabel.equals(fiscalYear.label)))
        .getSingleOrNull();
    return row?.lastSequence ?? 0;
  }
}
