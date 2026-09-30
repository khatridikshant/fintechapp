/// An accounting period: a label and an inclusive date range.
///
/// Deliberately free of any calendar logic. It does not know about Bikram
/// Sambat, Shrawan, or Ashadh, and it never derives its own boundaries. A
/// `FiscalYear` is told its range by whatever calendar produced it. See
/// [NepaliFiscalCalendar] for the Nepali rules.
///
/// Only dates are compared, never instants. A transaction posted at 14:00 on the
/// last day of the fiscal year is inside it. Comparing raw `DateTime` values
/// would compare that timestamp against midnight of the last day and wrongly
/// reject it, which is the single easiest mistake to make in this class.
class FiscalYear {
  FiscalYear({
    required this.label,
    required DateTime start,
    required DateTime end,
  })  : startDate = _dateOnly(start),
        endDate = _dateOnly(end) {
    if (endDate.isBefore(startDate)) {
      throw ArgumentError(
        'A fiscal year cannot end before it starts: '
        '${_dateOnly(start)} to ${_dateOnly(end)}.',
      );
    }
  }

  /// Human-facing label, for example `FY 2082/83`.
  final String label;

  /// First day of the period, inclusive.
  final DateTime startDate;

  /// Last day of the period, inclusive.
  final DateTime endDate;

  /// Whether [date] falls inside this fiscal year.
  ///
  /// Both bounds are inclusive, and only the date part of [date] is considered.
  bool contains(DateTime date) {
    final candidate = _dateOnly(date);
    return !candidate.isBefore(startDate) && !candidate.isAfter(endDate);
  }

  /// Number of days in the period, counting both ends.
  int get dayCount => endDate.difference(startDate).inDays + 1;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  bool operator ==(Object other) =>
      other is FiscalYear &&
      other.label == label &&
      other.startDate == startDate &&
      other.endDate == endDate;

  @override
  int get hashCode => Object.hash(label, startDate, endDate);

  @override
  String toString() =>
      'FiscalYear($label, ${_iso(startDate)} to ${_iso(endDate)})';

  static String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
