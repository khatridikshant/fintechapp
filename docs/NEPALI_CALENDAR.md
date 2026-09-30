# The Nepali calendar, explained

Written for someone who is not a calendar engineer. It explains what the
Bikram Sambat calendar is, why this application cannot work without it, what has
been checked so far, and — importantly — **what has not been checked, and how to
check it before launch**.

If you read one section, read **"What has not been verified yet"**.

---

## Why this application needs a calendar at all

Nepal does not use January to December as its financial year. The financial year
runs from **1 Shrawan to the end of Ashadh**, which is roughly mid-July to
mid-July in the Gregorian calendar.

This is not a preference. It is the Nepali tax year, the Nepali fiscal year, and
how Nepali businesses file. An accounting system that put a March transaction in
the wrong year would produce a wrong tax return.

So the application has to answer one question precisely: **which financial year
does this date fall into?**

---

## What Bikram Sambat is

Bikram Sambat, usually shortened to **BS**, is the calendar used in Nepal and
Nepal's neighbouring countries. It is roughly 57 years ahead of the Gregorian
calendar. When you read **2082** in a Nepali document, that is not the year 2082
of anything you would recognise.

- Today, 30 September 2026 (Gregorian), is about **2083 Ashwin** in BS.
- The fiscal year **2082/83** ran from **17 July 2025 to 16 July 2026**.

The application shows BS years the way Nepali businesses do, and stores dates
internally in a way that cannot be confused.

### The twelve months

| # | BS month | Roughly falls in |
| --- | --- | --- |
| 1 | Baishakh | mid-April to mid-May |
| 2 | Jestha | mid-May to mid-June |
| 3 | Ashadh | mid-June to mid-July |
| **4** | **Shrawan** | **mid-July to mid-August** ← fiscal year starts here |
| 5 | Bhadra | mid-August to mid-September |
| 6 | Ashwin | mid-September to mid-October |
| 7 | Kartik | mid-October to mid-November |
| 8 | Mangsir | mid-November to mid-December |
| 9 | Poush | mid-December to mid-January |
| 10 | Magh | mid-January to mid-February |
| 11 | Falgun | mid-February to mid-March |
| 12 | Chaitra | mid-March to mid-April |

The fiscal year starts in month 4 and ends in month 3 of the *next* year. That is
why a year is written **2082/83** rather than just 2082.

---

## Why the dates cannot be worked out by a formula

This is the part that surprises people.

A Gregorian month has a fixed length: April is always 30 days, so April's length
is a rule. A **BS month has no fixed length.** Months are 29, 30, 31, or 32 days,
and the lengths change from year to year depending on how the lunar and solar
cycles line up.

So there is no formula. The only way to know when Shrawan 1, 2083 falls is to
have a **table** that says how many days each month of each year contains.

That table is a list of facts. The Government of Nepal sets it and the **Nepal
Panchanga Nirnayak Samiti** publishes the official calendar. It is data in the
same way that "April has 30 days" is data.

---

## How this application stores the data

The table lives in this repository, in
`desktop/lib/src/domain/fiscal/bs_calendar_data.dart`. It covers **BS 1969 to
BS 2199**, which is roughly Gregorian 1932 to 2143.

### Why it is not a downloaded package

The application originally used a third-party package for this. It was removed
on purpose.

The reasoning is supply chain, not licensing. That package held the single most
compliance-critical dataset in the product, and it belonged to **one person**. If
that person had changed the licence, gone commercial, been bought by a
competitor, or simply stopped maintaining it, the application would have been
unable to ship, with no practical alternative.

Keeping the data in-tree means **you** can read it, check it, and correct it.

---

## What has been verified, and how

Four independent checks. All of them run automatically, so a mistake fails the
build rather than reaching a customer.

**1. The data is internally consistent.** For every one of the 231 years, the
twelve month lengths add up to the year's total. A single wrong number would
break this.

**2. Every year is a real year length.** Every year is **365 or 366 days**. This
is the check that matters most, and it has already earned its place: see
"the fake year" below.

**3. Every month is plausible.** No month is shorter than 29 or longer than 32
days, which is the real-world range for BS months.

**4. Known dates line up.** These are published dates, asserted in the test
suite:

| BS date | Gregorian date |
| --- | --- |
| 1 Baishakh 2000 | 14 April 1943 |
| 1 Baishakh 2082 | 14 April 2025 |
| **1 Shrawan 2082** | **17 July 2025** |
| 1 Shrawan 2083 | 17 July 2026 |

The 17 July 2025 date is the one to be most confident about: it is the day
Nepal's fiscal year 2082/83 actually began.

In addition, the test suite walks **every single day of nine widely separated
years** and checks the date converts there and back again without drift. That
catches an off-by-one error that happens to line up at a year boundary.

---

## What has NOT been verified yet

**This is the honest part, and it is why this document exists.**

The checks above prove the data is **internally consistent** and **matches some
known public dates**. They do **not** prove the table matches the Government of
Nepal's published calendar in every year.

Concretely, what has *not* been done:

- No year has been compared line by line against the officially published Nepali
  calendar.
- The data's origin was a third-party open-source table, verified for consistency
  and for a handful of anchors, but not audited against the official source.
