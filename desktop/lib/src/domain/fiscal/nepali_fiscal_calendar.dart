import 'bs_calendar.dart';
import 'fiscal_year.dart';

/// Builds Nepal's fiscal years.
///
/// Nepal's fiscal year runs from **1 Shrawan to the last day of Ashadh of the
/// following BS year**. That is why a year is labelled with two numbers:
/// Shrawan falls in month 4, and the year ends eight and a half months later,
/// in month 3 of the next BS year.
///
///   FY 2082/83 = 1 Shrawan 2082  ->  last day of Ashadh 2083
///
/// This is the only place that rule is written down. Everything else asks this
/// class for a [FiscalYear], so the rule cannot drift between features.
class NepaliFiscalCalendar {
  const NepaliFiscalCalendar({this.bs = const BsCalendar()});

  final BsCalendar bs;

  /// Builds the fiscal year that starts in [startBsYear].
  ///
  /// [startBsYear] is the BS year that Shrawan falls in, so `2082` produces
  /// `FY 2082/83`.
  FiscalYear forBsYear(int startBsYear) {
    if (startBsYear > BsCalendar.latestUsableYear ||
        startBsYear < BsCalendar.earliestYear) {
      throw BsYearOutOfRangeException(
        startBsYear,
        BsCalendar.earliestYear,
        BsCalendar.latestUsableYear,
      );
    }

    final start = bs.toGregorian(
      year: startBsYear,
      month: BsCalendar.shrawan,
      day: 1,
    );
    final end = bs.lastDayOfMonth(
      startBsYear + 1,
      BsCalendar.ashadh,
    );

    return FiscalYear(
      label: labelForBsYear(startBsYear),
      start: start,
      end: end,
    );
  }

  /// The fiscal year that contains [date].
  ///
  /// A date in Baishakh, Jestha, or Ashadh belongs to the fiscal year that
  /// started in the previous BS year, because the fiscal year does not end until
  /// Ashadh is over.
  FiscalYear containing(DateTime date) {
    final bsDate = bs.fromGregorian(date);
    final startBsYear =
        bsDate.month >= BsCalendar.shrawan ? bsDate.year : bsDate.year - 1;
    return forBsYear(startBsYear);
  }

  /// `2082` becomes `FY 2082/83`.
  static String labelForBsYear(int startBsYear) {
    final nextTwoDigits = ((startBsYear + 1) % 100).toString().padLeft(2, '0');
    return 'FY $startBsYear/$nextTwoDigits';
  }

  /// The inverse of [labelForBsYear]: `FY 2082/83` becomes the fiscal year that
  /// starts in BS 2082.
  ///
  /// This lets a stored label be turned back into a whole fiscal year, so a
  /// record only ever needs to persist the label. Storing the start and end
  /// dates as well would duplicate a fact that the label already determines, and
  /// duplicated facts drift apart.
  ///
  /// Throws on a label that does not match, rather than guessing a year. A
  /// plausible-looking wrong year would misfile records.
  FiscalYear fromLabel(String label) {
    final match = RegExp(r'^FY (\d{4})/(\d{2})$').firstMatch(label);
    if (match == null) {
      throw ArgumentError(
        'Cannot read a fiscal year from the label "$label". Expected a label '
        'shaped like "FY 2082/83".',
      );
    }

    final startBsYear = int.parse(match.group(1)!);
    final expectedNext = ((startBsYear + 1) % 100).toString().padLeft(2, '0');
    if (match.group(2) != expectedNext) {
      throw ArgumentError(
        'The label "$label" is inconsistent: "$startBsYear" must be followed '
        'by "$expectedNext".',
      );
    }

    return forBsYear(startBsYear);
  }
}
