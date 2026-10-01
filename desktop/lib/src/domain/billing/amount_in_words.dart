import '../shared/money.dart';

/// Writes an amount in words.
///
/// Rule 17 requires the grand total **in figures and in words**. An amount in
/// words is what makes a figure hard to alter: a written "Rupees One Lakh Twelve
/// Thousand Three Hundred Forty Five" is not a thing to be quietly edited, and the
/// mismatch between the two is a classic audit finding.
///
/// ## Integer only, by construction
///
/// Only the **whole rupees** are written. The paisa are appended as digits
/// (`Rupees ... and 45 Paisa Only`), which is how Nepali and Indian commercial
/// documents do it. Converting paisa to words would need a second vocabulary and
/// would buy nothing: a bill states the figures separately in the amount column.
///
/// This is a display concern, so it takes a [Money] and returns text. It never
/// returns a number that could be stored as an amount.
String amountInWords(Money amount) {
  final rupees = amount.minorUnits ~/ 100;
  final paisa = amount.minorUnits.abs() % 100;

  final buffer = StringBuffer();
  if (amount.minorUnits < 0) buffer.write('Minus ');

  buffer.write('Rupees ');
  buffer.write(_words(rupees));
  buffer.write(' Rupees');

  if (paisa != 0) {
    buffer.write(' and ');
    buffer.write('$paisa Paisa');
  }
  buffer.write(' Only');
  return buffer.toString();
}

/// Converts a non-negative integer to its English name.
///
/// The Indian numbering system is used (`lakh`, `crore`), not the international
/// `million`/`billion`, because those are the units Nepali invoices, cheque
/// books, and tax forms are written in.
String _words(int value) {
  if (value == 0) return 'Zero';

  // Each entry pairs a divisor with the name of that divisor, in descending
  // order. **The two must stay the same length and in the same order** — when
  // they did not, 100,000 came out as "Ten Hundred Crore".
  const units = <int, String>{
    10000000: 'Crore',
    100000: 'Lakh',
    1000: 'Thousand',
    100: 'Hundred',
  };

  final words = <String>[];
  var remaining = value;

  units.forEach((divisor, name) {
    final count = remaining ~/ divisor;
    if (count == 0) return;
    words.add('${_underThousand(count)} $name');
    remaining -= count * divisor;
  });

  if (remaining > 0) words.add(_underThousand(remaining));

  return words.join(' ');
}

/// Names a number below one thousand.
String _underThousand(int value) {
  const ones = <String>[
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
  ];
  const tens = <String>[
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety',
  ];

  final words = <String>[];
  if (value >= 100) {
    words.add('${ones[value ~/ 100]} Hundred');
    final rest = value % 100;
    if (rest > 0) words.add(_underThousand(rest));
    return words.join(' ');
  }

  if (value >= 20) {
    words.add(tens[value ~/ 10]);
    final rest = value % 10;
    if (rest > 0) words.add(ones[rest]);
    return words.join(' ');
  }

  return ones[value];
}
