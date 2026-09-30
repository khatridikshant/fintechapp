/// Fixed-precision monetary value.
///
/// Money is stored as an integer count of minor units (paisa for NPR), never as
/// a floating point number. Dart's default numeric type is `double`, which is
/// binary floating point and cannot represent most decimal fractions exactly.
/// Using it for authoritative financial calculation is prohibited.
///
/// The domain layer must never accept a `double` or `num` as an amount. If a
/// value arrives from outside (JSON, text input, a database column) it must be
/// parsed into [Money] at the boundary and never widen back to a double.
class Money implements Comparable<Money> {
  const Money._(this.minorUnits, this.currency);

  /// Creates a value from a count of minor units.
  ///
  /// Use [fromMajorUnits] when the amount originates outside the domain.
  const Money.minor(int minorUnits, String currency)
      : this._(minorUnits, currency);

  /// Number of minor units, e.g. paisa. May be negative.
  final int minorUnits;

  /// ISO 4217 currency code, e.g. `NPR`.
  final String currency;

  /// Number of decimal places the currency uses.
  ///
  /// Nepal's rupee is a two-decimal currency, so 1 Rs is 100 paisa.
  static const int minorUnitDigits = 2;

  /// The scale factor between major units and minor units.
  static const int minorUnitScale = 100;

  /// Builds money from a major-unit amount such as `1234.56`.
  ///
  /// Accepts [num] so that parsed JSON can be converted directly. The value is
  /// rounded half-up to the nearest minor unit, and the rounding is asserted by
  /// the caller through tests rather than silently trusted.
  factory Money.fromMajorUnits(num majorUnits, String currency) {
    return Money.minor(
      (majorUnits * minorUnitScale).round(),
      currency,
    );
  }

  /// Parses a user-entered string such as `"1,250,000.50"` or `"Rs 500"`.
  ///
  /// Returns `null` rather than throwing so that form validation can report the
  /// problem to the user.
  static Money? tryParse(String input, String currency) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null) return null;
    return Money.fromMajorUnits(value, currency);
  }

  /// The amount expressed in major units, for display and export only.
  ///
  /// Never feed this back into arithmetic. Use [minorUnits].
  double get majorUnits => minorUnits / minorUnitScale;

  Money add(Money other) {
    _assertSameCurrency(other);
    return Money.minor(minorUnits + other.minorUnits, currency);
  }

  Money subtract(Money other) {
    _assertSameCurrency(other);
    return Money.minor(minorUnits - other.minorUnits, currency);
  }

  Money negated() => Money.minor(-minorUnits, currency);

  Money abs() => Money.minor(minorUnits.abs(), currency);

  /// Multiplies by a whole quantity, such as an invoice line quantity.
  Money times(int quantity) => Money.minor(minorUnits * quantity, currency);

  /// Treats this amount as a unit price and multiplies by a fractional quantity
  /// expressed as `numerator / denominator`.
  ///
  /// Use this for measured goods such as 2.5 kg at Rs 40.00/kg. For a whole
  /// quantity use [times], which is exact and performs no rounding.
  ///
  /// Rounds half-up to the nearest minor unit.
  Money timesFraction(int numerator, int denominator) {
    require(denominator != 0, 'Quantity denominator must not be zero.');
    return Money.minor(
      _divideRoundHalfUp(minorUnits * numerator, denominator),
      currency,
    );
  }

  /// Applies a rate expressed in basis points (1 bp = 0.01%).
  ///
  /// 2500 bp is 25%. Used for discounts and tax rates so that no floating
  /// point value is introduced.
  Money applyBasisPoints(int basisPoints) {
    require(
      basisPoints >= 0,
      'Basis points must not be negative; use subtract for reductions.',
    );
    return Money.minor(
      _divideRoundHalfUp(minorUnits * basisPoints, 10000),
      currency,
    );
  }

  /// Splits this amount into [parts] shares without losing or inventing paisa.
  ///
  /// The remainder is distributed one minor unit at a time to the earliest
  /// shares, so the parts always sum back to the original amount. This is used
  /// for allocating tax or discount across invoice lines.
  List<Money> allocate(int parts) {
    require(parts > 0, 'Cannot allocate into zero or negative parts.');
    final base = minorUnits ~/ parts;
    var remainder = minorUnits - (base * parts);
    final sign = remainder.isNegative ? -1 : 1;
    remainder = remainder.abs();
    return List<Money>.generate(parts, (index) {
      final extra = index < remainder ? sign : 0;
      return Money.minor(base + extra, currency);
    });
  }

  bool get isZero => minorUnits == 0;
  bool get isPositive => minorUnits > 0;
  bool get isNegative => minorUnits < 0;

  /// Sum of a list of amounts. Empty input yields zero in [currency].
  static Money sum(Iterable<Money> amounts, String currency) {
    return amounts.fold(
      Money.minor(0, currency),
      (total, amount) => total.add(amount),
    );
  }

  static int _divideRoundHalfUp(int numerator, int denominator) {
    final isNegative = numerator < 0;
    final value = numerator.abs();
    final rounded = (value + denominator ~/ 2) ~/ denominator;
    return isNegative ? -rounded : rounded;
  }

  void _assertSameCurrency(Money other) {
    if (other.currency != currency) {
      throw CurrencyMismatchException(currency, other.currency);
    }
  }

  /// Compares amounts. Throws if the currencies differ, because ordering
  /// amounts across currencies is not a meaningful operation without a rate.
  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  bool operator >(Money other) => compareTo(other) > 0;
  bool operator >=(Money other) => compareTo(other) >= 0;
  bool operator <(Money other) => compareTo(other) < 0;
  bool operator <=(Money other) => compareTo(other) <= 0;

  Money operator +(Money other) => add(other);
  Money operator -(Money other) => subtract(other);
  Money operator -() => negated();

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => 'Rs ${minorUnits / minorUnitScale}';

  /// Formats for display with thousands separators and negative sign placement.
  ///
  /// `Rs -1,250.00` rather than `-Rs 1,250.00`.
  String format({String symbol = 'Rs'}) {
    final isNegativeAmount = minorUnits < 0;
    final digits =
        minorUnits.abs().toString().padLeft(minorUnitDigits + 1, '0');
    final whole = digits.substring(0, digits.length - minorUnitDigits);
    final fraction = digits.substring(digits.length - minorUnitDigits);
    final grouped = whole.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '${isNegativeAmount ? '-' : ''}$symbol $grouped.$fraction';
  }
}

class CurrencyMismatchException implements Exception {
  CurrencyMismatchException(this.expected, this.actual);

  final String expected;
  final String actual;

  @override
  String toString() =>
      'CurrencyMismatchException: cannot combine $expected with $actual. '
      'Multi-currency accounting is out of scope for V1.';
}

/// Throws [ArgumentError] with [message] when [condition] is false.
void require(bool condition, String message) {
  if (!condition) throw ArgumentError(message);
}
