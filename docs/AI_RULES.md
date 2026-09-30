# AI Development Rules

This is a contract, not a suggestion. Every AI agent working on this repository
must read this file before modifying code. It is derived from
`Rewritten_Business_Application_Architecture.txt` sections 43-44 and
`process.txt` section 16.

## Layer boundaries

```
presentation  ->  application  ->  domain
                                   ^
                                   |
                             infrastructure
```

Dependencies point inward only. The domain depends on nothing.

## NEVER

- Put accounting logic in UI or presentation code.
- Write SQL, or reference a table name, in presentation code.
- Let presentation code touch SQLite, drift, or any database type.
- Directly modify journal balances or account balances.
- Delete a posted financial transaction.
- Delete an inventory movement.
- Bypass the accounting engine.
- Change the database schema without a migration.
- Change accounting behaviour without adding or updating tests.
- Make a cloud call mandatory for normal accounting operations.
- Change a test merely to make it pass.
- Invent an unspecified accounting rule.
- Implement an ambiguous requirement without asking.
- Perform unrelated refactoring during a feature task.
- Modify more architectural layers than the task requires.
- Use `double` or `num` to represent a monetary amount. Use `Money`.
- Introduce a dependency with a commercial, paid, or non-permissive licence
  without explicit written approval. See "Dependency policy" below.
- Put licensing, authentication, or device-binding logic in a business domain.
- Restore licence, subscription, session, or device state from a business
  database backup.
- Conclude a fiscal year before the server has confirmed archival of the
  completed SQLite file.
- Delete or discard a previous fiscal-year database before archival is confirmed.
- Write to a historical fiscal-year database. Historical years are read-only.

## ALWAYS

- Route every business action through a use case in
  `lib/src/application/`.
- Make every business operation a single atomic database transaction.
- Represent money with the `Money` value object from
  `lib/src/domain/shared/money.dart`.
- Record an inventory movement for every stock change, with a reason and a
  reference.
- Derive reports from accounting data. Never store a report total.
- Make a draft document editable, and a posted document immutable. Corrections
  use credit notes, debit notes, reversals, or compensating movements.
- Reset the invoice serial only when an invoice is actually issued, never when a
  draft is created.
- Validate that a transaction date belongs to the active fiscal year before
  posting it.
- Reject an unbalanced journal.
- Write a failing test before implementing financial behaviour.
- Commit in small, reviewable units.
- Ask when a requirement is ambiguous. Stopping to ask is cheaper than guessing
  at an accounting rule.

## The three kinds of passing

These are different and must not be confused.

1. **Code compiles.** `flutter analyze` succeeds. This proves nothing about
   accounting correctness.
2. **Automated tests pass.** Better, but a test can itself encode a wrong
   expectation.
3. **The accounting scenario is independently verified.** You calculated the
   expected result by hand from the accounting rules, the application agrees,
   and the journal balances.

Only (3) closes a gate. Never advance a gate on (1).

## Dependency policy

The project is committed to zero licensing cost. Every dependency must be MIT,
BSD-3, Apache-2.0, or an equivalently permissive licence.

Explicitly rejected, despite being common search results:

| Package | Why rejected |
| --- | --- |
| `syncfusion_flutter_datagrid`, `syncfusion_flutter_charts` | Commercial licence. The most common result for a Flutter data grid, and a trap. |
| Any Avalonia Accelerate / Pro component | Commercial, per-seat. Not in this repo, recorded so it is not reintroduced. |

Approved dependencies, all permissive. The **In use** column is not decoration:
a package listed as approved but not in use is not in `pubspec.yaml`, and adding
it is a normal dependency decision, not a pre-approved one.

| Package | Licence | Purpose | In use |
| --- | --- | --- | --- |
| `drift` | MIT | SQLite, type-safe queries, migrations | **Yes** |
| `drift_dev`, `build_runner` (dev) | MIT | Code generation for drift | **Yes** |
| `sqlite3` | MIT | Native SQLite bindings, imported directly by `sqlite_native.dart` | **Yes** |
| `sqlite3_flutter_libs` | MIT | Bundles SQLite into the shipped application | **Yes** |
| `path`, `path_provider` | MIT / BSD-3 | Database file location | **Yes** |
| `crypto` | BSD-3 | SHA-256 checksums for verifying backups | **Yes** |
| `cupertino_icons` | MIT | Shipped with the Flutter template | **Yes** |
| `flutter_lints` (dev) | BSD-3 | The lint set | **Yes** |
| `pluto_grid` | MIT | Dense desktop data grid | No — approved for later |
| `fl_chart` | MIT | Restrained charts | No — approved for later |
| `go_router` | BSD-3 | Navigation | No — approved for later |
| `flutter_secure_storage` | BSD-3 | OS-protected token and licence storage | No — approved for later |

**The Bikram Sambat calendar is deliberately NOT a package.** Its data is kept
in-tree in `lib/src/domain/fiscal/bs_calendar_data.dart`, because a single
maintainer should not be able to change the licence, withdraw the package, or
discontinue it for the one dataset the product cannot ship without. The
`bikram_sambat` package was evaluated and **rejected on those supply-chain
grounds**; see ADR 009. If a future calendar package is proposed, weigh it as
supply-chain risk, not just licence text.

**MIT and BSD-3 both require the copyright notice to be retained**, so the
application must expose a reachable licences screen. Flutter's
`showLicensePage` covers this and aggregates every dependency's licence
automatically.

Declare a package you import directly, even when it arrives transitively. The
analyzer enforces this with `depend_on_referenced_packages`, and it is correct to.

Before adding any package, verify its licence and record it here. An **unknown**
licence is not a permissive licence: `nepali_calendar` was rejected on exactly
that basis. Do not adopt a package whose licence you cannot read.

## Task sizing

A good task is bounded:

> Implement the `CreateExpense` use case. Do not modify the UI, the database
> schema, sync, or fiscal-year logic. Create the journal entry through the
> accounting engine. Add tests for cash expense, bank expense, and a zero
> amount. Run the full suite. Do not modify existing tests unless the documented
> requirement changed.

A bad task:

> Build the accounting module.

Never let one change touch many unrelated layers at once.
