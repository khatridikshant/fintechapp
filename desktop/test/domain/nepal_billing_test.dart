import 'package:financeapp/src/domain/billing/amount_in_words.dart';
import 'package:financeapp/src/domain/billing/business_profile.dart';
import 'package:financeapp/src/domain/billing/customer.dart';
import 'package:financeapp/src/domain/billing/hs_code.dart';
import 'package:financeapp/src/domain/billing/invoice.dart';
import 'package:financeapp/src/domain/billing/invoice_compliance.dart';
import 'package:financeapp/src/domain/billing/invoice_line.dart';
import 'package:financeapp/src/domain/billing/nepal_tax_rules.dart';
import 'package:financeapp/src/domain/billing/nepali_pan.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the Nepali billing rules.
///
/// The rules behind these are recorded with their sources in
/// `docs/NEPALI_BILLING.md`. **Where the sources conflict, the test says so** and
/// pins the conservative behaviour, rather than pretending the law is settled.
///
/// Most of these are about *boundaries*, because that is where a compliance rule
/// is actually lost: a ceiling tested with `<=` and written as `<` is not a bug in
/// the test, it is a tax bill issued in the wrong form.
void main() {
  const pan = '301234567';

  final registeredSeller = BusinessProfile(
    name: 'Sharma Electronics Pvt. Ltd.',
    panNumber: pan,
    isVatRegistered: true,
    address: 'New Road, Kathmandu',
  );

  /// A seller with no PAN. Cannot issue a valid tax bill at all.
  final panlessSeller = BusinessProfile(name: 'Not Registered Yet');

  /// Builds an invoice with an exact unit price, so a test can land a total
  /// precisely on a boundary. Going through whole rupees cannot: VAT is rounded,
  /// so `rupees * 1.13` lands on the ceiling only for some inputs, and a test
  /// that assumes otherwise silently stops testing the boundary.
  ///
  /// Declared before [anInvoice] because Dart does not hoist local functions.
  Invoice anInvoicePriced(Money unitPrice, [int vatRateBasisPoints = 1300]) =>
      Invoice(
        id: 'inv-1',
        issueDate: DateTime(2026, 3, 23),
        customerId: 'cus-1',
        vatRateBasisPoints: vatRateBasisPoints,
        lines: [
          InvoiceLine(
            description: 'Keyboard',
            quantity: 1,
            unitPrice: unitPrice,
          ),
        ],
      );

  Invoice anInvoice({
    int rupees = 100000,
    int vatRateBasisPoints = 1300,
  }) =>
      anInvoicePriced(Money.fromMajorUnits(rupees, 'NPR'), vatRateBasisPoints);

  group('PAN handling', () {
    test('accepts nine digits', () {
      expect(NepaliPan.tryParse(pan)?.digits, pan);
    });

    test('accepts the grouped form a PAN is written in', () {
      expect(NepaliPan.tryParse('301-234-567')?.digits, pan);
      expect(NepaliPan.tryParse('301 234 567')?.digits, pan);
    });

    test('rejects a wrong length rather than storing it', () {
      expect(NepaliPan.tryParse('30123456'), isNull);
      expect(NepaliPan.tryParse('3012345678'), isNull);
    });

    test('rejects letters and stray punctuation', () {
      // A PAN pasted out of a PDF must not smuggle in anything but digits.
      expect(NepaliPan.tryParse('30123A567'), isNull);
      expect(NepaliPan.tryParse('301/234/567'), isNull);
      expect(NepaliPan.tryParse('abc'), isNull);
    });

    test('treats blank and null as absent, not as a value', () {
      expect(NepaliPan.tryParse(null), isNull);
      expect(NepaliPan.tryParse(''), isNull);
      expect(NepaliPan.tryParse('   '), isNull);
    });

    test('groups for printing without storing a second representation', () {
      expect(NepaliPan.tryParse(pan)!.grouped, '301-234-567');
    });

    test('a customer with a malformed PAN is refused, not silently panless',
        () {
      // Silently dropping it would let an invalid PAN reach a printed bill, where
      // it looks compliant and is not.
      expect(
        () => Customer(id: 'c1', name: 'X', panNumber: '30123A567'),
        throwsArgumentError,
      );
    });

    test('a VAT-registered customer must have a PAN', () {
      // In Nepal the VAT number *is* the PAN with a registration flag.
      expect(
        () => Customer(id: 'c1', name: 'X', isVatRegistered: true),
        throwsArgumentError,
      );
    });

    test('an individual with no PAN is a normal, supported customer', () {
      final walkIn = Customer(id: 'c1', name: 'Ram Bahadur');
      expect(walkIn.hasPan, isFalse);
      expect(walkIn.pan, isNull);
    });

    test('the business code is quoted, never the internal id', () {
      final business = Customer(id: 'c1', code: 'C-0001', name: 'Ram Bahadur');
      expect(business.displayReference, 'C-0001');

      // With no code, the name is the best a person can quote.
      expect(Customer(id: 'c2', name: 'Sita').displayReference, 'Sita');
    });
  });

  group('the seller side of Rule 17', () {
    test('a business with no PAN cannot issue a valid tax bill', () {
      final compliance = InvoiceCompliance.check(
        invoice: anInvoice(),
        seller: panlessSeller,
        rules: NepalTaxRules.current,
        sellerSignatureCaptured: true,
      );

      expect(
        compliance.issues,
        contains(InvoiceComplianceIssue.sellerPanMissing),
      );
      expect(compliance.isCompliant, isFalse);
      expect(compliance.messages.single, contains('not a valid tax bill'));
    });

    test('a registered seller must charge VAT', () {
      final compliance = InvoiceCompliance.check(
        invoice: anInvoice(vatRateBasisPoints: 0),
        seller: registeredSeller,
        rules: NepalTaxRules.current,
        sellerSignatureCaptured: true,
      );

      expect(
        compliance.issues,
        contains(InvoiceComplianceIssue.vatChargedWhileRegistered),
      );
    });

    test('a registered seller charging a non-standard rate is reported', () {
      final compliance = InvoiceCompliance.check(
        invoice: anInvoice(vatRateBasisPoints: 500),
        seller: registeredSeller,
        rules: NepalTaxRules.current,
        sellerSignatureCaptured: true,
      );

      expect(
        compliance.issues,
        contains(InvoiceComplianceIssue.vatRateDiffersFromStandard),
      );
    });

    test('an un-registered seller charging no VAT is not reported', () {
      // The majority of small Nepali businesses are not VAT-registered, and an
      // invoice must not be flagged for a tax it was never liable to charge.
      final compliance = InvoiceCompliance.check(
        invoice: anInvoice(vatRateBasisPoints: 0),
        seller: BusinessProfile(name: 'Small Shop', panNumber: pan),
        rules: NepalTaxRules.current,
        sellerSignatureCaptured: true,
      );

      expect(compliance.issues, isEmpty);
    });

    test('a missing signature and seal is reported', () {
      final compliance = InvoiceCompliance.check(
        invoice: anInvoice(),
        seller: registeredSeller,
        rules: NepalTaxRules.current,
      );

      expect(
        compliance.issues,
        contains(InvoiceComplianceIssue.sellerSignatureMissing),
      );
    });
  });

  group('the abbreviated retail invoice, Rule 17(Ka)', () {
    final ceiling = NepalTaxRules.current.abbreviatedInvoiceCeiling;

    test('is allowed at the ceiling itself', () {
      // Boundary tested as inclusive, because "up to NPR 10,000" means up to and
      // including. Getting this wrong issues the wrong document form.
      //
      // Rs 8,849.56 of goods plus 13% VAT (Rs 1,150.44) is exactly Rs 10,000.00.
      // Asserted on the total first, so a change to the VAT calculation cannot
      // quietly stop this testing the boundary.
      final atCeiling = anInvoicePriced(Money.fromMajorUnits(8849.56, 'NPR'));
      expect(atCeiling.total.minorUnits, ceiling);
      expect(
        NepalTaxRules.current.mayUseAbbreviatedInvoice(atCeiling.total),
        isTrue,
        reason: 'the ceiling is inclusive',
      );
    });

    test('is refused one paisa above the ceiling', () {
      expect(
        NepalTaxRules.current.mayUseAbbreviatedInvoice(
          Money.minor(ceiling + 1, 'NPR'),
        ),
        isFalse,
      );
    });

    test('is refused when the total is above the ceiling', () {
      final invoice = anInvoice(rupees: 50000);
      expect(invoice.total.minorUnits, greaterThan(ceiling));

      final compliance = InvoiceCompliance.check(
        invoice: invoice,
        seller: registeredSeller,
        rules: NepalTaxRules.current,
        kind: InvoiceKind.abbreviatedRetailInvoice,
        sellerSignatureCaptured: true,
      );

      expect(
        compliance.issues,
        contains(InvoiceComplianceIssue.abbreviatedAboveCeiling),
      );
    });

    test('a full tax invoice is never reported as over the ceiling', () {
      final compliance = InvoiceCompliance.check(
        invoice: anInvoice(rupees: 50000),
        seller: registeredSeller,
        rules: NepalTaxRules.current,
        kind: InvoiceKind.taxInvoice,
        sellerSignatureCaptured: true,
      );

      expect(
        compliance.issues,
        isNot(contains(InvoiceComplianceIssue.abbreviatedAboveCeiling)),
      );
    });
  });

  group("the buyer's PAN", () {
    test('is required when the buyer is VAT-registered', () {
      final noPanBuyer = Customer(id: 'cus-3', name: 'Some Firm');

      final compliance = InvoiceCompliance.check(
        invoice: anInvoice(rupees: 200),
        seller: registeredSeller,
        buyer: noPanBuyer,
        rules: NepalTaxRules.current,
        kind: InvoiceKind.taxInvoice,
        sellerSignatureCaptured: true,
      );

      expect(
        compliance.issues,
        contains(InvoiceComplianceIssue.buyerPanMissing),
      );
    });

    test('is required on a full tax invoice above the threshold', () {
      final compliance = InvoiceCompliance.check(
        invoice: anInvoice(rupees: 500000),
        seller: registeredSeller,
        buyer: Customer(id: 'cus-2', name: 'Ram Bahadur'),
        rules: NepalTaxRules.current,
        kind: InvoiceKind.taxInvoice,
        sellerSignatureCaptured: true,
      );

      expect(
        compliance.issues,
        contains(InvoiceComplianceIssue.buyerPanMissing),
      );
    });

    test('is not required for a small cash sale', () {
      final compliance = InvoiceCompliance.check(
        invoice: anInvoice(rupees: 100),
        seller: registeredSeller,
        buyer: Customer(id: 'cus-2', name: 'Ram Bahadur'),
        rules: NepalTaxRules.current,
        kind: InvoiceKind.abbreviatedRetailInvoice,
        sellerSignatureCaptured: true,
      );

      expect(
        compliance.issues,
        isNot(contains(InvoiceComplianceIssue.buyerPanMissing)),
        reason: 'a walk-in cash sale under the ceiling needs no PAN',
      );
    });

    test('is not required when there is no buyer at all', () {
      final compliance = InvoiceCompliance.check(
        invoice: anInvoice(rupees: 500000),
        seller: registeredSeller,
        rules: NepalTaxRules.current,
        sellerSignatureCaptured: true,
      );

      expect(
        compliance.issues,
        isNot(contains(InvoiceComplianceIssue.buyerPanMissing)),
      );
    });

    test('a present and valid PAN produces no issue', () {
      final compliance = InvoiceCompliance.check(
        invoice: anInvoice(rupees: 500000),
        seller: registeredSeller,
        buyer: Customer(
          id: 'cus-1',
          name: 'XYZ Suppliers',
          panNumber: pan,
          isVatRegistered: true,
        ),
        rules: NepalTaxRules.current,
        sellerSignatureCaptured: true,
      );

      expect(compliance.isCompliant, isTrue);
    });
  });

  group('the rules travel as data, not as constants', () {
    test('a different VAT rate changes the verdict without a code change', () {
      // This is the specification's requirement: rules "shall not be treated as
      // permanently fixed application constants".
      final futureRates = NepalTaxRules(
        version: 'test/future',
        standardVatRateBasisPoints: 1500,
        abbreviatedInvoiceCeiling: 5000000,
        buyerPanThreshold: 20000000,
        recordRetentionYearsVat: 7,
        recordRetentionYearsIncomeTax: 5,
      );

      final compliance = InvoiceCompliance.check(
        invoice: anInvoice(vatRateBasisPoints: 1300),
        seller: registeredSeller,
        rules: futureRates,
        sellerSignatureCaptured: true,
      );

      expect(
        compliance.issues,
        contains(InvoiceComplianceIssue.vatRateDiffersFromStandard),
      );
      expect(compliance.rulesVersion, 'test/future');
    });

    test('VAT retention binds over income-tax retention', () {
      const rules = NepalTaxRules.current;
      expect(
        rules.recordRetentionYearsVat,
        greaterThan(rules.recordRetentionYearsIncomeTax),
      );
      expect(rules.bindingRetentionYears, rules.recordRetentionYearsVat);
    });
  });

  group('amount in words, required by Rule 17', () {
    test('writes whole rupees', () {
      expect(
        amountInWords(Money.fromMajorUnits(1, 'NPR')),
        'Rupees One Rupees Only',
      );
    });

    test('uses lakh and crore, not million and billion', () {
      // Those are the units Nepali invoices and cheque books are written in.
      expect(
        amountInWords(Money.fromMajorUnits(100000, 'NPR')),
        contains('One Lakh'),
      );
      expect(
        amountInWords(Money.fromMajorUnits(10000000, 'NPR')),
        contains('One Crore'),
      );
    });

    test('writes paisa separately rather than as words', () {
      expect(
        amountInWords(Money.fromMajorUnits(112345.45, 'NPR')),
        'Rupees One Lakh Twelve Thousand Three Hundred Forty Five '
        'Rupees and 45 Paisa Only',
      );
    });

    test('handles zero', () {
      expect(
        amountInWords(Money.fromMajorUnits(0, 'NPR')),
        'Rupees Zero Rupees Only',
      );
    });

    test('marks a negative amount', () {
      expect(
        amountInWords(Money.fromMajorUnits(-50, 'NPR')),
        startsWith('Minus '),
      );
    });

    test('never introduces a floating point value', () {
      // The value must come from integer minor units throughout.
      expect(amountInWords(Money.fromMajorUnits(19.99, 'NPR')),
          contains('99 Paisa'));
    });
  });

  group('HS code, added by the 46th amendment', () {
    test('accepts a code with at least four digits', () {
      expect(HsCode.tryParse('8471')?.digits, '8471');
      expect(HsCode.tryParse('8471.30')?.digits, '847130');
    });

    test('exposes the four-digit heading the invoice carries', () {
      expect(HsCode.tryParse('84713010')!.heading, '8471');
    });

    test('rejects a malformed code rather than printing it', () {
      expect(HsCode.tryParse('847'), isNull);
      expect(HsCode.tryParse('8471ABC0'), isNull);
    });

    test('is absent for a service, which is not an error', () {
      expect(HsCode.tryParse(null), isNull);
    });
  });
}
