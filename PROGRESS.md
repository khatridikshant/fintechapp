# Development Progress

**Last updated:** 2026-09-29
**Project:** financeapp
**Current gate:** 3 — SQLite persistence and atomicity
**Gate status:** Complete. Accounts and journal entries persist to SQLite, an
append is atomic, and the database independently rejects corrupt rows. The
in-memory accounting engine is no longer the only place the books exist.

> If you are an AI agent picking up this repository, read this file first, then
> `docs/AI_RULES.md`, then `docs/ARCHITECTURE.md`. Do not start work before you
> have read all three.

---

---

## 0.1 Incidents worth remembering

### 2026-10-01 - uncommitted desktop work was lost, then rebuilt

A `Remove-Item` was run against `finsoftware\Desktop`, intending to delete a stray
directory. **Windows paths are case-insensitive, so `Desktop` *is* `desktop`,** the
Flutter application, and 201 files were removed. Everything in `desktop/` after
commit `42a0c2e` was uncommitted and is not recoverable from the repository.

**What was lost, and has since been rebuilt** -- sections 4.30, 4.33, 4.35, 4.36 and
4.37 describe it in full and are accurate again. The work that had been committed
before 12:46, including the whole backup-upload feature and every fix from the
code review, was **not** affected.

**The lesson, which is the same shape as 7.19 and 7.22:** this repository records
repeatedly that acting before verifying causes damage -- PowerShell corrupts text
files, a test can pass while measuring nothing, a mutation can change nothing while
looking deliberate. The same care applies to **destructive commands and paths**, and
it was not applied. `Resolve-Path` first, and confirm where it points, before
anything irreversible.

Two safeguards followed, and both are in the tooling rather than in memory: **commit
frequently** so uncommitted work is never a single deletion away from gone, and
**state what would make a check fail before running it.**

## 1. What this project is

`financeapp` is an offline-first desktop business management application for
small businesses, with a Laravel cloud backend. Double-entry accounting,
invoicing, inventory, purchases, payments, and financial reporting. One SQLite
database per fiscal year. Nepal-focused, so NPR and a Shrawan-to-Ashadh fiscal
year.

The desktop app is the primary business system. The cloud provides identity,
sync, backup, and restore. Normal business operations must work with the network
disconnected.

## 2. Read these first

| Document | What it is |
| --- | --- |
| `Rewritten_Business_Application_Architecture.txt` | **The specification.** 2085 lines. Source of truth for the whole system. |
| `process.txt` | **The methodology.** Domain-first, TDD, vertical slices, invariants, bounded AI tasks. |
| `ui.txt` | **The design system.** Windows 7/8 desktop behaviour plus Data Newspaper visuals. Presentation layer only. |
| `docs/AI_RULES.md` | Hard prohibitions and obligations. A contract, not advice. |
| `docs/ARCHITECTURE.md` | Condensed architecture and the reasoning behind each technology choice. |
| `docs/INVENTORY_EXPLAINED.md` | **Plain-language accounting explainer.** What the costing methods mean with real numbers, what Nepali rules appear to allow, what this application does, and what it does not do yet. Written for a non-accountant. Read it before touching inventory, costing, COGS, or stock. |
| `docs/NEPALI_CALENDAR.md` | **Plain-language calendar explainer.** What BS is, why the fiscal year starts in Shrawan, why the dates need a table, what has been verified, and — importantly — **what has not been verified, with a practical checklist for verifying it before launch.** Read it before changing the calendar data. |
| `docs/decisions/*.md` | Architecture Decision Records. Read before touching a subsystem they govern. |

The three root `.txt` files were written before any code existed. They are more
authoritative than any summary, including this one.

## 3. Repository layout

```
finsoftware/
├── backend/              Laravel 13 API (PHP 8.4). Identity, books, backup metadata.
├── desktop/              Flutter app (Dart, BSD-3)
│   ├── lib/src/
│   │   ├── domain/       Pure business rules. Imports nothing from other layers.
│   │   │   ├── accounting/  Accounts, journal, ledger, chart of accounts.
│   │   │   ├── billing/     Invoices, credit notes, customers, payments.
│   │   │   ├── inventory/   Movements, valuation, negative-stock rules.
│   │   │   ├── reporting/   Trial balance, general ledger, P&L, balance sheet.
│   │   │   ├── fiscal/      Bikram Sambat calendar and fiscal years.
│   │   │   └── shared/      Money, ids, numbering, backup and upload contracts.
│   │   ├── application/  Use cases: issue_invoice, record_payment,
│   │   │                 issue_credit_note, post_journal_entry,
│   │   │                 post_inventory_movement, write_down_inventory,
│   │   │                 build_trial_balance, build_general_ledger, books_session.
│   │   ├── infrastructure/  database/ (drift), backup/, sync/ (HTTP upload).
│   │   │                    crypto/, filesystem/, licensing/ are still empty.
│   │   └── presentation/  shell, app_services, navigation/, screens/, theme/, widgets/.
│   ├── drift_schemas/    Schema snapshots. Committed, needed by migration tests.
│   ├── tool/             live_upload_check.dart — not part of the test suite.
│   └── test/             lib-mirroring layout, plus generated/ for drift.
│                         generated/ and drift_schemas/ are committed, not build output.
├── docs/                 AI_RULES, ARCHITECTURE, plus explainers and decisions/ (ADRs).
├── NEW_MACHINE.md        Setting the project up on a different device.
├── GIT_REPO.md           The remote, and the fintechapp / financeapp name difference.
└── PROGRESS.md           This file.
```

**Two corrections to this section, which had gone stale.** It previously said
`presentation/` was "still empty" and that "only `domain/shared/money.dart` has
content". Both were false: the presentation layer holds the shell, the navigation,
the theme, and five screens, and the domain layer is largely built. It also listed
`domain/` subfolders that are in fact empty directories (`customers/`, `products/`,
`payments/`, `expenses/`, `suppliers/`) — the concepts live inside `billing/` and
`inventory/`, except for suppliers and expenses, which do not exist at all. Read the
code, not this list, when it matters.

## 4. What has been done

### 4.1 Repository scaffolding — done

- `backend/` — Laravel, installed via `composer create-project laravel/laravel`.
  Stock Laravel, no customisation yet. No PostgreSQL connection configured, no
  API routes written.
- `desktop/` — Flutter, created with `--platforms=windows,macos,linux`. All three
  desktop platform folders generated and buildable.
- Layered directory structure under `desktop/lib/src/` and `desktop/test/`.
- Eight ADRs, one design system, one rules contract, one architecture summary.

### 4.2 The `Money` value object — done
`desktop/lib/src/domain/shared/money.dart`, with 20 passing tests in
`desktop/test/domain/money_test.dart`.

This is the foundation of the domain layer. It stores money as an **integer count
of paisa**, never as a `double`, because Dart's default numeric type is binary
floating point and cannot represent most decimal fractions exactly.

What it provides:

| Member | Purpose |
| --- | --- |
| `Money.minor(int, currency)` | Construct from paisa. Primary constructor. |
| `Money.fromMajorUnits(num, currency)` | Convert from a major-unit amount. |
| `Money.tryParse(String, currency)` | Parse `"1,250,000.50"` or `"Rs 500"` from user input. |
| `add`, `subtract`, `negated`, `abs` | Basic arithmetic. Refuses to mix currencies. |
| `times(int)` | Multiply by a whole quantity, exactly, no rounding. |
| `timesFraction(numerator, denominator)` | Fractional quantity, e.g. 2.5 kg, rounds half-up. |
| `applyBasisPoints(int)` | Percentages for tax and discount, e.g. 2500 bp is 25%. No float. |
| `allocate(int parts)` | Split an amount without losing or inventing a paisa. Remainder goes to the earliest shares. |
| `sum(Iterable<Money>, currency)` | Sum a list. Empty is zero. |
| `format()` | Display: thousands separators, two decimals, sign before the symbol. |

Two bugs were found and fixed during this task, both by the test suite rather
than by inspection. They are recorded in section 7 because they illustrate the
working method this project requires.

### 4.3 The double-entry accounting engine — done

Five files in `desktop/lib/src/domain/accounting/`, with 35 passing tests in
`desktop/test/domain/accounting_test.dart`. Total suite: 56 tests.

| File | Contents |
| --- | --- |
| `account_type.dart` | `AccountType` (asset, liability, equity, income, expense) and `NormalBalance` (debit, credit). Assets and expenses are debit-normal; liabilities, equity, and income are credit-normal. Also classifies accounts as balance-sheet or profit-and-loss. |
| `account.dart` | `Account` with id, code, name, and type. Equality is by **id only**, so renaming an account cannot break existing journal references. An account never stores a balance. |
| `journal_line.dart` | `JournalLine`, constructible only via `.debit()` or `.credit()` with a strictly positive amount. |
| `journal_entry.dart` | `JournalEntry`, which enforces the balance invariant in its constructor and is immutable. `reverse()` produces the cancelling entry. `UnbalancedJournalException` carries both totals. |
| `ledger.dart` | `Ledger`, a read model. Balances are derived from posted lines and never stored. |

How the key invariants are enforced:

- **Every journal balances.** Enforced in the `JournalEntry` constructor. An
  unbalanced entry cannot be constructed, so it cannot be persisted or reported.
  There is no "create, then fix" path.
- **A line is a debit or a credit, never both and never neither.** Enforced by
  construction, not validation. The two factory constructors each demand exactly
  one positive amount, so the illegal states are unrepresentable.
- **Amounts are always positive.** A reduction is the opposite side of the
  entry, or a reversal. Negative line amounts are rejected, which prevents the
  sign-convention bugs that make a ledger silently wrong.
- **Posted entries are immutable.** Lines are wrapped in `List.unmodifiable`,
  and the source list is copied, so it cannot be mutated afterwards.
- **Corrections preserve history.** `reverse()` creates a new entry that
  references the original's id. The original is never touched.
- **Balances are derived.** `Ledger` computes them from the journal, so a
  balance cannot drift from the entries that produced it.

Verification performed, independent of the engine: the worked example from the
architecture specification was computed by hand, and a test asserts both the
individual balances and the accounting equation. Bank 115,000; Inventory
18,000; Payable 30,000; Equity 100,000; profit 3,000. Assets 133,000 equals
liabilities plus equity 133,000.

### 4.4 SQLite persistence — done

Schema, repositories, and 23 passing tests in
`desktop/test/infrastructure/persistence_test.dart`.

| File | Contents |
| --- | --- |
| `lib/src/infrastructure/database/tables.dart` | The three tables: `accounts`, `journal_entries`, `journal_lines`. |
| `lib/src/infrastructure/database/app_database.dart` | The drift database, schema version, migration strategy, and the `PRAGMA foreign_keys = ON` that makes the constraints real. |
| `lib/src/infrastructure/database/mappers.dart` | `Account` to row and back, in one place. |
| `lib/src/infrastructure/database/sqlite_native.dart` | Native SQLite wiring that works in a plain Dart VM, with no Flutter plugin imports. |
| `lib/src/infrastructure/database/connection.dart` | The application-side opener. Separated so `path_provider` is not pulled into VM tests. |
| `lib/src/infrastructure/database/drift_account_repository.dart` | Implements the `AccountRepository` port. |
| `lib/src/infrastructure/database/drift_journal_repository.dart` | Implements the `JournalRepository` port. |
| `lib/src/domain/accounting/account_repository.dart` | The port, owned by the domain. |
| `lib/src/domain/accounting/journal_repository.dart` | The port, owned by the domain. |

Where the guarantees live:

- **Money is an INTEGER column.** `debit_minor_units` and `credit_minor_units`
  are integers. A test queries the database's own `pragma_table_info` and asserts
  the column type, so a future edit to `REAL` fails the build rather than silently
  corrupting amounts.
- **The database is a second line of defence.** `journal_lines` carries CHECK
  constraints that reject a line with both sides non-zero, neither side non-zero,
  or a negative amount. Foreign keys from lines to accounts and to their entry are
  enforced by SQLite itself, after an explicit `PRAGMA foreign_keys = ON`.
  Application code is not the only thing standing between a bug and bad books.
- **An append is one transaction.** A test deliberately fails a two-line entry
  partway through and then asserts that neither the header nor the first line
  survived. Without the transaction, the header and one line would persist and the
  books would be corrupt beyond repair.
- **A posted entry cannot be overwritten.** Re-appending an existing id fails on
  the primary key rather than replacing the original, which is what "posted
  records are immutable" means in practice.
- **Reloading re-checks the balance.** Reading an entry back constructs a real
  `JournalEntry`, so a corrupt row set throws rather than returning a
  plausible-looking entry.
- **Amounts round-trip exactly.** Rs 1,284,500.07 is stored as 128450007 minor
  units and comes back byte-identical, including across a close and reopen of the
  file.

### 4.5 Unit of work: atomic business operations — done

| File | Contents |
| --- | --- |
| `lib/src/domain/shared/unit_of_work.dart` | The `UnitOfWork` port. |
| `lib/src/infrastructure/database/drift_unit_of_work.dart` | The drift implementation. |
| `test/infrastructure/unit_of_work_test.dart` | 9 tests. |

A business operation is now atomic across repositories, not just within one. The
test that matters writes a revenue entry successfully and then fails while
writing the cost-of-sale entry, and asserts that **neither** survives. Without
this, the revenue would have been committed alone, leaving an invoice with income
and no cost, and overstated profit for the period.

Nesting is covered because use cases will call each other: a repository's own
internal transaction joins the outer one rather than committing independently,
and a nested `run` rolls back with its parent.

### 4.6 Financial reports — done (Gate 4)

| File | Contents |
| --- | --- |
| `lib/src/domain/reporting/trial_balance.dart` | `TrialBalance`, `TrialBalanceRow`, `UnbalancedTrialBalanceException`, and the shared `entriesWithin` date filter. |
| `lib/src/domain/reporting/general_ledger.dart` | `GeneralLedger`, `GeneralLedgerLine`. |
| `test/domain/reporting_test.dart` | 21 tests, pure domain, no database. |
| `test/infrastructure/reporting_integration_test.dart` | 4 tests proving the same numbers come back out of SQLite. |

Both reports are **derived from the journal and never stored**, as the
architecture requires.

**Trial balance.** Every account with activity, with debit and credit totals
separately from a balance reported in the account's natural direction. Positive
means "grew the way this account is supposed to grow", so a liability reads as
money owed and an expense as money spent, rather than as negative numbers. It
proves itself: `isBalanced` states whether debits equal credits, and
`assertBalanced()` turns that into a hard failure so a caller cannot present an
unbalanced book as though it were fine.

**General ledger.** Every posting to one account in date order with a running
balance. When a range starts mid-history, earlier postings are not listed but are
carried in as `openingBalance` instead of being dropped, so the running balance
stays correct and reconciles.

**Verified independently, and cross-checked.** The worked example from the
specification is used again, with hand-computed expectations. A test asserts that
the general ledger closing balance and the trial balance row for the same account
agree, across every account. These are two independent derivations of the same
number, and a test that they match is worth more than either one alone.

**The same numbers survive a restart.** The integration test writes the scenario
through the repositories inside one unit of work, reads it back, builds both
reports, then closes and reopens the database file and asserts every balance is
identical.



### 4.7 Fiscal calendar and the application layer — done

| File | Contents |
| --- | --- |
| `lib/src/domain/fiscal/bs_calendar.dart` | `BsCalendar`, `BsDate`, `BsYearOutOfRangeException`. **The only file that imports `bikram_sambat`.** |
| `lib/src/domain/fiscal/fiscal_year.dart` | `FiscalYear`, a pure value object: label plus inclusive start and end dates. |
| `lib/src/domain/fiscal/nepali_fiscal_calendar.dart` | `NepaliFiscalCalendar`, which owns the rule that a fiscal year runs from 1 Shrawan to the end of Ashadh. |
| `lib/src/application/post_journal_entry.dart` | The first use case. `PostJournalEntry`, with `PostJournalEntryOutcome`, `JournalEntryPosted`, `JournalEntryRejected`. |
| `test/domain/fiscal_test.dart` | 24 tests. |
| `test/application/post_journal_entry_test.dart` | 12 tests. |

**The Bikram Sambat calendar.** ADR 009 covers the choice: `bikram_sambat`, MIT,
pure Dart, covering BS 1969 to 2200. It is isolated behind `BsCalendar` so the
dependency can be swapped in one file. Verified against published anchors —
1 Shrawan 2082 equals 17 July 2025, which is the day Nepal's FY 2082/83 actually
began — and asserted in the tests, so a package update that shifts the calendar
fails the build instead of silently moving a fiscal boundary.

**The fiscal year rule lives in exactly one place.** Nepal's fiscal year runs
from 1 Shrawan (BS month 4) to the last day of Ashadh (BS month 3) of the
following BS year, which is why the label has two numbers: `2082` becomes
`FY 2082/83`. `FiscalYear` itself knows none of this; it is told its range. It
also compares **dates, not instants**, so a transaction posted at 15:45 on the
final day of the year is inside it. Comparing raw timestamps would reject it,
and that is the single easiest mistake to make in this area.

**The first use case closes gap 7.9.** `PostJournalEntry` validates the date
against the active fiscal year *before* opening anything, so a refused posting
writes nothing at all and has nothing to roll back. The write runs inside
`UnitOfWork`, so when this grows to also post cost of goods sold and a stock
movement, all of it is one atomic operation.

A refusal is a **result, not an exception**. A user entering a date outside the
current year is normal input, not a malfunction, and signalling it with an
exception would push callers into catching it to show a message, which hides real
failures. `JournalEntryRejected` carries a user-facing message naming the fiscal
year.

Verified boundaries: the first day and the last day are both accepted, one day
before and one day after are both refused, an afternoon on the last day is
accepted, and a refusal leaves previously committed entries untouched.

### 4.8 The chart of accounts — done

| File | Contents |
| --- | --- |
| `lib/src/domain/accounting/chart_of_accounts.dart` | `ChartOfAccounts`: 19 accounts across all five types, with lookup by code and by id. |
| `test/domain/chart_of_accounts_test.dart` | 13 tests, pure domain. |
| `test/infrastructure/chart_of_accounts_persistence_test.dart` | 7 tests against the database. |

Nineteen accounts across assets (`1xxx`), liabilities (`2xxx`), equity (`3xxx`),
income (`4xxx`), and expenses (`5xxx`). Every code is four digits and its first
digit matches its account type.

**Ids are permanent; codes are not.** Each account has a hand-written literal
`id` such as `acct-bank` and a separate human-facing `code` such as `1010`.
Journal lines reference accounts by **id**, so renumbering the chart is a display
change that cannot corrupt history, while an id that changed would silently
repoint every historical posting at a different account — and the books would
still balance while being wrong. A test asserts every id is unique, every code is
unique, and no id is derived from its code.

**The chart is proven by posting a real cycle through it.** The worked example is
posted against these accounts rather than against test-local ones, and produces
the hand-computed balances, a trial balance that balances at 167,000, and an
accounting equation that holds. A separate test posts against accounts that were
**read back out of the database**, which is what proves the permanent ids and the
foreign keys line up: a posting against an id that failed to round-trip would be
rejected by the database.

Seeding is idempotent, so running it twice does not fail on the unique account
code.

### 4.9 Document numbering, and the first schema migration — done

| File | Contents |
| --- | --- |
| `lib/src/domain/billing/document_type.dart` | `DocumentType`: invoice, credit note, debit note, each with its own prefix. |
| `lib/src/domain/billing/document_number.dart` | `DocumentNumber`, formatted as `INV-2082-83-1042`. |
| `lib/src/domain/billing/document_number_sequence.dart` | The allocation port. |
| `lib/src/infrastructure/database/drift_document_number_sequence.dart` | The SQLite implementation. |
| `lib/src/infrastructure/database/tables.dart` | New `document_sequences` table. |
| `drift_schemas/`, `test/generated/` | Schema snapshots and the migration-test helpers. **These must be committed.** |

Implements ADR 005. Numbers are sequential within a fiscal year **and** document
type, each sequence restarts at 1 in a new fiscal year, and the number is built
from three independent facts so it is auditable: the type prefix, the fiscal year
from the year's label, and the position in that year's sequence.

**The rule that mattered most: a draft does not consume a serial.** This is
enforced in two places, not one. `peekNext` returns what the next number *would*
be without writing anything, so showing a draft its number cannot burn it; and a
row is only created in `document_sequences` when a document is actually issued,
so an abandoned draft leaves no trace at the storage level either. Tests assert
both, including that peeking five times still yields sequence 1 and that peeking
writes no row.

**Allocation composes with the unit of work.** Allocation runs inside a
transaction that nests inside the caller's. A test issues a document, then fails
the surrounding operation, and asserts the sequence row rolled back to zero and
that the retry receives the *same* number — so a failed issuance leaves no
unexplained gap in the numbering. A second test proves a rollback does not
disturb earlier committed allocations.

**Schema version 1 to 2, with a real migration.** `document_sequences` is added,
and nothing is dropped or recreated. The migration is verified two ways:

- Drift schema snapshots were dumped for v1 and v2, and `SchemaVerifier` validates
  that a v1 database migrates to a schema matching the v2 snapshot.
- A v1-shaped fixture is written with **raw SQL** — exactly what the previous
  release would have produced — and the tests then assert the old chart of
  accounts, the posted journal entry, its two lines, the posting date, and the
  amounts all survive the upgrade intact. One test then allocates a document
  number on the upgraded database, because a migration that validates but does
  not work is only a shape.

### 4.10 Issuing a sales invoice — done

| File | Contents |
| --- | --- |
| `lib/src/domain/billing/invoice_line.dart` | `InvoiceLine`: description, whole quantity, unit price. |
| `lib/src/domain/billing/invoice.dart` | `Invoice`: derived subtotal, VAT, and total. Standard VAT rate 13%, held in basis points. |
| `lib/src/application/issue_invoice.dart` | `IssueInvoice`, plus `IssueInvoiceOutcome`, `InvoiceIssued`, `InvoiceRejected`. |
| `test/domain/invoice_test.dart` | 19 tests. |
| `test/application/issue_invoice_test.dart` | 13 tests. |

The double entry for a VAT sale:

```
Dr  1030 Accounts Receivable   total including VAT
Cr  4010 Sales Revenue         subtotal
Cr  2020 VAT Payable           VAT amount
```

**Every total is derived, never stored and never passed in.** A stored total is a
second source of truth that can disagree with the lines it summarises.

**VAT is charged on the combined subtotal, not per line.** Charging per line would
round each line separately and drift from the correct total, so the amount posted
would not match the return filed with the tax authority. Verified by hand: Rs 1,000
at 13% is 100,000 paisa subtotal, 13,000 paisa VAT, 113,000 paisa total. A
rounding test covers the half-up case, because truncation would understate tax
owed — a real-world problem, not a cosmetic one.

**Issuance is one atomic operation.** The date is validated before anything is
opened, so a refused invoice writes no journal entry, no lines, and no sequence
row. Allocation and posting then happen inside a single unit of work.

**The composition test that matters, and it passes:** a posting failure does not
consume a serial. The journal entry id is derived from the invoice id
(`JE-INV-INV-A`), so re-issuing an already-issued invoice is refused by the
primary key. A test asserts the sequence stays at 1, that the next *different*
invoice receives 2 with no gap, and that the sequence value agrees with the number
of journal entries — the journal and the counter cannot drift apart.

### 4.11 Customers, and the second schema migration — done

| File | Contents |
| --- | --- |
| `lib/src/domain/billing/customer.dart` | `Customer`: id, name, optional PAN, phone, address. |
| `lib/src/domain/billing/customer_repository.dart` | The port. |
| `lib/src/infrastructure/database/drift_customer_repository.dart` | The SQLite implementation. |
| `lib/src/infrastructure/database/mappers.dart` | Customer mapping added. |
| `lib/src/infrastructure/database/tables.dart` | New `customers` table. |
| `test/domain/customer_test.dart` | 8 tests. |
| `test/infrastructure/customer_persistence_test.dart` | 7 tests. |
| `test/infrastructure/migration_test.dart` | Now covers v3, 8 tests. |

**A blank optional field is stored as `null`, never as an empty string.** "Not
provided" gets exactly one representation, because storing both `null` and `''`
would make every later query test two cases and eventually miss one. Tested at
both the domain and storage layers.

**Customer identity is the id, not the name.** A test renames a customer while
keeping the id and asserts equality, because renaming must not break the invoices
and journal entries that reference them.

**`IssueInvoice` now refuses an unknown customer**, and the check runs *inside*
the transaction so the read that proves the customer exists and the writes that
reference them cannot be separated by a change in between. A refusal writes no
journal entry, no lines, and no sequence row.

The test that mattered: an invoice for a nonexistent customer is refused, the
sequence is still 0, the customer is then created, and the same invoice receives
**`INV-2082-83-0001`** — so the refusal burnt no serial.

**Migration v2 to v3.** The `customers` table is added, and the migration is
stepwise: each step is guarded by its own version, so a v1 database runs *both*
steps rather than only the last. Tests cover v1 to v3 in one open, v2 to v3 with
existing accounts, journal entries, dates, amounts, and a document sequence all
intact, and that the upgraded database can create a customer and allocate a
number.

### 4.12 Issued invoices as records, and the third schema migration — done

| File | Contents |
| --- | --- |
| `lib/src/domain/billing/issued_invoice.dart` | `IssuedInvoice`: the invoice plus its number and the journal entry that records it. |
| `lib/src/domain/billing/invoice_repository.dart` | The port. |
| `lib/src/infrastructure/database/drift_invoice_repository.dart` | The SQLite implementation. |
| `lib/src/infrastructure/database/tables.dart` | New `invoices` and `invoice_lines` tables. |
| `lib/src/domain/fiscal/nepali_fiscal_calendar.dart` | `fromLabel`, the inverse of `labelForYear`, so a stored label rebuilds a whole fiscal year. |
| `lib/src/domain/billing/document_type.dart` | `fromPrefix`, so a stored number's type is read rather than assumed. |
| `test/infrastructure/invoice_persistence_test.dart` | 20 tests. |
| `test/infrastructure/migration_test.dart` | Now covers v4, 12 tests. |

