# ADR 002 — One SQLite database per fiscal year

**Status:** Accepted

## Context
A single database that grows across many years becomes slow, hard to archive,
and impossible to make immutable once closed. Year-end reporting also becomes
awkward because every report must filter out prior years.

## Decision
Each fiscal year has its own SQLite file, for example
`accounting-FY-2082-83.db`. A file never spans two fiscal years.

```
Book ABC
├── accounting-FY-2081-82.db   archived, read-only
├── accounting-FY-2082-83.db   archived, read-only after close
└── accounting-FY-2083-84.db   current, writable
```

## Consequences
- Only the active database is writable during normal operation.
- Concluded years open read-only and are never silently modified.
- A correction to a closed year requires an explicit controlled reopen workflow.
- Carry-forward at year end moves only opening balances and opening inventory
  quantity and valuation. Ordinary sales, purchases, expenses, payments, and
  journal history are not copied forward; they stay in the archived database.
- The previous database is never deleted or discarded before the server confirms
  archival succeeded.
