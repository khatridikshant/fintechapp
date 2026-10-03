import '../shared/money.dart';
import 'purchase_line.dart';

/// A purchase bill: what the business bought, from whom, and for how much.
///
/// ## The mirror of [Invoice], and deliberately not a copy
///
/// Structurally the same — id, date, supplier, lines, VAT rate — but the
/// accounting differs in three ways that matter, and ADR 012 records each:
///
/// 1. **Input VAT is an asset**, debited to `1150 Input VAT Recoverable`. On the
///    sales side VAT is a liability; here it is money the business has *paid* and
///    will recover.
/// 2. **Inventory carries the net figure.** `1040` is debited with the subtotal,
///    not the gross. Capitalising the gross would put a recoverable tax into the
///    cost of goods sold when the stock is later sold.
/// 3. **A line may carry its own VAT rate**, because one supplier can invoice
///    standard-rated and zero-rated goods in the same bill. A sales invoice
///    deliberately does not allow this — see [PurchaseLine].
///
/// Every total is **derived from the lines**, never stored and never passed in.
/// A stored total is a second source of truth that can disagree with the lines it
/// summarises, and this document is evidence in an audit.
class Purchase {
  const Purchase._({
    required this.id,
    required this.issueDate,
    required this.supplierId,
    required this.lines,
    required this.vatRateBasisPoints,
  });

  /// Nepal's standard VAT rate, 13%, expressed in basis points.
  ///
  /// **A default, not the application constant.** `NepalTaxRules` carries the rate
  /// in force with a version string, because the Finance Act sets it annually;
  /// this constant exists so a `PurchaseLine` with no explicit rate is still
  /// explicit about being 13%, and a production posting reads the rate from the
  /// rules rather than from here.
  static const int vatStandardRate = 1300;

  factory Purchase({
    required String id,
    required DateTime issueDate,
    required String supplierId,
    required List<PurchaseLine> lines,
    int vatRateBasisPoints = vatStandardRate,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('A purchase needs an id.');
    }
    if (supplierId.trim().isEmpty) {
      throw ArgumentError(
        'A purchase needs a supplier. Stock received from nobody cannot be '
        'recorded as stock on hand.',
      );
    }
    if (lines.isEmpty) {
      throw ArgumentError(
        'A purchase needs at least one line. A purchase with no lines would '
        'post a payable for nothing, which is a liability with no document '
        'behind it.',
      );
    }
    if (vatRateBasisPoints < 0) {
      throw ArgumentError(
        'A VAT rate must not be negative, got $vatRateBasisPoints basis points.',
      );
    }

    final currencies = {for (final line in lines) line.unitPrice.currency};
    if (currencies.length > 1) {
      throw ArgumentError(
        'Every line on a purchase must be in one currency, got '
        '${currencies.join(', ')}. A payable totalling two currencies is not a '
        'real amount.',
      );
    }

    return Purchase._(
      id: id.trim(),
      issueDate: issueDate,
      supplierId: supplierId.trim(),
      lines: List.unmodifiable(lines),
      vatRateBasisPoints: vatRateBasisPoints,
    );
  }

  /// The draft's identity. Re-issuing a purchase with an id that has already been
  /// posted is refused by the primary key on its journal entry.
  final String id;

  final DateTime issueDate;

  /// Identifies the supplier being paid.
  final String supplierId;

  final List<PurchaseLine> lines;

  /// The rate applied to lines that do not carry their own. See [vat].
  final int vatRateBasisPoints;

  /// Currency of the purchase, taken from the lines.
  String get currency => lines.first.unitPrice.currency;

  /// Sum of the line totals, before VAT. **This is the value that enters stock.**
  Money get subtotal =>
      Money.sum(lines.map((line) => line.lineTotal), currency);

  /// VAT on the purchase.
  ///
  /// **One rule, chosen by the data.** When every line carries the same rate — the
  /// normal case — VAT is charged once on the combined subtotal, so rounding
  /// cannot drift between this bill and the return filed with the authority. When
  /// lines carry **different** rates, each is charged at its own rate, because a
  /// zero-rated line must contribute no VAT at all rather than a share of a
  /// single rounded total.
  ///
  /// Both paths are integer paisa and half-up. There is no `double` anywhere.
  Money get vat {
    final distinctRates = {for (final line in lines) line.vatRateBasisPoints};
    if (distinctRates.length <= 1) {
      // Single rate, including the "every line is zero-rated" case, which yields
      // a zero and lets a posting use case omit the line entirely.
      return subtotal.applyBasisPoints(vatRateBasisPoints);
    }
    return Money.sum(lines.map((line) => line.vat), currency);
  }

  /// What the business owes the supplier: subtotal plus VAT.
  Money get total => subtotal.add(vat);

  /// Whether this purchase carries no VAT.
  ///
  /// Named so a posting use case can **omit the input VAT line** rather than post
  /// a zero — a journal line must carry a positive amount on one side, and a
  /// return expects no line rather than a zero line.
  bool get isZeroRated => vat.isZero;

  /// The lines that bring stock in.
  List<PurchaseLine> get stockLines =>
      lines.where((line) => line.receivesStock).toList(growable: false);

  /// Whether this purchase moves any stock at all.
  ///
  /// False for a bill of services, freight, or a fixed asset — all real purchases
  /// that happen not to be tracked stock.
  bool get receivesStock => stockLines.isNotEmpty;

  @override
  String toString() =>
      'Purchase($id, ${lines.length} lines, ${total.format()})';
}