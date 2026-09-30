# ADR 009 — Bikram Sambat calendar: in-tree data, not a package

**Status:** Accepted. **Supersedes the earlier version of this ADR**, which
selected the `bikram_sambat` package. Rejected by the product owner on
2026-09-30.

## Context

The fiscal year runs from **1 Shrawan to the end of Ashadh** and is identified as
**FY 2082/83** — Bikram Sambat (BS) dates. Everything else in the specification is
Gregorian.

BS cannot be derived from the Gregorian calendar. Months are 29 to 32 days long
and the lengths change year to year, so the boundaries come from published data.

That data is **the single most compliance-critical dataset in the product**. Get a
fiscal boundary wrong and transactions land in the wrong year, which distorts
revenue, cost, and tax across two periods at once.

## The decision that was reversed

An earlier version of this ADR adopted the `bikram_sambat` package: MIT, pure
Dart, no transitive dependencies, covering BS 1969 to 2200.

**The product owner rejected it on supply-chain grounds**, which is the right
reason. It was a dependency on a single maintainer for the one piece of data the
product cannot ship without. If that author changed the licence, went commercial,
was bought, or stopped maintaining the package, the fiscal calendar would become
un-shippable. For a commercial Nepali product that is a real exposure, and
"MIT today" is not a guarantee about "MIT when we need to ship".

## Decision

**Keep the calendar data in-tree**, in
`lib/src/domain/fiscal/bs_calendar_data.dart`, and implement the conversion
ourselves in `bs_calendar.dart`.

The data is a table of month lengths per BS year. That is **factual civil-calendar
information**, set by the Government of Nepal and published by the Nepal Panchanga
Nirnayak Samiti. How many days a given Nepali month has is a fact, in the same way
that how many days April has is a fact. Facts are not owned by anyone, which is
exactly why this is reasonable to keep in-tree where the team can audit it.

The table was originally taken from `bikram_sambat` (MIT, © 2024 Kedar Karki),
so that provenance is recorded rather than glossed over. Retaining a first-party
copy of the data is not a licence question; the licence question was about
depending on the *package*, and that is what has been removed.

## Consequences

**Coverage is BS 1969 to BS 2199**, roughly AD 1932 to AD 2143.

**The upstream BS 2200 entry was excluded.** It consisted of twelve 31-day months
totalling **372 days**, which no calendar year can be. It was projected
placeholder data, not a real calendar, and carrying it as though it were
authoritative would have been worse than not having it. A fiscal year needing BS
2200 is now refused with a clear error rather than answered with nonsense.

**The data is ours, so the data is tested.** `test/domain/bs_calendar_data_test.dart`
checks that every year has twelve months, every month is 29 to 32 days, **every
year is 365 or 366 days**, the years are contiguous, and the excluded placeholder
is absent. It also walks **every single day of nine spread-out years** and asserts
the conversion round-trips, which is what catches an off-by-one that happens to
line up at a year boundary.

**A latent timezone bug was fixed in the process.** The package applied a fixed
**+5:45 Nepal offset**, so a user whose machine was set to any other timezone
would have been given dates shifted by that offset. Our implementation does all
arithmetic in **UTC**, where every day is exactly 24 hours and daylight saving
cannot move a date, and then presents the result as a local date-only value. The
calendar is now correct on a machine in any timezone.

**Attribution is no longer required for the calendar.** The MIT notice for
`bikram_sambat` disappears from the licences page along with the dependency. The
in-tree data carries its provenance in its own documentation.

## Open item: verify against the official calendar before shipping

The table has been checked for **internal consistency** (every year's twelve
month lengths sum to its stated length) and against **known public anchors** —
1 Baishakh 2000 BS = 14 April 1943, 1 Shrawan 2082 = 17 July 2025, 1 Baishakh
2082 = 14 April 2025. Those anchors are asserted in the tests, so a data error
would fail the build.

**That is not the same as an audit against the Government of Nepal's published
calendar.** Before launch, the years the product will actually be used in should
be checked against the official Nepali calendar. This is recorded here so it is
not assumed done.
