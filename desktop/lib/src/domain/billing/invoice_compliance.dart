import 'business_profile.dart';
import 'customer.dart';
import 'invoice.dart';
import 'nepal_tax_rules.dart';

/// Which of the two invoice forms in Rule 17 an invoice is being issued as.
///
/// **Both are legal, and the choice is not purely the seller's.** A full
/// [taxInvoice] carries everything; an [abbreviatedRetailInvoice] exists for
/// high-volume small retail and is permitted only within a ceiling and only
/// because such a seller deals with cash customers at speed.
enum InvoiceKind {
  /// Rule 17 tax invoice: the complete document.
  taxInvoice,

  /// Rule 17(Ka) abbreviated retail invoice: VAT inclusive, single copy, buyer
  /// PAN optional.
  abbreviatedRetailInvoice,
}

/// One way an invoice fails a statutory requirement.
///
/// Each is a **fact about the document**, not advice, so a screen can show it and
/// the owner can decide. Where sources conflict the conflict is recorded in
/// `docs/NEPALI_BILLING.md`, not resolved silently.
enum InvoiceComplianceIssue {
  /// The seller has no PAN on file. A bill without the supplier's PAN is not a
  /// valid tax bill.
  sellerPanMissing,

  /// The seller is VAT-registered but the invoice carries no VAT at all.
  ///
  /// A VAT-registered business must charge VAT on every taxable supply. An
  /// invoice with a zero rate may be legitimate — zero-rated or exempt goods — but
  /// it is never legitimate by accident.
  vatChargedWhileRegistered,

  /// VAT has been charged at a rate other than the standard rate in force.
  vatRateDiffersFromStandard,

  /// Above the Rule 17(Ka) ceiling, so the abbreviated form may not be used.
  abbreviatedAboveCeiling,

  /// The buyer's PAN is required — registered buyer, a full tax invoice, or a
  /// total at or above the threshold — and it is absent.
  buyerPanMissing,

  /// The buyer's PAN is present but malformed. Treated as absent, because a
  /// malformed PAN is not a PAN and must not appear on the bill.
  buyerPanMalformed,

  /// No authorised signature and seal recorded for the seller.
  sellerSignatureMissing,
}

/// The result of checking an invoice against the rules in force.
///
/// This is deliberately **advisory**: it reports what is missing so a business can
/// decide. Refusing to issue the invoice would be worse — an owner who needs to
/// bill a customer at closing time would be stuck, and would work around the
/// application entirely.
class InvoiceCompliance {
  const InvoiceCompliance._({
    required this.issues,
    required this.rulesVersion,
    required this.kind,
  });

  /// Check [invoice] as issued by [seller] against [rules].
  ///
  /// [buyer] may be null for a sale to a walk-in customer, which is a normal cash
  /// sale; the buyer's PAN checks are then simply not applicable.
  factory InvoiceCompliance.check({
    required Invoice invoice,
    required BusinessProfile seller,
    required NepalTaxRules rules,
    Customer? buyer,
    InvoiceKind kind = InvoiceKind.taxInvoice,
    bool sellerSignatureCaptured = false,
  }) {
    final issues = <InvoiceComplianceIssue>[];

    // The seller's own identity. Without a PAN this is not a valid tax bill at
    // all, so it is reported first: the rest of the checks are moot without it.
    //
    // **Checked on the document, not only on the profile.** The invoice carries a
    // copy of the seller details as they were when it was issued, and that copy is
    // the one printed on the paper. A profile with a PAN does not rescue an
    // invoice that was issued without a snapshot, because the record would still
    // contradict the document if the details later change.
    final stampedPan = invoice.sellerPan;
    if (stampedPan == null || stampedPan.trim().isEmpty) {
      issues.add(InvoiceComplianceIssue.sellerPanMissing);
    } else if (seller.pan == null) {
      issues.add(InvoiceComplianceIssue.sellerPanMissing);
    }

    // A registered business charging no tax on a real sale is the failure an
    // audit looks for first.
    if (seller.isVatRegistered && invoice.subtotal.isPositive) {
      if (invoice.vatRateBasisPoints == 0) {
        issues.add(InvoiceComplianceIssue.vatChargedWhileRegistered);
      } else if (invoice.vatRateBasisPoints !=
          rules.standardVatRateBasisPoints) {
        issues.add(InvoiceComplianceIssue.vatRateDiffersFromStandard);
      }
    }

    if (kind == InvoiceKind.abbreviatedRetailInvoice &&
        !rules.mayUseAbbreviatedInvoice(invoice.total)) {
      issues.add(InvoiceComplianceIssue.abbreviatedAboveCeiling);
    }

    _checkBuyerPan(
      issues,
      invoice: invoice,
      buyer: buyer,
      kind: kind,
      rules: rules,
    );

    if (!sellerSignatureCaptured) {
      issues.add(InvoiceComplianceIssue.sellerSignatureMissing);
    }

    return InvoiceCompliance._(
      issues: List.unmodifiable(issues),
      rulesVersion: rules.version,
      kind: kind,
    );
  }

