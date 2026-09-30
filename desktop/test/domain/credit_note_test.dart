import 'package:financeapp/src/domain/billing/credit_note.dart';
import 'package:financeapp/src/domain/billing/invoice.dart';
import 'package:financeapp/src/domain/billing/invoice_balance.dart';
import 'package:financeapp/src/domain/billing/invoice_line.dart';
import 'package:financeapp/src/domain/billing/payment.dart';
import 'package:financeapp/src/domain/accounting/account.dart';
import 'package:financeapp/src/domain/accounting/account_type.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:flutter_test/flutter_test.dart';

const npr = 'NPR';

Money rs(int majorUnits) => Money.minor(majorUnits * 100, npr);

DateTime day(int d) => DateTime(2026, 9, d);

const bank = Account(
    id: 'acct-bank', code: '1010', name: 'Bank', type: AccountType.asset);

InvoiceLine line(int quantity, int unitPriceRupees,
        {String description = 'item'}) =>
    InvoiceLine(
      description: description,
      quantity: quantity,
      unitPrice: rs(unitPriceRupees),
    );

CreditNote creditOf(List<InvoiceLine> lines, {int? vatRate}) => CreditNote(
      id: 'CRN-1',
      invoiceId: 'INV-1',
      date: day(15),
      lines: lines,
      vatRateBasisPoints: vatRate ?? CreditNote.standardVatRate,
    );

Invoice invoiceOf(int totalRupees, {int vatRate = 0}) => Invoice(
      id: 'INV-1',
      issueDate: day(1),
      customerId: 'cust-1',
      lines: [line(1, totalRupees)],
      vatRateBasisPoints: vatRate,
    );

Payment paymentOf(int amountRupees, {String id = 'PAY-1'}) => Payment(
      id: id,
      invoiceId: 'INV-1',
      date: day(15),
      amount: rs(amountRupees),
      account: bank,
    );

void main() {
  group('CreditNote totals', () {
    test('mirrors an invoice: subtotal, VAT on the combined subtotal, total',
        () {
      final note = creditOf([line(1, 1000)]);

      // Rs 1,000 -> 100,000 paisa; VAT 13% -> 13,000; total 113,000.
      expect(note.subtotal.minorUnits, 100000);
      expect(note.vat.minorUnits, 13000);
      expect(note.total.minorUnits, 113000);
    });

    test('VAT is charged on the combined subtotal, not per line', () {
      final note = creditOf([line(2, 300), line(1, 400)]);

      expect(note.subtotal.minorUnits, 100000);
      expect(note.vat.minorUnits, 13000);
      expect(note.total.minorUnits, 113000);
    });

    test('a partial credit produces the matching fraction of VAT', () {
      // Rs 500 -> 50,000 paisa; VAT 13% -> 6,500; total 56,500.
      final note = creditOf([line(1, 500)]);

      expect(note.subtotal.minorUnits, 50000);
      expect(note.vat.minorUnits, 6500);
      expect(note.total.minorUnits, 56500);
    });

    test('a zero-rated credit note produces no VAT', () {
      final note = creditOf([line(1, 1000)], vatRate: 0);

      expect(note.subtotal.minorUnits, 100000);
      expect(note.vat.isZero, isTrue);
      expect(note.total.minorUnits, 100000);
    });

    test('the standard VAT rate matches the invoice standard rate', () {
      // The two constants must agree, or a credit note would reverse a
      // different amount of tax than the invoice charged.
      expect(CreditNote.standardVatRate, Invoice.vatStandardRate);
    });

    test('the currency comes from the lines', () {
      expect(creditOf([line(1, 100)]).currency, npr);
    });

    test('mixing currencies is rejected', () {
      expect(
        () => creditOf([
          line(1, 100),
          InvoiceLine(
            description: 'foreign',
            quantity: 1,
            unitPrice: const Money.minor(100, 'USD'),
          ),
        ]),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });
  });

  group('CreditNote validation', () {
    test('an id is required', () {
      expect(
        () => CreditNote(
          id: '  ',
          invoiceId: 'INV-1',
          date: day(15),
          lines: [line(1, 100)],
        ),
        throwsArgumentError,
      );
    });

    test('the invoice being credited is required', () {
      // A correction with no original document cannot be audited.
      expect(
        () => CreditNote(
          id: 'CRN-1',
          invoiceId: '',
          date: day(15),
          lines: [line(1, 100)],
        ),
        throwsArgumentError,
      );
    });

    test('at least one line is required', () {
      expect(() => creditOf([]), throwsArgumentError);
    });

    test('a negative VAT rate is rejected', () {
      expect(
        () => creditOf([line(1, 100)], vatRate: -100),
        throwsArgumentError,
      );
    });

    test('the lines are immutable', () {
      final note = creditOf([line(1, 100)]);
      expect(() => note.lines.add(line(1, 100)), throwsUnsupportedError);
    });

    test('compares by id', () {
      expect(creditOf([line(1, 100)]), creditOf([line(1, 999)]));
    });
  });

  group('InvoiceBalance with credit notes', () {
    test('an uncredited invoice has the full amount uncredited', () {
      final balance = InvoiceBalance.of(invoiceOf(1000), const []);

      expect(balance.credited.isZero, isTrue);
      expect(balance.uncredited.minorUnits, 100000);
      expect(balance.isFullyCredited, isFalse);
    });

    test('a credit note reduces both outstanding and uncredited', () {
      final balance = InvoiceBalance.of(
        invoiceOf(1000),
        const [],
        creditNotes: [
          creditOf([line(1, 400)], vatRate: 0)
        ],
      );

      expect(balance.credited.minorUnits, 40000);
      expect(balance.outstanding.minorUnits, 60000);
      expect(balance.uncredited.minorUnits, 60000);
    });

    test('credits do not change what was received', () {
      final balance = InvoiceBalance.of(
        invoiceOf(1000),
        [paymentOf(500)],
        creditNotes: [
          creditOf([line(1, 200)], vatRate: 0)
        ],
      );

      expect(balance.received.minorUnits, 50000);
      expect(balance.credited.minorUnits, 20000);
      expect(balance.outstanding.minorUnits, 30000);
      // Uncredited ignores payments: the invoice can still be credited for what
      // has not been credited, even though part of it has been paid.
      expect(balance.uncredited.minorUnits, 80000);
    });

    test('a paid invoice can still be credited, leaving a refund due', () {
      // This is the case the ceiling must allow: bound by the uncredited amount
      // rather than by what is still owed, or a fully paid invoice could never
      // be corrected.
      final balance = InvoiceBalance.of(
        invoiceOf(1000),
        [paymentOf(1000)],
        creditNotes: [
          creditOf([line(1, 1000)], vatRate: 0)
        ],
      );

      expect(balance.outstanding.minorUnits, -100000);
      expect(balance.isRefundDue, isTrue);
      expect(balance.refundDue.minorUnits, 100000);
      expect(balance.isSettled, isFalse);
    });

    test('a full credit with no payment settles the invoice', () {
      final balance = InvoiceBalance.of(
        invoiceOf(1000),
        const [],
        creditNotes: [
          creditOf([line(1, 1000)], vatRate: 0)
        ],
      );

      expect(balance.outstanding.isZero, isTrue);
      expect(balance.isSettled, isTrue);
      expect(balance.isFullyCredited, isTrue);
      expect(balance.refundDue.isZero, isTrue);
    });
  });
}
