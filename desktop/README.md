# financeapp — desktop

The Flutter desktop application. This is the **primary business system**: all
accounting, billing, inventory, and reporting happens here, on the user's own
machine, with no network required.

Windows, macOS, and Linux are targeted. Windows is the platform currently built
and tested on this machine.

## Running it

```bash
flutter pub get
flutter run -d windows
```

After a schema change, regenerate the drift code and the schema snapshots:

```bash
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump lib/src/infrastructure/database/app_database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/generated/
```

`drift_schemas/` and `test/generated/` are **committed, not build output**. The
migration tests read them; deleting them breaks the suite.

## Before committing

```bash
dart format lib test tool
flutter analyze     # must be clean
flutter test        # must be green
```

## Checking the upload against a real server

The upload's unit tests replace the HTTP transport with a fake, so the real
socket and the multipart encoding on the wire are not covered by the suite.
`tool/live_upload_check.dart` closes that gap. It is not named `*_test.dart`, so
`flutter test` does not pick it up.

```bash
cd ../backend && php artisan serve --port=8124
cd ../desktop
FINANCEAPP_SERVER=http://127.0.0.1:8124 flutter test tool/live_upload_check.dart
```

It registers a throwaway account each run, so it starts from a book with no
revisions and can assert exact revision numbers.

## Layout

```
lib/src/
├── domain/          Pure business rules. Imports nothing from the other layers.
│   ├── accounting/  Journal entries, the ledger, the accounting equation
│   ├── billing/     Invoices and credit notes
│   ├── customers/   Customer records
│   ├── payments/    Payments received, derived invoice balances
│   ├── products/    Product records
│   ├── inventory/   Movements, valuation, write-downs, negative-stock rules
│   ├── expenses/    Expense accounts
│   ├── suppliers/   Supplier records
│   ├── fiscal/      The Bikram Sambat calendar, in-tree
│   ├── reporting/   Trial balance, general ledger, P&L, balance sheet
│   └── shared/      Money, ids, document numbering, the backup contract
├── application/     Use cases. One business operation per use case, each atomic.
├── infrastructure/  SQLite via drift, the filesystem, backup, HTTP
└── presentation/    Flutter UI. Never imports a repository or a domain internal.
```

The dependency direction is one-way: `presentation → application → domain`, with
`infrastructure` implementing ports the domain declares. `domain/` imports nothing.
`test/presentation/architecture_test.dart` enforces this by reading the source.

## Where the books live

One SQLite database per fiscal year, named `accounting-FY-<start>-<end>.db`. The
trading year is writable; a concluded year is opened with `PRAGMA query_only`, so
the database itself refuses writes rather than relying on the screen to hide a
button.

See `../PROGRESS.md` for the current state and the next task, and `../docs/` for
the architecture, the development contract, and the decision records.