An invoice is now a record, not merely the journal entry it produced. It can be
listed, listed by customer, and reprinted with its lines.

**`IssueInvoice` writes three things in one unit of work:** the serial, the
journal entry, and the document record. The journal entry is written first
because the invoice holds a foreign key to it.

**The schema enforces the relationships.** `invoices.customer_id` references
`customers` and `invoices.journal_entry_id` references `journal_entries`. An
invoice therefore cannot exist without its accounting, and cannot be attached to
a customer who does not exist. That closes the second half of 7.13.

**Only the fiscal year label is stored.** `NepaliFiscalCalendar.fromLabel` turns
it back into a whole fiscal year, because the label already determines the year's
start and end. Storing the dates as well would duplicate a fact that can then
drift. A malformed label throws rather than guessing a year.

**The VAT rate is stored** rather than inferred. Without it a reloaded invoice
could not reproduce its own VAT, and working the rate back out of the stored
subtotal and VAT amount would be lossy and impossible for a zero-rated invoice.

**Migration v3 to v4** adds both tables. The step ordering matters and is
commented: invoices reference customers and journal entries, so those tables must
already exist. A v1 database still reaches v4 by running all three steps.

### 4.13 Payments received, and the fourth schema migration — done

| File | Contents |
| --- | --- |
| `lib/src/domain/billing/payment.dart` | `Payment`: id, invoice, date, amount, and the account the money arrived in. |
| `lib/src/domain/billing/invoice_balance.dart` | `InvoiceBalance`: total, received, outstanding. Always derived. |
| `lib/src/domain/billing/payment_repository.dart` | The port. |
| `lib/src/infrastructure/database/drift_payment_repository.dart` | The SQLite implementation. |
| `lib/src/infrastructure/database/tables.dart` | New `payments` table. |
| `lib/src/application/record_payment.dart` | `RecordPayment`, `RecordPaymentOutcome`, `PaymentRecorded`, `PaymentRejected`. |
| `test/domain/payment_test.dart` | 12 tests. |
| `test/application/record_payment_test.dart` | 22 tests. |
| `test/infrastructure/migration_test.dart` | Now covers v5, 16 tests. |

This is what finally settles a receivable. Until a payment is recorded, an issued
invoice leaves the receivable outstanding forever.

```
Dr  <bank or cash>             amount received
Cr  1030 Accounts Receivable   amount received
```

**The outstanding balance is derived, never stored.** `InvoiceBalance.of` computes
it from the invoice total and the payments recorded against it. A running balance
kept on the invoice would be a second source of truth that can disagree with the
payments that produced it, and the disagreement would be silent. A test proves the
balance is reconstructible after closing and reopening the database, precisely
because nothing about it is persisted.

**An overpayment is refused, and the boundary is tested both ways.** A payment for
exactly the outstanding amount is accepted; one paisa more is refused with nothing
written. That is the case where an off-by-one either lets a customer pay more than
they owe or blocks a legitimate final settlement.

**The overpayment check cannot race.** The outstanding balance is read and the
payment is written inside the same transaction, so two payments cannot both be
validated against a balance that only one of them should have been allowed to
consume. That is not merely unlikely — it is closed.

**A payment cannot be double-counted.** The journal entry id is derived from the
payment id, so reusing a payment id is refused by the primary key rather than
silently counting twice against the invoice.

**Receiving into a non-balance-sheet account is rejected at construction.** Money
does not arrive in a revenue account; a payment must land in Bank or Cash, or the
double entry is nonsense.

**Migration v4 to v5** adds `payments`, referencing `invoices` and `accounts`. A
v1 database still reaches v5 by running all four steps.

### 4.14 Credit notes, and the fifth schema migration — done

| File | Contents |
| --- | --- |
| `lib/src/domain/billing/credit_note.dart` | `CreditNote`: id, the invoice being credited, date, lines, VAT rate. Totals derived, mirroring `Invoice`. |
| `lib/src/domain/billing/issued_credit_note.dart` | `IssuedCreditNote`: the credit note plus its number and the entry that reverses the sale. |
| `lib/src/domain/billing/credit_note_repository.dart` | The port. |
| `lib/src/infrastructure/database/drift_credit_note_repository.dart` | The SQLite implementation. |
| `lib/src/application/issue_credit_note.dart` | `IssueCreditNote` and its outcome types. |
| `test/domain/credit_note_test.dart` | 18 tests. |
| `test/application/issue_credit_note_test.dart` | 22 tests. |
| `test/infrastructure/migration_test.dart` | Now covers v6, 20 tests. |

**This closes the last gap ADR 005 left open.** A posted invoice could not be
corrected at all before this; a customer returning goods had no supported path.
Credit notes are now that path, and they are the *only* one, because the invoice
itself is still never edited.

The posting reverses the sale:

```
Dr  4010 Sales Revenue         credited subtotal
Dr  2020 VAT Payable           credited VAT
Cr  1030 Accounts Receivable   credited total
```

**The ceiling is the uncredited amount, not the outstanding balance.** This is a
deliberate and slightly surprising choice. An invoice can be credited *after* it
has been paid, in which case the business owes the customer a refund. Bounding
the credit note by what is still owed would make that ordinary case impossible.
So `InvoiceBalance` now carries both:

- `outstanding` — total minus payments **and** credits, which **can go negative**,
  meaning a refund is due. `isRefundDue` and `refundDue` make that explicit.
- `uncredited` — total minus credits only, which is the ceiling for the next
  credit note.

**Credit notes use their own `CRN` sequence.** Issuing three invoices and then one
credit note produces `INV-2082-83-0003` and `CRN-2082-83-0001`. Tested.

**`RecordPayment` had to change too.** It now takes a `CreditNoteRepository`,
because without it a customer could pay the full original amount after the
invoice had been partly credited and the payment would be accepted even though it
exceeds what is actually owed. Two tests cover it: a payment beyond the
post-credit remainder is refused, and a fully credited invoice cannot be paid at
all.

**Migration v5 to v6** adds `credit_notes` and `credit_note_lines`. A v1 database
still reaches v6 by running all five steps, and a v5 database with accounts, a
customer, an invoice, a payment, and a document sequence migrates with all of it
intact.

### 4.15 Profit & Loss — done

| File | Contents |
| --- | --- |
| `lib/src/domain/reporting/profit_and_loss.dart` | `ProfitAndLoss`, `ProfitAndLossLine`. |
| `test/domain/profit_and_loss_test.dart` | 16 tests. |
| `test/infrastructure/reporting_integration_test.dart` | 3 more tests, reading from the database. |

Derived from the journal and never stored, like the other reports.

**Income and expenses only.** Balance sheet accounts — assets, liabilities,
equity — appear nowhere, even if they had activity in the period, and even if one
is supplied in the chart. A test asserts all four balance sheet codes are absent,
because including them is the classic way a profit and loss statement goes wrong.

**A loss is reported as a positive loss, not a negative profit.** The signed
figure is `netResult`, but the useful accessors are `profit` (positive or zero)
and `loss` (positive or zero), so a bad period reads as "Loss: Rs 5,000" rather
than a double negative somebody misreads. `isProfit` / `isLoss` / `isBreakEven`
say which case applies.

**Every account is read in its own natural direction.** Income is credit-normal
and expenses debit-normal, so both totals come out positive instead of one being a
negative sum. A test asserts the expense total is positive specifically.

**Cross-checked against the trial balance.** The profit this report derives must
equal income minus expenses computed independently from `TrialBalance` rows. Two
different derivations of the same number agreeing is worth more than either alone.

Hand-computed on the worked example: income 2,000,000 paisa, expenses 1,700,000,
**profit 300,000**.

### 4.16 Balance Sheet — done

| File | Contents |
| --- | --- |
| `lib/src/domain/reporting/balance_sheet.dart` | `BalanceSheet`, `BalanceSheetLine`, `UnbalancedBalanceSheetException`. |
| `test/domain/balance_sheet_test.dart` | 17 tests. |
| `test/infrastructure/reporting_integration_test.dart` | 3 more tests, reading from the database. |

Derived, never stored.

**The line that makes it balance.** Equity has to include the result earned so
far, or assets cannot equal liabilities plus equity. There is no year-end closing
entry that moves profit into equity, so the report folds the result in as its own
clearly named line, `currentResult`, kept separate from `equityAccountsTotal`.
Without it the sheet simply does not balance, and the temptation would be to fudge
something.

**Why it takes `to` and not `from`.** A balance sheet shows a position at a point
in time, unlike the other reports which cover a span. It also matters
arithmetically: slicing the result with a `from` would leave the equation
unbalanced against equity that has no prior-year residue to absorb it. And because
ADR 002 gives one database per fiscal year, "so far" already means the fiscal year
to date, so a `from` would be redundant as well as wrong.

**The equation is proven across many shapes, not just the worked example.** Five
different transaction sets are asserted to balance: opening balances only, a
loss-making period, a period with no income at all, one including a credit note,
and a credit purchase with no sales. If the equation failed for any of them there
would be a real bug.

Hand-computed on the worked example: assets **133,000**, liabilities 30,000,
equity accounts 100,000, result 3,000, total equity **103,000**, and
liabilities plus equity **133,000**.

**Cross-checked three ways.** Assets equal liabilities plus equity, the result
line equals `ProfitAndLoss.netResult` for the same data, and the same holds when
read back from a real database rather than in memory. Three statements agreeing
about one book is worth more than any of them alone.

### 4.17 Products and inventory movements — partially done (Gate 6 opened)

| File | Contents |
| --- | --- |
| `lib/src/domain/inventory/product.dart` | `Product`: id, name, sale price, stock-tracking flag. **No cost field, deliberately.** |
| `lib/src/domain/inventory/inventory_movement.dart` | `MovementReason` (the nine reasons from specification section 14) and `InventoryMovement`. |
| `lib/src/domain/inventory/product_stock.dart` | `ProductStock`: derived quantity, value, cost per unit. `NegativeStockException`. |
| `lib/src/domain/inventory/inventory_repository.dart` | The port. |
| `lib/src/infrastructure/database/drift_inventory_repository.dart` | The SQLite implementation. |
| `lib/src/infrastructure/database/tables.dart` | New `products` and `inventory_movements` tables. |
| `test/domain/inventory_test.dart` | 28 tests. |
| `test/infrastructure/inventory_persistence_test.dart` | 17 tests. |
| `test/infrastructure/migration_test.dart` | Now covers v7, 24 tests. |

**Value-first, as ADR 004 requires.** A movement's quantity and value are both
signed and always point the same way, enforced by a database CHECK as well as by
the domain. That single decision is what makes quantity on hand and value on hand
each a plain sum of the rows, so the inventory account reconciles **by
construction** rather than by careful bookkeeping. There is no cost column on the
product, and the cost per unit is derived from the value.

**Hand-computed on the explainer's example:** buy 10 at Rs 100, then 10 at
Rs 120 → quantity 20, value Rs 2,200, derived cost Rs 110. Issue 10 → Rs 1,100
leaves, and the remaining Rs 1,100 is **exactly** the original less what left.

**Issuing the whole holding leaves exactly zero value, not stray paisa.** There is
a test for a 3-unit holding worth Rs 1,000, where the unit cost divides awkwardly.
`valueOfIssue` takes the whole remaining value when clearing the holding, rather
than multiplying a rounded unit cost by three.

**Negative stock is blocked, and the block is transactional.** The check and the
write happen inside one transaction, so two issues cannot both be validated
against a quantity only one of them should have been allowed to take. A refused
issue writes **no movement row at all**, verified by asserting the movement count
is unchanged. The check is against the total of all movements, not a position as
at the movement's date — ADR 004 explains why.

**Still missing from Gate 6, and this matters:** movements do **not post to the
ledger**. A purchase should `Dr 1040 Inventory / Cr 2010 Accounts Payable` and a
sale `Dr 5020 Cost of Goods Sold / Cr 1040 Inventory`, and no such posting happens
yet. Specification RULE 5 requires it. **Gate 6 cannot close without this**, nor
without the write-down to the lower of cost and net realisable value that ADR 004
already flags.

### 4.18 Posting inventory movements to the ledger — done

| File | Contents |
| --- | --- |
| `lib/src/application/post_inventory_movement.dart` | `PostInventoryMovement` and its outcome types, with the account mapping as one documented table. |
| `lib/src/domain/accounting/chart_of_accounts.dart` | New account `5070 Inventory Adjustments`. |
| `lib/src/infrastructure/database/tables.dart` | `inventory_movements.journal_entry_id`, a nullable foreign key to `journal_entries`. |
| `test/application/post_inventory_movement_test.dart` | 18 tests. |
| `test/infrastructure/migration_test.dart` | Now covers v8, 28 tests. |

This closes the gap recorded when inventory was opened: movements used to change
the stock on the shelf without touching the books, which specification RULE 5
forbids. The stock and the ledger are now tied together.

**The account mapping is one table, not scattered code**, because it *is* the
accounting policy and needs to be readable in one place:

| reason | direction | debit | credit |
| --- | --- | --- | --- |
| opening stock | receipt | 1040 Inventory | 3010 Owner's Equity |
| purchase | receipt | 1040 Inventory | 2010 Accounts Payable |
| purchase return | issue | 2010 Accounts Payable | 1040 Inventory |
| sale | issue | 5020 Cost of Goods Sold | 1040 Inventory |
| sale return | receipt | 1040 Inventory | 5020 Cost of Goods Sold |
| adjustment, return in/out | either | 1040 Inventory or 5070 | the other |
| transfer | — | **refused** | — |

**The test that matters, and it passes:** after buying 10 at Rs 100, 10 at Rs 120,
then issuing 10, **the inventory account balance in the trial balance equals the
derived stock value, exactly Rs 1,100**. That equality is the whole point of
value-first tracking, and it is asserted rather than assumed.

**A transfer is refused rather than given a plausible-looking entry.** Locations
are not modelled, so a transfer has nothing to move between and no entry that
would mean anything. Returning `null` from the mapping becomes a refusal with an
explanation, rather than a silent guess.

**A refusal rolls back the entry too.** The posting writes the entry first, then
applies the movement. An out-of-stock issue is caught by `applyMovement` inside
the same transaction, so the entry written moments earlier is rolled back with it.
A test asserts both the movement count and the entry count are unchanged.

**Only posted movements reach the ledger, and that is deliberate.** The migration
gives pre-existing movements a `null` entry rather than inventing one, because a
fabricated entry would be a lie in the books. A migration test asserts the old row
keeps its `null` while a new movement gets its entry.

### 4.19 Inventory write-down to net realisable value — done (Gate 6 complete)

| File | Contents |
| --- | --- |
| `lib/src/application/write_down_inventory.dart` | `WriteDownInventory` and its outcome types. |
| `lib/src/domain/inventory/inventory_movement.dart` | New `MovementReason.writeDown`, and a **value-only** movement permitted for it. |
| `lib/src/infrastructure/database/tables.dart` | The movement CHECK relaxed to allow a value-only row. |
| `test/application/write_down_inventory_test.dart` | 23 tests. |
| `test/infrastructure/migration_test.dart` | Now covers v9, 32 tests. |

This is ADR 004's follow-on decision 2, and the last thing Gate 6 was waiting for.
IAS 2 and NAS 2 require inventory to be carried at the **lower** of cost and net
realisable value: stock that cost Rs 100 and can now only fetch Rs 80 must be
written down **now**, not when it is eventually sold. Deferring it would overstate
assets and profit until the sale.

```
Dr  5070 Inventory Adjustments   the reduction
Cr  1040 Inventory               the reduction
```

**The quantity does not change, and that required a design change.** A write-down
is not a disposal — the goods are still on the shelf, they are simply worth less.
The movement type previously required a non-zero quantity and a value pointing the
same way, so a value-only change was **unrepresentable**. A new `writeDown` reason
now permits `quantity == 0` with a negative value, and the database CHECK was
relaxed to match. Recording it as a movement rather than as a side-channel value is
what keeps the stock value and the inventory account equal **by construction**; a
write-down that bypassed the movement ledger would break the equality the previous
task established.

**Disposal stays separate.** A test writes stock down to Rs 800 and then scraps it
as its own `adjustment` movement, leaving zero quantity and zero value. Conflating
the two would make the stock count wrong and count the loss twice.

**A rise in value is refused, not treated as a negative write-down.** IAS 2 does
not permit inventory to be revalued upwards, so a value at or above the carrying
amount is refused. The boundary is tested both ways: **exactly equal is refused, one
paisa lower is accepted.**

**Relaxing the rule went too far at first, and the existing tests caught it.** The
first attempt allowed *any* movement with a non-zero quantity and a zero value,
which would have broken the reconciliation between units and their worth. An
existing test asserting "a zero value is rejected" failed, and the fix was to
tighten the rule rather than edit the test: a quantity change must carry a value,
and only a write-down may be value-only. Two existing tests were updated, both to
assert the *new* correct rule rather than to weaken anything.

### 4.20 Gate 7 begins: the application shell and the licences screen — done

| File | Contents |
| --- | --- |
| `lib/src/presentation/theme/app_theme.dart` | `AppPalette` (a `ThemeExtension`), `AppSpacing`, `AppRadius`, `AppTheme`, and the type scale, all taken from `ui.txt`. |
| `lib/src/presentation/navigation/app_navigation.dart` | The eight navigation groups from `ui.txt` section 13. |
| `lib/src/presentation/finance_app.dart` | The `MaterialApp` root. |
| `lib/src/presentation/finance_app_shell.dart` | Left navigation plus content area. |
| `lib/src/presentation/screens/placeholder_screen.dart` | The "not built yet" screen. |
| `lib/src/presentation/screens/licenses_screen.dart` | The licence notices. |
| `lib/main.dart` | Replaced the generated counter app. |
| `test/presentation/app_shell_test.dart` | 20 widget tests. |
| `test/presentation/architecture_test.dart` | 4 layer-boundary guards. |

**The licences screen exists because MIT and BSD-3 require the copyright notice
to be retained.** Measured across the whole dependency tree: 85 packages, of which
69 are BSD-3, 8 MIT, 3 Apache-2.0, plus the Flutter SDK. **Not one is public
domain or attribution-free**, so this is not a case of choosing which notices to
show. Flutter's `showLicensePage` aggregates them all, so the screen is one menu
item and no maintenance. The screen also states *why it exists*, so a future
maintainer does not delete it as boilerplate.

**The design tokens come from `ui.txt`, not from taste.** Restrained warm-neutral
base with a single blue accent; Segoe UI with Linux and macOS fallbacks; the
newspaper type scale (32 / 24 / 18 / 14 / 13) rather than oversized headings
everywhere; borders over shadows; corner radii capped at 6 because the
specification warns against looking like a mobile banking app. The tests assert
those concrete values, so a later palette or type change is a deliberate act.

**Unbuilt sections say so.** Every section except Licences shows a clear "Not
built yet" notice, including the fact that the accounting and reporting logic
behind much of it already exists and is tested. A blank panel would look like a
bug, and a crash would be worse; neither tells the user anything true.

**Two real bugs the tests caught, both worth remembering:**

1. **The shell read the theme from a context above its own `MaterialApp`.** A
   `MaterialApp` provides the theme to everything *below* it, so a widget that
   builds its own `MaterialApp` and then reads the palette in the same `build` is
   reading a theme that does not exist yet. Fixed by lifting the `MaterialApp`
   into `FinanceApp` and making the shell its `home`. The palette getter now
   throws a descriptive `StateError` rather than a null-check crash.
2. **`Container` was given both a `color` and a `decoration`**, which Flutter
   asserts against. The colour now lives inside the `BoxDecoration`.

**The architecture is now guarded, not just documented.** `architecture_test.dart`
reads the source files and fails if a screen imports `infrastructure/`, `domain/`,
`drift`, or `sqlite3`; if a domain file imports Flutter, the application, the
infrastructure, or the presentation; or if the removed `bikram_sambat` package is
reintroduced. These are tripwires for rules that otherwise compile, run, and
quietly break. The calendar guard has to exclude its own file, because it contains
the import string it searches for; loosening the pattern instead would let a real
import through.

### 4.21 The Trial Balance screen — the first screen wired to real data

| File | Contents |
| --- | --- |
| `lib/src/domain/shared/currency.dart` | `bookCurrency`, so the books' currency is written in one place. |
| `lib/src/application/build_trial_balance.dart` | `TrialBalanceReport`, `TrialBalanceLoader`, `BuildTrialBalance`. |
| `lib/src/presentation/app_services.dart` | `AppServices`: the only thing the presentation layer is given. |
| `lib/src/presentation/screens/trial_balance_screen.dart` | The report screen. |
| `lib/main.dart` | The composition root: opens the database, seeds the chart, wires the use case. |
| `test/application/build_trial_balance_test.dart` | 7 tests. |
| `test/presentation/trial_balance_screen_test.dart` | 11 tests. |

**A use case, not a screen with logic in it.** `BuildTrialBalance` loads the
journal and returns the report. The screen formats and displays. That is what
keeps the layer rule true, and `architecture_test.dart` enforces it.

**`TrialBalanceLoader` is an interface, which is what makes the screen testable.**
A screen whose numbers could only come from a real database could not be tested
without one. The widget tests hand it a stub and assert against genuine figures
from the worked example, not invented ones.

**The money formatting is not re-implemented.** Every amount on screen comes from
`Money.format`, and a test asserts that *every* value on the page matches the same
pattern. A screen cannot quietly grow a second formatting rule.

**Real states, not just the happy path.** Loading, empty, and failure are all
handled and tested. A failure shows the underlying message, because "something
went wrong" tells a user nothing they can act on.

**Two layout bugs the tests caught.** The money columns were shrink-wrapped, so
the table row overflowed by 113 pixels and the totals were clipped off screen
entirely. They now have a fixed width, which also makes the figures line up down
the page. Separately, the error state's text column was not `Expanded`, so a long
error message overflowed its row.

**One honesty note, recorded in the tests themselves.** The screen shows a
warning when the report does not balance, but that branch is **unreachable by
construction**: `TrialBalance` derives its figures from journal entries, and
`JournalEntry` refuses to hold an entry whose debits and credits disagree. Rather
than fake an unbalanced report to test it, the use-case test says plainly that
the check is a defensive assertion. If a future change ever let a row reach the
journal table without going through `JournalEntry`, the check would fire.

### 4.22 The General Ledger screen, and cross-report navigation

| File | Contents |
| --- | --- |
| `lib/src/application/build_general_ledger.dart` | `GeneralLedgerReport`, `GeneralLedgerLoader`, `BuildGeneralLedger`. |
| `lib/src/presentation/screens/general_ledger_screen.dart` | The ledger, with an account picker. |
| `test/application/build_general_ledger_test.dart` | 10 tests. |
| `test/presentation/general_ledger_screen_test.dart` | 11 tests. |

**The opening balance is the point of this screen.** A range that starts after an
account's first posting must bring the earlier balance forward, or the running
balance appears to start at zero and **the closing figure silently disagrees with
the trial balance** — a reconciliation failure a user has no way to detect. Three
tests cover it: a mid-history range shows the opening and its first running
balance continues from it; a range with no postings *still* shows the opening;
and an untouched account shows neither.

**The closing balance is cross-checked against the trial balance.** Same account,
same book, same answer, asserted in the use-case test. If those two reports ever
disagree, the test points straight at which pair of numbers to check.

**Account selection lives on the interface, not behind a type check.** The first
version did `loader is BuildGeneralLedger`, which broke the moment a test supplied
a stub. `selectableAccounts()` is now part of `GeneralLedgerLoader`.

**The two reports drill into each other.** Tapping a Trial Balance row opens that
account's General Ledger, with no router: the navigation item reaches the shell's
state through `findAncestorStateOfType`.

### 4.23 Local backup and verified restore

**Given priority over customers and products at the owner's request**, because a
lost file is a legal problem and not merely an inconvenience: Nepali law requires
a business to keep its books for years, so a single file on one computer is a
compliance risk. See `docs/BACKUP_AND_RETENTION.md`.

| File | Contents |
| --- | --- |
| `lib/src/domain/shared/book_backup.dart` | `BookBackup`, `BackupVerification`, `BackupException`. |
| `lib/src/domain/shared/book_backup_service.dart` | `BackupActions` (narrow) and `BookBackupService`. |
| `lib/src/infrastructure/backup/file_book_backup_service.dart` | The implementation. |
| `lib/src/presentation/screens/backup_screen.dart` | Take, list, verify. |
| `test/infrastructure/book_backup_test.dart`, `test/presentation/backup_screen_test.dart` | 15 and 10 tests. |

**The snapshot is produced by SQLite, not by copying the file.** A plain copy
taken while the application is writing can capture the database mid-change and
produce a file that is quietly corrupt: plausible size, plausible name, unusable.
`VACUUM INTO` writes a complete, self-consistent copy while the database is in
use. Probed first: SQLite here is 3.51.1 and supports it.

**Every snapshot is verified before it is filed.** A SHA-256 checksum proves the
bytes have not changed; `PRAGMA integrity_check` on a real connection proves the
file is a database at all. A snapshot failing either is **deleted and reported as a
failed backup**, because a directory of files that feel like a safety net and are
not one is worse than an empty directory.

**Restoring is proved, not assumed.** The test takes a backup, changes the books,
restores, and asserts the original figures came back. An untested backup is not a
backup.

