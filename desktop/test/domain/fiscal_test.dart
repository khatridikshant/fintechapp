import 'package:financeapp/src/domain/fiscal/bs_calendar.dart';
import 'package:financeapp/src/domain/fiscal/fiscal_year.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const bs = BsCalendar();
  const calendar = NepaliFiscalCalendar();

  group('FiscalYear', () {
    test('rejects a period that ends before it starts', () {
      expect(
        () => FiscalYear(
          label: 'broken',
          start: DateTime(2026, 7, 17),
          end: DateTime(2026, 7, 16),
        ),
        throwsArgumentError,
      );
    });

    test('accepts a single-day period', () {
      final year = FiscalYear(
        label: 'one day',
        start: DateTime(2026, 7, 17),
        end: DateTime(2026, 7, 17),
      );
      expect(year.dayCount, 1);
      expect(year.contains(DateTime(2026, 7, 17)), isTrue);
    });

    test('includes both boundary dates', () {
      final year = FiscalYear(
        label: 'test',
        start: DateTime(2026, 7, 17),
        end: DateTime(2027, 7, 16),
      );

      expect(year.contains(DateTime(2026, 7, 17)), isTrue,
          reason: 'the first day is inside the period');
      expect(year.contains(DateTime(2027, 7, 16)), isTrue,
          reason: 'the last day is inside the period');
    });

    test('excludes the day before the start and the day after the end', () {
      final year = FiscalYear(
        label: 'test',
        start: DateTime(2026, 7, 17),
        end: DateTime(2027, 7, 16),
      );

      expect(year.contains(DateTime(2026, 7, 16)), isFalse);
      expect(year.contains(DateTime(2027, 7, 17)), isFalse);
    });

    test('a time of day on the last day is still inside', () {
      // This is the off-by-one that matters. Comparing raw instants would test
      // 2027-07-16 14:30 against midnight of the last day and wrongly reject a
      // transaction posted during the final afternoon of the fiscal year.
      final year = FiscalYear(
        label: 'test',
        start: DateTime(2026, 7, 17),
        end: DateTime(2027, 7, 16),
      );

      expect(year.contains(DateTime(2027, 7, 16, 14, 30)), isTrue);
      expect(year.contains(DateTime(2027, 7, 16, 23, 59, 59)), isTrue);
      expect(year.contains(DateTime(2026, 7, 17, 0, 0, 1)), isTrue);
    });

    test('a time of day just outside the range is outside', () {
      final year = FiscalYear(
        label: 'test',
        start: DateTime(2026, 7, 17),
        end: DateTime(2027, 7, 16),
      );

      expect(year.contains(DateTime(2026, 7, 16, 23, 59)), isFalse);
      expect(year.contains(DateTime(2027, 7, 17, 0, 0, 1)), isFalse);
    });

    test('compares by value', () {
      final a = FiscalYear(
          label: 'FY 2082/83',
          start: DateTime(2025, 7, 17),
          end: DateTime(2026, 7, 16));
      final b = FiscalYear(
          label: 'FY 2082/83',
          start: DateTime(2025, 7, 17),
          end: DateTime(2026, 7, 16));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('BsCalendar', () {
    test('matches known published anchors', () {
      // Nepal's FY 2082/83 began on 17 July 2025.
      expect(
        bs.toGregorian(year: 2082, month: BsCalendar.shrawan, day: 1),
        DateTime(2025, 7, 17),
      );
      // Baishakh 1 is Nepali New Year.
      expect(
        bs.toGregorian(year: 2082, month: BsCalendar.baishakh, day: 1),
        DateTime(2025, 4, 14),
      );
    });

    test('converts in both directions', () {
      final ad = bs.toGregorian(year: 2082, month: 8, day: 29);
      final back = bs.fromGregorian(ad);

      expect(back.year, 2082);
      expect(back.month, 8);
      expect(back.day, 29);
    });

    test('round-trips every day of a BS year without drift', () {
      final start = bs.firstDayOfMonth(2082, BsCalendar.baishakh);
      final total = bs.daysInYear(2082);

      for (var offset = 0; offset < total; offset++) {
        final ad = start.add(Duration(days: offset));
        final converted = bs.fromGregorian(ad);
        final roundTripped = bs.toGregorian(
          year: converted.year,
          month: converted.month,
          day: converted.day,
        );
        expect(roundTripped, ad, reason: 'drifted at offset $offset');
      }
    });

    test('month lengths are self-consistent with the year length', () {
      // The month lengths come from walking until the month rolls over. If that
      // walk were off by one anywhere, the twelve lengths would no longer sum to
      // the true length of the year, so this checks the method rather than
      // trusting it.
      for (final year in [1969, 2000, 2070, 2082, 2083, 2090, 2100, 2199]) {
        final sum = List.generate(12, (i) => bs.daysInMonth(year, i + 1))
            .fold<int>(0, (a, b) => a + b);
        expect(sum, bs.daysInYear(year),
            reason: 'month lengths do not add up for BS $year');
        expect(sum, greaterThanOrEqualTo(365));
        expect(sum, lessThanOrEqualTo(366));
      }
    });

    test('the final year in the table cannot be measured, and says so', () {
      // Measuring BS 2200's last month needs BS 2201, which the table does not
      // contain. This must fail with a clear domain error rather than a range
      // error from inside the third-party package, and it must never be guessed.
      expect(
        () => bs.daysInMonth(BsCalendar.latestYear, 12),
        throwsA(isA<BsYearOutOfRangeException>()),
      );
      expect(
        () => bs.daysInYear(BsCalendar.latestYear),
        throwsA(isA<BsYearOutOfRangeException>()),
      );

      // The last usable year still works.
      expect(bs.daysInYear(BsCalendar.latestUsableYear), greaterThan(364));
    });

    test('every month length is a plausible 29 to 32 days', () {
      for (final year in [2070, 2082, 2083, 2090]) {
        for (var month = 1; month <= 12; month++) {
          final days = bs.daysInMonth(year, month);
          expect(days, greaterThanOrEqualTo(29),
              reason: 'BS $year-$month was implausibly short');
          expect(days, lessThanOrEqualTo(32),
              reason: 'BS $year-$month was implausibly long');
        }
      }
    });

    test('the last day of a month is followed by the first day of the next',
        () {
      for (var month = 1; month <= 11; month++) {
        final last = bs.lastDayOfMonth(2083, month);
        final nextFirst = bs.firstDayOfMonth(2083, month + 1);
        expect(nextFirst.difference(last).inDays, 1,
            reason: 'gap between BS 2083-$month and month ${month + 1}');
      }
    });

    test('an unsupported BS year is refused rather than guessed', () {
      expect(
        () => bs.toGregorian(year: 1900, month: 1, day: 1),
        throwsA(isA<BsYearOutOfRangeException>()),
      );
      expect(
        () => bs.toGregorian(year: 2500, month: 1, day: 1),
        throwsA(isA<BsYearOutOfRangeException>()),
      );
    });

    test('a day that does not exist in the month is refused', () {
      final tooLong = bs.daysInMonth(2083, 8) + 1;
      expect(
        () => bs.toGregorian(year: 2083, month: 8, day: tooLong),
        throwsRangeError,
      );
      expect(
          () => bs.toGregorian(year: 2083, month: 8, day: 0), throwsRangeError);
      expect(
        () => bs.toGregorian(year: 2083, month: 13, day: 1),
        throwsRangeError,
      );
    });
  });

  group('NepaliFiscalCalendar', () {
    test('the fiscal year runs from 1 Shrawan to the end of Ashadh', () {
      final year = calendar.forBsYear(2082);

      expect(year.label, 'FY 2082/83');
      expect(year.startDate, DateTime(2025, 7, 17), reason: '1 Shrawan 2082');
      expect(year.endDate, bs.lastDayOfMonth(2083, BsCalendar.ashadh));
    });

    test('the year ends the day before the next one begins', () {
      final year = calendar.forBsYear(2082);
      final next = calendar.forBsYear(2083);

      expect(year.endDate.add(const Duration(days: 1)), next.startDate);
      expect(year.dayCount, 365);
    });

    test('does not end in Shrawan, and does not start in Ashadh', () {
      final year = calendar.forBsYear(2082);

      // Shrawan is month 4 and Ashadh is month 3, so the period spans the BS
      // year boundary. A fiscal year that started and ended in the same BS
      // calendar year would be a different, wrong rule.
      expect(bs.fromGregorian(year.startDate).month, BsCalendar.shrawan);
      expect(bs.fromGregorian(year.endDate).month, BsCalendar.ashadh);
      expect(bs.fromGregorian(year.endDate).year, 2083);
    });

    test('labels use two digits for the second year', () {
      expect(NepaliFiscalCalendar.labelForBsYear(2082), 'FY 2082/83');
      expect(NepaliFiscalCalendar.labelForBsYear(2089), 'FY 2089/90');
      expect(NepaliFiscalCalendar.labelForBsYear(2099), 'FY 2099/00');
    });

    test('finds the fiscal year containing a date', () {
      // 29 September 2026 is in BS 2083 month 6, after Shrawan, so it belongs to
      // the year that started in 2083.
      final autumn = calendar.containing(DateTime(2026, 9, 29));
      expect(autumn.label, 'FY 2083/84');
      expect(autumn.contains(DateTime(2026, 9, 29)), isTrue);

      // 1 May 2026 is in BS 2083 month 1, before Shrawan, so it still belongs to
      // the year that started in 2082.
      final spring = calendar.containing(DateTime(2026, 5, 1));
      expect(spring.label, 'FY 2082/83');
      expect(spring.contains(DateTime(2026, 5, 1)), isTrue);
    });

    test('the boundary dates fall in the right fiscal year', () {
      final year = calendar.forBsYear(2082);

      expect(calendar.containing(year.startDate).label, 'FY 2082/83');
      expect(calendar.containing(year.endDate).label, 'FY 2082/83');
      expect(
        calendar.containing(year.endDate.add(const Duration(days: 1))).label,
        'FY 2083/84',
      );
      expect(
        calendar
            .containing(year.startDate.subtract(const Duration(days: 1)))
            .label,
        'FY 2081/82',
      );
    });

    test('containing agrees with forBsYear across a whole year', () {
      final year = calendar.forBsYear(2082);

      for (var offset = 0; offset < year.dayCount; offset++) {
        final date = year.startDate.add(Duration(days: offset));
        expect(calendar.containing(date).label, year.label,
            reason: 'day $offset of ${year.label} was misattributed');
      }
    });

    test('a fiscal year that would need the missing final year is refused', () {
      expect(
        () => calendar.forBsYear(BsCalendar.latestYear),
        throwsA(isA<BsYearOutOfRangeException>()),
      );
      expect(
        () => calendar.forBsYear(BsCalendar.earliestYear - 1),
        throwsA(isA<BsYearOutOfRangeException>()),
      );
      // The last usable year still produces a complete period.
      expect(
        () => calendar.forBsYear(BsCalendar.latestUsableYear),
        returnsNormally,
      );
    });
  });
}
