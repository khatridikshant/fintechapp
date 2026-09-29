# ADR 003 — One book per account in V1

**Status:** Accepted

## Context
Multi-book support multiplies the surface area of fiscal-year transitions, sync
conflicts, licence enforcement, and UI navigation.

## Decision
V1 supports exactly one book per account, and one active desktop installation
per account. One installation operates on one current fiscal-year database at a
time.

## Consequences
- Simultaneous edits from two machines on the same book do not need to be
  solved. This removes most sync complexity.
- Multi-device sync is explicitly deferred and must be designed separately later.
- Book lifecycle operations: create, open, rename, archive, conclude fiscal year,
  and controlled reopen of a closed period.
- Archiving a book makes it read-only. Deletion, if implemented, requires an
  explicit warning and is never a normal accounting correction.
