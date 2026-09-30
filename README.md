# financeapp

Offline-first desktop business management software for small businesses, with a
Laravel cloud backend for identity, sync, backup, and restore.

Double-entry accounting, invoicing, inventory, purchases, payments, and financial
reporting. One SQLite database per fiscal year. Nepal-focused: NPR, fiscal year
running Shrawan to Ashadh.

## Layout

| Path | What it is |
| --- | --- |
| `backend/` | Laravel 13 API. Identity, books, fiscal-year metadata, sync, backup, restore, licensing, admin. |
| `desktop/` | Flutter app for Windows, macOS, and Linux. The primary business system. |
| `docs/` | Architecture, the AI development contract, and Architecture Decision Records. |
| `docs/INVENTORY_EXPLAINED.md` | **Plain-language explainer** for inventory costing: what the methods mean with real numbers, what Nepali rules allow, and what this application does. Written for a non-accountant. |
| `docs/BACKUP_AND_RETENTION.md` | **Plain-language explainer** for backup and record keeping: what Nepali law appears to require, how a backup is verified, and what a local backup still does not protect against. |
| `docs/NEPALI_CALENDAR.md` | **Plain-language explainer** for the Bikram Sambat calendar, including what has and has not been verified about the calendar data, and how to verify it before launch. |
| `AGENTS.md` | Entry point for any AI agent. Read first. |
| `PROGRESS.md` | Handoff state and the next task. |
| `*.txt` | The three original specifications. These are the source of truth. |

## Start here

If you are a developer or an AI agent, in this order:

1. `AGENTS.md`
2. `PROGRESS.md` — read **section 7** in full. It holds the accumulated
   discoveries, the resolved gaps, the open questions, and the traps that cost
   time the first time. It is the most valuable part of this repository to read.
3. `docs/AI_RULES.md`
4. `docs/ARCHITECTURE.md`

The three root specification files are long. Read the section relevant to your
task rather than all 4000 lines at once.

## Continuing on a new machine

**See [`NEW_MACHINE.md`](NEW_MACHINE.md) for the full guide** — prerequisites, the
commands for both bash and Windows PowerShell, what to verify, and the gotchas.

Two things are worth stating here because they are easy to get wrong:

- **Note the PostgreSQL password before you leave the old machine.** It lives in
  `backend/.env`, which is deliberately not committed, so it is not recoverable
  from GitHub.
- **The backend test suite does not need PostgreSQL.** Laravel runs its feature
  tests on an in-memory SQLite database, so `php artisan test` passes on a machine
  with no PostgreSQL at all. Only `migrate`, `db:show`, and actually serving the
  API need the real database.

What a clone must rebuild — `backend/vendor/`, `backend/.env`, and Flutter's
generated state (`desktop/.dart_tool/`, `desktop/build/`, and the platform
`ephemeral/` folders) — takes under a minute in total. Everything else, including
the generated drift code and the Windows runner source, is committed.

## Development

```bash
# Desktop
cd desktop
flutter test        # must be green before any commit
flutter analyze     # must be clean
flutter run -d windows

# Backend
cd backend
php artisan test
php artisan serve
```

## The rule that matters most

The UI never manipulates accounting data directly. A button calls a use case,
the use case goes through the accounting engine, the engine writes a balanced
journal, and infrastructure persists it inside one transaction.

```
Widget -> CreateExpenseCommand -> CreateExpense -> AccountingEngine -> SQLite
```

This is what makes the accounting rules testable, and what lets the UI be
replaced without touching anything that affects the numbers.

## Technology

| Layer | Choice | Licence |
| --- | --- | --- |
| Desktop UI and runtime | Flutter / Dart | BSD-3, no paid tier |
| Local database | SQLite via `drift` | MIT |
| Backend | Laravel 13, PHP 8.4 | MIT |
| Cloud metadata | PostgreSQL | PostgreSQL Licence |
| SQLite snapshots | File or object storage | n/a |

The project carries zero licensing cost. Every dependency must be permissively
licensed. See `docs/AI_RULES.md` for the approved list and the explicitly
rejected commercial packages.
