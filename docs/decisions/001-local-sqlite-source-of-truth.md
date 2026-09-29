# ADR 001 — Local SQLite is the source of truth

**Status:** Accepted

## Context
The product is offline-first. The user's accounting data lives on their own
computer. The cloud exists for identity, sync, backup, and recovery.

## Decision
The active fiscal-year SQLite database on the local machine is the authoritative
business system. The cloud is never required for a normal business operation.

## Consequences
- Every use case must work with the network disconnected.
- The cloud must be designed so that a device which has never synced is still a
  fully functional installation.
- Fiscal-year conclusion is the deliberate exception, because archival on the
  server must succeed before the transition is finalised.
- Restoring a database must never restore licence, subscription, or session
  state, which lives in separate protected storage.