  /// The buyer's PAN rules, kept separate because they are the most tangled.
  ///
  /// A PAN is required when **any** of these hold: the buyer is VAT-registered,
  /// the document is a full tax invoice (so the Rule 17 ceiling applies), or the
  /// total is at or above the individual threshold.
  ///
  /// **A malformed PAN is reported as missing rather than accepted.** Printing an
  /// invalid PAN gives the appearance of compliance without the substance, and a
  /// bill carrying one is not a valid tax bill — so it is treated as absent and
  /// said so plainly, rather than being quietly formatted into nine digits.
  static void _checkBuyerPan(
    List<InvoiceComplianceIssue> issues, {
    required Invoice invoice,
    required Customer? buyer,
    required InvoiceKind kind,
    required NepalTaxRules rules,
  }) {
    if (buyer == null) return;

    final pan = buyer.pan;
    final required = buyer.isVatRegistered ||
        kind == InvoiceKind.taxInvoice ||
        rules.buyerPanRequiredByAmount(invoice.total);

    if (!required) return;
    if (pan != null) return; // Present and valid.

    // `Customer` rejects a malformed PAN at construction, so reaching here with
    // `pan == null` means genuinely absent. The issue is still reported
    // separately so the wording can say which it was if that ever changes.
    issues.add(InvoiceComplianceIssue.buyerPanMissing);
  }

  /// Everything wrong with the document, in the order reported.
  final List<InvoiceComplianceIssue> issues;

  /// Which rule set produced this verdict, so an invoice can record it.
  final String rulesVersion;

  /// The form the invoice was issued as.
  final InvoiceKind kind;

  /// True when nothing is missing.
  ///
  /// **Read this as "nothing found to be missing", not as legal advice.** The
  /// rules behind it change with the Finance Act, and `docs/NEPALI_BILLING.md`
  /// records what has and has not been verified.
  bool get isCompliant => issues.isEmpty;

  /// The issues, phrased so they can be shown to a user.
  List<String> get messages => issues.map(describe).toList(growable: false);

  /// A plain description of one issue, for a screen.
  static String describe(InvoiceComplianceIssue issue) => switch (issue) {
        InvoiceComplianceIssue.sellerPanMissing =>
          'This business has no PAN on file. A bill without the supplier\'s PAN '
              'is not a valid tax bill.',
        InvoiceComplianceIssue.vatChargedWhileRegistered =>
          'This business is VAT-registered, but no VAT has been charged. That is '
              'valid only if the goods are zero-rated or exempt.',
        InvoiceComplianceIssue.vatRateDiffersFromStandard =>
          'VAT has been charged at a rate other than the standard rate in force.',
        InvoiceComplianceIssue.abbreviatedAboveCeiling =>
          'An abbreviated retail invoice cannot be used above the Rule 17(Ka) '
              'ceiling. Issue a full tax invoice.',
        InvoiceComplianceIssue.buyerPanMissing =>
          'The buyer\'s PAN is required here but was not given.',
        InvoiceComplianceIssue.buyerPanMalformed =>
          'The buyer\'s PAN is not a valid nine-digit number, so it cannot be '
              'printed on the bill.',
        InvoiceComplianceIssue.sellerSignatureMissing =>
          'No authorised signature and seal has been recorded for this invoice.',
      };

  @override
  String toString() =>
      'InvoiceCompliance(${issues.length} issue(s), rules $rulesVersion)';
}
