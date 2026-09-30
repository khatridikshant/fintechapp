import 'package:financeapp/src/domain/billing/invoice.dart';
import 'package:financeapp/src/domain/billing/invoice_line.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:flutter_test/flutter_test.dart';

const npr = 'NPR';

Money rs(int majorUnits) => Money.minor(majorUnits * 100, npr);

DateTime day(int d) => DateTime(2026, 9, d);

InvoiceLine line(int quantity, int unitPriceRupees,
        {String description = 'item'}) =>
    InvoiceLine(
      description: description,
      quantity: quantity,
      unitPrice: rs(unitPriceRupees),
    );

Invoice invoiceWith(List<InvoiceLine> lines, {int? vatRate}) => Invoice(
      id: 'INV-1',
      issueDate: day(15),
      customerId: 'cust-1',
      lines: lines,
      vatRateBasisPoints: vatRate ?? Invoice.vatStandardRate,
    );

void main() {
  group('InvoiceLine', () {
    test('a line total is unit price times quantity', () {
      expect(line(2, 300).lineTotal.minorUnits, 60000);
      expect(line(1, 400).lineTotal.minorUnits, 40000);
      expect(line(7, 125).lineTotal.minorUnits, 87500);
    });

    test('a quantity of zero is rejected', () {
      expect(
        () => InvoiceLine(description: 'x', quantity: 0, unitPrice: rs(100)),
        throwsArgumentError,
      );
    });

    test('a negative quantity is rejected', () {
      expect(
        () => InvoiceLine(description: 'x', quantity: -1, unitPrice: rs(100)),
        throwsArgumentError,
      );
    });

    test('a zero or negative unit price is rejected', () {
      expect(
        () => InvoiceLine(description: 'x', quantity: 1, unitPrice: rs(0)),
        throwsArgumentError,
      );
      expect(
        () => InvoiceLine(
          description: 'x',
          quantity: 1,
          unitPrice: Money.minor(-100, npr),
        ),
        throwsArgumentError,
      );
    });

    test('an empty description is rejected', () {
      expect(
        () => InvoiceLine(
          description: '   ',
          quantity: 1,
          unitPrice: rs(100),
        ),
        throwsArgumentError,
      );
    });
  });

  group('Invoice totals', () {
    test('a single line at Rs 1,000 with 13% VAT', () {
      final invoice = invoiceWith([line(1, 1000)]);

      // Hand-computed: 1,000.00 -> 100,000 paisa.
      // VAT 13% of 100,000 = 13,000 paisa.
      // Total = 113,000 paisa.
      expect(invoice.subtotal.minorUnits, 100000);
      expect(invoice.vat.minorUnits, 13000);
      expect(invoice.total.minorUnits, 113000);
    });

    test('VAT is charged on the combined subtotal, not per line', () {
      final invoice = invoiceWith([line(2, 300), line(1, 400)]);

      // 2 x 300 = 600, 1 x 400 = 400, subtotal 1,000.00.
      expect(invoice.subtotal.minorUnits, 100000);
      expect(invoice.vat.minorUnits, 13000);
      expect(invoice.total.minorUnits, 113000);
      expect(invoice.lines.length, 2);
    });

    test('the total is always subtotal plus VAT', () {
      final invoice = invoiceWith([line(3, 249), line(5, 17)]);
      expect(
        invoice.subtotal.add(invoice.vat),
        invoice.total,
      );
    });

    test('VAT rounds half-up to the nearest paisa', () {
      // Rs 1.50 = 150 paisa. 13% = 19.5 paisa, which must round to 20, not 19.
      // Truncation here would understate tax owed, which is a real-world problem
      // rather than a cosmetic one.
      final invoice = invoiceWith([
        InvoiceLine(
          description: 'small item',
          quantity: 1,
          unitPrice: Money.minor(150, npr),
        ),
      ]);

      expect(invoice.vat.minorUnits, 20);
      expect(invoice.total.minorUnits, 170);
    });

    test('a zero VAT rate produces no VAT', () {
      final invoice = invoiceWith([line(1, 1000)], vatRate: 0);

      expect(invoice.subtotal.minorUnits, 100000);
      expect(invoice.vat.isZero, isTrue);
      expect(invoice.total.minorUnits, 100000);
    });

    test('a negative VAT rate is rejected', () {
      expect(
        () => invoiceWith([line(1, 1000)], vatRate: -100),
        throwsArgumentError,
      );
    });

    test('the currency comes from the lines', () {
      expect(invoiceWith([line(1, 1000)]).currency, npr);
    });

    test('mixing currencies is rejected', () {
      expect(
        () => invoiceWith([
          line(1, 1000),
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

  group('Invoice validation', () {
    test('an invoice with no lines is rejected', () {
      expect(
        () => invoiceWith([]),
        throwsArgumentError,
      );
    });

    test('an invoice without a customer is rejected', () {
      expect(
        () => Invoice(
          id: 'INV-1',
          issueDate: day(15),
          customerId: '  ',
          lines: [line(1, 100)],
        ),
        throwsArgumentError,
      );
    });

    test('an invoice without an id is rejected', () {
      expect(
        () => Invoice(
          id: '',
          issueDate: day(15),
          customerId: 'cust-1',
          lines: [line(1, 100)],
        ),
        throwsArgumentError,
      );
    });

    test('the lines are immutable', () {
      final invoice = invoiceWith([line(1, 100)]);
      expect(
        () => invoice.lines.add(line(1, 100)),
        throwsUnsupportedError,
      );
    });

    test('the source list cannot be used to mutate the invoice', () {
      final source = <InvoiceLine>[line(1, 100)];
      final invoice = invoiceWith(source);
      source.clear();
      expect(invoice.lines.length, 1);
    });

    test('the standard VAT rate is 13 percent', () {
      expect(Invoice.vatStandardRate, 1300,
          reason: 'Nepal charges 13% VAT; basis points keep it exact');
    });
  });
}
