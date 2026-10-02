import '../accounting/journal_entry.dart';
import '../shared/money.dart';

/// Where the money came from and where it went, for a period.
///
/// ## Cash, not profit
///
/// This is a **cash statement, not an accrual one.** A sale on credit moves nothing,
/// so it appears nowhere here, and a payment of an old invoice appears even though
/// no sale happened in the period. That is the correct behaviour for a cash
/// statement, and the reason it cannot be derived from the profit and loss report:
/// those two are supposed to disagree, and a business that shows them agreeing is
/// hiding a problem.
///
/// ## Where it is derived from
///
/// From the accounts whose movement *is* cash: bank and cash. Every other
/// balance sheet account is excluded, so an accrual movement cannot leak in.
class CashFlow {
  const CashFlow._({
    required this.currency,
    required this.openingCash,
    required this.received,
    required this.paid,
  });

  /// Builds the statement for [entries] between [from] and [to].
  ///
  /// [isCashAccount] decides which accounts are cash, rather than this report
  /// naming accounts — the chart of accounts owns which accounts are cash, and a
  /// report that hardcoded them would disagree the first time a business added a
  /// second cash box.
  ///
  /// ## What counts as opening cash
  ///
  /// Entries dated **strictly before** [from] are opening cash, unless
  /// [openingIncludesBoundary] is set.
  ///
  /// That flag exists for the whole-fiscal-year view. The opening-balance entry
  /// that opens a year is dated **exactly on the year's first day**, not the day
  /// before, so under the strict rule it would be reported as cash received
  /// during the year — the opposite of what it is. Rather than shifting the date
  /// to make a rule fit, the boundary is stated: for a year, the first day itself
  /// is opening.
  ///
  /// An explicit date range from a caller keeps the strict rule, because there the
  /// caller chose the boundary and a transaction on the first day really did happen
  /// in the period.
  factory CashFlow.from({
    required List<JournalEntry> entries,
    required bool Function(String accountId) isCashAccount,
    required String currency,
    DateTime? from,
    DateTime? to,
    bool openingIncludesBoundary = false,
  }) {
    var opening = 0;
    var received = 0;
    var paid = 0;

    for (final entry in entries) {
      // An entry after the window is ignored entirely, in either direction.
      if (to != null && entry.date.isAfter(to)) continue;

      // Anything before the period still counts towards the opening balance,
      // because that cash was in the account when the period began.
      final precedesPeriod = from != null &&
          (openingIncludesBoundary
              ? !entry.date.isAfter(from)
              : entry.date.isBefore(from));

      for (final line in entry.lines) {
        if (!isCashAccount(line.account.id)) continue;

        if (precedesPeriod) {
          opening +=
              line.isDebit ? line.amount.minorUnits : -line.amount.minorUnits;
        } else if (line.isDebit) {
          received += line.amount.minorUnits;
        } else {
          paid += line.amount.minorUnits;
        }
      }
    }

    return CashFlow._(
      currency: currency,
      openingCash: Money.minor(opening, currency),
      received: Money.minor(received, currency),
      paid: Money.minor(paid, currency),
    );
  }

  final String currency;

  /// Cash at the start of the period.
  final Money openingCash;

  /// Money in, from customers and anything else that reached the bank.
  final Money received;

  /// Money out, for anything that left it.
  final Money paid;

  /// Cash at the end of the period.
  Money get closingCash => openingCash.add(received).subtract(paid);

  /// Money in less money out over the period, excluding the opening balance.
  Money get netMovement => received.subtract(paid);

  /// True when more came in than went out over the period.
  bool get isNetInflow => netMovement.isPositive;

  @override
  String toString() =>
      'CashFlow(opening $openingCash, in $received, out $paid, '
      'closing $closingCash)';
}

/// A total for one named thing, used by the summary reports.
class ReportTotal {
  const ReportTotal({required this.label, required this.amount});

  final String label;
  final Money amount;

  @override
  String toString() => 'ReportTotal($label, $amount)';
}

/// Sales for a period: what was invoiced, net of what was credited back.
///
/// ## Credits are subtracted, not ignored
///
/// A credit note reduces what the business has sold. Leaving it out would overstate
/// revenue on exactly the documents a business issues when something has gone
/// wrong, which is when the number is read most carefully.
class SalesSummary {
  const SalesSummary._({
    required this.currency,
    required this.grossSales,
    required this.credits,
    required this.byProduct,
  });

