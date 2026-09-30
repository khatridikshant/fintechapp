import 'package:bikram_sambat/bikram_sambat.dart';

/// A date in the Bikram Sambat calendar.
typedef BsDate = ({int year, int month, int day});

/// Converts between Bikram Sambat (BS) and Gregorian (AD) dates.
///
/// **This is the only file in the project that knows `bikram_sambat` exists.**
/// Everything else depends on this class, so the third-party package can be
/// pinned, replaced, or removed by editing one file, and the fiscal rules stay
/// untouched. The package is MIT licensed; see ADR 009.
///
/// The conversion cannot be done with a formula. BS months are 29 to 32 days
/// long and the lengths change from year to year, so the boundaries come from a
/// data table. `bikram_sambat` supplies that table for [earliestYear] to
/// [latestYear]. Nothing here guesses outside that range: an unsupported year
/// throws, because silently falling back would place transactions in the wrong
/// fiscal year.
class BsCalendar {
  const BsCalendar();

  /// Earliest BS year the underlying data covers.
  static const int earliestYear = 1969;

  /// Latest BS year the underlying data covers.
  static const int latestYear = 2200;

  /// Last BS year whose **length** can be measured.
  ///
  /// Measuring a whole year, or the final month of a year, requires the
  /// following year's data. The table stops at [latestYear], so that final year
  /// has no usable successor and cannot be measured. Nothing may silently
  /// assume otherwise, because an unmeasurable month would either throw from
  /// deep inside the third-party package or, worse, be guessed.
  static const int latestUsableYear = latestYear - 1;

  /// BS month numbers. Baishakh is 1, so Shrawan is 4 and Ashadh is 3.
  static const int baishakh = 1;
  static const int ashadh = 3;
  static const int shrawan = 4;

  /// Converts a BS date to the Gregorian date that begins that day.
  ///
  /// Rejects a year outside the supported range and a day that does not exist
  /// in that month.
  DateTime toGregorian({
    required int year,
    required int month,
    required int day,
  }) {
    _checkYear(year);
    RangeError.checkValueInInterval(month, 1, 12, 'month');
    RangeError.checkValueInInterval(day, 1, daysInMonth(year, month), 'day');
    return BikramSambat(year, month, day).toDateTime();
  }

  /// Converts a Gregorian date to the BS date that contains it.
  ///
  /// Only the date part is used, so the time of day never shifts the result
  /// across a day boundary.
  BsDate fromGregorian(DateTime date) {
    final bs = DateTime(date.year, date.month, date.day).toBikramSambat();
    return (year: bs.year, month: bs.month, day: bs.day);
  }

  /// Number of days in a BS month.
  ///
  /// Found by walking forward until the month changes, because the package does
  /// not expose a month-length table. This is validated by a test asserting that
  /// the twelve month lengths sum to the true length of the year, for a spread
  /// of years, which would fail if the walk were off by one.
  ///
  /// The walk for month 12 crosses into the next year, so that case needs the
  /// following year to exist in the table. See [latestUsableYear].
  int daysInMonth(int year, int month) {
    RangeError.checkValueInInterval(month, 1, 12, 'month');
    // Month 12 is measured against the following year's first month.
    _checkYear(month == 12 ? year + 1 : year);

    var days = 0;
    for (var day = 1; day <= 32; day++) {
      final candidate = BikramSambat(year, month, day);
      if (candidate.year != year || candidate.month != month) break;
      days = day;
    }
    return days;
  }

  /// The last day of a BS month, as a Gregorian date.
  DateTime lastDayOfMonth(int year, int month) =>
      toGregorian(year: year, month: month, day: daysInMonth(year, month));

  /// The first day of a BS month, as a Gregorian date.
  DateTime firstDayOfMonth(int year, int month) =>
      toGregorian(year: year, month: month, day: 1);

  /// Total days in a BS year, measured from its first day to the next year's.
  int daysInYear(int year) {
    _checkYear(year + 1);
    final start = firstDayOfMonth(year, baishakh);
    final nextStart = firstDayOfMonth(year + 1, baishakh);
    return nextStart.difference(start).inDays;
  }

  static void _checkYear(int year) {
    if (year < earliestYear || year > latestYear) {
      throw BsYearOutOfRangeException(year, earliestYear, latestYear);
    }
  }
}

/// Raised when a BS year falls outside the supported data range.
///
/// This is deliberately fatal rather than a warning. Guessing a calendar
/// boundary would file a transaction under the wrong fiscal year, which is
/// precisely the class of error the architecture exists to prevent.
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
