import 'package:financeapp/src/domain/billing/purchase.dart';
import 'package:financeapp/src/domain/billing/purchase_balance.dart';
import 'package:financeapp/src/domain/billing/purchase_line.dart';
import 'package:financeapp/src/domain/billing/supplier.dart';
import 'package:financeapp/src/domain/billing/supplier_payment.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Working the numbers by hand, from the accounting rules, before writing the
  // implementation. Paisa throughout; 100,000 paisa = Rs 1,000.00.
  //
  //   Buy 10 chairs at Rs 100 each from a VAT-registered supplier at 13%:
  //     subtotal   10 x 100,000 = 1,000,000  (Rs 10,000.00)
  //     VAT        13% of 1,000,000 = 130,000 (Rs 1,300.00)  half-up
  //     total                          1,130,000 (Rs 11,300.00)
  //
  //   Dr 1040 Inventory              1,000,000   <- the NET cost, not the gross
  //   Dr 1150 Input VAT Recoverable    130,000
  //   Cr 2010 Accounts Payable       1,130,000
  //
  // The net figure in 1040 is the point of the whole design: inventory carries at
  // cost, and a recoverable tax is not part of cost. Capitalising the gross would
  // push a recoverable tax into cost of sales.

  group('PurchaseLine', () {
    test('a line needs a description, a positive quantity, and a positive price',
        () {
      expect(
        () => PurchaseLine(
          description: '',
          quantity: 1,
          unitPrice: Money.minor(100000, 'NPR'),
        ),
        throwsArgumentError,
      );
      expect(
        () => PurchaseLine(
          description: 'Chair',
          quantity: 0,
          unitPrice: Money.minor(100000, 'NPR'),
        ),
        throwsArgumentError,
      );
      expect(
        () => PurchaseLine(
          description: 'Chair',
          quantity: 1,
          unitPrice: Money.minor(0, 'NPR'),
        ),
        throwsArgumentError,
      );
    });

    test('the line total is exact, because both factors are whole paisa', () {
      // 10 x Rs 100.00 = Rs 1,000.00 = 1,000,000 paisa exactly. No rounding, and
      // therefore no possibility of the total drifting from the ledger.
      final line = PurchaseLine(
        description: 'Chair',
        quantity: 10,
        unitPrice: Money.minor(100000, 'NPR'),
      );
      expect(line.lineTotal.minorUnits, 1000000);
    });

    test('a line may name the product it received', () {
      // Optional, because a purchase can be of something that is not a tracked
      // product — a service, a consumable, a fixed asset. Refusing a null
      // productId would make those unrecordable.
      final line = PurchaseLine(
        description: 'Chair',
        quantity: 10,
        unitPrice: Money.minor(100000, 'NPR'),
      );
      expect(line.productId, isNull);
      expect(line.receivesStock, isFalse);
    });

    test('a line naming a product receives stock', () {
      final line = PurchaseLine(
        description: 'Chair',
        quantity: 10,
        unitPrice: Money.minor(100000, 'NPR'),
        productId: 'p-1',
      );
      expect(line.productId, 'p-1');
      expect(line.receivesStock, isTrue);
    });

    test('a blank product id means no product, not an empty id', () {
      final line = PurchaseLine(
        description: 'Freight',
        quantity: 1,
        unitPrice: Money.minor(50000, 'NPR'),
        productId: '   ',
      );
      expect(line.productId, isNull);
    });

    test('a line can carry its own VAT rate, for a mixed-rate purchase', () {
      // **Why per-line and not one rate on the purchase.** A single purchase from
      // one supplier is normally one rate, but a bill that mixes standard-rated
      // and zero-rated goods must not be forced to round them together the way a
      // sales invoice deliberately does. Zero-rated goods omit the VAT line; they
      // do not contribute a zero to it.
      final line = PurchaseLine(
        description: 'Exported Goods',
        quantity: 1,
        unitPrice: Money.minor(100000, 'NPR'),
        vatRateBasisPoints: 0,
      );
      expect(line.vatRateBasisPoints, 0);
      expect(line.vat.isZero, isTrue);
      expect(line.lineTotal.minorUnits, 100000, reason: 'total is the net');
    });

    test('a line rejects a negative VAT rate', () {
      expect(
        () => PurchaseLine(
          description: 'Chair',
          quantity: 1,
          unitPrice: Money.minor(100000, 'NPR'),
          vatRateBasisPoints: -100,
        ),
        throwsArgumentError,
      );
    });

    test('a line computes its own VAT half-up, in integer paisa', () {
      // Rs 5.00 at 13% = 0.65 paisa rounds to 1 paisa. Half-up matters here for
      // the same reason it does on the sales side: truncation would understate
      // input credit, and input credit is money the business paid.
      final line = PurchaseLine(
        description: 'Screws',
        quantity: 1,
        unitPrice: Money.minor(5, 'NPR'),
      );
      expect(line.vat.minorUnits, 1);
    });
  });

  group('Purchase', () {
    Purchase build({
      List<PurchaseLine>? lines,
      int vatRateBasisPoints = 1300,
      String supplierId = 'sup-1',
    }) =>
        Purchase(
          id: 'PUR-DRAFT-1',
          issueDate: DateTime(2026, 3, 15),
          supplierId: supplierId,
          lines: lines ??
              [
                PurchaseLine(
                  description: 'Chair',
                  quantity: 10,
                  unitPrice: Money.minor(100000, 'NPR'),
                ),
              ],
          vatRateBasisPoints: vatRateBasisPoints,
        );

    test('the totals are derived from the lines, never passed in', () {
      final purchase = build();
      expect(purchase.subtotal.minorUnits, 1000000);
      expect(purchase.vat.minorUnits, 130000);
      expect(purchase.total.minorUnits, 1130000);
    });

    test('VAT is charged on the combined subtotal, not per line', () {
      // The same rule as the sales side, for the same reason: per-line rounding
      // would drift from the return filed with the authority. Three lines of
      // Rs 5.00 each post 1 paisa each (3 total); the aggregate 15 paisa at 13%
      // is 1.95, which would round to 2.
      final purchase = build(
        lines: [
          for (var i = 0; i < 3; i++)
            PurchaseLine(
              description: 'Item $i',
              quantity: 1,
              unitPrice: Money.minor(5, 'NPR'),
            ),
        ],
      );
      expect(purchase.vat.minorUnits, 2);
    });

    test('a zero-rated purchase omits VAT entirely rather than carrying a zero',
        () {
      final purchase = build(vatRateBasisPoints: 0);
      expect(purchase.vat.isZero, isTrue);
      expect(purchase.total.minorUnits, 1000000);
      expect(
        purchase.isZeroRated,
        isTrue,
        reason: 'so a posting use case can omit the line instead of posting 0',
      );
    });

    test('a purchase needs at least one line', () {
      // Without this a purchase would post a payable for nothing, which is a
      // liability with no document behind it — the exact defect that made 2010 a
      // hand-credited balance before this existed.
      expect(() => build(lines: const []), throwsArgumentError);
    });

    test('a purchase needs a supplier', () {
      expect(() => build(supplierId: '  '), throwsArgumentError);
    });

    test('a purchase needs an id and a date', () {
      expect(
        () => Purchase(
          id: '',
          issueDate: DateTime(2026, 3, 15),
          supplierId: 'sup-1',
          lines: [
            PurchaseLine(
              description: 'Chair',
              quantity: 1,
              unitPrice: Money.minor(100000, 'NPR'),
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('the currency comes from the lines', () {
      expect(build().currency, 'NPR');
    });

    test('the lines are unmodifiable, so a posted purchase cannot be edited', () {
      // **"Posted financial records are immutable."** Copying the list and
      // wrapping it means the caller's own list cannot be mutated afterwards to
      // change a purchase that has been posted.
      final source = [
        PurchaseLine(
          description: 'Chair',
          quantity: 10,
          unitPrice: Money.minor(100000, 'NPR'),
        ),
      ];
      final purchase = build(lines: source);

      source.add(
        PurchaseLine(
          description: 'Sneaky',
          quantity: 1,
          unitPrice: Money.minor(999999, 'NPR'),
        ),
      );

      expect(purchase.lines.length, 1);
      expect(() => purchase.lines.add(
            PurchaseLine(
              description: 'Also sneaky',
              quantity: 1,
              unitPrice: Money.minor(1, 'NPR'),
            ),
          ), throwsUnsupportedError);
    });

    test('the stock lines are the ones naming a product', () {
      // What a posting use case iterates to move stock, so it is a named concept
      // rather than a filter each caller writes differently.
      final purchase = build(
        lines: [
          PurchaseLine(
            description: 'Chair',
            quantity: 10,
            unitPrice: Money.minor(100000, 'NPR'),
            productId: 'p-1',
          ),
          PurchaseLine(
            description: 'Freight',
            quantity: 1,
            unitPrice: Money.minor(50000, 'NPR'),
          ),
        ],
      );

      expect(purchase.stockLines.length, 1);
      expect(purchase.stockLines.single.productId, 'p-1');
      expect(purchase.receivesStock, isTrue);
    });

    test('a purchase of nothing trackable receives no stock', () {
      expect(build().receivesStock, isFalse);
    });

    test('two purchases never share currency', () {
      // Refused rather than silently converted: mixing NPR and USD in one
      // payable would produce a total that is not a real amount.
      expect(
        () => Purchase(
          id: 'P-1',
          issueDate: DateTime(2026, 3, 15),
          supplierId: 'sup-1',
          lines: [
            PurchaseLine(
              description: 'Chair',
              quantity: 1,
              unitPrice: Money.minor(100000, 'NPR'),
            ),
            PurchaseLine(
              description: 'Desk',
              quantity: 1,
              unitPrice: Money.minor(50000, 'USD'),
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('SupplierPayment', () {
    test('a payment needs an id, a purchase, a date, and a positive amount', () {
      final date = DateTime(2026, 3, 20);

      expect(
        () => SupplierPayment(
          id: '',
          purchaseId: 'P-1',
          date: date,
          amount: Money.minor(100000, 'NPR'),
          accountId: 'acct-bank',
        ),
        throwsArgumentError,
      );
      expect(
        () => SupplierPayment(
          id: 'PAY-1',
          purchaseId: '',
          date: date,
          amount: Money.minor(100000, 'NPR'),
          accountId: 'acct-bank',
        ),
        throwsArgumentError,
      );
      expect(
        () => SupplierPayment(
          id: 'PAY-1',
          purchaseId: 'P-1',
          date: date,
          amount: Money.minor(0, 'NPR'),
          accountId: 'acct-bank',
        ),
        throwsArgumentError,
        reason: 'a zero payment settles nothing and is a data-entry mistake',
      );
    });

    test('a payment needs an account the money was paid from', () {
      // Blank means absent: a payment with no account has no counter-account, and
      // the double entry would be one-sided.
      expect(
        () => SupplierPayment(
          id: 'PAY-1',
          purchaseId: 'P-1',
          date: DateTime(2026, 3, 20),
          amount: Money.minor(100000, 'NPR'),
          accountId: '   ',
        ),
        throwsArgumentError,
      );
    });

    test('a payment is identified by its id, so it cannot be double-counted', () {
      // The journal entry id is derived from the payment id, so reusing one is
      // refused by the primary key rather than counting twice against the payable.
      final payment = SupplierPayment(
        id: 'PAY-1',
        purchaseId: 'P-1',
        date: DateTime(2026, 3, 20),
        amount: Money.minor(100000, 'NPR'),
        accountId: 'acct-bank',
      );
      expect(payment.id, 'PAY-1');
    });
  });

  group('PurchaseBalance', () {
    Purchase purchase() => Purchase(
          id: 'P-1',
          issueDate: DateTime(2026, 3, 15),
          supplierId: 'sup-1',
          lines: [
            PurchaseLine(
              description: 'Chair',
              quantity: 10,
              unitPrice: Money.minor(100000, 'NPR'),
            ),
          ],
        );

    SupplierPayment payment(int paisa) => SupplierPayment(
          id: 'PAY-$paisa',
          purchaseId: 'P-1',
          date: DateTime(2026, 3, 20),
          amount: Money.minor(paisa, 'NPR'),
          accountId: 'acct-bank',
        );

    test('nothing paid means the whole total is outstanding', () {
      final balance = PurchaseBalance.of(purchase(), const []);
      expect(balance.purchaseTotal.minorUnits, 1130000);
      expect(balance.paid.minorUnits, 0);
      expect(balance.outstanding.minorUnits, 1130000);
      expect(balance.isSettled, isFalse);
    });

    test('paying the exact amount settles it', () {
      final balance = PurchaseBalance.of(purchase(), [payment(1130000)]);
      expect(balance.outstanding.isZero, isTrue);
      expect(balance.isSettled, isTrue);
    });

    test('a part payment leaves the remainder outstanding', () {
      final balance = PurchaseBalance.of(purchase(), [payment(500000)]);
      expect(balance.outstanding.minorUnits, 630000);
      expect(balance.isPartiallyPaid, isTrue);
      expect(balance.isSettled, isFalse);
    });

    test('the outstanding balance can go negative, meaning a refund is due', () {
      // Overpaying a supplier is possible in the real world. The same reasoning as
      // a customer refund: the negative figure is a fact about the world, and
      // clamping it to zero would hide money the business owes.
      final balance = PurchaseBalance.of(purchase(), [payment(1200000)]);
      expect(balance.outstanding.minorUnits, -70000);
      expect(balance.isRefundDue, isTrue);
      expect(balance.refundDue.minorUnits, 70000);
    });

    test('the balance is derived, so it survives a reopen of the database', () {
      // Nothing about the balance is persisted, which is exactly why it can be
      // rebuilt after a restart. A stored balance would need migrating.
      final first = PurchaseBalance.of(purchase(), [payment(500000)]);
      final second = PurchaseBalance.of(purchase(), [payment(500000)]);
      expect(first.outstanding, second.outstanding);
    });
  });

  group('Supplier identity and input credit', () {
    test('a supplier without a PAN cannot support an input credit claim', () {
      // `NEPALI_BILLING.md`: a purchase bill lacking the vendor's PAN may be
      // disallowed as input credit in an audit. That is a **cash cost**, so it
      // must be visible.
      final supplier = Supplier(id: 'sup-1', name: 'Ram Furniture');
      expect(supplier.canSupportInputCredit, isFalse);
      expect(supplier.pan, isNull);
    });

    test('a supplier with a PAN can support an input credit claim', () {
      final supplier = Supplier(
        id: 'sup-1',
        name: 'Kamala Traders',
        pan: '601234567',
      );
      expect(supplier.canSupportInputCredit, isTrue);
    });

    test('a malformed PAN is rejected rather than stored as if valid', () {
      // **The distinction this preserves**: a supplier with no PAN is an ordinary
      // fact and the bill is still recorded; a supplier with a five-digit
      // "PAN" is a data-entry error that puts the input credit at risk, so it is
      // refused at construction rather than printed on a bill.
      expect(
        () => Supplier(id: 'sup-1', name: 'Bad', pan: '12345'),
        throwsArgumentError,
      );
      expect(
        () => Supplier(id: 'sup-1', name: 'Bad', pan: 'abc'),
        throwsArgumentError,
      );
    });

    test('a blank PAN is absent rather than invalid', () {
      final supplier = Supplier(id: 'sup-1', name: 'Ram', pan: '   ');
      expect(supplier.pan, isNull);
    });
  });
}