  factory SalesSummary.from({
    required List<ReportTotal> grossSales,
    required List<ReportTotal> credits,
    required String currency,
  }) {
    var gross = 0;
    for (final line in grossSales) {
      gross += line.amount.minorUnits;
    }
    var refunded = 0;
    for (final line in credits) {
      refunded += line.amount.minorUnits;
    }

    return SalesSummary._(
      currency: currency,
      grossSales: Money.minor(gross, currency),
      credits: Money.minor(refunded, currency),
      byProduct: List<ReportTotal>.unmodifiable(grossSales),
    );
  }

  final String currency;

  /// What was invoiced before credits.
  final Money grossSales;

  /// What was credited back.
  final Money credits;

  /// Gross sales by product.
  final List<ReportTotal> byProduct;

  /// **Sales net of credits** — the figure that answers "what did we sell".
  Money get netSales => grossSales.subtract(credits);

  @override
  String toString() => 'SalesSummary(gross $grossSales, credits $credits)';
}

/// Stock on hand, by product.
///
/// Derived from the **inventory movements**, which is the same authoritative source
/// the stock balance uses. Reading stock from somewhere else would let the report
/// and the balance sheet disagree, and one of them would be wrong.
class InventorySummary {
  const InventorySummary._({required this.lines});

  factory InventorySummary.from({
    required List<ReportTotal> lines,
  }) =>
      InventorySummary._(
        lines: List<ReportTotal>.unmodifiable(lines),
      );

  /// What is held, per product.
  final List<ReportTotal> lines;

  /// The total value of stock held.
  Money get totalValue {
    var total = 0;
    for (final line in lines) {
      total += line.amount.minorUnits;
    }
    final currency = lines.isEmpty ? 'NPR' : 'NPR';
    return Money.minor(total, currency);
  }

  @override
  String toString() => 'InventorySummary(${lines.length} products)';
}

/// The figures a VAT return needs, for a period.
///
/// ## The basis matters
///
/// Output VAT is on **invoices issued**, not on money received. A customer paying
/// over three instalments does not create three periods of output VAT. The total is
/// therefore the **gross invoice amount including VAT**, less credit notes, which
/// is exactly what the declaration asks for.
class TaxSummary {
  const TaxSummary._({
    required this.currency,
    required this.rateBasisPoints,
    required this.taxableSales,
    required this.outputVat,
    required this.taxablePurchases,
    required this.inputVat,
    required this.credits,
  });

  /// The standard rate the figures were computed at.
  static const int standardRateBasisPoints = 1300;

  factory TaxSummary.from({
    required List<ReportTotal> taxableSales,
    required List<ReportTotal> taxablePurchases,
    required List<ReportTotal> credits,
    required int rateBasisPoints,
    required String currency,
  }) {
    var sales = 0;
    for (final line in taxableSales) {
      sales += line.amount.minorUnits;
    }
    var purchases = 0;
    for (final line in taxablePurchases) {
      purchases += line.amount.minorUnits;
    }
    var credited = 0;
    for (final line in credits) {
      credited += line.amount.minorUnits;
    }

    // VAT is computed on the amount **excluding** VAT, and the return shows both.
    final netSales = sales - credited;

    return TaxSummary._(
      currency: currency,
      rateBasisPoints: rateBasisPoints,
      taxableSales: Money.minor(netSales, currency),
      outputVat: Money.minor(_vatOn(netSales, rateBasisPoints), currency),
      taxablePurchases: Money.minor(purchases, currency),
      inputVat: Money.minor(_vatOn(purchases, rateBasisPoints), currency),
      credits: Money.minor(credited, currency),
    );
  }

  final String currency;

  /// The rate these figures were computed at, so a return cannot be read without
  /// knowing which rate applied.
  final int rateBasisPoints;

  /// Sales excluding VAT, net of credits.
  final Money taxableSales;

  /// VAT due on those sales.
  final Money outputVat;

  /// Purchases excluding VAT.
  final Money taxablePurchases;

  /// VAT paid on those purchases.
  final Money inputVat;

  /// Sales that were credited back, and so removed from the period.
  final Money credits;

  /// Output VAT less input VAT. **Negative means a refund is due.**
  Money get netVatPayable => outputVat.subtract(inputVat);

  /// VAT is computed in basis points and rounded **half-up once**, so the figure on
  /// the return is the figure that was stored.
  static int _vatOn(int netExcludingVat, int rateBasisPoints) {
    if (netExcludingVat <= 0) return 0;
    return (netExcludingVat * rateBasisPoints / 10000).round();
  }

  @override
  String toString() =>
      'TaxSummary(output $outputVat, input $inputVat, net $netVatPayable)';
}