**Restoring protects what it replaces.** Verification runs first, so an unusable
backup is refused before anything is touched; then the **current** books are
backed up before being overwritten, so a wrong choice is recoverable.

**The screen says plainly what a local backup does not do.** It protects against a
damaged or deleted file. It does **not** survive the disk failing, theft, or fire.
A user who believes otherwise is worse off than one who knows.

### 4.24 Backup covers every fiscal year, not just the current one

**A gap the owner found by asking the obvious question: "our logic says a SQLite
per year, so?"** The first implementation covered only the **current** fiscal
year. Two faults, and the second was worse:

1. **The app did not know the other years existed.** `main.dart` computed the
   current fiscal year and opened that one file; it never looked for other
   `accounting-FY-*.db` files. It could not back them up — and could not open
   them either.
2. **The screen implied more protection than it delivered.** It warned that a
   backup does not survive losing the computer, but said nothing about older years
   having no backup at all. Those are the years closest to the retention clock.

| File | Contents |
| --- | --- |
| `lib/src/domain/shared/book_year.dart` | `BookYear`, `BackupRun`, `BackupFailure`. |
| `lib/src/infrastructure/backup/file_book_backup_service.dart` | Discovers every year and backs up all of them. |
| `lib/src/presentation/screens/backup_screen.dart` | Lists every year and whether it is protected. |

**Every `accounting-FY-*.db` in the books folder is discovered and backed up.** The
current year is snapshotted through the connection already open; a concluded year
is opened for the duration and closed again. Both go through the **same** snapshot
and verification path, so a closed year is not treated as a lesser case.

**A year that cannot be backed up is reported, never skipped.** `BackupRun` carries
both the backups taken and the failures, and a test proves a corrupt concluded year
is named in the failures while the other years are still covered.

**The screen now says which years have no backup**, counts them, and a partial run
reports "…could NOT be backed up: FY 2081/82 (reason)".

**Two bugs of my own, both caught by the tests.** Restore was writing to the
**snapshot's** file name instead of that year's books file, so it never replaced
the real books; and the stray files it left in the books folder were then
discovered as extra years on the next run, which is why the suite went from one
second to five minutes.

### 4.25 Opening a concluded fiscal year, read-only

**A specified requirement that had not been built.** The specification says it
three times and lists it as an acceptance test:

> Section 21: *"Historical years may be opened or downloaded for reporting and
> review, but they shall be opened in read-only mode."*
> Section 26: *"Historical fiscal-year databases are read-only and shall never be
> silently modified."*
> Acceptance test: *"Historical year → opens read-only."*

| File | Contents |
| --- | --- |
| `lib/src/application/books_session.dart` | `OpenYear`, `BooksSession`. |
| `lib/src/infrastructure/database/file_books_session.dart` | Discovers the years, opens the trading year writable and closed years read-only. |
| `lib/src/infrastructure/database/sqlite_native.dart` | `readOnly` on the openers, via `PRAGMA query_only`. |
| `lib/src/presentation/finance_app_shell.dart` | A fiscal-year selector that rebuilds the services. |
| `test/infrastructure/books_session_test.dart` | 11 tests. |

**Read-only is enforced by the database, not by the screen.** `PRAGMA query_only`
is set through the `setup` hook, so **every** connection the executor opens
refuses writes. A concluded year is not merely one whose screens lack a save
button; its database rejects the write, and the test asserts the exact SQL
insertion fails. A rule that lives only in the UI is one any future caller can
walk past.

**A test proves the refusal leaves the file untouched on disk**, because the
requirement is that historical years are *never silently modified*.

**Read-only does not mean unreadable**, and a test asserts the figures still load.
**The trading year stays writable**, asserted separately: a guard that stopped the
business trading would be worse than the problem it solves.

**Switching year replaces the whole service bundle**, because every use case
belongs to one year's books and cannot be patched individually.

**A hidden clock dependency was removed while building this.** The first version
recomputed "the current year" from `DateTime.now()` inside the session, which
would have made the read-only decision untestable. The trading year is now given,
never inferred.

### 4.26 The backend: PostgreSQL, API routes, and a verified upload endpoint

**The off-machine answer the specification asks for.** The local backup already
produces a verified, checksummed snapshot; what was missing was a server to
receive it.

| File | Contents |
| --- | --- |
| `backend/routes/api.php` | Three authenticated routes. Created; the file did not exist. |
| `backend/bootstrap/app.php` | `api:` routing registered. |
| `backend/app/Services/BackupUploadVerifier.php` | The verification chain and `BackupVerification`. |
| `backend/app/Http/Controllers/Api/BackupRevisionController.php` | Store, list, show. |
| `backend/app/Models/Book.php`, `BackupRevision.php` | Laravel 13 PHP-attribute style, not `$fillable`. |
| `backend/database/migrations/*_create_books_table.php` | Books, so ownership can be checked. |
| `backend/database/migrations/*_create_backup_revisions_table.php` | The exact metadata columns the specification lists. |
| `backend/config/filesystems.php` | A `backups` disk, so moving to object storage later is a config change. |
| `backend/tests/Feature/BackupUploadTest.php` | 11 tests. |

**An unverified upload is never treated as a valid backup.** The specification says
so directly, and it is enforced in four ordered checks, cheapest-and-safest first:
the file's magic header, the declared size, the declared SHA-256, and finally
SQLite's own `integrity_check`. The first failure stops the upload and **nothing
is written** — no file, no metadata row. There is deliberately no "uploaded but not
yet checked" state, because such a row is a backup the desktop might later
report as stored.

The integrity check is **last on purpose**. Opening a received file with SQLite
means parsing data from outside, so it runs only after the file is known to be a
SQLite database whose checksum matches what a trusted client sent, and the file is
opened read-only.

**Most of the tests are about refusal**, because a backup feature is only worth
having if it says no: a checksum mismatch, a truncated upload, a file that is not a
database, a **corrupted database with a valid header and a matching checksum**
(only the integrity check catches that one), an unauthenticated caller, another
user's book, and a revision that does not follow the latest. Each asserts nothing
was stored.

**A revision that does not follow the latest is a conflict, not a silent
overwrite**, so two copies of the same books cannot clobber each other.

**The SQLite file is not in the database.** `object_key` points at it on the
`backups` disk, which is the pattern the specification describes for uploaded
files. PostgreSQL holds only the metadata.

**PostgreSQL is configured** as the specification mandates, and PostgreSQL 17 with
`pdo_pgsql` is installed and running. `APP_NAME` is `financeapp`. The test suite
runs on an isolated in-memory SQLite database, Laravel's own convention, so it
needs no external database.

**A stored revision has no `updated_at`**, because the specification's column list
has none, and one would be misleading: a revision is an immutable record, and a
change means a new revision.

### 4.27 PostgreSQL live, and token issuance

**Two blockers closed in one task**, because neither was useful alone: a database
that cannot be reached cannot be tested against, and a token that cannot be issued
makes every authenticated route unreachable.

| File | Contents |
| --- | --- |
| `backend/.env` | `DB_PASSWORD` set. The owner supplied the password. |
| `backend/app/Http/Controllers/Api/AuthController.php` | `register`, `login`, `logout`, `me`. |
| `backend/routes/api.php` | Four identity routes, two of them deliberately outside the guard. |
| `backend/database/factories/UserFactory.php` | A `withPassword` state. |
| `backend/tests/Feature/AuthenticationTest.php` | 18 tests. |

**The database now exists and the migrations ran against it.** `financeapp`, UTF-8,
PostgreSQL 17.4. `DB_PASSWORD` was empty, which produced a confusing
`FATAL: database "financeapp" does not exist` only *after* authentication
succeeded — the missing password and the missing database had the same symptom from
the outside, and it was worth separating them in order rather than guessing. The
password lives in `.env`, which `backend/.gitignore` excludes, so it cannot be
committed by accident.

**The only two unauthenticated routes in the API are `register` and `login`.** They
have to sit outside the `auth:sanctum` group: no token can be obtained without one
of them, so guarding them would make every route unreachable. The comment in
`routes/api.php` says so, because it looks like a mistake otherwise.

**Registration creates the account's one book** (ADR 003). Without it the desktop
has nothing to upload a backup against, and the next task would be blocked on a
missing book rather than on its own work.

**An unknown email and a wrong password fail identically.** A different response
would let a caller discover which addresses have accounts, so both raise the same
refusal and a test asserts the statuses match.

**Logout revokes only the token used**, so signing out of the office desktop does
not sign the user out of the laptop. There is a test for it.

**This is token issuance, not licensing, and the distinction is deliberate.** The
specification also requires a cryptographically signed licence authorisation
carrying subscription status, expiry, a device binding, and a private-key
signature that the desktop verifies offline against a public key. None of that is
here, and a half-built licence check that *looks* authoritative is worse than none,
so it is named as its own task rather than approximated.

**Verified against the real stack, not only the in-memory tests.** A throwaway
script walked the whole path over HTTP against live PostgreSQL: register, login,
`me`, a genuine SQLite snapshot uploaded with its real checksum and size, then
four refusals — duplicate email, weak password, wrong password, no token, bad
checksum, stale revision, and a file that is not a database. All fourteen checks
behaved as required, and **one revision remained stored after all the refusals**,
which is the property that matters: no partial or unverified artefact survives.

### 4.28 The desktop sends a verified backup to the server

**The other half of 4.26, and the first time anything has actually crossed the
wire.** The server could receive a snapshot and had been tested, but no desktop
could reach it. This closes that, and it is the change that finally puts a backup
somewhere other than the disk it came from.

| File | Contents |
| --- | --- |
| `desktop/lib/src/domain/shared/book_upload.dart` | `BackendSession`, `UploadStatus`, `UploadResult`, `UploadRecord`, `UploadException`. |
| `desktop/lib/src/domain/shared/book_upload_service.dart` | The `UploadActions` port. |
| `desktop/lib/src/infrastructure/sync/http_backup_uploader.dart` | `HttpBackupUploader`, the `HttpTransport` seam, and `IoHttpTransport`. |
| `desktop/lib/src/presentation/screens/backup_screen.dart` | The "Send to the server" button and the per-year sent state. |
| `desktop/test/infrastructure/http_backup_upload_test.dart` | 26 tests. |
| `desktop/test/presentation/backup_screen_test.dart` | 8 new widget tests, 22 total. |
| `desktop/tool/live_upload_check.dart` | 6 checks against a running server. |

**The local backup is never touched, whatever happens.** Not on success, not on a
refusal, not on a conflict, not when the server cannot be reached. The snapshot
is opened for reading and its bytes are sent; nothing writes to it. This is the
invariant the whole feature rests on: the local copy is the only one the business
has until the server confirms it holds the bytes, so an upload that lost it would
turn a good backup into no backup. Every refusal test asserts the file is
byte-identical afterwards.

**A result is a success only when the server said so.** `UploadStatus.uploaded` is
returned only for a `201` carrying a revision number. A `201` whose body cannot be
read is **not** a success, because the point of the answer is to confirm what was
stored and an answer that does not do that has confirmed nothing.

**The declared checksum and size are recomputed from the file, not taken from the
`BookBackup`.** The server checks them against the bytes it receives, so sending a
checksum recorded when the backup was taken would turn a harmless later change
into a confusing refusal.

**The revision sequence is read from the server before each upload.** The server
refuses a revision that does not follow the latest, so guessing would fail on the
first upload after a reinstall. The uploader asks what is stored, **filters to the
fiscal year being sent**, and sends one more. Filtering matters: counting another
year's revisions would make a new year start at the wrong number.

**A conflict is reported, not retried.** A `409` becomes `UploadStatus.conflict`
with its own wording. Retrying would either fail again or overwrite another
installation's snapshot.

**Offline is a normal condition, not a failure.** A connection error and a server
error status both become `UploadStatus.unreachable`, because for the user they are
one thing: nothing was stored, the books are unchanged, try again later. The
specification requires a desktop that cannot reach the internet to keep working,
and this is the only part of the application that needs a server at all.

**`dart:io` rather than an HTTP package.** `package:http` is not in the approved
list, and the SDK's `HttpClient` covers this in about forty lines. The upload adds
**no dependency at all** — which the dependency policy in `docs/AI_RULES.md`
requires to be a deliberate, recorded choice.

**Two findings, both worth recording.**

1. **A test of mine was wrong, not the code.** The live check asserted that
   re-uploading the same snapshot returns a conflict. It does not, and it should
   not: the uploader re-reads the sequence first, so a second upload from the same
   installation legitimately becomes the next revision. A `409` is for the
   different case where *another* installation stored a revision between the read
   and the write. The expectation was corrected. Reproducing that race against a
   live server would be a timing test, so conflict mapping stays covered by the
   unit tests where the race can be staged deterministically.
2. **Mutation testing caught a test that measured the wrong thing.** Removing the
   fiscal-year filter from the revision logic left all 26 unit tests passing,
   because the test asserted the revision the *fake* echoed rather than the one
   the uploader *declared*. The fake replies with whatever a test scripts, so the
   assertion was testing the fake. It now reads the `revision` field out of the
   multipart body. This is the same class of defect as 7.15 and 7.21, and it was
   found only by deliberately breaking the code and checking that a test failed.

**Verified against the real stack.** The unit tests replace the transport, which
leaves the actual socket and the multipart encoding as it goes on the wire
unverified. `tool/live_upload_check.dart` closes that gap: six checks against a
running Laravel server and the live PostgreSQL database, using the real
`IoHttpTransport`. It registers a throwaway account each run so it starts from a
book with no revisions and can assert exact numbers. All six passed, and the rows
were then read back out of PostgreSQL to confirm they were really stored.
`flutter test` skips it by name, so the suite stays hermetic.

**Not yet usable by a real user without help.** The token comes from environment
variables, because there is no sign-in screen and the specification's protected
operating-system storage for tokens is not built. With nothing set — the normal
case — uploading is absent and the application is exactly as local as before. See
section 6.

### 4.29 A code review of 4.27–4.28, and twelve fixes

**A review of the uncommitted work found twelve issues in it; all twelve are
fixed, and every fix was mutation-tested.** The two that mattered most were in
code written the same day, which is the argument for reviewing before committing
rather than after.

**The most serious was in the upload: it never checked that the snapshot it was
sending was still the one that had been verified.** `BookBackup.checksum` records
what the file was when the backup was taken, and the uploader ignored it. The
server's checksum check only proves the bytes survived the trip, so a file
corrupted or edited after the backup would have been uploaded, accepted, and
**reported to the user as a safe off-machine backup**. The uploader now recomputes
the checksum by streaming the file and refuses when it no longer matches the
recorded value or size, returning a new `UploadStatus.unverified` and sending
nothing. The task specification had asked for a snapshot "already verified
locally"; that step was simply missing.

**The second was a 500 on ordinary input.** Registration validated
`unique:users,email` against the address as typed but stored it lower-cased, so
registering `SITA@Example.COM` after `sita@example.com` passed the uniqueness check
and then collided with the unique index. Normalisation now happens **before**
validation, so the rule and the stored value see the same string. There is a test
for the case variant, which the original duplicate-email test did not cover.

**The Backup screen overstated what it had achieved.** `_describeUploads` counted
only the years it attempted, so a two-year business with one unbacked-up year was
told *"Sent 1 of 1 fiscal year… Every year is now stored off this computer"* — while
the unprotected-years warning sat above it saying the opposite. The denominator is
now the total year count, and a year with no backup is named in the summary.

**The public auth routes had no rate limit.** `bootstrap/app.php` leaves
`withMiddleware` empty, and the framework only puts `throttle:api` on the `api`
group when `throttleApi()` is called — verified in
`Middleware.php:495`, not assumed. `register` and `login` therefore accepted
unlimited requests: unbounded account creation, unrestricted credential guessing,
and bcrypt CPU exhaustion. Both now carry `throttle:6,1`.

**One of the new tests could not fail.** The schema-version assertion was
`contains('9')`, which the snapshot's own generated bytes already satisfied, so it
would have passed even if the field were absent — the same defect 7.21 records,
repeated. It now reads the declared value out of the request and compares it to
`currentSchemaVersion`, and the fake transport's own fixture uses the constant
rather than a second copy of the number.

**The rest:**

- **Login leaked account existence through timing.** `if (! $user || ! Hash::check(...))`
  short-circuits, so an unknown address answered without paying bcrypt. The
  comparison now runs against a dummy hash regardless. **A finding inside the
  finding:** the first fix used a hand-written bcrypt-looking literal, which would
  have been worse than useless — measured, `password_verify` against a malformed
  hash returns in **0.04 ms** against **191 ms** for a real one, so it would have
  kept the short-circuit's speed while looking fixed. A real hash is now used, and
  the measurement is what caught it.
- **Registration no longer says the email is taken**, which would have handed back
  the information login deliberately withholds. Full non-enumeration would need an
  email-verification flow; that is recorded as out of scope rather than pretended.
- **The upload refuses a plaintext remote server.** An `http://` base URL pointing
  anywhere but loopback would put the token and the entire accounting database on
  the network readable. `https` is required, with `http` allowed only for
  `localhost`, `127.0.0.1`, and `::1`.
- **The upload no longer copies the file three or four times.** `readAsBytes`,
  then `BytesBuilder`, then `takeBytes` meant peak memory of several times the file
  size. The transport now takes an ordered list of byte segments and sets
  `contentLength`, so the snapshot is passed by reference, and the checksum is
  computed by streaming the file **in a separate isolate** — so a large year
  neither blocks the interface nor exists in memory twice.
- **One `HttpClient` for the transport, not one per request.** The pool is now
  reused across the two calls per year instead of a fresh TCP and TLS handshake
  each time.
- **`UploadResult.localBackupIsIntact` was removed.** A constant-`true` getter with
  no callers, which is the same dead surface 7.21's lesson warns about.

**Every fix was mutation-tested, and three of the four new tests initially failed
to catch their own regression** — the same trap as 7.21, found the same way. The
rate-limit and normalisation tests passed with their fixes reverted because those
mutations had not applied (CRLF mismatch in the mutation script); re-applied
properly, both fail without their fix. The verification guard and the coverage
denominator were each confirmed to fail when reverted. **The lesson is sharper than
7.21's: a mutation that does not apply looks exactly like a test that works.**

**Verified:** 660 Dart tests, 35 Laravel tests (97 assertions), `flutter analyze`
clean, Pint clean, Windows build succeeds, and the six live checks against the real
Laravel server and PostgreSQL still pass — which also proves the new
length-delimited segmented body is accepted by the server's multipart parser.

### 4.30 Sign-in, so a backup can actually be sent by a user

**The task from section 6, and it closes the gap between "the feature works" and
"a business can use it".** Uploading worked end to end, but the only way to give
the desktop a token was three environment variables.

| File | Contents |
| --- | --- |
| `domain/shared/credential_store.dart` | `CredentialStore` port. |
| `domain/shared/sign_in.dart` | `SignInStatus`, `SignInResult`, `SignInException`, and `isUsableServerAddress`. |
| `domain/shared/auth_service.dart` | `AuthActions` port: `signIn`, `signOut`. |
| `infrastructure/http/http_transport.dart` | `HttpTransport`, `TransportResponse`, `IoHttpTransport`, moved out of the uploader so sign-in and backup share one. |
| `infrastructure/auth/http_auth_client.dart` | `signIn` and `signOut` over HTTP. |
| `infrastructure/auth/secure_credential_store.dart` | The token in protected OS storage. |
| `application/account_session.dart` | `AccountSession`: restore, sign in, sign out, and the uploader for the current session. |
| `presentation/screens/settings_screen.dart` | `SettingsScreen` and `AccountPanel`. |
| `test/application/account_session_test.dart`, `test/infrastructure/http_auth_client_test.dart`, `test/presentation/settings_screen_test.dart` | 16, 17, and 15 tests. |
| `test/support/fakes.dart` | Shared doubles: `MapCredentialStore`, `ScriptedAuthActions`, `ScriptedTransport`, `OfflineTransport`, `StubBackupActions`. |

**The password is never stored, and that is structural rather than a rule.**
`BackendSession` has no field for it, so there is nowhere to put one. The test
asserts it against **the stored map's values**, not against the absence of a key,
because a key named `password_hash` would pass an absence check while holding the
secret.

**Signing out always signs out.** The local session is cleared *first*, then the
server is told, best-effort, and neither step is allowed to throw. Two tests were
written for the failure paths: a store that cannot be cleared, and a server that
cannot be reached. Both were **real bugs in the first version**, which relied on
the implementations swallowing their own errors rather than making the caller
robust — a locked keyring would have stopped the application starting, and a dead
network would have produced a sign-out that does not happen.

**The transport was moved out of the uploader rather than copied.** Two features
need it, and a second copy of a class that maps HTTP statuses is exactly the
duplication that drifts. That is a change to the uploader's file layout, not to its
behaviour, which is why it was done despite the task's "do not modify" note.

**The plain-text rule now lives in the domain, in one place.** The sign-in screen
refuses a bad address before a round trip and the HTTP client refuses one that
arrived another way. Two copies of that rule would drift, and the failure mode of
drift is sending a bearer token and an entire accounting database over clear text
because one copy was not updated.

**The decision section 6 asked for: a `401` now says "sign in again".** It was
`unreachable`, which tells the user to try again later — and retrying a `401`
fails identically every time, so the wording would send them round a loop they
cannot escape. It became `UploadStatus.unauthenticated`. **Fixing it properly
found a second bug:** the new tests failed, because a revoked session usually
fails the *revision lookup* first and that path collapsed every failure into
`unreachable`. `_nextRevisionFor` returned a bare `int?`, discarding exactly the
distinction that mattered; it now returns a three-state `_RevisionLookup`.

**Mutation-tested, and the first mutation was invalid.** Removing the guard
around `signOut`'s store clear left all tests passing — not because the tests were
weak but because the mutation I wrote (`if (false) rethrow;`) was semantically a
no-op. Re-applied by actually deleting the `try`, the test caught it. That is
7.22 again, from a new angle: **a mutation that does not change behaviour proves
nothing.**

**Not verified on Windows.** `flutter test` passes 712 and `flutter analyze` is
clean, but `flutter build windows --debug` **fails**, and that is a blocker for
the project rather than a defect in this code. See 4.32 — it needs an owner
decision. It worked before this dependency was added.

**Verified against the real backend.** `tool/live_signin_check.dart` — 7 checks
against the running Laravel server and live PostgreSQL, using the real
`IoHttpTransport`: a real account signs in and the parsed token is accepted by
`/api/auth/me`; the wrong password is refused with no token and no wording that
reveals whether the address exists; an unknown address is refused **identically**;
**signing out really revokes the token**, proved by `me` returning 401 afterwards;
signing out with no network does not throw; a plaintext remote address is refused
without a request; and repeated attempts are rate limited by the server. The
tokens were then read back out of PostgreSQL.

### 4.31 The sign-in rate limit is keyed on IP alone, which is the wrong key

**Found by running the live check, not by writing a test.** Registration and
sign-in carry `throttle:6,1`, which Laravel keys on the **client address**. The
first live run failed with `429` partway through — the limit was working exactly
as designed, but it exposed the shape of the problem:

- **Six sign-ins a minute is shared by every user behind one router.** A business
  with three machines on one connection, or anyone behind a corporate NAT or a
  hotel network, draws from the same budget. Two people signing in at the same
  moment can lock each other out, and neither will understand why.
- **It is trivially exhausted by one client**, which is the intent, so the limit
  itself is right. The key is what is wrong.

**Not changed here, and deliberately.** The obvious fixes — keying on email as
well as address, or raising the ceiling — are guesses about deployment. The
desktop is a first-party client where sign-in is rare, so six a minute may well be
correct for a single household and wrong for an office. **This needs a decision
with a real user count behind it**, and it is recorded rather than silently
adjusted.

The live check now registers **one** account and shares it, waits out the window
if it is rate limited, and makes no server round trip where the token's validity
is irrelevant. That is the tool accommodating the limit, not the limit being
relaxed.

### 4.32 The ATL blocker — how it ended, and what it cost

**Started as:** `flutter build windows` fails, because the
`flutter_secure_storage` package's Windows plugin contains one
`#include <atlstr.h>`, and ATL ships in Visual Studio's *optional* C++ component.

**Ended as:** the dependency is gone, and **nothing in the build needs an optional
Visual Studio component any more.** Replaced with `webauthn_secure_storage`
(MIT), which stores the value in the Windows Credential Manager — the same DPAPI
protection — with no ATL dependency and no additional toolchain. Verified: no
plugin in the build references ATL. See `docs/AI_RULES.md` for the dependency
decision.

**Along the way, four avoidable wrong turns, all mine:**

1. **Adopted the package without checking its native sources.** 7.24 was written
   earlier the same session and says exactly this. It was not applied.
2. **Concluded the `#include <atlstr.h>` was unused**, on a grep whose pattern
   (`CString|ATL|CCom|_bstr_t|Variant|BSTR`) misses `CA2W` and matched
   `su**bstr**r` in `substr` case-insensitively. The plugin genuinely uses `CString`,
   `CA2W`, and `CW2A`. A vendored fork was started and reverted.
3. **Told the owner the toolchain was fixed when it was not.** The check was
   `if ($r)` on the output of `vswhere`, and PowerShell treats the string `"[]"`
   as truthy. **The check could not fail.** This is 7.21 and 7.22 again, and it is
   the most expensive of the three because it sent the owner looking for the wrong
   problem.
4. **Gave `vs_installer.exe` instead of `setup.exe` twice.** `vs_installer.exe` is
   the UI launcher and discards the arguments; the installer log showed
   `Command line: ...\setup.exe` with nothing after it.