- Only a few specific years have been confirmed against outside sources. The rest
  are trusted because the table is coherent and comes from a widely used project.

**Why this matters.** If a single month length is wrong in the year your customer
is operating in, then a transaction dated near that boundary lands in the **wrong
fiscal year**. The ledger still balances, the trial balance still balances, and
nothing looks broken. But the year-end tax figure, the profit reported to the tax
office, and the opening balances of the next year are all wrong.

This is the most dangerous class of bug in the whole application, precisely
because everything still looks correct.

### How likely is it?

For **recent and current years** — the ones that will actually be used — the risk
is low. Those are the years the source table is most likely to have right, and two
of them are confirmed above.

For **distant future years**, the risk is higher and grows with distance. That is
normal: nobody can publish the exact length of a month 150 years from now, so
tables like this are projected. Far-future data is a projection, not a fact, and
this one says so implicitly by being excluded or flagged.

---

## How to verify before launch

**Pick the years your customers will actually use.** In practice that is the
current fiscal year and the next two or three. For 2026 that means roughly
**BS 2082 to BS 2085**. Verifying 231 years is not the task; verifying the years
that will be touched is.

**Get the official calendar.** The Nepal Panchanga Nirnayak Samiti publishes it,
and it is republished by Nepali newspapers and calendar publishers every year.
You need one printed or published Nepali calendar per year you intend to check.

**For each year, check two dates.** That is sufficient, because the months sum to
the year:

1. **1 Shrawan of that year** — the fiscal year start date. This is the date
   printed at the top of every Nepali calendar, so it is the easiest to find and
   the most important.
2. **The last day of Ashadh of the following year** — the fiscal year end date.
   Alternatively, check 1 Shrawan of the *next* year and take the day before it.

**Record what you checked.** Write the confirmed dates into
`test/domain/fiscal_test.dart` under `matches known published anchors`, together
with where each came from and who checked it. That way a future maintainer knows
which years are confirmed and which are merely internally consistent.

**If a date is wrong,** correct that year's entry in
`bs_calendar_data.dart`. The consistency tests will immediately tell you if the
correction breaks the year total, and the existing anchors will tell you if you
have broken something that used to work.

---

## The "fake year" that was found and removed

The source table's last entry, **BS 2200**, consisted of twelve 31-day months
totalling **372 days**.

No calendar year is 372 days. That was placeholder data, generated to fill the
end of the table, not a real calendar. Shipping it would have meant that a
customer operating in the year 2200 would have received a fiscal year that was
seven days longer than it should be.

It has been **excluded**, and a request for a fiscal year needing it is refused
with a clear error rather than answered with nonsense. The application's stated
range is **BS 1969 to BS 2199**.

This is the clearest example of why the "every year is 365 or 366 days" test
exists. It was written after finding this, and it would catch the same class of
problem in any future data.

---

## A bug that was fixed along the way

The removed package applied a **fixed +5:45 offset**, the timezone in Nepal. That
means it assumed every user was in Nepal.

A Nepali customer working from Australia, the UK, or India would have been shown
dates shifted by the difference between their timezone and Nepal's. On a date
boundary that is the difference between a transaction being in the right fiscal
year and the wrong one.

The replacement does all of its arithmetic in **UTC**, where every day is exactly
24 hours and daylight saving cannot shift a date, and then presents the result as
a plain calendar date with no time on it. The calendar is now correct on a
computer set to any timezone in the world.

---

## What happens if a date is wrong

So the risk is not hypothetical, it is worth being clear about it.

- Transactions near the affected boundary would be filed in the wrong year.
- The journal would still balance. Every internal check would still pass.
- The profit and the tax figure for the year would be wrong.
- The opening balances of the following year would be wrong.

Because nothing would look broken, this is exactly the kind of defect that must be
checked by a person against an outside source, rather than trusted to tests that
only prove the data agrees with itself.

---

## Glossary

| Term | Meaning |
| --- | --- |
| **BS / Bikram Sambat** | The calendar used in Nepal. Roughly 57 years ahead of the Gregorian calendar. |
| **AD / Gregorian** | The January-to-December calendar used for the specification and most of the world. |
| **Shrawan** | BS month 4. The fiscal year starts here. Roughly mid-July. |
| **Ashadh** | BS month 3. The fiscal year ends here. Roughly mid-June to mid-July. |
| **FY 2082/83** | The fiscal year starting 1 Shrawan 2082 and ending at the end of Ashadh 2083. |
| **Nepal Panchanga Nirnayak Samiti** | The body that sets and publishes the official Nepali calendar. |
| **Projected year** | A future year whose month lengths are predicted rather than known. Real calendars are not available that far ahead. |

---

## See also

- `docs/decisions/009-bikram-sambat-calendar.md` — the formal decision record,
  including the supply-chain reasoning.
- `desktop/lib/src/domain/fiscal/bs_calendar_data.dart` — the data itself, with its
  own documentation.
- `desktop/lib/src/domain/fiscal/bs_calendar.dart` — the conversion, and the UTC
  handling.
- `desktop/test/domain/bs_calendar_data_test.dart` — the integrity checks, and
  where to add newly confirmed dates.
- `Rewritten_Business_Application_Architecture.txt` section 29 — the
  specification's fiscal-year requirements.
