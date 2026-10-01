import '../shared/money.dart';

/// The tax rules in force, carried as data with a version.
///
/// ## Why these are not constants
///
/// The architecture specification is explicit:
///
/// > Nepal's applicable tax rules shall be verified against current authoritative
/// > requirements before production release and **shall not be treated as
/// > permanently fixed application constants**.
///
/// Nepal sets the VAT rate in the **Finance Act, annually**, and the registration
/// and abbreviated-invoice thresholds have moved more than once. A rate written as
/// `const int vatStandardRate = 1300` in the domain is a rule that will silently be
/// wrong the year the Finance Act changes it, and nothing in the code will say so.
///
/// So the rules travel as a value with a [version]. Changing a rate is new data,
/// not a code change, and the version can be printed on a VAT return or attached
/// to a backup so a question six months later has an answer.
///
/// ## The defaults are the current published position, not a guarantee
///
/// [NepalTaxRules.current] uses the standard 13% rate and the Rule 17(Ka) ceiling
/// of NPR 10,000. Both are recorded with their sources in
/// `docs/NEPALI_BILLING.md`, together with the points where the sources
/// conflict. The conflicts are represented by conservative behaviour and a single
/// method to change, rather than being resolved by guessing.
class NepalTaxRules {
  const NepalTaxRules({
    required this.version,
    required this.standardVatRateBasisPoints,
    required this.abbreviatedInvoiceCeiling,
    required this.buyerPanThreshold,
    required this.recordRetentionYearsVat,
    required this.recordRetentionYearsIncomeTax,
  });

  /// The published position at the time of writing.
  ///
  /// Named [current] rather than being the only instance, so a caller that needs
  /// the rules for a past fiscal year can pass a different one.
  static const NepalTaxRules current = NepalTaxRules(
    version: '2053/Rule17@FY2082-83',
    standardVatRateBasisPoints: 1300,
    abbreviatedInvoiceCeiling: 1000000,
    buyerPanThreshold: 10000000,
    recordRetentionYearsVat: 6,
    recordRetentionYearsIncomeTax: 5,
  );

  /// Identifies the rule set, so an invoice can record which rules produced it.
  ///
  /// This matters because a rate changes mid-history: an invoice issued under the
  /// old rules must remain explainable when it is audited, rather than appearing
  /// to have been calculated by rules that did not yet exist.
  final String version;

  /// The standard VAT rate in basis points. 1300 = 13%.
  ///
  /// Basis points, never a percentage or a `double`, so no floating-point value
  /// can enter a tax calculation.
  final int standardVatRateBasisPoints;

  /// The ceiling, in paisa, above which an abbreviated retail invoice may not be
  /// used. Rule 17(Ka): NPR 10,000.
  final int abbreviatedInvoiceCeiling;

  /// The total, in paisa, at or above which a buyer's PAN must appear even when
  /// the buyer is an individual and not VAT-registered.
  ///
  /// **This is the figure the sources disagree about** — see
  /// `docs/NEPALI_BILLING.md`. The value used here is the stricter of the two
  /// reported figures, so a bill asks for a PAN slightly more eagerly than
  /// strictly required. That direction was chosen on purpose: over-asking costs a
  /// line on a form, whereas under-asking can cost input credit at audit.
  final int buyerPanThreshold;

  /// VAT record retention, in years. The longer period, and the binding one.
  final int recordRetentionYearsVat;

  /// Income-tax record retention, in years, under Income Tax Act Section 81(2).
  ///
  /// Runs from the **expiry of the income year**, not from the transaction date,
  /// which is why the two must be kept apart.
  final int recordRetentionYearsIncomeTax;

  /// Whether an abbreviated retail invoice may be used for [total].
  ///
  /// **Two conditions, and the second is not the seller's to decide.** A
  /// transaction within the ceiling may use the abbreviated form — but if the
  /// buyer asks for a full tax invoice, one must be issued (Section 14A). This
  /// method answers only the ceiling; the request is reported by
  /// `InvoiceCompliance` rather than decided silently.
  bool mayUseAbbreviatedInvoice(Money total) =>
      total.minorUnits <= abbreviatedInvoiceCeiling;

  /// Whether [total] is at or above the buyer-PAN threshold.
  ///
  /// `>=` rather than `>`, because a threshold is an inclusive boundary and being
  /// wrong on the inclusive case means a missing PAN on a bill that needed one.
  bool buyerPanRequiredByAmount(Money total) =>
      total.minorUnits >= buyerPanThreshold;

  /// The years a fiscal year's records must be kept.
  ///
  /// The **longer** of the two statutory periods, because the shorter one is not
  /// the constraint that binds. A year cannot be deleted until both clocks have
  /// run.
  int get bindingRetentionYears =>
      recordRetentionYearsVat > recordRetentionYearsIncomeTax
          ? recordRetentionYearsVat
          : recordRetentionYearsIncomeTax;
}
