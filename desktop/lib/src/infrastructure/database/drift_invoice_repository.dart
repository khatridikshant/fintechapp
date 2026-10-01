import 'package:drift/drift.dart' show OrderingTerm;

import '../../domain/billing/document_number.dart';
import '../../domain/billing/document_type.dart';
import '../../domain/billing/invoice.dart';
import '../../domain/billing/invoice_line.dart';
import '../../domain/billing/invoice_repository.dart';
import '../../domain/billing/issued_invoice.dart';
import '../../domain/fiscal/nepali_fiscal_calendar.dart';
import '../../domain/shared/money.dart';
import 'app_database.dart';

/// Stores issued invoices as records.
///
/// The repository needs a [NepaliFiscalCalendar] in order to rebuild a
/// `DocumentNumber` from the stored fiscal year label. Only the label is
/// persisted, because the label already determines the year's start and end and
/// storing those too would duplicate a fact that can then drift.
class DriftInvoiceRepository implements InvoiceRepository {
  DriftInvoiceRepository(
    this._db, {
    NepaliFiscalCalendar calendar = const NepaliFiscalCalendar(),
  }) : _calendar = calendar;

  final AppDatabase _db;
  final NepaliFiscalCalendar _calendar;

  @override
  Future<void> save(IssuedInvoice issued) {
    // One transaction. If any line fails, the invoice header rolls back with it,
    // so an invoice without its lines can never be observed.
    return _db.transaction(() async {
      final invoice = issued.invoice;

      // A plain insert, not an upsert. An issued invoice is a legal document;
      // replacing it silently would destroy the original.
      await _db.into(_db.invoices).insert(
            InvoicesCompanion.insert(
              id: invoice.id,
              number: issued.number.value,
              sequence: issued.number.sequence,
              fiscalYearLabel: issued.number.fiscalYear.label,
              customerId: invoice.customerId,
              issueDate: invoice.issueDate,
              currency: invoice.currency,
              vatRateBasisPoints: invoice.vatRateBasisPoints,
              subtotalMinorUnits: invoice.subtotal.minorUnits,
              vatMinorUnits: invoice.vat.minorUnits,
              totalMinorUnits: invoice.total.minorUnits,
              journalEntryId: issued.journalEntryId,
            ),
          );

      // The seller details printed on this invoice.
      //
      // Written only when there is something to record. An invoice issued before
      // this existed has no snapshot, and inventing one now would put a PAN on
      // paper that never carried it.
      final sellerName = invoice.sellerName;
      final sellerPan = invoice.sellerPan;
      if (sellerName != null && sellerPan != null) {
        await _db.into(_db.invoiceSellers).insert(
              InvoiceSellersCompanion.insert(
                invoiceId: invoice.id,
                sellerName: sellerName,
                sellerPan: sellerPan,
              ),
            );
      }

      var lineNumber = 1;
      for (final line in invoice.lines) {
        await _db.into(_db.invoiceLines).insert(
              InvoiceLinesCompanion.insert(
                invoiceId: invoice.id,
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
  Future<IssuedInvoice?> byId(String id) async {
    final row = await (_db.select(_db.invoices)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return _rebuild(
      row,
      await _linesFor(id),
      seller: await _sellerFor(id),
    );
  }

  @override
  Future<List<IssuedInvoice>> all() async {
    final rows = await (_db.select(_db.invoices)
          ..orderBy([
            (t) => OrderingTerm(expression: t.issueDate),
            (t) => OrderingTerm(expression: t.sequence),
          ]))
        .get();

    final issued = <IssuedInvoice>[];
    for (final row in rows) {
      issued.add(
        _rebuild(
          row,
          await _linesFor(row.id),
          seller: await _sellerFor(row.id),
        ),
      );
    }
    return issued;
  }

  @override
  Future<List<IssuedInvoice>> forCustomer(String customerId) async {
    final rows = await (_db.select(_db.invoices)
          ..where((t) => t.customerId.equals(customerId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.issueDate),
            (t) => OrderingTerm(expression: t.sequence),
          ]))
        .get();

    final issued = <IssuedInvoice>[];
    for (final row in rows) {
      issued.add(
        _rebuild(
          row,
          await _linesFor(row.id),
          seller: await _sellerFor(row.id),
        ),
      );
    }
    return issued;
  }

  /// The seller snapshot for one invoice, or null when it was issued before
  /// snapshots existed.
  ///
  /// **Nullable on the right**, because most invoices issued before v11 have no
  /// snapshot row and inventing one would put a PAN on paper that never carried it.
  Future<InvoiceSellerRow?> _sellerFor(String invoiceId) {
    return (_db.select(_db.invoiceSellers)
          ..where((t) => t.invoiceId.equals(invoiceId)))
        .getSingleOrNull();
  }

  Future<List<InvoiceLineRow>> _linesFor(String invoiceId) {
    return (_db.select(_db.invoiceLines)
          ..where((t) => t.invoiceId.equals(invoiceId))
          // Line number preserves the order the lines were entered in, which is
          // the order they print in.
          ..orderBy([(t) => OrderingTerm(expression: t.lineNumber)]))
        .get();
  }

  /// Rebuilds a domain invoice from its rows.
  ///
  /// The `Invoice` constructor re-derives the totals, so a corrupt row set is
  /// caught here rather than returned as a plausible-looking invoice.
  IssuedInvoice _rebuild(
    InvoiceRow row,
    List<InvoiceLineRow> lineRows, {
    InvoiceSellerRow? seller,
  }) {
    final lines = lineRows
        .map(
          (line) => InvoiceLine(
            description: line.description,
            quantity: line.quantity,
            unitPrice: Money.minor(line.unitPriceMinorUnits, line.currency),
          ),
        )
        .toList();

    final invoice = Invoice(
      id: row.id,
      issueDate: row.issueDate,
      customerId: row.customerId,
      lines: lines,
      vatRateBasisPoints: row.vatRateBasisPoints,
      // Restored from the snapshot, so a historical invoice shows the seller
      // details it was printed with rather than today's.
      sellerName: seller?.sellerName,
      sellerPan: seller?.sellerPan,
    );

    final number = DocumentNumber.of(
      type: _documentTypeOf(row),
      fiscalYear: _calendar.fromLabel(row.fiscalYearLabel),
      sequence: row.sequence,
    );

    return IssuedInvoice(invoice: invoice, number: number);
  }

  /// The document type, read back from the stored number's prefix.
  ///
  /// Invoices are the only type issued today, but the prefix is read rather than
  /// assumed, so that credit notes do not silently reload as invoices once they
  /// exist.
  DocumentType _documentTypeOf(InvoiceRow row) {
    final prefix = row.number.split('-').first;
    final type = DocumentType.fromPrefix(prefix);
    if (type == null) {
      throw StateError(
        'Invoice ${row.id} has a number "${row.number}" whose prefix "$prefix" '
        'does not match any known document type.',
      );
    }
    return type;
  }
}
