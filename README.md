# financeapp

Offline-first desktop business management software for small businesses, with a
Laravel cloud backend for identity, sync, backup, and restore.

Double-entry accounting, invoicing, inventory, purchases, payments, and financial
reporting. One SQLite database per fiscal year. Nepal-focused: NPR, fiscal year
running Shrawan to Ashadh.

## Layout

| Path | What it is |
| --- | --- |
| `backend/` | Laravel 12 API. Identity, books, fiscal-year metadata, sync, backup, restore, licensing, admin. |
| `desktop/` | Flutter app for Windows, macOS, and Linux. The primary business system. |
| `docs/` | Architecture, the AI development contract, and Architecture Decision Records. |
| `docs/INVENTORY_EXPLAINED.md` | **Plain-language explainer** for inventory costing: what the methods mean with real numbers, what Nepali rules allow, and what this application does. Written for a non-accountant. |
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

The repository is designed so a fresh clone is enough. Two directories are
deliberately not committed, because they are generated or secret. Both rebuild in
under a minute.

```bash
git clone <your-repo-url> financeapp
cd financeapp

# Backend
cd backend
composer install                 # rebuilds vendor/ (8,864 files, not committed)
cp .env.example .env             # .env is never committed; it holds APP_KEY
php artisan key:generate         # writes a new APP_KEY into .env

# Desktop
cd ../desktop
flutter pub get                  # reads the committed pubspec.lock
flutter test                     # expect: All tests passed!
flutter run -d windows
```

What is committed that makes this reproducible:

| File | Why it matters |
| --- | --- |
| `backend/composer.lock` | Pins exact backend package versions. |
| `desktop/pubspec.lock` | Pins exact Dart package versions. |
| `backend/.env.example` | Template for the `.env` you must create locally. |
| `desktop/windows`, `linux`, `macos` | Flutter's native folders. Committing them means you do not need to re-run `flutter create`. |

What is deliberately not committed:

| Path | Why | Rebuild with |
| --- | --- | --- |
| `backend/vendor/` | Dependencies. Huge, and resolved by the lockfile. | `composer install` |
| `backend/.env` | Contains `APP_KEY`. Never commit it. | `cp .env.example .env` + `key:generate` |
| `desktop/.dart_tool/`, `build/` | Generated build state. | `flutter pub get` |

**Required local toolchain:** PHP 8.4+ with Composer, Flutter stable, and the
native build tools for your platform (Visual Studio with the C++ workload on
Windows, Xcode on macOS, GTK dev headers and clang on Linux).

**PostgreSQL is not needed yet.** No migrations have been written and the backend
still defaults to its shipped configuration. You will not hit a database error
until backend work actually starts.

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
