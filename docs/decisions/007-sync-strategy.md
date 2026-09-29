# ADR 007 — Sync strategy

**Status:** Accepted

## Context
Sync must not corrupt a correct local database. An accounting file that is
half-synced, truncated, or mismatched is worse than no backup at all.

## Decision
Sync operates on **whole SQLite snapshots**, never on row-level deltas.

**Desktop:** validate, create a consistent snapshot, compute SHA-256, upload.

**Server:** authenticate, verify book ownership, verify fiscal year, verify the
expected revision, store the file, write metadata to PostgreSQL, return the new
revision.

An unverified upload is never treated as a valid backup. Checksum, file size,
book, fiscal year, and schema version are all validated before the backup is
marked successful.

## Storage split

PostgreSQL stores **metadata only**:

```
book_id, fiscal_year_id, object_key, file_size, checksum,
database_version, created_at, archived_at, revision, archive_status
```

Object or file storage holds the **actual SQLite file**:

```
books/{book-id}/fiscal-years/{fiscal-year-id}/
├── revisions/       active-year snapshots
└── archive.db       concluded year, immutable
```

The SQLite file is never stored as a PostgreSQL table or blob.

## Restore

Never overwrite the current database in place.

```
current DB -> local emergency backup -> authenticate -> verify authorisation
-> download -> verify metadata and checksum -> SQLite integrity check
-> run migrations if applicable -> replace -> open
```

A historical year follows the same verification path and then opens read-only.

## Consequences
- If the local database is lost and neither a cloud snapshot nor a fiscal-year
  archive exists, the data cannot be recovered. This is stated to the user rather
  than hidden.
- Checksum and file-size mismatch aborts the restore without touching the current
  database.
- Sync is an online feature. It is never on the path of a business operation.
- In V1, one book has one active installation, so expected-revision checking
  detects the "someone else synced this" case without needing a merge algorithm.
