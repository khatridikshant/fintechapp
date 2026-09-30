import 'package:drift/drift.dart' show OrderingTerm;

import '../../domain/billing/credit_note.dart';
import '../../domain/billing/credit_note_repository.dart';
import '../../domain/billing/document_number.dart';
import '../../domain/billing/document_type.dart';
import '../../domain/billing/invoice_line.dart';
import '../../domain/billing/issued_credit_note.dart';
import '../../domain/fiscal/nepali_fiscal_calendar.dart';
import '../../domain/shared/money.dart';
import 'app_database.dart';

/// Stores issued credit notes as records.
///
/// The repository needs a [NepaliFiscalCalendar] to rebuild the document number
/// from the stored fiscal year label, exactly as the invoice repository does.
class DriftCreditNoteRepository implements CreditNoteRepository {
  DriftCreditNoteRepository(
    this._db, {
    NepaliFiscalCalendar calendar = const NepaliFiscalCalendar(),
  }) : _calendar = calendar;

  final AppDatabase _db;
  final NepaliFiscalCalendar _calendar;

  @override
  Future<void> save(IssuedCreditNote issued) {
    return _db.transaction(() async {
      final creditNote = issued.creditNote;

      // A plain insert, not an upsert. A credit note is a financial record;
      // replacing it silently would destroy the original.
      await _db.into(_db.creditNotes).insert(
            CreditNotesCompanion.insert(
              id: creditNote.id,
              number: issued.number.value,
              sequence: issued.number.sequence,
              fiscalYearLabel: issued.number.fiscalYear.label,
              invoiceId: creditNote.invoiceId,
              date: creditNote.date,
              currency: creditNote.currency,
              vatRateBasisPoints: creditNote.vatRateBasisPoints,
              subtotalMinorUnits: creditNote.subtotal.minorUnits,
              vatMinorUnits: creditNote.vat.minorUnits,
              totalMinorUnits: creditNote.total.minorUnits,
              journalEntryId: issued.journalEntryId,
            ),
          );

      var lineNumber = 1;
      for (final line in creditNote.lines) {
        await _db.into(_db.creditNoteLines).insert(
              CreditNoteLinesCompanion.insert(
                creditNoteId: creditNote.id,
                lineNumber: lineNumber,
                description: line.description,
                quantity: line.quantity,
                unitPriceMinorUnits: line.unitPrice.minorUnits,
                currency: line.unitPrice.currency,
              ),
            );
        lineNumber++;
      }
    });
  }

  @override
  Future<IssuedCreditNote?> byId(String id) async {
    final row = await (_db.select(_db.creditNotes)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return _rebuild(row, await _linesFor(id));
  }

  @override
  Future<List<IssuedCreditNote>> forInvoice(String invoiceId) async {
    final rows = await (_db.select(_db.creditNotes)
          ..where((t) => t.invoiceId.equals(invoiceId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.date),
            (t) => OrderingTerm(expression: t.sequence),
          ]))
        .get();
    return _rebuildAll(rows);
  }

  @override
  Future<List<IssuedCreditNote>> all() async {
    final rows = await (_db.select(_db.creditNotes)
          ..orderBy([
            (t) => OrderingTerm(expression: t.date),
            (t) => OrderingTerm(expression: t.sequence),
          ]))
        .get();
    return _rebuildAll(rows);
  }

  Future<List<IssuedCreditNote>> _rebuildAll(List<CreditNoteRow> rows) async {
    final notes = <IssuedCreditNote>[];
    for (final row in rows) {
      notes.add(_rebuild(row, await _linesFor(row.id)));
    }
    return notes;
  }

  Future<List<CreditNoteLineRow>> _linesFor(String creditNoteId) {
    return (_db.select(_db.creditNoteLines)
          ..where((t) => t.creditNoteId.equals(creditNoteId))
          ..orderBy([(t) => OrderingTerm(expression: t.lineNumber)]))
        .get();
  }

  /// Rebuilds a credit note from its rows.
  ///
  /// The `CreditNote` constructor re-derives the totals, so a corrupt row set is
  /// caught here rather than returned as a plausible-looking document.
  IssuedCreditNote _rebuild(
    CreditNoteRow row,
    List<CreditNoteLineRow> lineRows,
  ) {
    final lines = lineRows
        .map(
          (line) => InvoiceLine(
            description: line.description,
            quantity: line.quantity,
            unitPrice: Money.minor(line.unitPriceMinorUnits, line.currency),
          ),
        )
        .toList();

    final creditNote = CreditNote(
      id: row.id,
      invoiceId: row.invoiceId,
      date: row.date,
      lines: lines,
      vatRateBasisPoints: row.vatRateBasisPoints,
    );

    final number = DocumentNumber.of(
      type: _documentTypeOf(row),
      fiscalYear: _calendar.fromLabel(row.fiscalYearLabel),
      sequence: row.sequence,
    );

    return IssuedCreditNote(creditNote: creditNote, number: number);
  }

  /// The document type, read back from the stored number's prefix.
  ///
  /// Read rather than assumed, so a credit note can never silently reload as an
  /// invoice or vice versa.
  DocumentType _documentTypeOf(CreditNoteRow row) {
    final prefix = row.number.split('-').first;
    final type = DocumentType.fromPrefix(prefix);
    if (type == null) {
      throw StateError(
        'Credit note ${row.id} has a number "${row.number}" whose prefix '
        '"$prefix" does not match any known document type.',
      );
    }
    return type;
  }
}
