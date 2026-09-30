import 'package:financeapp/src/domain/fiscal/bs_calendar.dart';
import 'package:financeapp/src/domain/fiscal/bs_calendar_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards on the in-tree Bikram Sambat data.
///
/// This data used to live in a third-party package, so its correctness was
/// somebody else's test suite. It is ours now, which means its integrity is our
/// problem, and these tests are the answer to that.
void main() {
  const bs = BsCalendar();

  group('The table is well formed', () {
    test('every year has exactly twelve month lengths', () {
      for (final entry in bsMonthLengths.entries) {
        expect(entry.value, hasLength(12),
            reason: 'BS ${entry.key} has ${entry.value.length} months');
      }
    });

    test('every month is between 29 and 32 days', () {
      for (final entry in bsMonthLengths.entries) {
        for (var month = 1; month <= 12; month++) {
          final days = bs.daysInMonth(entry.key, month);
          expect(days, greaterThanOrEqualTo(29),
              reason: 'BS ${entry.key} month $month is $days days');
          expect(days, lessThanOrEqualTo(32),
              reason: 'BS ${entry.key} month $month is $days days');
        }
      }
    });

    test('every year is 365 or 366 days', () {
      // A real calendar year is never anything else. The 372-day placeholder
      // that the upstream table ended with is the reason this test exists.
      for (final year in bsMonthLengths.keys) {
        final days = bs.daysInYear(year);
        expect(days, anyOf(365, 366),
            reason: 'BS $year is $days days, which is not a calendar year');
      }
    });

    test('the years are contiguous with no gaps', () {
      final years = bsMonthLengths.keys.toList()..sort();
      expect(years.first, BsCalendar.earliestYear);
      expect(years.last, BsCalendar.latestYear);
      for (var i = 1; i < years.length; i++) {
        expect(years[i], years[i - 1] + 1,
            reason: 'gap between BS ${years[i - 1]} and BS ${years[i]}');
      }
    });

    test('the excluded placeholder year is genuinely absent', () {
      expect(bsMonthLengths.containsKey(2200), isFalse);
      expect(BsCalendar.latestYear, 2199);
    });
  });

  group('Conversion is exact and reversible', () {
    test('every day of a spread of years round-trips', () {
      // Walking a whole year day by day is the only way to catch an off-by-one
      // that happens to line up at the year boundary.
      for (final year in [
        1969,
        1975,
        2000,
        2050,
        2070,
        2082,
        2083,
        2100,
        2198
      ]) {
        var date = bs.firstDayOfMonth(year, BsCalendar.baishakh);
        final end = bs.firstDayOfMonth(year + 1, BsCalendar.baishakh);

        var count = 0;
        while (date.isBefore(end)) {
          final back = bs.fromGregorian(date);
          expect(back.year, year, reason: 'wrong year for $date');
          final again = bs.toGregorian(
            year: back.year,
            month: back.month,
            day: back.day,
          );
          expect(again, date, reason: 'round trip failed at $date');
          count++;
          date = date.add(const Duration(days: 1));
        }

        expect(count, bs.daysInYear(year),
            reason: 'BS $year should have $count days');
      }
    });

    test('consecutive BS days are consecutive AD days', () {
      for (final year in [2000, 2082, 2083]) {
        final first = bs.firstDayOfMonth(year, BsCalendar.baishakh);
        for (var i = 1; i < 30; i++) {
          final previousBs = bs.fromGregorian(first.add(Duration(days: i - 1)));
          final currentBs = bs.fromGregorian(first.add(Duration(days: i)));
          final expectedDay = previousBs.day + 1;
          expect(
            currentBs.day,
            expectedDay <= 30 ? expectedDay : 1,
            reason: 'discontinuity on day $i of BS $year',
          );
        }
      }
    });

    test('converting a date back gives the same date', () {
      final ad = DateTime(2026, 9, 29);
      final bsDate = bs.fromGregorian(ad);
      final again = bs.toGregorian(
        year: bsDate.year,
        month: bsDate.month,
        day: bsDate.day,
      );
      expect(again, ad);
    });

    test('the time of day never shifts the date', () {
      // Only the date part matters, so a late-evening timestamp must not roll
      // into the next day.
      final midnight = bs.toGregorian(year: 2083, month: 1, day: 1);
      final lateEvening =
          DateTime(midnight.year, midnight.month, midnight.day, 23, 59, 59);
      expect(bs.fromGregorian(lateEvening).day, 1);
      expect(bs.fromGregorian(midnight).day, 1);
    });
  });

  group('Anchors', () {
    test('the epoch is correct', () {
      // 1 Baishakh 2000 BS = 14 April 1943 AD, a widely published anchor.
      expect(
        bs.toGregorian(year: 2000, month: BsCalendar.baishakh, day: 1),
        DateTime(1943, 4, 14),
      );
    });

    test('the Nepali fiscal year anchors are correct', () {
      expect(
        bs.toGregorian(year: 2082, month: BsCalendar.shrawan, day: 1),
        DateTime(2025, 7, 17),
      );
      expect(
        bs.toGregorian(year: 2083, month: BsCalendar.shrawan, day: 1),
        DateTime(2026, 7, 17),
      );
      expect(
        bs.toGregorian(year: 2082, month: BsCalendar.baishakh, day: 1),
        DateTime(2025, 4, 14),
      );
    });
  });
}
