import 'bs_calendar_data.dart';

/// A date in the Bikram Sambat calendar.
typedef BsDate = ({int year, int month, int day});

/// Converts between Bikram Sambat (BS) and Gregorian (AD) dates.
///
/// **The calendar data is in-tree**, in `bs_calendar_data.dart`, because the
/// fiscal calendar is the single most compliance-critical dataset in the product
/// and it should not depend on one maintainer remaining available or remaining
/// MIT. See ADR 009.
///
/// The conversion is a cumulative day count from a fixed anchor rather than a
/// chain of rules, so there is nowhere for a special case to hide.
///
/// BS months cannot be derived from the Gregorian calendar. They are 29 to 32
/// days long and the lengths change year to year, so they come from
/// `bsMonthLengths`. An unsupported year throws rather than extrapolating,
/// because a guessed boundary files transactions under the wrong fiscal year.
class BsCalendar {
  const BsCalendar();

  /// Earliest BS year the in-tree data covers.
  static const int earliestYear = 1969;

  /// Latest BS year the in-tree data covers.
  ///
  /// The upstream table claimed BS 2200, but that entry is placeholder data. It
  /// is excluded here, so a fiscal year needing it is refused rather than
  /// answered with a 372-day "year". See `bs_calendar_data.dart`.
  static const int latestYear = 2199;

  /// Last BS year whose **length** can be measured.
  ///
  /// Measuring a year, or the final month of a year, requires the following
  /// year's data.
  static const int latestUsableYear = latestYear - 1;

  /// BS month numbers. Baishakh is 1, so Shrawan is 4 and Ashadh is 3.
  static const int baishakh = 1;
  static const int ashadh = 3;
  static const int shrawan = 4;

  /// 1 Baishakh 2000 BS falls on 14 April 1943 AD.
  ///
  /// A published, checkable anchor. Every conversion is counted from here, so a
  /// single wrong constant would shift every date in the product, and the tests
  /// pin it against independent known dates.
  ///
  /// The epoch is **UTC on purpose**. Day arithmetic is done in UTC, where every
  /// day is exactly 24 hours and daylight saving cannot shift a result, and the
  /// finished date is then presented as a local date-only value. Doing the
  /// arithmetic in local time would let a 23- or 25-hour day move a date by one.
  static final DateTime _epoch = DateTime.utc(1943, 4, 14);

  /// Rewrites a UTC instant as a local date-only value, keeping the year, month,
  /// and day and discarding the clock and the offset.
  static DateTime _asLocalDate(DateTime utcDate) =>
      DateTime(utcDate.year, utcDate.month, utcDate.day);

  /// Days from the epoch to 1 Baishakh of [year]. May be negative.
  static int _daysToYearStart(int year) {
    var days = 0;
    if (year >= 2000) {
      for (var y = 2000; y < year; y++) {
        days += _yearLength(y);
      }
    } else {
      for (var y = year; y < 2000; y++) {
        days -= _yearLength(y);
      }
    }
    return days;
  }

  /// Converts a BS date to the Gregorian date that begins that day.
  ///
  /// Rejects a year outside the data, a month outside 1 to 12, and a day that
  /// does not exist in that month.
  DateTime toGregorian({
    required int year,
    required int month,
    required int day,
  }) {
    _checkYear(year);
    RangeError.checkValueInInterval(month, 1, 12, 'month');
    RangeError.checkValueInInterval(day, 1, daysInMonth(year, month), 'day');

    var days = _daysToYearStart(year);
    for (var m = 1; m < month; m++) {
      days += daysInMonth(year, m);
    }
    days += day - 1;

    return _asLocalDate(_epoch.add(Duration(days: days)));
  }

  /// Converts a Gregorian date to the BS date that contains it.
  ///
  /// Only the date part is used, so the time of day never shifts the result
  /// across a day boundary.
  BsDate fromGregorian(DateTime date) {
    final target = DateTime.utc(date.year, date.month, date.day);
    final offset = target.difference(_epoch).inDays;

    // Binary search for the year, then walk the months. 231 years is small
    // enough that a linear walk would also be correct, but a binary search keeps
    // the cost flat if the table ever grows.
    var low = earliestYear;
    var high = latestYear;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (_daysToYearStart(mid) <= offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }

    final year = low;
    var remaining = offset - _daysToYearStart(year);
    var month = 1;
    while (month <= 12) {
      final length = daysInMonth(year, month);
      if (remaining < length) break;
      remaining -= length;
      month++;
    }

    return (year: year, month: month, day: remaining + 1);
  }

  /// Number of days in a BS month.
  int daysInMonth(int year, int month) {
    RangeError.checkValueInInterval(month, 1, 12, 'month');
    final lengths = _monthLengthsFor(year);
    return lengths[month - 1];
  }

  /// Total days in a BS year, as the sum of its twelve months.
  int daysInYear(int year) => _yearLength(year);

  static int _yearLength(int year) =>
      _monthLengthsFor(year).fold<int>(0, (a, b) => a + b);

  /// The last day of a BS month, as a Gregorian date.
  DateTime lastDayOfMonth(int year, int month) =>
      toGregorian(year: year, month: month, day: daysInMonth(year, month));

  /// The first day of a BS month, as a Gregorian date.
  DateTime firstDayOfMonth(int year, int month) =>
      toGregorian(year: year, month: month, day: 1);

  static List<int> _monthLengthsFor(int year) {
    _checkYear(year);
    final lengths = bsMonthLengths[year];
    if (lengths == null) {
      // Unreachable while _checkYear and the table agree, but a missing entry
      // must fail loudly rather than index into nothing.
      throw StateError('No Bikram Sambat month lengths for year $year.');
    }
    return lengths;
  }

  static void _checkYear(int year) {
    if (year < earliestYear || year > latestYear) {
      throw BsYearOutOfRangeException(year, earliestYear, latestYear);
    }
  }
}

/// Raised when a BS year falls outside the in-tree calendar data.
///
/// Deliberately fatal rather than a warning. Guessing a calendar boundary would
/// file a transaction under the wrong fiscal year, which is precisely the class
/// of error the architecture exists to prevent.
class BsYearOutOfRangeException implements Exception {
  BsYearOutOfRangeException(this.year, this.earliest, this.latest);

  final int year;
  final int earliest;
  final int latest;

  @override
  String toString() =>
      'BsYearOutOfRangeException: BS year $year is outside the '
      'supported range $earliest to $latest. Add calendar data for this year '
      'rather than guessing, because a wrong fiscal boundary silently misfiles '
      'transactions.';
}
