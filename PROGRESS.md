# Development Progress

**Last updated:** 2026-09-29
**Project:** financeapp
**Current gate:** 1 — Domain model
**Gate status:** In progress. Not passed. Gate 1 is not closed.

> If you are an AI agent picking up this repository, read this file first, then
> `docs/AI_RULES.md`, then `docs/ARCHITECTURE.md`. Do not start work before you
> have read all three.

---

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
| `docs/decisions/*.md` | Architecture Decision Records. Read before touching a subsystem they govern. |

The three root `.txt` files were written before any code existed. They are more
authoritative than any summary, including this one.

## 3. Repository layout

```
finsoftware/
├── backend/              Laravel API (PHP 8.4)
├── desktop/              Flutter app (Dart, BSD-3)
│   ├── lib/src/
│   │   ├── domain/       Pure business rules. Imports nothing from other layers.
│   │   ├── application/  Use cases, commands, queries, transaction orchestration.
│   │   ├── infrastructure/ SQLite, filesystem, sync, licensing, crypto.
│   │   └── presentation/ Flutter UI.
│   └── test/
│       ├── domain/  application/  infrastructure/  helpers/
├── docs/                 Architecture, rules, ADRs
└── PROGRESS.md           This file.
```

Directory folders under `lib/src/` and `test/` were created empty. Only
`domain/shared/money.dart` has content. The rest is a skeleton.

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

## 5. What has NOT been done

Everything else. Specifically, none of the following exist:

- Chart of accounts, the journal, or the double-entry accounting engine.
- Any use case. `application/` is empty.
- Any database schema, migration, or repository. `infrastructure/` is empty.
- Expenses, invoices, customers, suppliers, products, inventory, payments.
- Financial reports.
- Any Flutter UI beyond the generated `main.dart` counter app.
- Any backend API, model, or migration beyond stock Laravel.
- Authentication, licensing, sync, backup, restore, fiscal-year lifecycle.
- `pubspec.yaml` still has no dependencies. The approved list is in
  `docs/AI_RULES.md`.

## 6. Next task

This is the next bounded task, ready to hand to an agent verbatim. Do not skip
ahead of it.

> **Implement the double-entry accounting engine: accounts, journal entries, and
> journal lines.**
>
> Scope: `desktop/lib/src/domain/accounting/` only, plus its tests in
> `desktop/test/domain/`.
>
> Do not modify: the UI, `pubspec.yaml`, the database schema, sync, licensing,
> fiscal-year logic, `infrastructure/`, or any existing test.
>
> Required behaviour:
> - An `Account` with a type: asset, liability, equity, income, expense. A
>   balance is derived, never stored as an independently editable field.
> - A `JournalEntry` with id, date, description, reference, and lines.
> - A `JournalLine` with account, debit, and credit. A line carries either a
>   debit or a credit, never both, and never neither.
> - A `Journal` that refuses to post an unbalanced entry. `sum(debits)` must
>   equal `sum(credits)` or construction throws.
> - All amounts use the existing `Money` type. Do not introduce `double` or `num`.
> - A posted journal entry is immutable. Corrections go through a reversing
>   entry, which creates the opposite effect and preserves the original.
>
> Tests to add:
> - Every posted journal balances.
> - An unbalanced journal is rejected.
> - A line with both a debit and a credit is rejected.
> - A line with neither is rejected.
> - A reversing entry has the exact opposite effect of the original and leaves
>   the original intact.
> - Debits and credits on a single account roll up to the correct balance with
>   the correct sign for each account type.
> - Floating point is never used: a test asserts that an amount of 0.1 plus 0.2
>   is exactly 0.30.
>
> Run `flutter test` and report the full result. Do not modify an existing test
> unless a documented requirement has changed. If a requirement is ambiguous,
> stop and ask.

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

### 7.4 Two questions are blocked on you

Both are recorded in `docs/decisions/004-inventory-costing-method.md` and both
must be answered by the product owner before Gate 6.

- **Which inventory costing method?** Moving weighted average, periodic weighted
  average, FIFO, or specific identification. This determines COGS, which
  determines gross profit and the balance sheet. The specification explicitly
  forbids an agent from choosing silently.
- **What happens on a negative inventory sale?** Block it, allow stock to go
  negative, or warn and allow. This interacts with the costing decision, because
  selling stock that does not exist has no defined cost.

**If inventory work is requested while these are open, stop and ask.**

## 8. Commands

Run from the repository root unless stated otherwise.

```bash
# Desktop
cd desktop
flutter test                    # full suite. Must be green before any commit.
flutter test test/domain        # domain layer only
flutter analyze                 # must be clean
flutter run -d windows          # run the app

# Backend
cd backend
php artisan test
php artisan migrate
php artisan serve
```

Toolchain present on this machine: PHP 8.4.17, Composer 2.8.5, Flutter (recent
stable), Node 20.18.0, .NET 8.0.402. Git is installed but no commits have been
made; version control is the project owner's responsibility at present.

## 9. Gate tracker

A gate closes only when its tests pass **and** the accounting results have been
verified by hand. Compiling is not passing. See `docs/AI_RULES.md`.

| Gate | Content | Status |
| --- | --- | --- |
| 1 | Domain model | In progress. `Money` done. Accounting engine not started. |
| 2 | Double-entry accounting engine | Not started |
| 3 | SQLite persistence and atomicity | Not started |
| 4 | Financial reports | Not started |
| 5 | Billing | Not started |
| 6 | Inventory and COGS | Blocked on ADR 004 |
| 7 | Complete offline workflow | Not started |
| 8 | Fiscal-year conclusion and archival | Not started |
| 9 | Cloud backup and restore | Not started |
| 10 | Production and real-world scenarios | Not started |

## 10. Change log

| Date | Change |
| --- | --- |
| 2026-09-29 | Read all three specifications. Chose Flutter over the TBD desktop framework; recorded as ADR 008. Scaffolded Laravel `backend/` and Flutter `desktop/`. Created the layered directory structure. Implemented the `Money` value object with 20 passing tests, fixing two bugs found by the tests. Wrote `docs/AI_RULES.md`, `docs/ARCHITECTURE.md`, and ADRs 001-008. Created this file. |