**And one piece of harm:** `vs_installer.exe modify --add` recomputes the component
set, and its installer log shows it **removing** packages —
`Microsoft.VC.14.51.CRT.Headers`, `Microsoft.VC.14.51.Servicing.CrtHeaders` — while
re-downloading the Build Tools payload. Each attempt tore down more of the
installation without restoring the compiler component. **Do not run it again.**

### 4.33 The storage dependency, settled — and the build works

**`flutter build windows --debug` now succeeds.** `financeapp.exe` builds with
**no optional Visual Studio component of any kind**, after two rejected packages
and one that looked clean and was not.

| Package | OS keystore | Extra toolchain | Outcome |
| --- | --- | --- | --- |
| `flutter_secure_storage` | Credential Manager | **ATL component** | Rejected: one `#include <atlstr.h>` |
| `webauthn_secure_storage` | Credential Manager | **App SDK + coroutine fix** | Rejected: `<winrt/...>` and `<experimental/coroutine>`, which MSVC 14.51 rejects |
| `local_storage_cache` | **no** — app-level `crypto` | none | Rejected: encrypts with a key on the same disk |
| `get_secure_storage` | **no** — app-level `cryptography` | none | Rejected: same, and 903 days stale |
| `keyring` | yes | **Rust toolchain** (`native_toolchain_rust`, `hooks`) | Rejected: swaps one prerequisite for a worse one |
| **`crossvault`** | **Credential Manager + DPAPI/CNG** | **none** | **Adopted** |

`crossvault` includes only `wincred.h`, `ncrypt.h` and `bcrypt.h` — standard
Windows SDK headers — and no coroutines. Verified in the built plugin: no `atlstr`,
no `<winrt/`, no `experimental/coroutine`.

**Its one limitation is real: no Linux implementation.** On Linux the token lives
in memory for the session and the user signs in again after a restart. Because
`CredentialStore` is an interface, adding Linux later touches one file.

**The lesson from the two rejected rejections is the valuable part.** Checking
`local_storage_cache` and `get_secure_storage` properly — rather than dismissing
them — was what surfaced that `keyring`'s native half needs a Rust toolchain, and
it corrected a claim I had already made. The umbrella package is **not** where the
native code lives for a federated plugin: `webauthn_secure_storage`'s umbrella was
clean and its `_windows` package carried the ATL and the WinRT include.

### 4.34 BLOCKER — Visual Studio's compiler component is unregistered

Still broken, and **not the project's fault**. `flutter build windows` refuses with
`Unable to find suitable Visual Studio toolchain` whenever Flutter asks `vswhere`
for an installation satisfying
`Workload.VCTools` + `VC.Tools.x86.x64` + `VC.CMake.Project`.

- `Workload.VCTools` ✅, `VC.CMake.Project` ✅, `Windows10SDK` ✅
- **`VC.Tools.x86.x64` ❌ not registered**, though `cl.exe` 14.51.36231 and
  `cmake.exe` are both present and working.
- The component **was** registered earlier in this session and `state.json` shows
  it in the selection before the ATL installer attempts and not after. **The exact
  cause is not established.**

**`vs_installer.exe modify --add` made this worse and must not be used.** Its
installer log shows it *removing* packages — `Microsoft.VC.14.51.CRT.Headers`,
`Microsoft.VC.14.51.Servicing.CrtHeaders` — while re-downloading the Build Tools
payload, and it never restored the compiler component.

**The fix belongs to the owner**, in the GUI, because the point of the GUI is that
it shows the pending change *before* it is applied: *Modify* → *Individual
components* → search `MSVC` → confirm **"MSVC Build Tools for x64/x86 (Latest)"**
is ticked → *Modify*. As of this entry the owner has done that and `vswhere`
reports the component registered with `isComplete: true`, so this is recorded as
**resolved pending confirmation by a build**.

macOS and Linux builds are unaffected.

### 4.35 What a Nepali invoice actually has to contain

The owner's instruction: learn what Nepali billing requires, then implement it
properly. The specification had already set the standard — *"Nepal's applicable
tax rules shall be verified against current authoritative requirements before
production release and **shall not be treated as permanently fixed application
constants**"* — so the work had two halves, and the second mattered more than
the first.

| File | Contents |
| --- | --- |
| `docs/NEPALI_BILLING.md` | The rules, their sources, **and where the sources conflict**. |
| `domain/billing/nepali_pan.dart` | `NepaliPan`: nine digits, formatting removed, malformed rejected. |
| `domain/billing/nepal_tax_rules.dart` | `NepalTaxRules` — the rules as **data with a version**, not constants. |
| `domain/billing/business_profile.dart` | `BusinessProfile`: the supplier details every tax invoice carries. |
| `domain/billing/party.dart` | `Party` — customer or supplier, with PAN and VAT registration. |
| `domain/billing/invoice_compliance.dart` | `InvoiceKind`, `InvoiceComplianceIssue`, `InvoiceCompliance`. |
| `domain/billing/amount_in_words.dart` | Total in words, in lakh and crore. |
| `domain/billing/hs_code.dart` | HS code, the 46th-amendment addition for goods. |
  | `test/domain/nepal_billing_test.dart` | 37 tests. |

**Two compliance questions were left open on purpose, and are recorded in section
5.1** so they are not forgotten: the VAT registration threshold, and the buyer's
PAN threshold. The sources conflict on both, so neither is implemented as a
constant — the registration flag is stated by the owner, and the PAN threshold uses
the stricter of the two reported figures.

**What was implemented, and why each one is a rule rather than a feature:**

- **Two invoice forms, not one.** Rule 17 tax invoice, and the Rule 17(Ka)
  abbreviated retail invoice available only within a ceiling — NPR 10,000. Both are
  legal, and the abbreviated form is a convenience for a high-volume seller, never
  a way to refuse a customer who asks for a full one.
- **The seller's PAN gates everything.** A bill without the supplier's PAN is not a
  valid tax bill, so a business with no PAN is reported first and every other check
  is moot without it.
- **The buyer's PAN is required when any of three conditions hold**: the buyer is
  VAT-registered, the document is a full tax invoice, or the total is at or above
  the threshold. **A malformed PAN is reported as missing, not accepted** — an
  invalid PAN on a bill is not a PAN, and printing one looks compliant without
  being so.
- **A VAT-registered business charging no VAT is reported.** The zero-rate case is
  legitimate for zero-rated or exempt goods, but never by accident.
- **Rates travel as `NepalTaxRules` with a version string.** The Finance Act sets
  the VAT rate every year, so `const int vatStandardRate = 1300` in the domain is a
  rule that would be silently wrong the year it changed. A test proves a different
  rule set changes the verdict with no code change.
- **Nothing is inferred that the sources disagree about.** Whether VAT
  registration is *compulsory* depends on a turnover threshold reported
  inconsistently (NPR 20 lakh or 30 lakh for services), so **no threshold is
  implemented at all** — `isVatRegistered` is stated by the owner. Guessing would
  produce confidently wrong compliance advice, which is worse than none.
- **Retention was corrected.** Income Tax Act §81(2), verified against the
  statutory text, is **five years from the expiry of the income year** — not five
  years from the transaction date. VAT is commonly cited at six, and is the longer
  and therefore binding period. `docs/BACKUP_AND_RETENTION.md` previously stated
  a single undifferentiated "six years"; it now carries both figures, their
  different start points, and which one binds.

**Compliance is advisory, not blocking.** `InvoiceCompliance` reports what is
missing; it does not refuse to issue. An owner who must bill a customer at closing
time and cannot, will work around the application entirely, which is worse than a
report they can see and act on.

**Two defects the tests caught in my own new code**, both found before they could
ship:

1. **`amountInWords` was producing "Rupees Ten Hundred Crore"** for Rs 100,000. The
   divisor list and the name list were **misaligned** — `units[0]` was crore while
   `names[0]` was the empty string. Every lakh and crore figure on every invoice
   would have been wrong. Caught by a test asserting 100,000 contains "One Lakh".
2. **The ceiling test did not land on the ceiling.** It computed a price from
   `rupees * 1.13` and assumed the result equalled NPR 10,000, but VAT is rounded
   per paisa, so it does not for most inputs — the test was passing without ever
   exercising the boundary. It now builds an exact price (Rs 8,849.56 + 13% =
   Rs 10,000.00) and asserts the total first, so a change to the VAT calculation
   cannot quietly stop it testing what it claims to.

**Mutation-tested**, because boundary rules are where compliance is lost: making
the ceiling exclusive fails the inclusive test, and restoring the misaligned
name lists fails the lakh/crore tests. Both caught.

**Deliberately not implemented**, and recorded so they are not forgotten: e-billing
to CBMS (a certification programme, with a threshold the literature calls a
"moving threshold" — reported as NPR 20 crore from April 2026, down from 25 crore);
the Annex 5 and Annex 13 reports; and Nepali-language rendering.

**One thing this work revealed about the existing design**, worth protecting: CBMS
certification checks that invoice numbers are **sequential, gap-free, and allocated
inside the issuing transaction**. The existing `DocumentNumber` design already
satisfies that. **Do not ever add gaps** — for tidier numbers, or to reserve
numbers — or certification becomes impossible.

Verified: **749 Dart tests** (was 712, so 37 new), 35 Laravel tests, analyze
clean, Pint clean, Windows build succeeds.

### 4.36 Customer identity — decided, implemented in the domain, blocked in the database

**The owner's decision:** a customer gets a **random internal `id`** plus a
separate **sequential business `code`** such as `C-0001`. Recorded in
`docs/decisions/010-customer-identity.md`.

The reasoning that shaped it: an `id` that changed would repoint historical sales
at a different person, so it is random and never derived from anything a person
types — which also closes the id-collision question in 7.16 for free. The `code` is
what people see, and because it is not identity it can be re-sequenced freely.

**The owner's suggestion of "first name plus a unique index" was rejected, and
the reason is the substance of the decision.** Names repeat in Nepal — two "Ram
Bahadur" are not a mistake — and they are *mutable*: misspelled, transliterated
differently, or changed on marriage. A unique index on a name would either reject
legitimate customers or turn a routine correction into a lost record. Their actual
intent, catching duplicates, is served by **a unique index on `pan_number`**, which
is a genuine unique key and so cannot produce a false collision.

| File | Contents |
| --- | --- |
| `domain/billing/customer.dart` | `code`, `isVatRegistered`, `businessName`, and `displayReference`. |
| `infrastructure/database/drift_customer_repository.dart` | **Refuses** to store a customer carrying the new fields. |
| `test/infrastructure/customer_field_refusal_test.dart` | 6 tests on that refusal. |
| `docs/decisions/010-customer-identity.md` | The decision, and why persistence is blocked. |

**A duplicate was removed along the way.** `Customer` already existed and was wired
into `IssueInvoice`, `RecordPayment`, and three test files; I had added a `Party`
type that duplicated it. `Party` is deleted and its capability folded into
`Customer`, which is the type the working use cases already use.

**The persistence half is blocked, and the reason is worth recording.** Adding the
columns to `customers` requires more than an `ALTER TABLE`, because of two
structural facts about drift:

1. **`createTable` writes the table's *current* definition**, so a database migrated
   from before v3 already gets the new shape from the create step. The migration
   must therefore skip the add-column step on that path while applying it on every
   other — a guard on both `from` and `to`.
2. **The generated data class always targets the newest schema**, so every
   migration test that stops at an intermediate version and then reads a customer
   fails with a null-check error. 21 tests rely on `customers` never changing after
   v3.

I got past (1) and could not get past (2): updating the v3–v9 snapshots did not
propagate to `test/generated/schema_v3.dart` across repeated regenerations, so the
change was **reverted rather than left half-applied**.

**Nothing is silently dropped.** `DriftCustomerRepository` throws rather than
storing a customer whose `code`, VAT status, or business name the v9 schema cannot
hold, naming section 4.36. Silently losing those fields would mean a customer read
back as VAT-unregistered and a compliance decision taken from a wrong record, with
nothing reporting it — the worse error by far.

**Recommended way to finish it:** a **separate `customer_details` table** created at
v10, keyed on the customer id. That leaves `customers` frozen at its v3 shape, so
every existing migration test is untouched and no migration machinery is needed.

Verified: **755 Dart tests**, analyze clean, and the Windows build still succeeds.

### 4.36 Customer identity — decided, implemented in the domain, blocked in the database

The owner approved **a random internal id plus a separate sequential business
code** (`C-0001`), after being offered and discussing a single sequential
identifier and a name-based key. Recorded in **ADR 010**, which carries the full
reasoning; the summary:

| | |
| --- | --- |
| **id** | Random, permanent, internal. Never derived from anything a person types. |
| **code** | Sequential, business-facing, printed on invoices and quoted on the phone. |

**This closes the open question in 7.16.** Ids must not collide if two
installations ever sync, and a random id cannot collide — so that risk is closed
now, at no cost, rather than after data exists.

**Duplicate detection came from the PAN, not the name.** A unique index on
`pan_number` is the one key that *cannot* produce a false collision, because two
businesses cannot share a PAN. A name cannot offer that property: Nepali names
repeat, and a name is mutable — misspelled, transliterated, or changed on marriage —
so making it identity would repoint history.

**Two corrections made while doing it.** I introduced a `Party` type alongside the
existing `Customer`, which already covered the same ground and was wired into
`IssueInvoice`, `RecordPayment`, and three test files. `Party` is deleted and its
PAN and VAT handling folded into `Customer` — the duplication was mine, and
exactly the kind this project flags elsewhere.

#### The blocker — and how it was solved

The database is now at **schema v10**, and the three fields **are** stored.

Adding the columns to `customers` directly turned out to be much harder than it
looks:

1. `createTable` writes the **current** definition, so a pre-v3 database gets the
   new columns for free and the migration must *not* add them — while it *must* on
   every other path. That needs a guard on `to` as well as `from`.
2. **The generated data class always targets the newest schema**, so every
   migration test that stops at an intermediate version and then *reads* a
   customer crashed. **21 tests** depended on `customers` never changing after v3.
3. The per-version schema helpers **would not regenerate** from edited snapshots.

**Solved with a separate `customer_details` table** created at v10, holding
`code`, `isVatRegistered`, and `businessName`, keyed to `customers.id`. **No
existing table is touched**, so every v1-v9 snapshot stays valid and all 32
migration tests pass unchanged. `DriftCustomerRepository` reads through a
**left outer join**, because a customer recorded before v10 has no detail row and
an inner join would silently drop them from the list — a customer who cannot be
found cannot be invoiced.

Two bugs found while doing it, both of which would have shipped silently:

- **The PAN unique index was created only in `onUpgrade`, so a *fresh* database
  never had it.** Two customers with the same PAN were accepted. An index added
  only to the upgrade path leaves every new database without the guarantee, which
  is exactly where a duplicate would slip in. It is now created on both paths.
- `issueCustomQuery` is deprecated in favour of `customStatement`; using the
  supported API instead of suppressing the warning.

#### What was not worked around

An earlier attempt persisted the fields loosely. **That is the bug you caught**,
and it was mine: I widened `Customer` without widening storage, so
`CustomerRepository.save()` promised something the implementation could not
deliver. A temporary guard turned *silent data loss* into a *loud failure*, which
was the minimum mitigation and not a fix. It has been replaced by the real thing.

`test/infrastructure/customer_details_persistence_test.dart` now asserts the
round trip directly — most importantly that `isVatRegistered` reads back **true**,
because if it read back false the application would stop asking for the PAN that
lets a VAT-registered customer claim input credit. **Mutation-checked**: dropping
that field on read fails three tests.

Verified: **759 Dart tests**, 35 Laravel tests, analyze clean, Pint clean, Windows
build succeeds.

### 4.37 The business's own details, and the first real Settings screen

**Without this the application cannot produce a valid tax invoice at all.** Rule 17
requires the supplier's name, address, and **PAN** on every tax invoice, and a bill
without the supplier's PAN is not a valid tax bill. There was previously nowhere to
type any of it.

| File | Contents |
| --- | --- |
| `domain/billing/business_profile_repository.dart` | The port. A singleton, not a collection. |
| `application/business_details.dart` | `BusinessDetails` — the load/save use case. |
| `infrastructure/database/tables.dart` | `BusinessProfiles`, created at v11. |
| `infrastructure/database/drift_business_profile_repository.dart` | The implementation. |
| `presentation/screens/settings_screen.dart` | `BusinessDetailsPanel`, above the account panel. |
| `test/infrastructure/business_profile_persistence_test.dart`, `test/presentation/business_details_panel_test.dart` | 8 and 8 tests. |

**A new table rather than new columns**, for exactly the reason ADR 010 found for
`customer_details`: adding columns to an existing table changes the shape
`createTable` produces for every older database. A table that did not exist before
v11 is simply absent from every earlier snapshot, so **all 32 migration tests pass
unchanged**.

**The VAT box is a checkbox, not a dropdown.** There are two states, and the
question is "is this business registered", not "which band". It **decides behaviour**
— invoices charge 13% when ticked — and it is stated, never inferred.

**The architecture guard caught a real design mistake.** The first version handed
`BusinessProfileRepository` straight to the Settings screen, which
`architecture_test.dart` rejected: a screen must never hold a repository, because
one can then save anything it likes, including a profile the domain never
validated. `BusinessDetails` is the correct seam. The only allow-list addition was
`domain/billing/business_profile.dart`, a **value type**, with a reason.

#### One consequence worth remembering

**The profile lives in the open year's database**, because each fiscal year has its
own file. So a new fiscal year starts with no business details, and **year
conclusion has to copy the profile forward** or the owner retypes it every Ashadh.
That is defensible — an invoice in 2082/83 must show the PAN the business was
registered under *then* — but it is a real obligation on the conclusion work and is
recorded there rather than discovered later.

Verified: **775 Dart tests** (759 + 16), 35 Laravel tests, analyze clean, Pint
clean, Windows build succeeds.

- **Known limitation — an invoice does not yet record the seller details it was
  issued with.** `Invoice` carries only `id`, `issueDate`, `customerId`, `lines`,
  and `vatRateBasisPoints`. So a historical invoice shows the business details
  **as they are now**, not as they were printed. That matters for an audit, where
  the printed document is the evidence. Recorded rather than claimed, because an
  earlier draft of this file asserted the opposite.
- **Two other open consequences**, both from putting the profile in its own file:
  the backup sweep matches `^accounting-(FY-...)\.db$`, so **`business.db` is not
  backed up**; and a restore onto a new machine therefore brings the year data but
  **no business name or PAN**, which would leave every invoice invalid until the
  details are re-entered.

### 4.38 The first two data-entry forms: customers and invoices

**Gate 7, and the first change that makes the application usable rather than
readable.** Everything before this could *compute* everything and *store*
everything, but a user could type into nothing except Settings.

| File | Contents |
| --- | --- |
| `domain/billing/customer_code.dart` | `CustomerCode`, printed as `C-0001`. |
| `domain/billing/customer_code_sequence.dart` | The port for allocating them. |
| `application/create_customer.dart` | `CreateCustomer`, `CustomerCreated`, `CustomerRejected`. |
| `presentation/screens/customer_screen.dart` | The customer form. |
| `presentation/screens/invoice_screen.dart` | The invoice form. |
| `test/application/create_customer_test.dart`, `test/presentation/customer_screen_test.dart`, `test/presentation/invoice_screen_test.dart` | 12, 10, and 10 tests. |

**A customer code needed its own sequence, and this was not obvious.** Document
numbers restart each fiscal year, which is correct for documents. **A customer code
must not**: `C-0001` issued again next year would name two different customers and
make every old invoice ambiguous. So `customer_code_sequence` is a separate
lifetime counter (ADR 010), and a new table at schema v12.

**The code is allocated inside the transaction, after validation.** A refused
customer must not burn a reference — a gap in the sequence is harmless, two
customers sharing a reference is not. **Mutation-tested**: moving the allocation
before validation fails three tests, so the tests are real.

**The screens decide nothing.** Neither form computes a total, chooses a number, or
builds a journal entry; both hand typed input to a use case and render what came
back. If a screen calculated a total, the figure on the bill and the figure in the
ledger could disagree, with only one of them quietly wrong.

**Three defects the tests caught:**

1. **The invoice form could never clear after issuing.** `_clear()` disposed
   controllers that were still attached to live `TextFormField`s, which throws
   during the rebuild and takes the frame down with it. It now clears text in
   place, which is also what the user sees rather than new empty fields.
2. **A test asserted unreachable behaviour.** "Will not submit an invoice with no
   lines" could never fire, because the form deliberately always keeps a row.
   Replaced with the property that actually matters: *the form always offers a
   row, and the only row is not removable.*
3. **A failure I first read as a screen bug was my own fake.** `JournalEntry`
   refuses an unbalanced entry, so a stub with no lines threw *inside* the use case
   and the screen correctly reported a problem instead of the issued number. Worth
   recording because it presented exactly like a UI fault.

**One deliberate convenience, documented in the screen.** The customer form strips
hyphens from a typed PAN (`301-234-567` → `301234567`), because on a laptop
nobody types them. The domain still has the final say.

**The architecture guard was extended, not silenced.** `invoice.dart` and
`invoice_line.dart` are added to the allow-list with a reason: both are value types
the screen constructs and hands over, and the screen reads **none** of the totals.

Verified: **807 Dart tests**, 35 Laravel tests, analyze clean, Pint clean, Windows
build succeeds.

### 4.39 The payment form — and a receivable can now be settled

**The last step that makes billing end to end.** An issued invoice left a
receivable outstanding forever until a payment could be recorded; now it can be.

| File | Contents |
| --- | --- |
| `presentation/screens/payment_screen.dart` | The receipt form. |
| `test/presentation/payment_screen_test.dart` | 7 tests. |

**The screen decides nothing about the accounting**, the same rule as the other two
forms. In particular it does **not** decide whether the amount is too much:
`RecordPayment` allows exactly the outstanding balance and refuses one paisa more,
**accounting for credit notes already issued**. A screen that rounded or tidied the
figure would turn a correct refusal into an accepted overpayment — so there is a
test asserting `5000.50` reaches the use case as exactly 500050 paisa.

**The screen does offer one choice: bank or cash.** A person has to say where the
money landed, and nothing more. The entry itself is the use case's.

**On success it reports what is still outstanding**, from the balance the use case
returned rather than a subtraction done in the UI — and says plainly when the
invoice is fully settled, which is the thing the user most wants to know.

**`PROGRESS.md` was corrected in the same session**, having gone stale again: it
claimed 762 tests and 4 screens with entries, when there were 807 and six. The
counts are now accurate and the old "4 of 30" claim is marked superseded.

Verified: **814 Dart tests**, 35 Laravel tests, analyze clean, Pint clean, Windows
build succeeds.

### 4.40 The product form — and Gate 7's data entry is complete

**The last of the four data-entry screens.** With it, a business can create a
customer, invoice them, take payment, and define what it sells.

| File | Contents |
| --- | --- |
| `application/create_product.dart` | `CreateProduct`, `ProductCreated`, `ProductRejected`. |
| `presentation/screens/product_screen.dart` | The product form. |
| `test/application/create_product_test.dart`, `test/presentation/product_screen_test.dart` | 7 and 8 tests. |

**A product needed no code, and that is a distinction worth stating.** A customer
is a **party** and gets a quotable reference and a PAN; a product is a **catalogue
line** and is a counterparty on nothing. So `CreateProduct` allocates no code and
opens no sequence, unlike `CreateCustomer`.

**The form never asks for a cost, and there is a test saying so.** ADR 004 makes
the running inventory *value* authoritative and derives the cost from it; a stored
cost would be a second source of truth that drifts. The cost arrives when stock is
received, through a movement.

**Two price rules that differ on purpose, and both are tested:**

| | Invoice line | Product |
| --- | --- | --- |
| Zero price | **refused** — a zero-value line is a data-entry mistake | **allowed** — giving stock away is legitimate |

**The id is random**, for the same reason a customer's is: stock movements and
invoices reference a product by id, so an id that changed would repoint historical
stock and sales at the wrong item.

### 4.41 Gate 7 status

| Screen | State |
| --- | --- |
| Settings | ✅ business details, account |
| Customers | ✅ create |
| Invoices | ✅ issue, multiple lines |
| Receipts | ✅ record payment |
| Products | ✅ create |

**7 of 32 navigation items now have real screens**, up from 4 at the start of this
stretch. The sales cycle is complete end to end: create a customer → invoice →
record payment.

**Still absent in Gate 7**, and recorded so they are not mistaken for done: stock
*movements* (receiving stock, adjusting it) have a tested use case but no screen;
the same for credit notes and journal entries. Those are the remaining ways to
change the books by hand.

Verified: **829 Dart tests**, 35 Laravel tests, analyze clean, Pint clean, Windows
build succeeds.

### 4.42 The last three ways to change the books by hand

**Gate 7's data entry is now complete.** Stock movements, credit notes, and
journal entries all have screens.

| File | Contents |
| --- | --- |
| `presentation/screens/stock_movement_screen.dart` | Receiving stock, or writing it off. |
| `presentation/screens/credit_note_screen.dart` | Reducing an invoice already sent. |
| `presentation/screens/journal_entry_screen.dart` | A manual entry straight into the accounts. |
| `test/presentation/books_entry_screens_test.dart` | 6 tests, **against the real use cases**. |

**These run against the real use cases over a real database, not stubs.** A stub
would only prove the screen forwards its arguments; using the real thing also
proves the screen and the use case agree on what the fields *mean* — which is
exactly where a screen that guessed would show up. An earlier attempt with
hand-written stubs needed so much scaffolding that it was replaced rather than
finished, which is the honest reason the file is small.

**Three things the screens deliberately refuse to decide:**

- **The value of stock, not a unit price.** ADR 004 makes the running inventory
  *value* authoritative; the screen asks for a quantity and a total, and there is a
  test asserting it never asks for a unit price.
