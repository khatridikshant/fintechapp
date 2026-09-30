# ADR 009 — Bikram Sambat calendar: `bikram_sambat`

**Status:** Accepted. Supersedes the "open question" recorded in
`PROGRESS.md` section 7.10.

## Context

The specification defines the fiscal year as **1 Shrawan to the end of Ashadh**
and identifies years as **FY 2082/83**. Those are Bikram Sambat (BS) dates. The
rest of the specification uses Gregorian dates.

BS cannot be converted with a formula. Months are **29 to 32 days long and the
lengths change from year to year**, driven by published data rather than
arithmetic. A wrong or missing entry does not produce a wrong-looking date; it
files a transaction under the wrong fiscal year, which silently misstates
revenue, cost, and tax for two periods at once. That is the exact class of
defect the architecture exists to prevent.

The product owner authorised a third-party BS calendar, subject to a permissive
licence.

## Decision

Use the **`bikram_sambat`** package, version `1.2.0`.

| | |
| --- | --- |
| Licence | **MIT** — Copyright (c) 2024 Kedar Karki |
| Type | Pure Dart, **no transitive dependencies** |
| Coverage | **BS 1969 to 2200** |
| Published | Actively maintained; 160 pub points |

Candidates rejected:

| Package | Reason |
| --- | --- |
| `nepali_calendar` | Licence is **`unknown`** on pub.dev, six years old, Dart 3 incompatible. An unknown licence is not a permissive licence. |
| `bs_ad_calendar` | MIT, but it is a Flutter calendar **widget** package. The conversion is needed in the domain, which must not depend on Flutter UI. |
| `clean_nepali_calendar` | BSD-3, but also a Flutter UI calendar and it pulls in `nepali_utils`. |

## Consequences

**Isolation.** `lib/src/domain/fiscal/bs_calendar.dart` is the only file in the
project that imports `bikram_sambat`. Everything else depends on `BsCalendar`, so
the package can be pinned, swapped, or removed by editing one file, and the
fiscal rules are unaffected.

**The supported range is enforced, not guessed.** `BsCalendar` throws
`BsYearOutOfRangeException` outside BS 1969 to 2200. Silently extrapolating would
place transactions in the wrong fiscal year.

**The final year in the table is not fully usable.** Measuring a year, or the
final month of a year, needs the following year's data. `latestUsableYear` is
therefore `2199`, and `NepaliFiscalCalendar` refuses to build a fiscal year that
would need `2201`. This was a real defect found by a test: the original
implementation leaked a `RangeError` from inside the third-party package instead
of failing with a domain error.

**Attribution.** The MIT licence requires the copyright notice to be retained.
Flutter aggregates dependency licence texts and exposes them through
`showLicensePage`, so the application **must** provide a reachable licences or
"about" screen. Treat that as a requirement of the UI gate, not a nicety.

**Month lengths are derived, not copied.** `bikram_sambat` does not expose a
month-length table, so `BsCalendar.daysInMonth` walks forward until the month
changes. That method is validated by a test asserting the twelve month lengths
sum to the true length of the year across a spread of years, which would fail if
the walk were off by one.

**Verified against published anchors.** 1 Shrawan 2082 equals 17 July 2025, the
day Nepal's FY 2082/83 began, and 1 Baishakh 2082 equals 14 April 2025. These are
asserted in `test/domain/fiscal_test.dart` so that a package update which shifts
the calendar fails the build rather than silently moving the fiscal boundary.

## Why not implement the calendar ourselves

It would mean embedding and maintaining a 232-year boundary table whose
provenance we would have to establish independently. The package is MIT, pure
Dart, dependency-free, and isolated behind one file, so the cost of adopting it
is low and the cost of reversing the decision is one file.
