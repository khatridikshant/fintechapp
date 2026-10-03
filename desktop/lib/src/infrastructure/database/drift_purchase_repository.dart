// `OrderingTerm` is restricted in, but `Value` must not be: a nullable column
// needs it, and a restricted import that hides `Value` turns a nullable `productId`
// into a compile error rather than a decision.
import 'package:drift/drift.dart' show OrderingTerm, Value;

import '../../domain/billing/document_number.dart';
import '../../domain/billing/document_type.dart';
import '../../domain/billing/issued_purchase.dart';
import '../../domain/billing/purchase.dart';
import '../../domain/billing/purchase_line.dart';
import '../../domain/billing/purchase_repository.dart';
import '../../domain/fiscal/nepali_fiscal_calendar.dart';
import '../../domain/shared/money.dart';
import 'app_database.dart';

/// Stores issued purchases as records.
///
/// The exact mirror of `DriftInvoiceRepository`, because a purchase is the same
/// kind of thing: a stored legal document rather than only a journal entry. That
/// document is what makes input VAT derivable and a payable settleable, which is
/// why it exists at all — see ADR 012.
///
/// Needs a [NepaliFiscalCalendar] to rebuild the `DocumentNumber` from the stored
/// fiscal year label. Only the label is persisted, because the label already
/// determines the year's bounds and storing those too would duplicate a fact that
/// can then drift.
class DriftPurchaseRepository implements PurchaseRepository {
  DriftPurchaseRepository(
    this._db, {
    NepaliFiscalCalendar calendar = const NepaliFiscalCalendar(),
  }) : _calendar = calendar;

  final AppDatabase _db;
  final NepaliFiscalCalendar _calendar;

  @override
  Future<void> save(IssuedPurchase issued) {
    // One transaction. If any line fails the header rolls back with it, so a
    // purchase without its lines can never be observed — and a bill whose lines are
    // missing cannot be reprinted or defended in an audit.
    return _db.transaction(() async {
      final purchase = issued.purchase;

      // A plain insert, not an upsert. A posted purchase bill is the evidence of
      // an input VAT claim; replacing it silently would destroy the original.
      await _db.into(_db.purchases).insert(
            PurchasesCompanion.insert(
              id: purchase.id,
              number: issued.number.value,
              sequence: issued.number.sequence,
              fiscalYearLabel: issued.number.fiscalYear.label,
              supplierId: purchase.supplierId,
              issueDate: purchase.issueDate,
              currency: purchase.currency,
              vatRateBasisPoints: purchase.vatRateBasisPoints,
              subtotalMinorUnits: purchase.subtotal.minorUnits,
              vatMinorUnits: purchase.vat.minorUnits,
              totalMinorUnits: purchase.total.minorUnits,
              journalEntryId: issued.journalEntryId,
            ),
          );

      var lineNumber = 1;
      for (final line in purchase.lines) {
        await _db.into(_db.purchaseLines).insert(
              PurchaseLinesCompanion.insert(
                purchaseId: purchase.id,
                lineNumber: lineNumber,
                description: line.description,
                quantity: line.quantity,
                unitPriceMinorUnits: line.unitPrice.minorUnits,
                currency: line.unitPrice.currency,
                vatRateBasisPoints: line.vatRateBasisPoints,
                // Wrapped because the column is nullable: a freight or service
                // line has no product, and `null` is the one representation of
                // "moves no stock". An empty string would match no product yet not
                // be null, so a "stock to receive" query would miss it.
                productId: Value(line.productId),
              ),
            );
        lineNumber++;
      }
    });
  }

  @override
  Future<IssuedPurchase?> byId(String id) async {
    final row = await (_db.select(_db.purchases)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return _rebuild(row, await _linesFor(id));
  }

  @override
  Future<List<IssuedPurchase>> all() async {
    final rows = await (_db.select(_db.purchases)
          ..orderBy([
            (t) => OrderingTerm(expression: t.issueDate),
            (t) => OrderingTerm(expression: t.sequence),
          ]))
        .get();

    final issued = <IssuedPurchase>[];
    for (final row in rows) {
      issued.add(_rebuild(row, await _linesFor(row.id)));
    }
    return issued;
  }

  @override
  Future<List<IssuedPurchase>> forSupplier(String supplierId) async {
    final rows = await (_db.select(_db.purchases)
          ..where((t) => t.supplierId.equals(supplierId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.issueDate),
            (t) => OrderingTerm(expression: t.sequence),
          ]))
        .get();

    final issued = <IssuedPurchase>[];
    for (final row in rows) {
      issued.add(_rebuild(row, await _linesFor(row.id)));
    }
    return issued;
  }

  Future<List<PurchaseLineRow>> _linesFor(String purchaseId) {
    return (_db.select(_db.purchaseLines)
          ..where((t) => t.purchaseId.equals(purchaseId))
          // Preserves the order the lines were entered in, which is the order the
          // bill prints in.
          ..orderBy([(t) => OrderingTerm(expression: t.lineNumber)]))
        .get();
  }

  /// Rebuilds a domain purchase from its rows.
  ///
  /// The `Purchase` constructor re-derives every total, so a corrupt row set is
  /// caught here rather than returned as a plausible-looking bill. Each line's own
  /// VAT rate is restored too, because a mixed-rate bill reloads as a mixed-rate
  /// bill rather than silently collapsing to the purchase's own rate.
  IssuedPurchase _rebuild(PurchaseRow row, List<PurchaseLineRow> lineRows) {
    final lines = lineRows
        .map(
          (line) => PurchaseLine(
            description: line.description,
            quantity: line.quantity,
            unitPrice: Money.minor(line.unitPriceMinorUnits, line.currency),
            vatRateBasisPoints: line.vatRateBasisPoints,
            productId: line.productId,
          ),
        )
        .toList();

    final purchase = Purchase(
      id: row.id,
      issueDate: row.issueDate,
      supplierId: row.supplierId,
      lines: lines,
      vatRateBasisPoints: row.vatRateBasisPoints,
    );

    final number = DocumentNumber.of(
      type: _documentTypeOf(row),
      fiscalYear: _calendar.fromLabel(row.fiscalYearLabel),
      sequence: row.sequence,
    );

    return IssuedPurchase(purchase: purchase, number: number);
  }

  /// The document type, read back from the stored number's prefix.
  ///
  /// Read rather than assumed so that a purchase return reloads as a return rather
  /// than as a purchase. Guessing would make a reversal indistinguishable from the
  /// bill it reverses.
  DocumentType _documentTypeOf(PurchaseRow row) {
    final prefix = row.number.split('-').first;
    final type = DocumentType.fromPrefix(prefix);
    if (type == null) {
      throw StateError(
        'Purchase ${row.id} has a number "${row.number}" whose prefix "$prefix" '
        'does not match any known document type.',
      );
    }
    return type;
  }
}