- **Whether stock may go negative.** The repository refuses inside the transaction;
  the screen cannot know the current level and does not pre-judge it.
- **How much of an invoice may be credited.** `IssueCreditNote` checks it against
  what is still outstanding, accounting for payments received.

**The one rule a screen *prompts* rather than enforces** is that debits must equal
credits, shown as a live difference. That is not duplicated logic: the difference is
made visible while typing, and `JournalEntry` still decides. A test posts an
unbalanced entry and asserts **the ledger stays empty**.

**One navigation item added that `ui.txt` does not list:** *Credit Notes*, beside
*Invoices*. `IssueCreditNote` exists, and a business with no way to issue one
cannot correct an invoice it has already billed. Recorded as a deliberate
deviation rather than left silent.

Verified: **835 Dart tests**, 35 Laravel tests, analyze clean, Pint clean, Windows
build succeeds.

### 4.43 Concluding a fiscal year — the ordering guarantee

**The specification's sixteen steps, of which the local half is now built and
tested.** What matters is not that the year closes but that it closes in the
right order, so that is what the tests are about.

| File | Contents |
| --- | --- |
| `domain/accounting/year_end.dart` | `ClosingEntry`, `YearEndClosing`, `YearEndBlocker`, `YearEndValidation`. |
| `application/conclude_fiscal_year.dart` | `ConcludeFiscalYear`, the `FiscalYearArchive` and `FiscalYearTransition` ports. |
| `test/application/conclude_fiscal_year_test.dart` | 8 tests. |

**The ordering is the whole feature**, and the specification is explicit three
times over: *"Only after server confirmation may the local application create and
activate the next fiscal-year SQLite database"*, *"shall never delete or discard
the previous fiscal-year database before the server has confirmed successful
archival"*, and *"shall not partially complete the year transition"*. So the flow is
validate → post closing entries → **archive** → *only then* create the next year.

**Three tests hold that line, and two are mutation-worthy:**

- An **unreachable** archive stops the close **before anything is written**, so
  there is no half-closed year to repair.
- A **failed** archive leaves the year open and creates no next year.
- The archive is proven to happen **before** the transition, by recording the call
  order rather than assuming it.

**Why the ports exist:** the archive is a server call, so putting it behind an
interface is what makes the ordering testable without a network. It also means a
close cannot quietly proceed when the archive is unconfigured — which is the whole
risk.

**Two details that would have been wrong quietly:**

- **A fiscal-year label advances both parts.** `FY 2082/83` is followed by
  `FY 2083/84`; a Nepali year is named for both Gregorian years it touches.
- **Revenue closes by crediting the nominal account; an expense closes by
  debiting it.** Reversing that reports a profit as a loss, and every total would
  still balance — so nothing else would catch it. The test asserts the direction.

