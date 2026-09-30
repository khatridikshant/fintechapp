# Backup and record retention, explained

Written for a business owner, not an engineer. It explains why losing the
database file is a legal problem and not just an inconvenience, what this
application does about it, and what it still does not do.

If you read one section, read **"What the application does now"** and then
**"What it still does not do"**.

---

## Why this matters more than it first appears

The application keeps your books in a single file on your computer — one file per
fiscal year, for example `accounting-FY-2082-83.db`.

That file is **the books**. There is no server copy. If it is deleted, or
corrupted, or the disk fails, then:

- every invoice, payment, expense, and journal entry is gone
- the trial balance and all reports are gone with it
- there is nothing to reconstruct it from

And unlike losing a document, this is not merely annoying. **Nepali tax law
requires a business to keep its books for a number of years.** A business that
cannot produce its records on demand is in a worse position than one that simply
had a bad year. So a lost file is a compliance failure, not only a data loss.

---

## What Nepali law asks for

**Read this section with the caveat at the end.**

Nepal requires businesses to maintain books of account and to keep them for
periods set by law. The two provisions that most often matter to a small
business are:

1. **Income tax.** The **Income Tax Act, 2058 (2001)** requires a person carrying
   on a business to maintain accounts and supporting records, and to retain them
   for a period after the end of the relevant income year. The figure commonly
   cited for income tax records is **five years**.
2. **Value Added Tax.** The **Value Added Tax Act, 2052 (1996)** requires
   registered persons to keep accounts, invoices, and returns, and its retention
   period is commonly cited as **six years**.

Other provisions can apply depending on your business — the Companies Act, for
instance, for a registered company.

### ⚠️ Verify this before relying on it

The general shape above — that books must be kept for **several years, and the
figure differs between income tax and VAT** — is well established and is why
retention matters. However:

- I have **not verified the exact number of years** against the current text of
  either Act, and the figures cited above are the commonly quoted ones, not a
  legal opinion.
- **Which provisions apply to you depends on your registration** — whether you
  are VAT-registered, whether you are a company, and your turnover.
- The retention clock starts from a defined point, and **which point** matters: an
  income year, a tax year, or the date of filing.

**Ask a Nepali chartered accountant or tax practitioner for the periods that
apply to your business.** This document is a design record. It is not accounting
or legal advice.

### What follows from it, whatever the exact number

The design does not depend on whether the answer is five years or six:

- **Backups must not be deleted casually.** An application that quietly discards
  last year's backup would destroy a record the law may require you to produce.
- **A backup must be verifiable.** A backup file that cannot be proved to be
  intact is not a record; it is a file with an optimistic name.
- **You must be able to see whether a backup exists, and when it was taken.** A
  retention obligation is impossible to meet if nobody knows the state of the
  records.

---

## What the application does now

### 1. It backs up **every** fiscal year, not only the current one

Because each year is its own file, a business that has traded for three years has
**three sets of books**, and all three must be kept. The application finds every
`accounting-FY-*.db` in your books folder and backs up all of them in one action.

This matters more than it sounds. The **older years are the ones closest to the
retention clock** and the most likely to be asked for, so a backup that covered
only the year you happen to be working in would leave the most exposed records
unprotected — while still looking reassuring.

The Backup screen lists every year it found and says plainly which ones have **no
backup at all**. If a year could not be backed up, the application says so and
names it, rather than quietly covering the rest and reporting success.

### 2. It takes a real snapshot, not a file copy

The obvious way to back up would be to copy the file. That is **wrong**, and
dangerously so.

If the application writes to the database while a copy is being taken, the copy
can capture the file halfway through a change. The result is a file that looks
like a database, has a plausible size, and is **quietly corrupt**. You would not
find out until the day you needed it.

Instead the application asks SQLite to produce a **consistent snapshot** using
`VACUUM INTO`. SQLite knows how to write out a complete, self-consistent copy
while the database is in use. The copy is correct by construction.

### 3. It proves the snapshot before trusting it

Every backup is checked before it is accepted:

- a **SHA-256 checksum** of the finished file is recorded, so later tampering or
  corruption is detectable
- SQLite's own **integrity check** runs against the snapshot, so a snapshot that
  is not a valid database is rejected rather than filed away as though it were
  fine

**A backup that fails either check is treated as a failed backup.** This is
deliberate: the alternative is a directory full of files that feel like a safety
net and are not one.

### 4. Nothing is ever overwritten

Backups are timestamped and kept, not rotated. Taking a new backup never destroys
an older one. Given the retention obligation above, discarding history is exactly
the wrong default.

### 5. Restoring protects what it replaces

Restoring replaces your current books with a backup, which is a genuinely
destructive act. So the order is:

```
verify the backup  ->  take an emergency backup of the CURRENT books
                   ->  replace  ->  verify the result
```

If the chosen backup turns out to be unusable, it is refused **before** anything
is touched. And the current books are captured first, so a wrong choice is
recoverable.

### 6. It is checked by actually restoring

An untested backup is not a backup. The test suite takes a backup, changes the
data, restores, and asserts the original figures came back. A backup that has
never been restored has only been *assumed* to work.

---

## What it still does not do

Being explicit, so none of this is assumed:

1. **No off-machine copy.** Everything above protects against a corrupt or
   accidentally deleted file. It does **not** protect against the disk failing,
   the computer being lost or stolen, or a fire. For that, a backup must leave
   the machine — onto a USB drive, an external disk, or the cloud.

   **This is the remaining gap, and it is the big one.** The application can now
   produce a verified backup reliably; getting it off the machine is not built
   yet.

2. **No automatic schedule.** Backups are taken when asked for. A business that
   forgets to press the button has no recent backup.

3. **No cloud backup or restore.** Gate 9 in `PROGRESS.md`. That needs the
   backend, which is not built.

4. **No encryption.** A backup file is readable by anyone who can open it. If a
   USB drive is lost, so are the books.

5. **A backup is per year, not one single file.** Every year is covered by the
   same action and each year gets its own file, which is what makes a restore
   possible without touching the other years. There is no single archive holding
   every year together.

---

## What you should do until the off-machine gap is closed

- **Take a backup at the end of every working day**, or at least every week, and
  after any large amount of entry.
- **Copy the backup folder onto a USB drive or an external disk.** The
  application cannot do this for you yet, so it is a manual step. Do it anyway —
  it is the difference between losing a day and losing everything.
- **Keep the external copy away from the computer**, so that a single incident
  cannot take both.
- **Never delete the only copy of a closed year.** Once a fiscal year is
  concluded it is a permanent record.

---

## Glossary

| Term | Meaning |
| --- | --- |
| **Books** | The accounting records of the business. In this application, the database file. |
| **Fiscal year** | The Nepali accounting year, 1 Shrawan to the end of Ashadh. See `NEPALI_CALENDAR.md`. |
| **Snapshot** | A complete, self-consistent copy of the database at one moment. |
| **Checksum** | A short code derived from a file's contents. If even one byte changes, the code changes, so corruption is detectable. |
| **Integrity check** | SQLite's own test that a database file is valid and not damaged. |
| **Retention period** | How long the law requires records to be kept. |

---

## See also

- `docs/decisions/007-sync-strategy.md` — the cloud backup and restore design,
  which uses the same verification rules.
- `docs/decisions/002-fiscal-year-per-database.md` — why each year is a separate
  file.
- `PROGRESS.md` section 9 — the gate tracker, where cloud backup is Gate 9.
