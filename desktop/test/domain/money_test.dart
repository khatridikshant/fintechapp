import 'package:financeapp/src/domain/shared/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const npr = 'NPR';

  Money rs(int majorUnits) => Money.minor(majorUnits * 100, npr);

  group('Money construction', () {
    test('parses major units into minor units without float drift', () {
      // In binary floating point 0.1 + 0.2 == 0.30000000000000004.
      // Money stores 10 paisa + 20 paisa, so the sum is exactly 30 paisa.
      expect(0.1 + 0.2, isNot(0.3), reason: 'the float behaviour we avoid');
      final a = Money.fromMajorUnits(0.1, npr);
      final b = Money.fromMajorUnits(0.2, npr);
      expect(a.add(b).minorUnits, 30);
    });

    test('rounds half-up to the nearest paisa', () {
      expect(Money.fromMajorUnits(10.005, npr).minorUnits, 1001);
      expect(Money.fromMajorUnits(10.004, npr).minorUnits, 1000);
    });

    test('preserves a value that floating point would lose', () {
      // 1,284,500.07 is not representable as a double.
      final m = Money.fromMajorUnits(1284500.07, npr);
      expect(m.minorUnits, 128450007);
    });

    test('tryParse strips formatting and rejects nonsense', () {
      expect(Money.tryParse('1,250,000.50', npr)?.minorUnits, 125000050);
      expect(Money.tryParse('Rs 500', npr)?.minorUnits, 50000);
      expect(Money.tryParse('', npr), isNull);
      expect(Money.tryParse('abc', npr), isNull);
    });
  });

  group('Money arithmetic', () {
    test('adds and subtracts', () {
      expect(rs(1000).add(rs(250)).minorUnits, 125000);
      expect(rs(1000).subtract(rs(250)).minorUnits, 75000);
    });

    test('refuses to combine different currencies', () {
      expect(
        () => rs(100).add(const Money.minor(100, 'USD')),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });

    test('negates and takes absolute value', () {
      expect(rs(-500).negated().minorUnits, 50000);
      expect(rs(-500).abs().minorUnits, 50000);
    });
  });

  group('Money multiplication', () {
    test('multiplies by a whole quantity exactly', () {
      expect(rs(1500).times(2).minorUnits, 300000);
    });

    test('multiplies by a fractional quantity with half-up rounding', () {
      // 2.5 kg at Rs 40.00/kg = Rs 100.00
      expect(rs(40).timesFraction(5, 2).minorUnits, 10000);
      // Rs 0.05 x 1.5 = 7.5 paisa -> rounds half-up to 8 paisa.
      expect(const Money.minor(5, npr).timesFraction(3, 2).minorUnits, 8);
      // Rs 0.01 x 3 = 3 paisa, no rounding needed.
      expect(const Money.minor(1, npr).timesFraction(3, 1).minorUnits, 3);
    });

    test('rejects a zero quantity denominator', () {
      expect(() => rs(40).timesFraction(1, 0), throwsArgumentError);
    });

    test('applies basis points for percentages', () {
      // 25% of Rs 22,500 = Rs 5,625
      expect(rs(22500).applyBasisPoints(2500).minorUnits, 562500);
      // 13% VAT on Rs 1,000 = Rs 130
      expect(rs(1000).applyBasisPoints(1300).minorUnits, 13000);
    });

    test('rejects negative basis points rather than silently negating', () {
      expect(() => rs(100).applyBasisPoints(-100), throwsArgumentError);
    });
  });

  group('Money allocation', () {
    test('never loses or invents a paisa', () {
      // Rs 100 split three ways cannot divide evenly. 10000/3 = 3333.33
      final parts = rs(100).allocate(3);
      expect(parts.map((p) => p.minorUnits), [3334, 3333, 3333]);
      expect(
        Money.sum(parts, npr).minorUnits,
        rs(100).minorUnits,
        reason: 'allocated parts must sum back to the original amount',
      );
    });

    test('handles negative amounts symmetrically', () {
      final parts = const Money.minor(-10000, npr).allocate(3);
      expect(parts.map((p) => p.minorUnits), [-3334, -3333, -3333]);
      expect(Money.sum(parts, npr).minorUnits, -10000);
    });

    test('rejects zero parts', () {
      expect(() => rs(100).allocate(0), throwsArgumentError);
    });
  });

  group('Money comparison', () {
    test('orders by minor units', () {
      expect(rs(100) > rs(99), isTrue);
      expect(rs(100) < rs(101), isTrue);
      expect(rs(100) == rs(100), isTrue);
      expect(rs(100).hashCode, rs(100).hashCode);
    });
  });

  group('Money formatting', () {
    test('groups thousands and always shows two decimals', () {
      expect(rs(1284500).format(), 'Rs 1,284,500.00');
      expect(rs(5).format(), 'Rs 5.00');
      expect(const Money.minor(7, npr).format(), 'Rs 0.07');
    });

    test('places the sign before the currency symbol', () {
      expect(const Money.minor(-125000, npr).format(), '-Rs 1,250.00');
    });
  });

  group('Money sum', () {
    test('empty sum is zero', () {
      expect(Money.sum(const <Money>[], npr).minorUnits, 0);
    });

    test('sums a list of amounts', () {
      expect(Money.sum([rs(1000), rs(250), rs(50)], npr).minorUnits, 130000);
    });
  });
}