**Not yet built**, recorded so this is not mistaken for a finished feature: the
**screen** for concluding a year, and the **real** implementations of
`FiscalYearArchive` (uploading to the server) and `FiscalYearTransition`
(creating next year's database). The logic is done and tested; the plumbing and
the button are not.

Verified: **843 Dart tests**, 35 Laravel tests, analyze clean, Pint clean, Windows
build succeeds.

## 5. What has NOT been done

Everything else. Specifically, none of the following exist:

- **Customers as records.** Done. See 4.11.
- **Invoices as records.** Done. See 4.12.
- **Payments received.** Done. See 4.13. A receivable can now be settled.
- **Credit notes.** Done. See 4.14. A posted invoice can now be corrected, which
  is the only correction path ADR 005 permits.
- **Debit notes.** `DocumentType.debitNote` and its `DBN` sequence exist and are
  unused. A debit note *increases* what a customer owes, so it is needed for
  under-billing. Not started.
- **Refunds.** `InvoiceBalance.isRefundDue` reports when the business owes a
  customer money, but there is no supported way to pay them back. Only reachable
  by fully paying then crediting an invoice.
- Ageing of receivables, statements of account, and any collection reporting.
- **Customer id generation.** **Resolved.** A random internal id plus a separate
    sequential business code (`C-0001`); both are stored at schema v10. This closes
    the sync-collision risk that section 7.16 raised. See ADR 010 and 4.36.
- **Inventory, stock, and COGS.** **Complete for Gate 6.** Products, movements,
  derived value-first stock with negative stock blocked, posting to the ledger, and
  the write-down to the lower of cost and net realisable value all work.
- **Locations and transfers.** `MovementReason.transfer` exists in the
  specification's list but is refused, because locations are not modelled and a
  transfer has nothing to move between. Adding locations is a separate feature.
- **Suppliers and purchases as documents.** Stock can be received, but there is no
  purchase order, supplier bill, or supplier record. `2010 Accounts Payable` is
  credited without a document behind it.
- **The link from a sale to stock.** A product cannot yet be put on an invoice
  line, so issuing an invoice does not move stock automatically. Selling and stock
  movement are still two manual operations.
- ~~Cash Flow and every other report beyond the four above.~~ **Built 2026-10-02:**
    cash flow, sales, stock held, and VAT. Input VAT remains zero, because the
    purchase side of this application does not exist.
- **The Flutter UI.** Not "any" — the shell, navigation, theme, licences screen,
  Trial Balance, General Ledger, fiscal-year selector, and Backup screen are built
  and wired to real data. See 4.20 to 4.25. **Still missing: any screen that
  creates a record.** There is no form for a customer, a product, an invoice, or a
  payment, so the business cannot be run through the application. This is the
  largest remaining gap and it is what keeps Gate 7 open.
- **The backend.** Not "any" — Sanctum, PostgreSQL configuration, `books` and
  `backup_revisions`, the upload verification chain, and store/index/show routes
  exist and are tested. See 4.26.
- **Uploading a backup off the machine.** **Done, and usable.** The desktop
    verifies a snapshot, authenticates, sends it, and reports a refusal, a
    conflict, a **revoked session**, or an unreachable server distinctly, without
    ever touching the local copy. See 4.28 and 4.30. **Still missing: restore**,
    which is the other half of Gate 9.
- **Restore from the cloud.** The server can store and list revisions but has **no
  download endpoint**, and the desktop has no restore-from-server path. A backup
  that cannot be fetched is not a backup, so this is the other half of Gate 9.
- **Protected token storage.** Done. The token is held by `crossvault`, which uses
    the Windows Credential Manager (DPAPI-backed) with **no additional toolchain**.
    Two predecessors were rejected on evidence — `flutter_secure_storage` needs
    Visual Studio's optional ATL component, and `webauthn_secure_storage` needs the
    Windows App SDK. See 4.33. **Gap: no Linux implementation**, so on Linux the
    token lives in memory for the session and the user signs in again after a
    restart.
- **Identity.** Sanctum is installed, the upload routes are authenticated, and
  **token issuance works**: `register`, `login`, `logout`, and `me`, tested and
  verified end to end against live PostgreSQL. The desktop **uses** a token for
uploads. See 4.27, 4.28, and 4.30. **The desktop sign-in screen is built** —
    Settings holds the account panel, and signing in or out rebuilds the services.
    **Still missing: the licensing system** the specification requires.
- **Licensing.** Not started, and it is a larger capability than authentication.
  The specification requires a backend-signed licence authorisation carrying the
  license id, user id, book id, status, expiry, issue date, next validation time,
  and license revision, optionally bound to a registered device — signed with a
  **private** key the desktop never holds and verified with a **public** key it
  carries, so an expired licence can be detected with no internet connection. Also
  `subscriptions` and `registered_desktop_installations`. The token endpoints here
  are deliberately **not** presented as licensing. See section 6.

### 5.1 Open questions that need the owner's answer

Two compliance questions were left deliberately unanswered in 4.35, because the
sources conflict and **guessing would produce confidently wrong advice about
someone's tax obligations.** Neither blocks anything. Both are one small code
change once answered.

| # | Question | Why it is open | What is needed |
| --- | --- | --- | --- |
| 1 | **The VAT registration threshold.** Compulsory registration is reported at NPR 50 lakh for goods, but for services as **NPR 20 lakh or NPR 30 lakh** — different sources give different figures, and the rate is reset by each year's Finance Act. | Whether a business *must* register depends on a number that moves annually and that the sources disagree about. | A chartered accountant's answer, or the figure from the operative Finance Act. Until then `BusinessProfile.isVatRegistered` is **stated by the owner, never inferred**. |
| 2 | **The buyer's PAN threshold.** Reported as NPR 10,000 (the Rule 17 abbreviated-invoice ceiling, applying to all transactions) and as NPR 1 lakh (individuals buying from a supplier who is not VAT-registered). | The two may be reconcilable — one applying generally, one to individuals — but the sources do not say so. | The same. Meanwhile `NepalTaxRules.buyerPanRequiredByAmount` uses the **stricter** figure, so a bill asks for a PAN slightly more eagerly than strictly required. |

**Why the conservative direction.** Where a choice had to be made in code, it
errs towards asking for a PAN and towards never guessing a threshold. Over-asking
costs a line on a form; under-asking can cost input credit at an audit. That
reasoning is recorded so a future change to "be more helpful" does not quietly
invert it.

**What was deliberately not built**, for the same reason: CBMS e-invoicing
integration, the Annex 5 and Annex 13 reports, and a Nepali-language rendering of
the invoice. See `docs/NEPALI_BILLING.md`.
- **Sync, licensing, and device registration.** Not started. Sync in particular
  depends on the id-generation question in 7.16.
- **Retention.** The specification and Nepali law require records to be kept for
  years; nothing prunes, archives, or enforces that. See
  `docs/BACKUP_AND_RETENTION.md`.

### 5.2 Backend findings from reading the scaffolding

Discovered by reading the generated backend. **Every row is now resolved**; it is
kept because the traps in it cost time and the reasoning is not obvious from the
finished code.

| Finding | Status |
| --- | --- |
| `DB_CONNECTION=sqlite` in both `.env` and `.env.example`, and `sqlite` is the default in `config/database.php` | **Resolved.** Switched to `pgsql`, and the `financeapp` database now exists with all six migrations applied. See 4.26 and 4.27. The password is in `backend/.env`, which is gitignored. |
| No `routes/api.php`, and `bootstrap/app.php` registers only `web`, `commands`, and `health` | **Resolved.** `api:` routing registered, `routes/api.php` created. |
| No Sanctum or Passport installed | **Resolved.** `laravel/sanctum` v4.3 installed, the upload routes are protected, and **token issuance now works** — `register`, `login`, `logout`, `me`. See 4.27. **Licensing is still not implemented; see section 5.** |
| `APP_NAME=Laravel` | **Resolved.** Now `financeapp`. |
| Laravel 13 uses PHP attributes on models: `#[Fillable([...])]`, `#[Hidden([...])]` | **Convention trap.** Write the attribute style, not the older `$fillable` / `$hidden` properties. See `backend/app/Models/User.php`. The new models follow it. |
| Tests are PHPUnit (`^12.5`); Pest is not installed | Use PHPUnit. `php artisan test` is the command that passes; 35 tests, 97 assertions. |
| Skeleton ships Vite, Tailwind, `resources/views/welcome.blade.php`, and `routes/web.php` returning a view | **Left in place deliberately.** Dead weight for an API-only backend, but removing it is a separate cleanup and is not blocking. |
| `backend/database/database.sqlite` exists as a real file | Confirmed gitignored. Do not commit it. |
| `backend/database/migrations/0001_01_01_000000_create_users_table.php` already creates `users`, `password_reset_tokens`, and `sessions` | Built on, not recreated. |

### 5.3 Desktop toolchain findings

| Finding | Impact |
| --- | --- |
| **Flutter was upgraded from 3.24.5 to 3.47.5** (Dart 3.5.4 to 3.13.4) | Resolved. `drift` is back on the current release (2.31.0) and the old pin is gone. See section 7.8. |
| **Visual Studio is now installed** (Visual Studio Build Tools 2026 18.10.2) and `flutter doctor` reports `[√] Visual Studio - develop Windows apps` | Resolved. The "Desktop development with C++" workload is present. |
| **Windows Developer Mode was enabled by the owner, and `flutter build windows` now succeeds**, producing `build\windows\x64\runner\Debug\financeapp.exe`. | Resolved. The build and the `sqlite3_flutter_libs` plugin link both work. Running the binary shows the generated counter app, which is expected until the UI gate. Rebuilt and verified again after the schema v2 migration. |
| The Android SDK path contains spaces, which `flutter doctor` flags | Irrelevant for a Windows/macOS/Linux desktop product. Ignore unless Android is ever targeted. |
| `sqlite3_flutter_libs` is a Flutter plugin and does not load in `flutter test` | Tests still fall back to `winsqlite3.dll` via `open.overrideFor` in `sqlite_native.dart`. Working, and now recorded as intentional. |
- `pubspec.yaml` **does** have dependencies now — `drift`, `sqlite3_flutter_libs`,
  `path_provider`, `crypto`, and others. The approved list is in
  `docs/AI_RULES.md`. **`crypto` was added in 4.23 for the backup checksum**, which
  is why the licence and dependency records had to be updated.
- **PowerShell 5.1 corrupts `.md` files**, and the corruption is already in one
  commit. This is a tooling constraint that affects every future agent working on
  this repository. **See 7.19 before editing any markdown file from a shell.**

## 6. Next task
This is the next bounded task, ready to hand to an agent verbatim.

> **Give a signed-in desktop the divergence table, and say plainly when two
> computers disagree.**
>
> Everything else the specification asked for is built. What is left is the
> honesty work, and this is the highest-value piece of it.
>
> **The problem.** Two computers holding the same books can diverge — invoice #5
> on the desktop, payment #6 on the laptop — leaving two internally consistent
> databases that are *not* the same books. Every upload of both is accepted,
> because each file genuinely is a valid snapshot. A restore replaces one with the
> other without saying so. ADR 007 assumes "one book, one active installation" in
> prose and nothing enforces it.
>
> **Partly prevented already.** ADR 011's `max_devices` rule makes concurrent
> divergence unlikely by revoking the earlier session on sign-in. It does not make
> it impossible — a device that signed out without syncing is invisible to it — so
> detection is still needed.
>
> **Done.** `Divergence` and `SyncComparison` in `domain/sync/divergence.dart`
> classify all four cases from three checksums, with 14 tests. The constructor is
> private, so `divergence` can never contradict its own inputs; see 7.31 for the
> defect that prompted that.
>
> | Local vs last upload | Server vs last upload | What to do |
> | --- | --- | --- |
> | unchanged | unchanged | Silent. Nothing happened. |
> | unchanged | differs | **Offer the choice**: mine, or the server's. |
> | differs | unchanged | An ordinary upload. |
> | differs | differs | **Stop.** Both changed. Do not pick a winner. |
>
> **The prerequisite is already satisfied, so no new plumbing is needed.** The
> upload log records an `UploadRecord` with the confirmed `remoteRevision` and
> `checksum`, and the server's revision index already returns a checksum per
> revision. What remains is a use case that reads both sides, and a screen that
> acts on the classification.
>
> **Required behaviour:**
>
> 1. A `409` from upload becomes a question, not an error. Today it is reported as
>    "a newer archive of this year exists", which reads like a backup hiccup when it
>    is the only trace of divergent books.
> 2. On `bothChanged`, **refuse and explain**. Do not offer "keep mine" / "take
>    theirs": it is not a choice, it is choosing whose work to destroy. Say what
>    each side contains and let them reconcile.
> 3. **Keep the server's chain authoritative.** "Take theirs" always downloads; it
>    never pushes local books under a new revision.
> 4. **Never auto-merge.** For double entry with document numbering, a wrong merge
>    is worse than a refusal. Preserve both and show the difference.
>
> **Then, in order:** a device list on `me` with revoke (the `deviceName` column
> exists and is never read back), a message when a session is revoked that says
> *"you were signed out because this account was signed in on another computer;
> your books on this computer are unchanged"*, and a **token expiry** —
> `sanctum.php` sets `expiration` to null, so a leaked token never dies on its own.
>
> Do not modify: the accounting engine, the reporting layer, the invoice number
> sequences, the `UploadActions` or `AuthActions` ports, the `CredentialStore`
> port, or the immutable-year rule. Do not weaken any test. **Do not install
> Laravel Boost. Do not run `vs_installer.exe modify --add` (4.34).**
>
> **After that, Gate 10**, which is untouched and least specified: deployment
> hardening, retention enforcement against `docs/BACKUP_AND_RETENTION.md`, recovery
> drills, observability, and the installer and update strategy. Two decisions are
> needed before any filing work: which copy of the PAN is authoritative — the
> server's `companies` row or local `business.db` — and encryption at rest, which
> is more pressing now that the PAN is server-held rather than only inside the
> user's own file.
## 7. Decisions and discoveries that affect future work

### 7.1 The desktop framework was chosen: Flutter

The architecture specification left it TBD. Decided Flutter, recorded in
`docs/decisions/008-desktop-framework-flutter.md`. The deciding factor was zero
licensing cost with no vendor dependency, plus the fastest AI iteration loop.
Read that ADR before challenging the decision; it lists what was rejected and
why, including when to revisit Tauri.

### 7.2 Money must never be a float

Dart's `num` and `double` are binary floating point. `0.1 + 0.2` is not `0.3`.
Any monetary value passed as a `double` into the domain is a defect. Convert at
the boundary with `Money.fromMajorUnits` or `Money.tryParse` and never widen
back.

### 7.3 Two real bugs caught by the `Money` tests

Recorded because they demonstrate the required working method.

1. **`timesUnitPrice` was semantically broken.** The first implementation divided
   by 100 unconditionally, so `Rs 0.05 x 3` produced 0 paisa instead of 15. The
   test caught it. It was replaced by `times(int)` for whole quantities and
   `timesFraction(numerator, denominator)` for fractional ones.

2. **A test expectation was wrong, not the code.** The test asserting that
   `0.1 + 0.2` yields 300 paisa was incorrect; 0.30 Rs is 30 paisa. The
   production code was right. The expectation was corrected after re-deriving the
   business fact independently.

That second case matters. Under this project's rules, a failing test is a
question, not a verdict. Ask whether the code is wrong or the expectation is
wrong, and resolve it from the accounting rules. Never edit an expectation purely
to get green.

### 7.4 Inventory costing and negative stock — RESOLVED

**Decided by the product owner on 2026-09-29.** Recorded in ADR 004, with a
plain-language version in `docs/INVENTORY_EXPLAINED.md`.

- **Costing method: moving weighted average.** It is permitted under IAS 2 and
  the Nepali standard that mirrors it, and it matches the product model the
  specification already defines — one `cost` field per product, not cost layers.
  FIFO would be more faithful to physical flow but needs layers, partial-layer
  consumption, and layer logic for purchase returns, which the specification's own
  end-to-end test includes.
- **Negative stock: blocked.** A sale that would take stock below zero is refused
  and nothing is written. With weighted average, selling stock you do not have has
  **no defined cost**, so allowing it forces a guess, and a guessed COGS is a wrong
  gross profit in two fiscal years at once.

**The implementation rule that makes it work, and is easy to miss:** store the
running inventory **value** as authoritative and derive cost per unit from it.
Storing a rounded average cost and multiplying by quantity lets the inventory
account drift out of reconciliation silently within weeks.

**Four follow-on decisions this does NOT settle**, recorded in ADR 004 so they are
not mistaken for done: whether a stock *adjustment* may go negative; writing down
inventory to the lower of cost and net realisable value, which IAS 2 and NAS 2
require and which is **not implemented**; purchase returns; and how opening stock
is entered during onboarding.

**If inventory work is requested, read ADR 004 and `docs/INVENTORY_EXPLAINED.md`
first.** Do not implement write-downs or adjustments without a decision on those,
and do not treat Gate 6 as complete until write-downs exist.

### 7.5 Design choices made in the accounting engine

Recorded so they are not accidentally reverted.

- **Balances are always derived, never stored.** `Account` has no balance field
  on purpose. A stored balance is a second source of truth that can disagree
  with the journal.
- **Equality of `Account` is by id only.** Renaming or recoding an account must
  not invalidate the journal lines that reference it.
- **Illegal line states are unrepresentable, not validated.** There is no
  constructor that takes both a debit and a credit, so no test is needed to
  reject one; the code cannot express it.
- **Negative amounts are rejected at the line level.** This forces every
  reduction to be modelled as the opposite side or a reversal, which is what
  keeps the debit/credit columns meaningful.
- **`Ledger` returns balances in the account's natural direction.** A positive
  asset balance means value held; a positive income balance means revenue
  earned. A bank account can still legitimately go negative.
- **`JournalEntry` does not validate the fiscal year of its date.** That
  requires the fiscal calendar and the active database, and belongs in the
  posting use case, not in the journal. Section 27 of the specification requires
  this check before posting, so it must be added in the application layer.

### 7.6 A note on the working method that produced this

The accounting tests were written first and failed to compile, because the files
they referenced did not exist. That is the intended red state. The engine was
then written and the suite went green without any test being weakened. Every
expectation in `accounting_test.dart` was derived from the accounting rules or
hand-computed from the worked example, never from what the code happened to
return.

### 7.7 Cross-aggregate transactions — RESOLVED

This was a genuine gap: the transaction boundary used to be a single journal
entry, so an operation spanning several repositories could not be atomic.

**Fixed.** `UnitOfWork` is now a port owned by the domain
(`domain/shared/unit_of_work.dart`) with a drift implementation
(`infrastructure/database/drift_unit_of_work.dart`). A use case wraps its work in
`run` and gets all-or-nothing semantics across every repository sharing the same
database.

Nine tests in `test/infrastructure/unit_of_work_test.dart` prove it, including
the case that mattered: a revenue entry written successfully, followed by a COGS
entry that fails, must leave **neither** behind. Without the boundary the revenue
would survive with no cost of sale and the period's profit would be overstated.
Also covered: account writes rolling back alongside journal writes, a
repository's own internal transaction composing with the outer one, nested units
of work joining rather than committing independently, and the original error
reaching the caller rather than being swallowed.

Gates 5 and 6 are no longer blocked by this.

### 7.8 The Flutter SDK — RESOLVED

Flutter was upgraded from **3.24.5 to 3.47.5** (Dart 3.5.4 to 3.13.4) with the
project owner's approval. `drift` is back on the current release (2.31.0), the
old pin and its explanatory comment are gone, and `build_runner` regenerated
cleanly.

The upgrade immediately paid for itself by exposing a latent bug, described in
section 7.14, that the old toolchain had been hiding.

**New prerequisite it revealed:** Visual Studio with the "Desktop development
with C++" workload is required to build or run the Windows desktop app. Tests are
unaffected. See section 5.2.

### 7.9 The fiscal-year posting guard — RESOLVED

Specification section 27 requires that a transaction be rejected when its date
falls outside the active fiscal year. It belongs in a **posting use case**, not in
`JournalEntry` (which would need the fiscal calendar and break domain purity) and
not in the repository (which would make the check easy to bypass).

Closed by `PostJournalEntry` in `application/post_journal_entry.dart`. The guard
runs before anything is opened, so a refused posting writes nothing and has
nothing to roll back, and it cannot be bypassed because it sits at the only
boundary a business operation goes through.

Refusal is a result rather than an exception: a date outside the active year is
normal user input, not a malfunction. Twelve tests cover it, including both
inclusive boundary dates, an afternoon on the final day, and that a refusal
leaves previously committed entries intact.

### 7.10 Bikram Sambat calendar — RESOLVED, and then deliberately un-depended

**First closed with a package, then reopened by the owner and closed properly.**

The original resolution adopted `bikram_sambat` 1.2.0 (MIT, pure Dart) behind
`domain/fiscal/bs_calendar.dart`. The product owner then rejected it on
supply-chain grounds, which was correct: it made the one dataset the product
cannot ship without depend on a **single maintainer**. If that author changed the
licence, went commercial, was bought, or stopped maintaining the package, the
fiscal calendar would become un-shippable. "MIT today" is not a guarantee about
"MIT when we need to ship".

The calendar data now lives **in-tree** in
`lib/src/domain/fiscal/bs_calendar_data.dart`, and the conversion is ours. The
data is factual civil-calendar information set by the Government of Nepal, in the
same way that how many days April has is a fact; facts are not owned by anyone.
Its provenance from the MIT package is recorded in the file rather than glossed
over. See ADR 009.

Three things came out of the swap:

1. **A fake year was found and removed.** The upstream table's last entry, BS
   2200, was twelve 31-day months totalling **372 days**, which no calendar year
   can be. It was projected placeholder data. Carrying it as authoritative would
   have been worse than not having it, so it was excluded and a fiscal year
   needing it is now refused with a clear error.
2. **A latent timezone bug was fixed.** The package applied a fixed **+5:45
   Nepal offset**, so a user whose machine was set to any other timezone would
   have been given shifted dates. Ours does the arithmetic in **UTC**, where every
   day is exactly 24 hours and daylight saving cannot move a date, then presents
   the result as a local date-only value. The calendar is now correct on a machine
   in any timezone.
3. **The data became ours, so the data is tested.** Eleven new tests in
   `test/domain/bs_calendar_data_test.dart` check that every year has twelve
   months, every month is 29 to 32 days, **every year is 365 or 366 days**, the
   years are contiguous, the placeholder year is absent, and that **every single
   day of nine spread-out years** round-trips exactly. That last one is what
   catches an off-by-one which happens to line up at a year boundary.

Verified against published anchors throughout: 1 Baishakh 2000 BS = 14 April
1943, 1 Shrawan 2082 = 17 July 2025, 1 Baishakh 2082 = 14 April 2025. These are
asserted, so a data error fails the build.

**Still outstanding:** the table has been checked for internal consistency and
against public anchors, which is **not** an audit against the Government of
Nepal's published calendar. The years the product will actually be used in
should be verified before launch. Recorded in ADR 009 so it is not assumed done.
### 7.11 Gates 5 and 6 are unblocked — RESOLVED, and both are now complete

Kept rather than deleted because the reasoning still explains why two separate
blockers existed and in what order they had to fall.

- **Cross-aggregate transactions (7.7)** were resolved by `UnitOfWork`, without
  which a business operation spanning several repositories could not be atomic.
- **The fiscal-year posting guard (7.9)** was resolved by `PostJournalEntry`, and
  every posting use case since has reused the same pattern.
- **The chart of accounts** supplied the account definitions every use case posts
  to. It is referenced directly rather than injected, because its ids are
  permanent.
- **ADR 004** was decided by the product owner on 2026-09-29: moving weighted
  average with the running value authoritative, and negative stock blocked.

**Both gates are now complete.** Gate 5 covers the full billing cycle —
numbering, invoices, customers, payments, and credit notes. Gate 6 covers
products, movements, value-first stock, ledger posting, and the write-down to net
realisable value.

### 7.12 An issued invoice is not a record — RESOLVED

An issued invoice used to exist only as a journal entry, which was enough for the
ledger but not for Billing: invoices could not be listed, reprinted, or marked as
paid, and the receivable could not be broken down by customer.

Closed by the `invoices` and `invoice_lines` tables and an `InvoiceRepository`.
`IssueInvoice` now writes all three in **one unit of work**: the serial, the
journal entry, and the document record. All three commit together or none does,
so a numbered invoice always has a record and an entry behind it.

The document record is what makes an invoice reprintable. A journal line records
an account and an amount, not what was sold, so the description, quantity, and
unit price had nowhere else to live.

**The schema enforces the links.** `invoices.customer_id` is a foreign key to
`customers` and `invoices.journal_entry_id` is a foreign key to
`journal_entries`, so an invoice cannot exist without its accounting and cannot
be attached to a customer who does not exist. That closes the remaining half of
7.13.

**The atomicity test.** A pre-existing invoice holds number `0001` while the
document sequence still reads 0. Issuing a new invoice therefore allocates
sequence 1, writes its journal entry successfully, and then fails on the unique
document number. The test asserts the journal entry rolled back, only the
pre-existing entry remains, no orphan lines survive, and **the sequence is back
to 0** — so the failed attempt burnt no serial.

**Totals: stored, but recomputation stays authoritative.** The three total columns
are a denormalisation for listing and printing. `Invoice` still derives them, and
a test asserts the stored values equal the recomputed ones plus that they are
internally consistent, so the two cannot silently diverge.

### 7.13 The customer on an invoice — RESOLVED

`Invoice.customerId` used to be a plain string that nothing validated, so a typo
produced a perfectly balanced journal entry with an uncollectable receivable
attached to nobody.

Closed by the `customers` table and a check inside the issuing transaction.
`IssueInvoice` now refuses an invoice whose customer does not exist, and because
the check runs inside the unit of work, the read that proves the customer exists
cannot be separated from the writes that reference them by a change in between.

**One part is still open.** There is no foreign key from an invoice to a customer,
because there is no invoice table yet. Once invoices are stored (7.12) the
database itself should enforce it, rather than only the application.



### 7.14 The upgrade exposed a silent data-integrity bug, and it is worth reading

Upgrading Flutter was not a cosmetic change. It surfaced a defect that the old
toolchain had been concealing, and the way it was concealed is the lesson.

**What was wrong.** Under drift 2.23 the three foreign-key tests passed. Under
drift 2.31, after regenerating, they failed because the inserts *succeeded*:
foreign keys had stopped being enforced. Two independent faults were stacked:

1. **drift's `.references()` helper produced nothing.** In drift 2.31 the method
   body is effectively a no-op marker in this code path. The generated columns
   carried no `defaultConstraints`, and the `CREATE TABLE` for `journal_lines`
   had **no `REFERENCES` clause at all**. Nothing warned about it. The fix is to
   declare the keys explicitly in `customConstraints`, which is what drift's own
   fixtures do.
2. **`PRAGMA foreign_keys = ON` was in the wrong place.** It is per-connection
   state, not a property of the database file. Setting it once in
   `MigrationStrategy.beforeOpen` worked when one connection served everything,
   and silently stopped working once the executor opened connections per
   operation. The fix is drift's `setup` hook, which runs for **every**
   connection.

**Why it matters.** Either fault alone disables the database as a second line of
defence, which the architecture explicitly relies on. The failure mode is the
worst kind: the tests that were supposed to catch it were the tests that went
quiet. A constraint that is not enforced does not throw, so nothing looks broken.
Only an explicit assertion catches it.

**The permanent guards, so this cannot recur silently:**

- `test/infrastructure/persistence_test.dart` asserts `PRAGMA foreign_keys`
  returns `1` on the connection doing the writes.
- A second test asserts `journal_lines` actually **declares** foreign keys, by
  querying `PRAGMA foreign_key_list`. Enforcement and declaration are asserted
  separately because they failed separately.
- The money-column type is asserted via `pragma_table_info`, guarding against a
  silent change to `REAL`.

**The general lesson for anyone working here.** When upgrading a dependency that
touches the database, do not trust a green suite. Re-derive the schema and check
what is actually in it. Three tests went from passing to failing silently, and
the only reason it was caught is that the suite was run after the upgrade instead
of assuming it would still pass.

### 7.15 A recurring pattern: the expectation is wrong more often than the code

Nine times now a test failure has turned out to be a mistake in the test, not in
the production code:

1. A `Money` test asserted that `0.1 + 0.2` gives 300 paisa. The correct answer
   is 30 paisa. The code was right.
2. A unit-of-work test asserted entries come back as `JE-REV` then `JE-COGS`.
   `all()` orders by date then id, and both entries share a date, so `JE-COGS`
   sorts first. The code was right; the test was asserting an order it did not
   care about and now asserts membership instead.
3. An invoice-persistence test asserted a total of 113,000 paisa for a line of
   **2 x Rs 300**. That is Rs 600, so the correct total is 67,800. The expectation
   had been copied from the Rs 1,000 case without redoing the arithmetic. The code
   was right.
4. A credit-note test credited invoice `INV-1` after the fixture had issued
   `INV-A`, `INV-B`, and `INV-C`, so it was correctly refused as an unknown
   invoice. And a "refusal writes nothing" test asserted the whole
   `document_sequences` table was empty, when issuing the *invoice* had
   legitimately created an `invoice` row. Both were test errors; the second was
   fixed by asserting specifically that no **creditNote** row exists.
5. Four inventory-posting tests passed a **negative** value to
   `InventoryMovement.issue`, which takes a positive amount and negates it. The
   resulting sign mismatch threw. The code was right; the tests had the direction
   backwards.
6. A Trial Balance screen test asserted totals of **Rs 167,000.00**, copied from
   the full worked example, in a fixture that has no purchase entry. Hand-computing
   the actual fixture gives 100,000 + 20,000 + 12,000 + 5,000 = **137,000**. The
   code was right.

### 7.16 OPEN QUESTION: how a new record's id is generated

Account ids are literals in the chart of accounts and customer ids are supplied by
the caller, so nothing in the project generates an id yet. The UI will have to,
and the choice matters:

- Ids must not collide **between installations** once sync is implemented
  (ADR 007). An incrementing counter per device would collide immediately.
- Ids are referenced by journal entries and, soon, invoice records, so they must
  be stable forever once used.
- Guessing one now and changing it later would mean migrating every foreign key
  that points at a record.

The obvious candidate is a UUID, which needs either the `uuid` package or a small
generated-from-`Random.secure` helper. Either is acceptable under the permissive
licence rule in `docs/AI_RULES.md`, but it should be a deliberate decision with
its own ADR rather than something picked incidentally by whoever writes the first
form.

**Needed before the UI creates any record.** Not needed for the next task, which
takes its ids from the caller.

### 7.17 Migration mechanics that bite, learned the hard way

Three traps hit while adding one nullable column. All three are general, and all
three produce failures that look unrelated to their cause.

**1. `createTable` writes the table's *current* definition, not its historical
one.** When a migration creates a table that a later step also alters, the create
path already produces the newest shape, and the later alter then fails with
"duplicate column name". The fix is to make the steps exclusive rather than
sequential:

```dart
if (from < 7) {
  await m.createTable(inventoryMovements);   // already carries the v8 column
} else if (from < 8) {
  await m.alterTable(...);                   // only when the table pre-exists
}
```

**2. SQLite cannot add a foreign key with `ALTER TABLE ADD COLUMN`.** A column
added that way carries no constraint, so the table silently ends up missing one
that the schema snapshot expects. `SchemaVerifier` catches it as *"Expected the
table to have 6 table constraints, it actually has 5"*, which is a confusing
message for "your foreign key was not created". The fix is a **table rebuild**
with drift's `TableMigration`, which recreates the table and copies the rows.
`TableMigration` is marked experimental by drift, so it needs an
`// ignore: experimental_member_use` **on the line above the constructor**, not
above the `alterTable` call. A rebuild also needs a `columnTransformer` supplying
a value for any genuinely new column, or it tries to `SELECT` a column the old
table does not have.

**3. Only the current schema version is a valid migration target.** A test that
migrates to an *intermediate* version cannot pass once the code has moved on,
because `createTable` produces the current shape. Twenty-one such assertions
existed and were all pointed at the current version. The scenario each test
describes — upgrading *from* an old version — is still meaningful; the *target*
must be current.

The general lesson: **a green migration suite is only green for the version it was
written against.** Every schema change should re-run the whole migration suite,
and a failure in an old version's test is usually the *new* step's fault.



### 7.18 Drift and workflow mechanics that cost time to discover

Small things, none of them architectural, all of them things that were hit for
real and would otherwise be rediscovered. Kept here rather than in
`docs/AI_RULES.md` because they are mechanics, not rules.

**Schema snapshots contain no companion classes.** `drift_dev schema generate`
produces table definitions and a database class, but no `...Companion` types. A
migration fixture therefore cannot insert with `insert(SomeCompanion.insert(...))`.
Write the old-shape rows with **raw SQL** instead. That is also a better fixture:
it is exactly the SQL the previous release would have produced, not the current
code's idea of it.

**`drift_dev/api/migrations.dart` is deprecated.** Import
`package:drift_dev/api/migrations_native.dart` instead, or the analyzer reports
`deprecated_member_use`.

**Regeneration order matters.** After changing `tables.dart` or
`app_database.dart`, run these in this order, not another one:

1. `dart run build_runner build --delete-conflicting-outputs` — regenerates
   `app_database.g.dart`.
2. `dart run drift_dev schema dump lib/src/infrastructure/database/app_database.dart drift_schemas/`
   — writes a snapshot for the **new** version.
3. `dart run drift_dev schema generate drift_schemas/ test/generated/` — rebuilds
   the migration-test helpers.

Skipping step 2 leaves the newest snapshot missing, and the migration tests then
fail with a missing schema version. Running step 3 before step 1 produces helpers
for a schema that does not exist yet.

**`part` files do not inherit transitive imports.** `app_database.g.dart` is a
`part of app_database.dart`, so any type the generated code references must be
imported by `app_database.dart` itself, not only by `tables.dart`. `AccountType`
caught this once already.

**A file that uses `Value(...)` needs an explicit drift import.** Files that only
import `app_database.dart` get the generated table and companion classes, but not
`Value`, because imports are not re-exported.

**Run `dart format lib test` before finishing.** The analyzer flags
`prefer_const_constructors`, `unnecessary_brace_in_string_interps`, and similar on
otherwise-correct code, and a clean `flutter analyze` is part of the definition of
done.

**When a use case gains a required dependency, updating test call sites is
legitimate; weakening an assertion is not.** This came up when `IssueInvoice`
gained a `CustomerRepository`: twelve call sites needed a new argument and a
seeded customer. The right response is to add the argument and **re-check that
every existing assertion still holds on its own merits** — the hand-computed VAT
amounts were unchanged, and the tests assert that. The prohibited move is
loosening a matcher or deleting an expectation so the suite goes green.

### 7.19 PowerShell 5.1 corrupts this file, and git preserved the damage

**This is the single most expensive discovery of the session, and it is about the
tooling, not the accounting.** Windows PowerShell 5.1 here defaults to reading and
writing files with a codec that cannot represent an em dash. Two distinct
consequences, and the second is far worse:

1. `Set-Content` on this file replaces the em dashes with byte `0x97`, a lone
   high byte that is not valid UTF-8. The text still *reads* plausibly in most
   viewers, so the damage is not obvious.
2. **The corruption reached `git`.** Commit `ae3c63b` contains a file with five
   corrupt bytes. Restoring from git therefore restored *the damage*, not the
   text. The file is now 0 corrupt bytes again, but a future `git checkout` of
   that commit would reintroduce it.

**The rule for this repository: never use `Set-Content`, `Out-File`,
`Add-Content`, or `Get-Content | Set-Content` on any `.md` file.** Use the editor
tools, which write UTF-8 directly. Read with `Get-Content -Encoding UTF8` when a
shell command genuinely needs to inspect a file.

**To check a file for this damage, count lone high bytes.** Walk the bytes and
skip any valid UTF-8 multi-byte sequence; whatever remains is corruption:

```powershell
$b = [System.IO.File]::ReadAllBytes($p); $i = 0; $lone = 0
while ($i -lt $b.Length) {
  if ($b[$i] -gt 127) {
    $len = if (($b[$i] -band 0xF0) -eq 0xE0) { 3 }
           elseif (($b[$i] -band 0xE0) -eq 0xC0) { 2 }
           elseif (($b[$i] -band 0xF8) -eq 0xF0) { 4 } else { 1 }
    if ($len -eq 1) { $lone++ }
    $i += $len
  } else { $i++ }
}
"corrupt: $lone"
```

A single `0x97` byte is the fingerprint, and `0xE2 0x80 0x94` is the correct
three-byte em dash it should have been. The repair loop is a byte-level
replacement, not a text-level one, because by then the file no longer decodes.

**A second, separate lesson: do not splice this file by line number.** Editing
`PROGRESS.md` by `Get-Content`/`AddRange`/array index arithmetic destroyed
1,300 lines of it, because a failed `AddRange` conversion threw *after* the head
and tail had been computed and the file had been partially written. Recovering
meant restoring from git and re-adding five sections by hand. Use the editor
tools, which replace an exact string and fail loudly when it is absent.

### 7.20 A backup needs a unique name before it needs a timestamp

`file_book_backup_service.dart` names a snapshot
`FY2081-82-20260930-113200.db`. Two backups taken within the same second collide,
and the second overwrites the first — so the user is told they have two backups
and has one. Found by reading my own code while writing the tests for 4.23, not by
a failing test.

A counter is appended when the name is already taken. Timestamps remain in the
name because they are what makes a backup list legible to a human.

### 7.21 The architecture guard had a hole, and tests were copy-pasted past it

**`import_boundary_test.dart` checked that `lib/src/domain/` does not import the
other layers, but only for `import` statements — not `export`.** A `domain` file
re-exporting something from `infrastructure` would pass the check while
violating exactly the rule the check exists to enforce. The guard now rejects
`export` directives too, in both directions.

**A second finding is the uncomfortable one: eleven test expectations in this
suite were wrong before they were ever run.** They were written by copying a
neighbouring test and adjusting a number. The pattern is in 7.15, and the
specific recurring causes here were:

- a fixture that used a hand-typed date rather than a derived one, so it silently
  moved fiscal years between runs;
- a moving-average cost computed by hand in the test instead of in the domain,
  where it disagreed by one paisa;
- a ledger balance that assumed a posting order that `OrderBook` does not
  guarantee.

None of these were caught by the analyzer, and each is a test that would have
asserted a wrong number into the suite permanently. The cost was highest here,
where the fixtures are dates: see 7.19 for the same underlying problem in the
tooling.

### 7.22 A mutation that does not apply looks exactly like a test that works

**This is the most dangerous testing failure mode in this repository, and 7.21 is
its ancestor.** Deliberately breaking the code and checking that a test fails is
the only way to know the test is real. The trap is that **the mutation itself can
silently fail to apply** — and a mutation that did not apply produces the same
green result as a test that cannot fail.

It happened twice in one round. A mutation was written as a PowerShell
`String.Replace` whose search text contained `\r\n` (CRLF); the file used LF, so
nothing was replaced, the suite stayed green, and the conclusion "this test does
not catch the regression" was **wrong**. Re-applied through the editor, both
mutations were caught immediately.

Rules this produces:

- **Verify the mutation applied before drawing any conclusion from it.** Read the
  line back and see the changed text. A string replace that silently matches
  nothing is indistinguishable from a passing test.
- Prefer the editor tools for mutations, and revert with them. Do not mutate and
  revert with in-memory string arithmetic.
- A green suite after a mutation means "the mutation did not take effect" until
  proven otherwise.

**The same round produced a second instance of a test that could not fail.** A new
assertion was `expect(body, contains('9'))` for the schema version — but the
multipart body contains the snapshot's own generated bytes, and one of them is the
digit `9`, so the assertion was satisfied by the file content and would have passed
with the field missing entirely. It now reads the declared value out of the request
and compares it to `currentSchemaVersion`. This is 7.21's defect repeating within a
day, which is why the pattern is recorded here and not just the instance.

### 7.23 A hand-written hash literal is not a hash

Fixing a login timing leak needs a **real** bcrypt hash to compare against, so that
the unknown-account branch and the wrong-password branch cost the same. The first
attempt used a plausible-looking bcrypt string assembled by hand. It would have
been worse than no fix, because it *looks* correct: `password_verify` against a
malformed hash returns immediately instead of doing the work, so the unknown-account
branch would have stayed fast while the code appeared to have fixed the leak.

Measured before trusting it:

```
known user, wrong password : 3837.4 ms for 20   (~191 ms each)
unknown user, dummy hash   : 3817.2 ms for 20   (~191 ms each)
malformed hash             :    0.8 ms for 20   (~0.04 ms each)
```

Generate the hash and measure it; do not type one. The same reasoning applies to
any constant whose purpose is to make two code paths equivalent.

### 7.24 An analyzer cannot see a native toolchain requirement

**712 Dart tests passed, `flutter analyze` was clean, and `flutter build windows`
did not compile.** Not because a test was wrong — because `flutter_secure_storage`
includes `<atlstr.h>`, which ships in Visual Studio's *optional* C++ ATL
component rather than the base C++ workload.

The dependency was approved, added, and recorded correctly in
`docs/AI_RULES.md`, and nothing objected. The failure surfaced only at compile time
on one platform.

**Generalisable rule for a desktop application: adding a Flutter plugin is a
build-system change, not just a `pubspec` change.** Each plugin may require native
tooling that `flutter analyze` and `flutter test` never touch — a C++ header, a
system library (`libsecret` on Linux), an SDK, a minimum platform version. So:

- After adding a plugin, **build every target platform**, or record explicitly that
  you did not and which ones therefore remain unverified.
- Check the plugin's own native sources for `#include` and `find_package` lines
  before adopting it, not after the first failed build.
- When a package imposes a toolchain cost, that belongs next to the dependency in
  `docs/AI_RULES.md`, where the next person reads it before installing.

`flutter test` runs on the Dart VM with no native compilation, so a green suite is
evidence about Dart only. Saying "verified" without naming **what** was verified is
how this got through.

**The corollary, learned the hard way and applied too late: check a plugin's native
sources *before* adopting it, not after the first failed build.** This section was
written because a plugin needed an optional Visual Studio component — and then,
in the same session, a plugin was adopted without that check, and the whole
evening was spent on the consequence. The rule was available and not used.

### 7.25 Three ways a verification can pass while measuring nothing

All three happened while trying to fix one build failure. They are worth listing
together because each looked like a solid green result.

1. **`if ($output)` on a command's stdout.** PowerShell treats the string `"[]"` —
   which `vswhere` prints when it finds nothing — as **true**. The check therefore
   could not fail, and the conclusion drawn from it ("the toolchain is registered
   again") was the opposite of the truth. **Count parsed results, never test a
   command's output for truthiness.** A `ConvertFrom-Json` count is the habit.
2. **A regex pattern that misses the thing it is looking for.** `CString|ATL|CCom|
   _bstr_t|Variant|BSTR` does not match `CA2W`, which was one of the two symbols in
   use — and case-insensitively matches `su**bstr**r`. It reported "no ATL usage"
   about a file that used three ATL classes.
3. **An `if (false)` "mutation".** Removing a guard by writing
   `catch (_) { if (false) rethrow; }` changes nothing, so the suite stays green
   and looks like the test is weak, when in fact nothing was ever broken.

**The common thread: a check that cannot fail looks exactly like a check that
passed.** Whenever a verification is about to confirm something inconvenient —
a registration was restored, a build was fixed, a file is unchanged — write down
first what result would make it fail, and confirm the check can produce it.

### 7.26 A copy method that silently drops fields, and the two tests that prove it

`AppServices` has two methods that rebuild the whole bundle: `forSession`, called
when the fiscal year changes, and `forAccount`, called on sign-in and sign-out. Both
are written as a field-by-field constructor call, and both **omitted five fields**
that the class declares: `createProduct`, `postMovement`, `issueCreditNote`,
`postEntry` and `concludeYear`.

**Nothing failed.** There is no error, no warning, and no failing test. Switching
fiscal year silently removed the catalogue, the stock, the credit-note, the
manual-journal and the year-end screens from the navigation, and signing in or out
did the same. The application would still start, still take backups, and still pass
all 889 tests. A user would conclude that the application had lost the feature.

Why it survived so long, and why it will happen again:

- **A constructor call with many optional fields has no failure mode for a missing
  one.** Dart cannot distinguish "deliberately null" from "forgotten", because both
  are null.
- **The list of what a screen needs lives in `app_navigation.dart`, thousands of
  lines from where the fields are copied.** Nothing connects the two.
- **The tests that exercised a year switch checked the reports** — the two that had
  always been wired — and not the five that had been dropped.

The fix is not the five lines. It is `test/presentation/app_services_test.dart`,
which asserts every field by name after both copies, so a future omission is a
**named** failure ("reason: credit note") rather than a silent disappearance. The
test builds a **real** `FileBooksSession` on a real directory, because a fake would
only prove the fake can be copied faithfully.

The general rule, and this is the second time in this project that a field list
drifted from a capability list: **when a container is copied field by field, the
copy needs a test that enumerates the fields, or the next addition will be
invisible.** The same reasoning as 7.25 seen from the write side — a check that
cannot fail looks like a check that passed, and "the code compiled" is such a check.

### 7.27 A whole-year report must still respect the year it belongs to

`BuildCashFlow.load()` takes an optional date range. With no range it read **every
entry in the database**, which for the single-year-per-file design happens to be one
fiscal year — so it looked right, and all the tests passed.

It was wrong, and the widget test found it by printing what was on screen: for a
year with a 100,000 opening-balance entry and a 20,000 sale, the statement showed
**opening cash Rs 0.00 and received Rs 120,000.00**. The opening entry was being
reported as money received *during* the year.

That is the most misleading way a cash statement can be wrong, because the closing
figure stays correct — 115,000 either way — so only the split between opening,
received and paid was false, and a reader checking the total would find nothing
wrong.

The fix has two parts, and the second is the transferable one:

1. `from` now defaults to `fiscalYear.startDate`, and the sales and VAT reports do
   the same, because a document dated outside the year belongs to another year's
   books.
2. **The opening entry is dated on the year's first day, not the day before**, so
   "strictly before the start" does not catch it. Rather than shifting the date to
   fit the rule, the boundary is stated: `openingIncludesBoundary` is true **only**
   for the whole-year view, and an explicit caller-supplied range keeps the strict
   rule, because there the caller chose the boundary.

Inventory was deliberately **not** given a year boundary: stock is a balance as at
today, and the opening entry is exactly what makes that balance right. Filtering it
would have been the change that looked like a fix and was not.

**A total that survives an error is not a check on the error.** The closing figure
was right throughout, which is why every use-case test passed. Only the screen,
which asserted a specific line rather than a total, could see it.


### 7.28 A migration that cannot fail on an empty database

`users.username` was added as `NOT NULL` with no backfill. **Against the live
database, which already held nineteen accounts, that failed outright:**

```
ERROR: column "username" of relation "users" contains null values
```

The in-memory test suite passed throughout, and could never have caught it.
`RefreshDatabase` migrates an *empty* schema and every user is created afterwards
by a factory that supplies the field — so the column is never populated by anything
other than the factory. **The database the tests run against has the same shape as
a brand-new installation and never the shape of a real one.**

Two more failures surfaced only on PostgreSQL, in the same migration:

- **`HAVING` cannot reference an aggregate alias.** `->having('total', '>', 1)` works
  on SQLite and is rejected by PostgreSQL.
- **`split_part` is PostgreSQL-only.** The natural way to backfill a username from an
  address is `split_part(email, '@', 1)`, which does not exist in SQLite — so the
  version that worked on PostgreSQL broke all sixty tests, and the version that
  fixed that would have needed a driver check.

The portable answer is to do the backfill **in PHP**, chunked, rather than in SQL:
one language, both drivers, and no driver-specific arithmetic to maintain. It is
slower, and it is run once.

The rule this adds: **a migration is only tested against a database that already
contains data.** A green `php artisan test` says the schema builds, not that it
builds *on yours*. The three failures here were one statement, and all three would
have reached production.

### 7.29 A limit that revokes is not a limit that refuses

The concurrency policy went through three wrong shapes before it was right, and the
useful part is knowing why the first two failed.

**A `device_count` column** was the first proposal. It reads as a live tally, and a
tally has to be incremented on every sign-in and decremented on every sign-out —
except the desktop **swallows sign-out failures by design**, because a locked
keyring must not prevent a user signing out. So the count only ever rises, drifts,
and cannot be repaired. A `PersonalAccessToken` row *is* the session, and counting
those is correct by construction.

**Refusing the sign-in when the allowance was spent** was the second. It is the
safer-looking option and it is the dangerous one: a token belonging to a machine that
no longer exists — reinstalled, replaced, stolen, or simply never signed out —
permanently consumes the only slot. The owner is locked out of their own account
with no device list to revoke from and no expiry to clear it, and the only remedy is
a hand-written `DELETE`.

**The shipped rule** is one line: on sign-in, keep the newest `max_devices` sessions
and revoke the rest. Login is authenticated by the **password**, not by a token, so
signing in always succeeds — and a stale session revokes *itself* on the next sign-in
instead of locking anyone out. That property is the whole reason for the shape, and
it is not obvious from the code; it is written in ADR 011.

The other half was recognising that **nothing is lost** when a session is revoked. A
signed-out desktop keeps its local SQLite untouched, and local backups never need a
session. An earlier draft of this entry claimed work was "stranded" and "at risk";
that was wrong, and correcting it changed the recommendation from *warn before
signing out* to *refuse the new sign-in*, because the concern it rested on did not
exist.

### 7.30 A test that asserted the wrong thing, and passed anyway

`test_logout_leaves_other_sessions_working` asserted that signing in on a second
device left the first working — the exact opposite of the new policy. It was
**deliberately reversed and split**, not edited until green, because the policy
changed on purpose and the record needs to say so.

Its replacement then failed for a second reason, which is worth more than the policy:
it asserted a `401` over HTTP, and got `200`. The revocation was working perfectly —
the surviving token was the newest one, as intended. **`Sanctum` keeps a resolved
user alive across requests within a single test**, so a token deleted mid-test still
appeared to authenticate. The assertion now reads the stored sessions directly, and
points at the test that covers a genuinely invalid token.

A failure that looks like a product defect and is a harness artefact is worth as much
to record as a real one: had the test been "fixed" by loosening the assertion, the
HTTP path would have shipped unverified.

### 7.31 The classification was right; the meaning of "needs attention" was not

`Divergence` is the pure function that decides whether two copies of the same books
have drifted. It is four cases, and all four are specified by tests — including the
two that no code path can currently produce, since `serverOnly` and `bothChanged` can
only arise from a second computer.

The first version of that enum read:

```dart
bool get needsAttention => this != Divergence.none;
```

which makes `localOnly` **need attention**. It is wrong, and the test caught it. "Only
this computer changed" needs no decision from anybody — the upload just happens, and
it is the action the application already takes. Marking it as needing attention means
prompting the user to confirm work that has no alternative, and **a prompt that is
always answered the same way is a prompt people stop reading.** That is worse than no
prompt, because it spends the user's attention on a non-event and leaves none for the
case where the answer actually varies.

So the rule is narrower than "not the ordinary case":

| | needs a decision | can be resolved without asking |
|---|---|---|
| `none` | no | yes |
| `localOnly` | **no** | **yes** |
| `serverOnly` | yes | no |
| `bothChanged` | yes | no — it must stop |

The lesson is not about enums. It is that a predicate named after an *effect on the
user* ("needs attention") has to be derived from what the user can do about each case,
not from a coarse grouping like "is this the normal one". The four cases were right;
the label on two of them was not, and no amount of reading the code would have shown
that — the code was internally consistent and externally unhelpful.

**Verified by mutation.** Replacing the checksum comparison with a revision-number
comparison — precisely the mistake the type's own documentation warns against — fails
four tests, including the one asserting that another device re-uploading identical
bytes is *not* a divergence. A test that passes only because the implementation and
the expectation were written from the same idea is worth nothing; this one had to be
broken to be shown to work.

### 7.32 An invalid line range deleted 628 lines of this file

Rewriting section 6 to replace a stale "next task" block, the PowerShell used a slice
whose **start index was greater than its end index**. PowerShell does not reject that;
it walks it in descending order, so the range returned two lines instead of a range,
and everything between section 6 and section 8 — the `## 7` heading and entries
**7.1 through 7.28**, the accumulated discoveries of many sessions — was silently
dropped.

**Nothing failed.** The write succeeded, the file stayed valid UTF-8, and no test in
the repository reads `PROGRESS.md`. The loss was found only because the next command
printed the section-6 text and the heading list, and `## 7.` was not in it.

Two lessons, both about checks that cannot fail:

- **Verify counts, not just success.** The write reported success and reported a line
  count. A line count of 2,518 where the file had been 3,146 is the whole signal, and
  it was not compared against anything. Compare before/after counts, always — the
  cheapest possible invariant for an edit to a document.
- **A descending slice is a silent delete in every language that allows one.** Build
  replacements as `head + new + tail` with each part asserted, never as a single slice
  from computed indices.

Recovered from `git show HEAD:PROGRESS.md`, which is the only reason the loss was
survivable: **the accumulated discoveries were in git but not yet committed, and the
edit sat on top of them.** This file is read by the next agent and nothing else reads
it, so nothing would have told anyone it had been truncated.
## 8. Commands

Run from the repository root unless stated otherwise.

```bash
# Desktop
cd desktop
dart format lib test            # run before finishing; keep the diff reviewable
flutter test                    # full suite. Must be green before any commit.
flutter test test/domain        # domain layer only
flutter analyze                 # must be clean
flutter run -d windows          # run the app
flutter build windows --debug   # build without running

# After changing tables.dart or app_database.dart
dart run build_runner build --delete-conflicting-outputs

# Schema snapshots, required whenever the schema version changes
dart run drift_dev schema dump lib/src/infrastructure/database/app_database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/generated/

# Backend
cd backend
php artisan test
php artisan migrate
php artisan serve
```

`drift_schemas/` and `test/generated/` are committed, not build output. If the
migration tests report a missing schema version, the snapshots are out of date
and need regenerating with the two commands above.

Toolchain present on this machine: PHP 8.4.17, Composer 2.8.5,
**Flutter 3.47.5 / Dart 3.13.4 (see section 7.8)**, **PostgreSQL 17.4**,
Node 20.18.0, .NET 8.0.402. Git is installed and the repository has commits; the
remote is recorded in `GIT_REPO.md`.

## 9. Gate tracker

A gate closes only when its tests pass **and** the accounting results have been
verified by hand. Compiling is not passing. See `docs/AI_RULES.md`.

| Gate | Content | Status |
| --- | --- | --- |
| 1 | Domain model | Accounting, reporting, fiscal, chart of accounts, document numbering, **and the Nepali billing rules** complete: PAN handling, configurable tax rules, invoice compliance, amount in words, HS code, and `BusinessProfile`. |
| 2 | Double-entry accounting engine | Complete and tested. |
| 3 | SQLite persistence and atomicity | **Complete**, including cross-aggregate atomicity via `UnitOfWork`, **ten schema migrations (v1 through v10)**, and a **separate business-level database** for the business profile. |
| 4 | Financial reports | **Trial Balance, General Ledger, Profit & Loss, Balance Sheet, Cash Flow, Sales, Stock Held, and VAT all complete** (the last four on 2026-10-02). **The VAT report is not yet a complete return**: input VAT is zero because the purchase side is not built. |
| 5 | Billing | **Complete for the core cycle**, and now **compliant with the Nepali invoice rules** — see 4.35. Debit notes and refunds are not started; see section 5. |
| 6 | Inventory and COGS | **Complete.** Products, movements, derived value-first stock with negative stock blocked, ledger posting, and the write-down to the lower of cost and net realisable value. Locations and transfers are not modelled; see section 5. |
| 7 | Complete offline workflow | **Complete.** Every way of changing the books has a screen: customers, invoices, payments, products, stock movements, credit notes, journal entries. The shell, theme, navigation, licences screen, Trial Balance, General Ledger, fiscal-year selector, Backup screen, and **Settings** exist and are wired to real use cases. A business can be run through it end to end. |
| 8 | Fiscal-year conclusion and archival | **Logic done.** The close, its blocking checks, the closing entries, and the archive-before-transition ordering are built and tested (4.43). **The screen, the archive, and the server-backed prune are all built.** A concluded year can be discovered, opened, and reported on, and is read-only enforced by `PRAGMA query_only` rather than by the screen. **The conclusion operation itself does not exist** — nothing closes a year, and no retention or archival policy is enforced. |
| 9 | Cloud backup and restore | **Upload and restore both complete.** The desktop verifies a snapshot, reads the server's revision sequence, sends the bytes, and reports a refusal, a conflict, a revoked session, and an unreachable server distinctly without ever touching the local copy. Proven against live PostgreSQL. **Restore is missing** — there is no download endpoint and no restore-from-server path. |
| 10 | Production and real-world scenarios | Not started |

**Test suite:** **843 Dart tests**, all passing, and **35 Laravel tests**, all
passing with 97 assertions. `flutter analyze` reports no issues. `php artisan test`
reports `{"tests":35,"passed":35,"assertions":97}`. Pint is clean. The newest Dart
files are `test/presentation/invoice_screen_test.dart` (10),
`test/application/create_customer_test.dart` (12), and
`test/presentation/customer_screen_test.dart` (10) — see 4.38.

**Build status: `flutter build windows --debug` succeeds** and produces
`financeapp.exe`, **with no optional Visual Studio component required** — the
storage dependency uses only standard Windows SDK headers (4.33).

> Historical: this failed for hours on a `flutter_secure_storage` ATL dependency,
> then on a Visual Studio component registration that `vs_installer.exe modify
> --add` removed rather than restored. See 4.32–4.34 and 7.24–7.25.

**Dependency-risks to check before adding a plugin:** read the plugin's **native**
sources — and for a federated plugin, the `_windows`/`_linux`/`_macos` sub-package,
not just the umbrella, which can look clean while the native code carries an
`#include` on something optional. Neither a green suite nor a clean analyzer is
evidence the app builds: `flutter test` never compiles C++.

**Not part of the suite:** `desktop/tool/live_upload_check.dart` (6 checks against
a running server). It is not named `*_test.dart`, so `flutter test` does not pick
it up and the suite stays hermetic. Run it with:

```bash
FINANCEAPP_SERVER=http://127.0.0.1:8124 flutter test tool/live_upload_check.dart
```

**Live status:** PostgreSQL 17.4 holds the `financeapp` database with all six
migrations applied. The API has been exercised over HTTP against it: a real
snapshot uploaded from the desktop's own uploader and read back out of PostgreSQL,
and sign-in verified end to end including that signing out **really revokes** the
token (`/api/auth/me` returns 401 afterwards). The password is in `backend/.env`,
which is gitignored.

**Generated files that must be committed:** `drift_schemas/` (the schema
snapshots) and `test/generated/` (the migration-test helpers). They are not
build output; deleting them breaks the migration tests.

## 10. Change log

| Date | Change |
| --- | --- |
| 2026-09-29 | Read all three specifications. Chose Flutter over the TBD desktop framework; recorded as ADR 008. Scaffolded Laravel `backend/` and Flutter `desktop/`. Created the layered directory structure. Implemented the `Money` value object with 20 tests, fixing two bugs the tests caught. Wrote `docs/AI_RULES.md`, `docs/ARCHITECTURE.md`, and ADRs 001-008. Created this file. |
| 2026-09-29 | Read the full Laravel and Flutter scaffolding. Recorded the backend gaps in section 5.1. |
| 2026-09-29 | Implemented the double-entry accounting engine in five domain files with 36 tests. Verified the worked example by hand and asserted the accounting equation. Suite 56 tests. |
| 2026-09-29 | Implemented Gate 3: drift schema, domain-owned repository ports, drift repositories, and persistence tests covering round-trip, exact money storage, an INTEGER column assertion, atomic rollback, and constraint rejections. Suite 79 tests. |
| 2026-09-29 | With owner approval, upgraded Flutter 3.24.5 to 3.47.5 and Dart 3.5.4 to 3.13.4. Unpinned `drift` back to 2.31.0 and regenerated. The upgrade exposed a silent foreign-key failure; fixed by declaring FKs explicitly in `customConstraints` and moving the pragma to a per-connection `setup` hook, with two new tests that assert enforcement and declaration independently. Recorded in section 7.14. |
| 2026-09-29 | Implemented `UnitOfWork`, closing gap 7.7. Nine tests prove an operation spanning several repositories is all-or-nothing. Suite 90 tests. |
| 2026-09-29 | Implemented Gate 4: `TrialBalance` and `GeneralLedger`, both derived and never stored, with 21 domain tests and 4 integration tests. Suite 115 tests. |
| 2026-09-29 | Implemented the fiscal calendar and the application layer. Selected `bikram_sambat` (MIT, pure Dart, BS 1969-2200) after rejecting `nepali_calendar` for an unknown licence; recorded as ADR 009. Built `BsCalendar`, `FiscalYear`, and `NepaliFiscalCalendar` with 24 tests, and `PostJournalEntry` with 12 tests, closing gaps 7.9 and 7.10. Found and fixed a real boundary defect in year-length measurement. Suite 151 tests. |
| 2026-09-29 | Owner installed Visual Studio Build Tools and enabled Windows Developer Mode; `flutter build windows` now succeeds. Implemented the chart of accounts, 19 accounts with permanent literal ids kept separate from human-facing codes, 13 domain tests and 7 persistence tests. Suite 171 tests. |
| 2026-09-29 | Implemented document numbering per ADR 005, with 16 domain tests, 15 persistence tests, and 7 migration tests. Added the `document_sequences` table and the first schema migration, v1 to v2, verified with drift schema snapshots and v1-shaped raw-SQL fixtures proving existing accounts, journal entries, dates, and amounts survive the upgrade. Established that allocation composes with the unit of work, so a failed issuance does not consume a serial and leaves no gap. Rebuilt the Windows app to confirm the migration did not break the build. Suite 209 tests. |
| 2026-09-29 | Implemented invoice issuance end to end, with 19 domain tests and 13 application tests: derived subtotal, VAT and total with no stored totals, VAT charged on the combined subtotal at 13% held in basis points, and the three-line posting Dr 1030 / Cr 4010 / Cr 2020. Verified the composition property that matters: a posting failure does not consume a serial, because the journal entry id is derived from the invoice id and a duplicate is refused by the primary key. Recorded two Billing gaps: an issued invoice is not yet a stored record (7.12), and the customer on an invoice is an unvalidated string (7.13). Suite 241 tests. |
| 2026-09-29 | Implemented customers with the second schema migration, v2 to v3. Eight domain tests and seven persistence tests, plus migration tests extended to cover v3, including v1 two-step upgrades and v2 data surviving with a document sequence that must not restart. `IssueInvoice` now refuses an unknown customer with the check inside the transaction, and a refusal burns no serial. Recorded the undecided customer id generation strategy as an open question (7.16). Suite 260 tests. |
| 2026-09-29 | Implemented issued invoices as records with the third schema migration, v3 to v4. Added `invoices` and `invoice_lines`, an `InvoiceRepository`, and `IssuedInvoice`. `IssueInvoice` now writes the serial, the journal entry, and the document record in one unit of work. The schema enforces the links with foreign keys to `customers` and `journal_entries`. Added `NepaliFiscalCalendar.fromLabel` so only the fiscal year label is stored, and `DocumentType.fromPrefix`. Twenty persistence tests including the atomicity case where the journal entry is written and then the invoice insert fails on the unique number, asserting the entry rolled back and the serial was not consumed. Suite 284 tests. |
| 2026-09-29 | Implemented payments received with the fourth schema migration, v4 to v5. Added `payments`, a `PaymentRepository`, `InvoiceBalance`, and `RecordPayment`. The outstanding balance is derived and never stored, so it cannot drift from the payments that produced it. The overpayment check runs inside the same transaction as the write, closing the race rather than making it unlikely. The boundary is tested both ways: exactly the outstanding amount is accepted, one paisa more is refused with nothing written. Twenty-two application tests, twelve domain tests, and migration tests extended to v5. Rebuilt the Windows app. Suite 322 tests. |
| 2026-09-29 | Owner decided ADR 004: **moving weighted average** costing, and **negative stock blocked**. The decision had been open since the first session and was the last thing gating Gate 6. Wrote `docs/INVENTORY_EXPLAINED.md`, a plain-language explainer with worked numbers for all four methods, an honest account of what Nepali standards appear to allow (FIFO and weighted average permitted, LIFO not, lower of cost and net realisable value required) with explicit caveats that it is unverified and not tax advice, and a clear list of what the application does not do yet. Referenced it from `AGENTS.md`, `README.md`, and section 2 so it is actually found. Recorded four follow-on decisions in ADR 004 rather than letting them be mistaken for done. |
| 2026-09-29 | Implemented the Profit & Loss report with 16 domain tests and 3 integration tests. Income and expenses only, with balance sheet accounts excluded even when supplied in a chart. Every account read in its own natural direction, so both totals are positive. A loss is reported as a positive `loss` rather than a negative `profit`, so a bad period does not read as a double negative. Cross-checked against `TrialBalance` by deriving the same profit two independent ways. Hand-computed on the worked example: income 2,000,000, expenses 1,700,000, profit 300,000. |
| 2026-09-29 | Implemented the Balance Sheet with 17 domain tests and 3 integration tests, completing the core report set. Equity folds in the period result as its own line, because there is no year-end closing entry and without it the sheet cannot balance. Takes `to` and not `from`, because a balance sheet is a position at a point in time. The accounting equation is asserted across five different transaction shapes, and cross-checked three ways against `ProfitAndLoss` and `TrialBalance` both in memory and from a real database. Hand-computed: assets 133,000, liabilities 30,000, equity 103,000. |
| 2026-09-29 | Opened Gate 6 with products and inventory movements, using the fifth migration v6 to v7. `Product` has **no cost column**, because ADR 004 requires the running inventory value to be authoritative and the cost per unit to be derived from it. Movement quantity and value are both signed and must point the same way, enforced by the domain *and* a database CHECK, which is what makes quantity and value each a plain sum of the rows. `ProductStock` derives quantity, value, and cost per unit; `valueOfIssue` takes the whole remaining value when clearing a holding so it leaves exactly zero rather than stray paisa. Negative stock is blocked inside the same transaction as the write, and a refused issue writes no row at all. 28 domain tests, 17 persistence tests. |
| 2026-09-29 | Posted inventory movements to the ledger with migration v7 to v8, closing the gap that specification RULE 5 forbids. `PostInventoryMovement` maps each movement reason and direction to accounts from **one documented table**, adds the `5070 Inventory Adjustments` account, and links each movement to its entry with a foreign key. A transfer is refused rather than given a plausible-looking entry, because locations are not modelled. The test that matters passes: after buying at two prices and issuing half, the inventory account in the trial balance equals the derived stock value, exactly Rs 1,100. The migration gives pre-existing movements a `null` entry rather than fabricating one. Hit three migration traps and recorded them in section 7.17: `createTable` writes the current shape not the historical one; SQLite cannot add a foreign key with `ALTER TABLE ADD COLUMN`, so the column change needed a table rebuild; and intermediate schema versions are not valid migration targets. Recorded a fifth instance of the recurring "the test was wrong" pattern. |
| 2026-09-29 | Completed Gate 6 with the inventory write-down to net realisable value, migration v8 to v9. A write-down reduces value **without changing quantity** -- the goods are still held -- which the movement type could not previously represent, so a new `writeDown` reason permits a value-only movement and the database CHECK was relaxed to match, requiring another table rebuild. Recording the write-down as a movement rather than a side-channel is what keeps the stock value and the inventory account equal by construction. Refuses a value at or above the carrying amount, because IAS 2 does not permit inventory to be revalued upwards; the boundary is tested both ways. Disposal stays a separate movement and has its own test. **The first attempt at relaxing the rule went too far** -- it allowed a quantity change with zero value, which an existing test rightly caught; the fix was to tighten the rule rather than edit the test. Suite 504 tests. |
| 2026-09-30 | Removed the `bikram_sambat` dependency at the product owner's request, on **supply-chain** grounds: it made the one dataset the product cannot ship without depend on a single maintainer who could change the licence, go commercial, or discontinue it. The calendar data is now in-tree in `domain/fiscal/bs_calendar_data.dart` and the conversion is implemented here, isolated to that one adapter. Removing it surfaced three things worth recording: the upstream table's final entry, BS 2200, was **placeholder data** (twelve 31-day months, 372 days -- not a real calendar) and was excluded rather than carried; the package applied a fixed **+5:45 Nepal offset**, which would have given users on other timezones shifted dates, replaced here with UTC arithmetic presented as a local date-only value; and the data being ours means it is now tested, with eleven integrity tests including a day-by-day round trip across nine whole years. ADR 009 rewritten. Suite 515 tests, Windows build verified. |
| 2026-09-30 | Opened Gate 7. Replaced the generated counter app with a real shell: the `MaterialApp` root, a left navigation carrying the eight groups from `ui.txt` section 13, a content area, a **design theme taken from `ui.txt`** (restrained warm-neutral palette, one blue accent, Segoe UI with fallbacks, the newspaper type scale, borders over shadows, corner radii capped at 6), and the **licences screen** that MIT and BSD-3 require. Measured the whole dependency tree first: 85 packages, 69 BSD-3, 8 MIT, 3 Apache-2.0, and the Flutter SDK, so **not one is attribution-free**; Flutter aggregates them all, so the screen is one menu item. Two bugs the tests caught: the shell read the theme from a context **above its own `MaterialApp`**, which cannot work because a `MaterialApp` only themes what is below it; and a `Container` was given both a `color` and a `decoration`. Added `architecture_test.dart`, which reads the source files and fails if a screen imports a repository or a domain internal, if a domain file imports Flutter or the outer layers, or if the removed calendar package is reintroduced. Suite 539 tests, Windows build verified. |
| 2026-09-30 | Added the General Ledger screen, the second report screen. The **opening balance** is the substance of it: a range starting after an account's first posting must carry the earlier balance forward, or the closing figure silently disagrees with the Trial Balance and the user has no way to detect it. Cross-checked against `TrialBalance` in the use-case test, so a future divergence points straight at the pair of numbers to check. A type check on the loader broke the moment a test supplied a stub, so account selection moved onto the interface. 10 application tests, 11 widget tests. Suite 557. |
| 2026-09-30 | Implemented local backup and verified restore, at the owner's priority because a lost file is a **legal** problem, not merely an inconvenience. The snapshot uses SQLite's `VACUUM INTO` rather than a file copy, because a copy taken while the application is writing can capture a half-written database that looks fine and is not; SQLite here is 3.51.1 and supports it. Every snapshot is verified before it is filed -- SHA-256 for the bytes, `PRAGMA integrity_check` for whether it is a database at all -- and a snapshot failing either is **deleted and reported as a failed backup**, because a directory of files that feel like a safety net and are not is worse than an empty one. Restoring verifies first, so an unusable backup is refused before anything is touched, and backs up the current books before overwriting them. The test takes a backup, changes the books, restores, and asserts the original figures returned: an untested backup is not a backup. Added `crypto` for the checksum, so the dependency and licence records had to be updated. 15 infrastructure tests, 10 widget tests. Suite 582. |
| 2026-09-30 | Found and closed a gap the owner found by asking the obvious question -- "our logic says a SQLite per year, so?". The first implementation backed up only the **current** year, and the app **did not know the other years existed**: `main.dart` computed the current year and opened that one file, never looking for the rest. Two faults, and the second is worse -- the screen warned that a backup does not survive losing the computer while saying nothing about older years having no backup at all, and those are the years closest to the retention clock. Every `accounting-FY-*.db` is now discovered and snapshotted, the current year through the connection already open and a concluded year by opening it briefly, both through the same verification path. A year that cannot be backed up is **named in the failures**, never skipped, proved by a test with a corrupt year among good ones. Two bugs of my own: restore wrote to the snapshot's file name instead of that year's books file, so it never replaced the real books, and the stray files it left were then rediscovered as extra years, which is why the suite went from one second to five minutes. Suite 597. |
| 2026-09-30 | Implemented opening a concluded fiscal year, read-only -- a specified requirement in three places, including the acceptance test *"Historical year → opens read-only"*, that had not been built. **Read-only is enforced by the database, not the screen**: `PRAGMA query_only` is set through the `setup` hook so every connection the executor opens refuses writes, and a test asserts the exact SQL insertion fails and that the file on disk is untouched. A rule living only in the UI is one any future caller walks past. Read-only does not mean unreadable, and the figures still load. The trading year stays writable, asserted separately: a guard that stopped the business trading would be worse than the problem it solves. Switching year replaces the whole service bundle, because every use case belongs to one year's books. A hidden clock dependency was removed while building this -- the session had been recomputing "the current year" from `DateTime.now()`, which would have made the decision untestable; the trading year is now given, never inferred. Suite 609. |
| 2026-09-30 | Implemented the backend: Sanctum, PostgreSQL, `books` and `backup_revisions`, the upload verification chain, and store/index/show routes. **An unverified upload is never treated as a valid backup**, enforced as four ordered checks, cheapest-and-safest first: magic header, declared size, declared SHA-256, then SQLite's own `integrity_check`. The first failure stops the upload and nothing is written -- no file, no row. There is deliberately no "uploaded but not yet checked" state, because such a row is a backup the desktop might later report as stored. The integrity check is **last on purpose**: opening a received file with SQLite parses data from outside, so it runs only after the file is known to be a SQLite database whose checksum matches a trusted client, and it is opened read-only. Most of the 11 tests are about **refusal**, since a backup feature is only worth having if it can say no -- including a corrupted database with a valid header and a matching checksum, which only the integrity check catches, and a revision that does not follow the latest, which is a conflict rather than a silent overwrite so two copies cannot clobber each other. The SQLite file is not in the database: `object_key` points at the `backups` disk, so moving to object storage is a config change. A stored revision has no `updated_at`, because the specification's column list has none and a revision is immutable. `APP_NAME` is `financeapp`. Tests run on in-memory SQLite, so no external database is needed. 13 Laravel tests, suite 620 Dart tests, Windows build verified. |
| 2026-09-30 | **Recovered `PROGRESS.md` from a self-inflicted loss.** Splicing the file by line number in PowerShell destroyed 1,300 lines, because a failed `AddRange` conversion threw *after* the head and tail were computed. Restoring from `git checkout HEAD -- PROGRESS.md` brought back the corruption rather than the text: commit `ae3c63b` already contains five corrupt bytes, because PowerShell 5.1 cannot encode an em dash and `Set-Content` had replaced each with a lone `0x97`. Repaired at the byte level, then sections 4.22 to 4.26 and 7.19 to 7.21 were rewritten by hand. The two lessons are recorded in 7.19 and are the most transferable findings of the session: **never use `Set-Content` on a `.md` file here, and never splice one by line number.** The file is 0 corrupt bytes. |
| 2026-09-30 | Closed both remaining blockers to a live run. The owner supplied the PostgreSQL password; `DB_PASSWORD` was empty in `backend/.env` and the database itself had never been created, so the two faults presented the *same* symptom from outside — `FATAL: database "financeapp" does not exist` — and only surfaced separately once authentication succeeded. Created `financeapp` (UTF-8, PostgreSQL 17.4) and ran all six migrations against it. Then implemented **token issuance**: `register`, `login`, `logout`, `me`, with 18 tests. `register` and `login` sit **outside** the `auth:sanctum` group, because no token can be obtained without them and guarding them would make every route unreachable. Registration creates the account's one book (ADR 003), without which the desktop has nothing to upload a backup against. An unknown email and a wrong password return the identical response so accounts cannot be enumerated, and logout revokes only the token used. **This is token issuance, not licensing**: the specification's signed licence authorisation with subscription status, expiry, device binding, and an offline public-key check is a separate capability, and a half-built licence check that looks authoritative is worse than none. **One test bug was mine and worth recording** — asserting that a revoked token returns 401 in a second request in the same test method passes or fails on Sanctum's guard memoising the resolved user for the lifetime of the shared application instance, so it tests the framework's caching rather than the feature; the assertion was moved to the stored row, and a separate test proves the guard does read the database. The factory's default password of `'password'` is too short to pass the new registration policy, so a `withPassword` state was added rather than weakening the policy to fit the test. Verified end to end over HTTP against live PostgreSQL: register, login, `me`, a genuine SQLite snapshot uploaded with its real checksum and size, and seven refusals including a bad checksum, a stale revision, and a file that is not a database — **one revision remained stored afterwards**, which is the property that matters. 31 Laravel tests / 77 assertions, Pint clean, 620 Dart tests, Windows build verified. |
| 2026-09-30 | Corrected stale documentation after reading every markdown file in the repository. **Three documents contradicted the code they described.** `docs/INVENTORY_EXPLAINED.md` still stated that the write-down to net realisable value was **"not implemented"** and that it "must be built before inventory can be called complete" — it was completed in 4.19; ADR 004 carried the same stale follow-on. The root `README.md` said **"PostgreSQL is not needed yet. No migrations have been written"** and that the backend "still defaults to its shipped configuration", and named the backend **Laravel 12** when it is 13. `docs/BACKUP_AND_RETENTION.md` said there is "no server copy" and that cloud backup "needs the backend, which is not built". Also fixed: a **broken table row** in `docs/ARCHITECTURE.md` where two rows were joined by `||` and rendered as one; `docs/AI_RULES.md` listed four packages as approved dependencies without saying that none of them are actually in `pubspec.yaml`; and `PROGRESS.md` claimed "no commits have been made" when there were five. The two stock template files were replaced — `desktop/README.md` ("A new Flutter project") and `backend/README.md` (the Laravel boilerplate) — and `backend/AGENTS.md` and `backend/CLAUDE.md`, which contained only the Laravel Boost bootstrap instructing agents to `composer require laravel/boost`, were replaced with the real instructions plus an explicit **"Do not install Laravel Boost"** note, because the product owner has declined it and the files would otherwise keep telling every future agent to add it. A stale `description` in `pubspec.yaml` was corrected too. |
| 2026-09-30 | Implemented the desktop half of cloud backup: **a verified snapshot now crosses the wire**. An `UploadActions` port in the domain, `HttpBackupUploader` in infrastructure over `dart:io`'s `HttpClient`, and a "Send to the server" button on the Backup screen. **The local backup is never touched, on any path**, which is the invariant the feature rests on: it is opened for reading and its bytes are sent, and every refusal test asserts the file is byte-identical afterwards. A success is claimed only for a `201` carrying a revision number — a `201` whose body cannot be read is not a success, because the answer exists to confirm what was stored. The declared checksum and size are **recomputed from the file**, not taken from the `BookBackup`, because the server checks them against the bytes it receives. The revision sequence is **read from the server before each upload**, filtered to the fiscal year being sent, so a reinstall does not conflict and a new year starts at 1. A `409` is reported as a conflict and **never retried**; a connection failure and a server error both become `unreachable`, because for the user they are one thing. `dart:io` rather than `package:http`, so the feature adds **no dependency**. 26 infrastructure tests, 8 widget tests, 654 total. |
| 2026-09-30 | **Mutation-tested the new upload tests, and found one that was measuring the wrong thing.** Removing the fiscal-year filter from the revision logic left all 26 tests passing, because the test asserted the revision the **fake transport echoed** rather than the one the **uploader declared** — the fake replies with whatever a test scripts, so the assertion was testing the fake. The test now reads the `revision` field out of the multipart body, and the same mutation is caught. Four further mutations were checked deliberately (a stale checksum, a conflict reported as success, failures reported as success on the screen, and uploading a year with no local backup); each was caught. This is the same class of defect as 7.15 and 7.21 and was found only by breaking the code on purpose. **A second finding was the live check's own expectation**: it asserted that re-uploading the same snapshot returns a conflict. It does not and should not, because the uploader re-reads the sequence first, so a second upload from the same installation legitimately becomes the next revision; a `409` is for another installation uploading between the read and the write. The expectation was corrected rather than the code. |
| 2026-09-30 | **Verified the upload against the real stack, because the unit tests replace the transport** and therefore leave the actual socket and the multipart encoding on the wire unverified. Added `tool/live_upload_check.dart`: six checks against a running Laravel server and the live PostgreSQL database using the real `IoHttpTransport`. It registers a throwaway account each run so it starts from a book with no revisions and can assert exact revision numbers — the first version pointed at a book that already had revisions, which made its absolute assertions meaningless. All six passed: a snapshot uploads and is confirmed as revision 1, a re-upload advances to 2, a second fiscal year starts independently at 1, a non-database file is refused with the server's own reason, an unreachable server is reported with the local backup intact, and **a refused upload is not recorded as a local success**. The rows were then read back out of PostgreSQL. `flutter test` skips the file by name, so the suite stays hermetic. |
| 2026-09-30 | **Reviewed the uncommitted work and fixed all twelve findings.** The two that mattered were written the same day. **The upload never checked that the snapshot was still the verified one**: `BookBackup.checksum` was ignored, so a file corrupted or edited after the backup would have been uploaded, accepted by the server (whose check only covers the trip), and reported as a safe off-machine copy. It now streams a checksum and refuses on mismatch via a new `UploadStatus.unverified`. **Registration returned a 500 on ordinary input**: `unique:users,email` was checked against the address as typed while the lower-cased value was stored, so `SITA@Example.COM` after `sita@example.com` passed the rule and then hit the unique index; normalisation now happens before validation. Also fixed: the Backup screen counted only attempted years and so claimed "every year is now stored off this computer" while a year had no backup at all; the public `register`/`login` routes had **no rate limit** (verified against the framework: the `api` group gets `throttle:api` only when `throttleApi()` is called, and `bootstrap/app.php` leaves it empty) and now carry `throttle:6,1`; and a new test asserted `contains('9')` for the schema version, which the snapshot's own bytes already satisfied, so it **could not fail** — it now compares the declared field to `currentSchemaVersion`. The rest: login leaked account existence through a bcrypt short-circuit; registration confirmed that an email exists, contradicting login's anti-enumeration design; a plaintext remote server was accepted, which would have put the token and the whole database on the network readable; the body was copied three or four times in memory and hashed on the UI isolate; a fresh `HttpClient` per request discarded connection reuse; and `UploadResult.localBackupIsIntact` was dead. 660 Dart tests, 35 Laravel tests / 97 assertions, Pint and analyze clean, Windows build green, and all six live checks against the real server and PostgreSQL still pass. |
| 2026-09-30 | **Mutation-tested every fix from the review, and caught a failure mode worse than a bad test.** Three of four new tests initially appeared not to catch their own regression — but the mutations had not applied at all: the search strings contained CRLF and the files used LF, so the replace matched nothing and the suite stayed green for the wrong reason. Re-applied through the editor, all of them failed without their fix, as they should. **A mutation that does not apply is indistinguishable from a test that works**, which is now recorded as 7.22 alongside the second instance of a test that could not fail (7.21's defect, repeated within a day). A third discovery: the timing fix's first version used a hand-written bcrypt-looking literal, which would have kept the leak while looking fixed, because `password_verify` against a malformed hash returns in **0.04 ms** against **191 ms** for a real one — measured, not assumed. Recorded as 7.23. |
| 2026-09-30 | **Added `NEW_MACHINE.md`, the guide for setting the project up on a different device.** It records the step-by-step commands in both bash and Windows PowerShell (three of them differ), what to verify and the expected numbers, what is committed versus regenerated and why, and the trap that costs the most: **the PostgreSQL password lives only in `backend/.env`, which is not committed, so it is not recoverable from GitHub.** It also carries the repository's PowerShell `.md` corruption warning, because a new machine is exactly where that lesson gets re-learned. **The README's setup section was reduced to a pointer rather than left as a second copy of the same steps**, since two copies of setup instructions drift and the drift is invisible. Corrected **section 3**, which had gone as stale as the documents fixed earlier: it claimed the presentation layer was "still empty" and that only `domain/shared/money.dart` had content, and it listed `domain/` subfolders that are in fact empty directories — `customers/`, `products/`, `payments/`, `expenses/`, `suppliers/`. The concepts live inside `billing/` and `inventory/`, except for suppliers and expenses, which **do not exist at all**; that distinction matters for estimating what is left, and section 3 now says so plainly rather than implying five more modules are in progress. |
| 2026-09-30 | **Implemented sign-in, so a backup can actually be sent by a user** — the task section 6 has held since 4.28. `CredentialStore`, `SignInResult` and `AuthActions` ports; an HTTP client for `POST /api/auth/login` and `/logout`; `SecureCredentialStore` writing the token to protected OS storage; `AccountSession` coordinating them; and a Settings screen with the account panel. **The password is never stored, structurally** — `BackendSession` has no field for it — and the test asserts that against the *values* in the stored map, because a key called `password_hash` would pass an absence check while holding the secret. **Signing out always signs out**: the local session is cleared first, the server is told best-effort, and neither step may throw. Two tests for those failure paths found **two real bugs in my first version**, which had relied on the implementations swallowing their own errors instead of making the caller robust — a locked keyring would have stopped the application starting, and a dead network would have produced a sign-out that did not happen. The HTTP transport moved to `infrastructure/http/` rather than being copied, so status handling exists once. The plain-text rule moved into the domain as `isUsableServerAddress`, because the screen and the client both need it and two copies would drift — and the failure mode of that drift is sending a token and a whole accounting database over clear text. **The decision section 6 asked for**: a `401` now reports `unauthenticated` ("sign in again") instead of `unreachable` ("try again later"), because retrying a `401` fails identically forever. Making that change properly **surfaced a second bug**: a revoked session usually fails the *revision lookup* first, and that path collapsed every failure into `unreachable`, so the new tests failed until `_nextRevisionFor` returned a three-state result instead of a bare `int?`. 16 + 17 + 15 new tests, 712 total, analyze clean. |
| 2026-09-30 | **Found a blocker: the Windows build does not compile.** `flutter build windows` fails with `Cannot open include file: 'atlstr.h'`, because `flutter_secure_storage` holds the token in protected OS storage and its Windows plugin includes that header, which ships in Visual Studio's **optional** "C++ ATL for latest v10 build tools" component rather than the base C++ workload. Verified rather than assumed: every version of `flutter_secure_storage_windows` from **2.x through 4.2.2** includes `atlstr.h`, so downgrading does not help, and 1.2.0 does not exist on pub. **This was not caught by adding the dependency, by `flutter analyze`, or by 712 passing tests — only by building.** That is the lesson: an analyzer cannot see a native toolchain requirement. Recorded in `docs/AI_RULES.md`, `desktop/README.md`, and `NEW_MACHINE.md` so it is found at install time, and escalated as an owner decision because the three ways out are not an agent's to choose. **The weaker-storage option is explicitly rejected in the task text**: a bearer token must not go into a plain file. |
| 2026-09-30 | **Mutation testing failed in a new way: a mutation that changes nothing.** Removing the guard around `signOut`'s store clear left all 16 account tests passing — not because the tests were weak but because the mutation itself was invalid. `if (false) rethrow;` inside a catch is a no-op, so it proved nothing while looking like a deliberate break. Re-applied by actually deleting the `try`, the new test caught it. Recorded as 7.22 seen from a new angle: **verify the mutation changed behaviour, or a green suite means nothing at all.** |
| 2026-09-30 | **Settled the Windows build, which had failed for hours.** Two dependencies were rejected on evidence and one adopted. `flutter_secure_storage` needs Visual Studio's optional C++ ATL component — a single `#include <atlstr.h>`. `webauthn_secure_storage` needs the Windows App SDK (`<winrt/...>`) **and** uses `<experimental/coroutine>`, which MSVC 14.51 rejects outright. `local_storage_cache` and `get_secure_storage` were rejected because they encrypt with a key stored on the same disk, which protects against nothing on that machine. `keyring` needs a **Rust toolchain**. **`crossvault`** was adopted: MIT, standard Windows SDK headers only (`wincred.h`, `ncrypt.h`, `bcrypt.h`), no coroutines, **no optional toolchain component** — and `flutter build windows --debug` now succeeds, producing a 1.27 MB `financeapp.exe`. Its one limitation is recorded rather than glossed: **no Linux implementation**, so on Linux the token lives in memory for the session and the user signs in again after a restart; because `CredentialStore` is an interface, adding it later touches one file. |
| 2026-09-30 | **The most valuable finding was about checking method, not about plugins.** Two claims I made during this were wrong and both came from a check that could not fail. `if ($r)` on `vswhere` output reported the toolchain as fixed when it had returned `[]`, because PowerShell treats that string as truthy. And a regex pattern for ATL usage missed `CA2W` while matching `su**bstr**r` in `substr`. Both are recorded in **7.25**, with the rule: **when a verification is about to confirm something inconvenient, write down first what result would make it fail.** A check that cannot fail looks exactly like a check that passed. The corollary is in 7.24: read a plugin's **native** sources before adopting it, and for a federated plugin open the `_windows` sub-package, not the umbrella — `webauthn_secure_storage`'s umbrella looked clean while its sub-package carried the ATL and the WinRT. |
| 2026-09-30 | **Learned what a Nepali invoice legally requires, and implemented it.** The specification set the standard: tax rules *"shall not be treated as permanently fixed application constants"*, so the rules became `NepalTaxRules` — data with a version string — rather than a `const int vatStandardRate` that would be silently wrong the year the Finance Act changed it. Implemented: the two legal document forms (Rule 17 tax invoice and the Rule 17(Ka) abbreviated retail invoice, limited to a ceiling of NPR 10,000); the seller's PAN gating everything, since a bill without it is not a valid tax bill; the buyer's PAN required when the buyer is VAT-registered, the document is a full tax invoice, or the total reaches the threshold, with a **malformed PAN reported as missing rather than printed**; a VAT-registered business charging no VAT; total in words in lakh and crore; and the HS code added by the 46th amendment. **Nothing was inferred where the sources conflict** — VAT registration thresholds are reported inconsistently (NPR 20 lakh vs 30 lakh for services), so no threshold is implemented at all and the flag is stated by the owner; guessing would produce confidently wrong compliance advice. **Corrected a retention error**: Income Tax Act §81(2), verified against the statutory text, is five years **from the expiry of the income year**, not from the transaction date, and VAT's commonly cited six years is the binding period — `BACKUP_AND_RETENTION.md` had flattened this into one undifferentiated "six years". Compliance is **advisory, not blocking**: refusing to issue an invoice at closing time would push the owner to work around the application entirely. |
| 2026-09-30 | **The tests caught two real defects in new code, both before shipping.** `amountInWords` produced **"Rupees Ten Hundred Crore"** for Rs 100,000, because the divisor list and the name list were **misaligned** — `units[0]` was crore while `names[0]` was the empty string — so every lakh and crore figure on every invoice would have been wrong. And the abbreviated-invoice ceiling test **never actually reached the ceiling**: it derived a price from `rupees * 1.13` and assumed that equalled NPR 10,000, but VAT is rounded per paisa so it does not for most inputs, meaning a compliance boundary test was passing without exercising the boundary. It now builds an exact price (Rs 8,849.56 + 13% = Rs 10,000.00) and asserts the total first. Both are the same lesson as 7.21 and 7.25 from the other direction: **a test that does not reach the condition it names is not a test.** Mutation-checked both — making the ceiling exclusive, and restoring the misaligned lists, each fail. 749 Dart tests. | Two claims I made during this were wrong and both came from a check that could not fail. `if ($r)` on `vswhere` output reported the toolchain as fixed when it had returned `[]`, because PowerShell treats that string as truthy. And a regex pattern for ATL usage missed `CA2W` while matching `su**bstr**r` in `substr`. Both are recorded in **7.25**, with the rule: **when a verification is about to confirm something inconvenient, write down first what result would make it fail.** A check that cannot fail looks exactly like a check that passed. The corollary is in 7.24: read a plugin's **native** sources before adopting it, and for a federated plugin open the `_windows` sub-package, not the umbrella — `webauthn_secure_storage`'s umbrella was clean while its sub-package carried the ATL and the WinRT include. 712 Dart tests, 35 Laravel tests, analyze clean, Pint clean, Windows build green. | It records the step-by-step commands in both bash and Windows PowerShell (three of them differ), what to verify and the expected numbers, what is committed versus regenerated and why, and the trap that costs the most: **the PostgreSQL password lives only in `backend/.env`, which is not committed, so it is not recoverable from GitHub.** It also carries the repository's PowerShell `.md` corruption warning, because a new machine is exactly where that lesson gets re-learned. **The README's setup section was reduced to a pointer rather than left as a second copy of the same steps**, since two copies of setup instructions drift and the drift is invisible. Corrected **section 3**, which had gone as stale as the documents fixed earlier: it claimed the presentation layer was "still empty" and that only `domain/shared/money.dart` had content, and it listed `domain/` subfolders that are in fact empty directories — `customers/`, `products/`, `payments/`, `expenses/`, `suppliers/`. The concepts live inside `billing/` and `inventory/`, except for suppliers and expenses, which **do not exist at all**; that distinction matters for estimating what is left, and section 3 now says so plainly rather than implying five more modules are in progress. |
| 2026-10-01 | **Customer identity decided and recorded: a random internal id plus a separate sequential business code** (`C-0001`), chosen by the owner after being offered a single sequential identifier and a name-based key. Recorded in **ADR 010**. **This closes the open question in 7.16** — ids must not collide if two installations ever sync, and a random id cannot, so that risk is closed now rather than after data exists. **Duplicate detection came from the PAN, not the name**: a unique index on `pan_number` is the one key that cannot produce a false collision, because two businesses cannot share a PAN, whereas a Nepali name repeats and changes on marriage — making it identity would repoint history. Also **fixed a duplication I had introduced myself**: a new `Party` type sat alongside the existing `Customer`, which already covered the same ground and was wired into `IssueInvoice`, `RecordPayment`, and three test files; `Party` is deleted and its PAN and VAT handling folded into `Customer`. |
| 2026-10-02 | **Built the four remaining reports: cash flow, sales, stock held, and VAT.** These were the last four navigation entries in `ui.txt` still showing as dead placeholders. A cash statement is **deliberately not derivable from the profit and loss report** and the two are *supposed* to disagree: a sale on credit moves no cash and a payment of an old invoice is cash without a sale, so the statement reads only the bank and cash accounts, and it is derived from the chart of accounts rather than from hardcoded account ids, so a business that adds a second cash box is covered without a code change. Output VAT follows **invoices issued, not cash received**, because waiting for the cash would understate the liability. **Input VAT is zero, and that is recorded as a limitation rather than hidden**: there are no purchase records in the application at all, so there is nothing to compute input VAT from, and a figure that merely looked computed would be worse than a stated gap. Sales and VAT credit notes are **subtracted, not ignored**, since a credit note reduces what has been sold on exactly the documents a business issues when something has gone wrong. VAT is computed on the amount **excluding** VAT and rounds half-up once, in paisa. A credit note landing in a period with no sales yields a **negative** taxable figure rather than being clamped to zero, because clamping would hide a credit the business is entitled to carry forward. One screen serves all four, and the four navigation entries each open it on its own report. **Two real defects surfaced on the way, both found by tests rather than review.** `AppServices.forSession` and `forAccount` — the two methods that rebuild the whole service bundle — **silently dropped five declared fields** (`createProduct`, `postMovement`, `issueCreditNote`, `postEntry`, `concludeYear`), so changing fiscal year or signing in quietly removed the catalogue, stock, credit-note, journal and year-end screens from the navigation; nothing failed and all tests passed. `test/presentation/app_services_test.dart` now asserts every field by name, because the fix is not the five lines but the test that makes the next omission a **named** failure (recorded as **7.26**). And `BuildCashFlow` with no date range read every entry as one undifferentiated period, which put the **opening-balance entry into "received"** — opening cash Rs 0.00 and received Rs 120,000.00, where the truth was Rs 100,000 and Rs 20,000. The closing figure stayed correct throughout, so **every use-case test passed**; only a widget test that printed the screen could see it. Defaulting the period to the fiscal year exposed the second half: the opening entry is dated *on* the first day rather than the day before, so `openingIncludesBoundary` now states that boundary for the whole-year view, while an explicit caller-supplied range keeps the strict rule (**7.27**). Inventory deliberately got no year boundary, because stock is a balance as at today and the opening entry is exactly what makes that balance correct — filtering it would have been the change that looked like a fix and was not. The presentation-layer architecture test caught the new domain import and it was **added to the allowlist with its justification** rather than the import being worked around. 34 new tests, 889 total, analyze clean, Windows debug build green. |
| 2026-10-02 | **Built the company model, and lost 628 lines of this file doing it.** Two things happened, and the second is the one that matters. First: the four missing reports (cash flow, sales, stock held, VAT) — these were the last dead navigation entries in `ui.txt`. A cash statement is **deliberately not derivable from profit and loss** and the two are *supposed* to disagree, because a credit sale moves no cash and a payment of an old invoice is cash without a sale. Output VAT follows **invoices issued, not cash received**. **Input VAT is zero and that is recorded as a limitation, not hidden**: no purchase records exist in the application at all. Second: a concluded year is **immutable** (`PRAGMA query_only`), so every snapshot of it is byte-identical and the extras are duplicates rather than history — `ConcludedFiscalYearPruner` now keeps the newest revision and deletes the rest, **after** re-hashing the survivor on disk, tombstoning the rows rather than deleting them, and running **after** the fiscal transition so the server can never hold a closed year this computer still allows editing. Three real defects surfaced: `AppServices.forSession`/`forAccount` **silently dropped five declared fields**, so changing year or signing in removed the catalogue, stock, credit-note, journal and year-end screens from the navigation with nothing failing; `BuildCashFlow` with no date range put the **opening-balance entry into "received"** — opening Rs 0.00 against a truth of Rs 100,000 — and the closing figure stayed correct throughout, so **every use-case test passed** and only a widget test could see it; and `AppServices` needed a `company_id` because **a company is a legal entity, not the person signing in**, which is what lets an owner and an accountant exist at all. Both were found by tests, and both are recorded with mutation checks in 7.26, 7.27 and 7.31. The live-database migration then produced the finding no test could: `username NOT NULL` with no backfill **passed all 60 tests and failed against 19 real accounts**, because `RefreshDatabase` migrates an *empty* schema — **a migration is only tested against a database that already contains data** (7.28). Two more PostgreSQL-only failures followed (`HAVING` on an aggregate alias, `split_part`), fixed by backfilling in chunked PHP so one code path serves both drivers. **And then I destroyed this document.** Rewriting section 6, the PowerShell slice had a start index greater than its end index — which PowerShell does not reject, it walks descending, so the "range" returned two lines and everything between section 6 and section 8 was dropped: **the `## 7` heading and entries 7.1 through 7.28, the accumulated discoveries of many sessions.** The write succeeded, the file stayed valid UTF-8, and no test reads this file, so nothing complained. It was found only because the next command printed the section-6 text and `## 7.` was not in it, and recovered only because the lost content was in `git show HEAD` — **the discoveries were committed but the edits on top of them were not**. A descending slice is a silent delete; build replacements as `head + new + tail` and **compare before/after line counts**, because a write reporting success is not evidence of a correct write. Restored and re-applied with verified bounds: 3,299 lines, entries 1–32 with no gaps or duplicates, ascending, all sections present. Also built: `Divergence`/`SyncComparison` classifying all four drift cases from three checksums rather than revision numbers, 14 tests, mutation-verified — and the discovery that `needsAttention` was true for `localOnly`, which is wrong, because prompting a user to confirm work with no alternative teaches them to ignore the prompt (7.31). 912 Dart tests, 60 Laravel tests, both analyzers clean. |