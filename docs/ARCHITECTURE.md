# Architecture

## Source specifications

This repository is built from three specification documents held at the
repository root. They are the source of truth. Where this summary and those
documents disagree, the documents win.

| File | Contains |
| --- | --- |
| `Rewritten_Business_Application_Architecture.txt` | The full system specification: product definition, accounting model, fiscal-year lifecycle, sync, restore, licensing, security, testing, and the architectural gates. |
| `process.txt` | The development methodology: domain-first, hexagonal, TDD, vertical slices, invariants, immutable financial records, bounded AI tasks. |
| `ui.txt` | The UI design system: Windows 7/8 desktop behaviour with a Data Newspaper visual language. Presentation layer only. |

Read all three before writing code.

## Repository layout

```
finsoftware/
├── backend/          Laravel API. Identity, books, fiscal-year metadata,
│                     sync, backup/restore, licensing, subscriptions, admin.
├── desktop/          Flutter desktop app. Windows, macOS, Linux.
│   └── lib/src/
│       ├── domain/          Pure business rules. No imports from any other layer.
│       ├── application/     Use cases, commands, queries. Orchestrates transactions.
│       ├── infrastructure/  SQLite, filesystem, sync, licensing, crypto.
│       └── presentation/    Flutter UI. Windows 7/8 + Data Newspaper.
├── docs/             Architecture, rules, decisions.
└── PROGRESS.md       Handoff state. Read this first.
```

The two deployables are separate. The desktop app must function with the backend
completely unreachable.

## Technology

| Layer | Choice | Licence | Notes |
| --- | --- | --- | --- |
| Desktop UI and application runtime | Flutter / Dart | BSD-3 | No paid tier exists. Windows, macOS, Linux. |
| Local database | SQLite via `drift` | MIT | One database per fiscal year. |
| Backend | Laravel 13, PHP 8.4 | MIT | Identity, books, backup metadata, licensing. |
| Cloud metadata database | PostgreSQL | PostgreSQL Licence | Metadata only, never SQLite file contents. |
| SQLite snapshots | File or object storage | n/a | Actual database files. |

## Why Flutter

The desktop stack was selected for three reasons, in order:

1. **Zero licensing cost with no vendor dependency.** BSD-3 has no paid tier and
   no commercial-use restriction. Nothing can be repriced or revoked later.
2. **The fastest AI-assisted iteration loop of the zero-cost options.** This
   project will be built largely by AI agents in bounded tasks. Dart compiles
   almost immediately, so failed compile-fix cycles cost little. Rust's
   ownership errors were judged a net negative here, because the project's real
   defence against wrong accounting is the test suite, not the type system.
3. **The UI is mostly forms and data entry**, which is Flutter's strongest
   category and matches the Windows 7/8 desktop design system in `ui.txt`.

The trade-off, accepted knowingly: Dart has no built-in fixed-precision decimal
and no immutable-primitive type system. The `Money` value object, backed by
integer minor units, is the mitigation and is the foundation of the domain layer.

Alternatives considered and rejected: Electron (weight, no useful numeric
safety), Qt (LGPL obligations), .NET MAUI (no Linux target), Avalonia (MIT core
is free, but the vendor now gates tooling behind per-seat commercial licences),
Tauri (zero cost, stronger guarantees, but slower AI iteration and a smaller
ecosystem for data-dense business UI).

## The one architectural rule

The UI must never directly manipulate accounting data.

```
Bad:   Widget -> UPDATE journal_entries

Good:  Widget -> CreateExpenseCommand -> CreateExpense
          -> AccountingEngine -> Journal -> SQLite
```

## Dependency direction

The domain layer imports nothing from the other layers. It does not know that
SQLite, Flutter, drift, HTTP, or the filesystem exist. This is what makes the
accounting rules testable in isolation and keeps the UI replaceable.

## Fiscal year model

One SQLite database per fiscal year. A database never spans two fiscal years.
Only the active year's database is writable. Concluded years are immutable
archives opened read-only.

Concluding a fiscal year is the one operation that requires internet, because the
completed database must be archived on the server before the transition is
finalised. See section 28 of the architecture specification for the full
16-step sequence and the failure-recovery rules.

## Architectural gates

Work proceeds in this order. A gate is closed only when its tests pass and the
accounting results have been independently verified by hand, not when the code
compiles.

| Gate | Content |
| --- | --- |
| 1 | Domain model: entities, relationships, documented rules |
| 2 | Double-entry accounting engine |
| 3 | SQLite persistence and transaction atomicity |
| 4 | Financial reports |
| 5 | Billing: customers, invoices, payments, receivables |
| 6 | Inventory and COGS |
| 7 | Complete offline workflow |
| 8 | Fiscal-year conclusion and archival |
| 9 | Cloud backup and restore |
| 10 | Production and real-world scenario testing |

Current gate: see `PROGRESS.md`.
