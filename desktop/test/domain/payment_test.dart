import 'package:financeapp/src/domain/accounting/account.dart';
import 'package:financeapp/src/domain/accounting/account_type.dart';
import 'package:financeapp/src/domain/billing/invoice.dart';
import 'package:financeapp/src/domain/billing/invoice_balance.dart';
import 'package:financeapp/src/domain/billing/invoice_line.dart';
import 'package:financeapp/src/domain/billing/payment.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:flutter_test/flutter_test.dart';

const npr = 'NPR';

Money rs(int majorUnits) => Money.minor(majorUnits * 100, npr);

DateTime day(int d) => DateTime(2026, 9, d);

const bank = Account(
    id: 'acct-bank', code: '1010', name: 'Bank', type: AccountType.asset);
const sales = Account(
    id: 'acct-sales-revenue',
    code: '4010',
    name: 'Sales Revenue',
    type: AccountType.income);

Invoice invoiceOf(int totalRupees) => Invoice(
      id: 'INV-1',
      issueDate: day(1),
      customerId: 'cust-1',
      lines: [
        InvoiceLine(
          description: 'item',
          quantity: 1,
          unitPrice: rs(totalRupees),
        ),
      ],
      vatRateBasisPoints: 0,
    );

Payment paymentOf(int amountRupees, {String id = 'PAY-1'}) => Payment(
      id: id,
      invoiceId: 'INV-1',
      date: day(15),
      amount: rs(amountRupees),
      account: bank,
    );

void main() {
  group('Payment construction', () {
    test('accepts a well-formed payment', () {
      final payment = paymentOf(500);

      expect(payment.id, 'PAY-1');
      expect(payment.invoiceId, 'INV-1');
      expect(payment.amount.minorUnits, 50000);
      expect(payment.currency, npr);
      expect(payment.account, bank);
    });

    test('a blank id is rejected', () {
      expect(
        () => Payment(
          id: '  ',
          invoiceId: 'INV-1',
          date: day(15),
          amount: rs(500),
          account: bank,
        ),
        throwsArgumentError,
      );
    });

    test('a missing invoice id is rejected', () {
      expect(
        () => Payment(
          id: 'PAY-1',
          invoiceId: '',
          date: day(15),
          amount: rs(500),
          account: bank,
        ),
        throwsArgumentError,
      );
    });

    test('a zero amount is rejected', () {
      expect(() => paymentOf(0), throwsArgumentError);
    });

    test('a negative amount is rejected', () {
      expect(
        () => Payment(
          id: 'PAY-1',
          invoiceId: 'INV-1',
          date: day(15),
          amount: Money.minor(-50000, npr),
          account: bank,
        ),
        throwsArgumentError,
      );
    });

    test('receiving into an income account is rejected', () {
      // Money does not "arrive in" revenue. A payment must land in a balance
      // sheet account such as Bank or Cash, or the double entry is nonsense.
      expect(
        () => Payment(
          id: 'PAY-1',
          invoiceId: 'INV-1',
          date: day(15),
          amount: rs(500),
          account: sales,
        ),
        throwsArgumentError,
      );
    });

    test('compares by id', () {
      expect(paymentOf(500), paymentOf(999));
      expect(
        paymentOf(500).hashCode,
        paymentOf(999).hashCode,
      );
      expect(paymentOf(500, id: 'PAY-1'), isNot(paymentOf(500, id: 'PAY-2')));
    });
  });

  group('InvoiceBalance', () {
    test('an unpaid invoice owes its full total', () {
      final balance = InvoiceBalance.of(invoiceOf(1130), const []);

      expect(balance.invoiceTotal.minorUnits, 113000);
      expect(balance.received.isZero, isTrue);
      expect(balance.outstanding.minorUnits, 113000);
      expect(balance.isSettled, isFalse);
      expect(balance.isPartiallyPaid, isFalse);
    });

    test('a partial payment leaves the correct remainder', () {
      // Hand-computed: Rs 1,130 - Rs 500 = Rs 630 = 63,000 paisa.
      final balance = InvoiceBalance.of(invoiceOf(1130), [paymentOf(500)]);

      expect(balance.received.minorUnits, 50000);
      expect(balance.outstanding.minorUnits, 63000);
      expect(balance.isPartiallyPaid, isTrue);
      expect(balance.isSettled, isFalse);
    });

    test('several partial payments accumulate', () {
      final balance = InvoiceBalance.of(invoiceOf(1000), [
        paymentOf(300, id: 'PAY-1'),
        paymentOf(200, id: 'PAY-2'),
        paymentOf(100, id: 'PAY-3'),
      ]);

      expect(balance.received.minorUnits, 60000);
      expect(balance.outstanding.minorUnits, 40000);
    });

    test('a full settlement leaves exactly zero outstanding', () {
      final balance = InvoiceBalance.of(invoiceOf(1130), [paymentOf(1130)]);

      expect(balance.received.minorUnits, 113000);
      expect(balance.outstanding.isZero, isTrue);
      expect(balance.isSettled, isTrue);
      expect(balance.isPartiallyPaid, isFalse);
    });

    test('the balance is derived, so it cannot disagree with its payments', () {
      // The same payments always produce the same balance, because nothing is
      // stored to drift out of step.
      final invoice = invoiceOf(1000);
      final payments = [
        paymentOf(250, id: 'PAY-1'),
        paymentOf(250, id: 'PAY-2')
      ];

      expect(
        InvoiceBalance.of(invoice, payments).outstanding,
        InvoiceBalance.of(invoice, payments).outstanding,
      );
      expect(
        InvoiceBalance.of(invoice, payments).outstanding.minorUnits,
        50000,
      );
    });
  });
}
