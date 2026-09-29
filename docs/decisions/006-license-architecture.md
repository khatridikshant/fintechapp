# ADR 006 — Licensing architecture

**Status:** Accepted

## Context
The product is commercial and must work offline. Enforcement must not require
the cloud on every operation, and must not risk the user's accounting data.

## Decision
The Laravel backend is authoritative for accounts, licences, subscriptions,
books, and registered installations. It issues a **cryptographically signed
licence authorisation** containing at minimum: licence id, user id, book id,
licence status, licence expiry date, issuance date, next required server
validation time, licence revision, and the registered device id where device
binding is enabled.

The desktop application holds **only the public verification key**. It verifies
the signature of every authorisation before trusting it. The private signing key
never ships to clients.

## Consequences
- Offline operation is possible because verification is local, not remote.
- The desktop cannot be tricked by editing a local licence file, because the
  signature will not verify.
- Licence **expiry** and **next required revalidation** are distinct concepts and
  must not be conflated. Expiry is an absolute local boundary. Revalidation may
  have an offline grace period.
- Expiry must be enforceable without internet, by comparing against the locally
  verified expiry date.
- Expiry locks the application and preserves all accounting data intact.
  It never deletes, corrupts, or modifies business records.
- Licence, session, and device state live in protected OS storage, separate from
  the business database, and are never restored from a business database backup.
- Clock-rollback detection uses the last trusted server time. This is tamper
  detection, not an absolute guarantee against a user with full machine control,
  and must not be documented as one.
- Licensing lives in `infrastructure/licensing/` and is isolated from every
  business domain.
- Licensing behaviour is covered by automated tests: valid signature, invalid
  signature, expired, not-yet-valid, periodic validation, offline operation,
  offline expiry, clock rollback, corrupted local state, device authorisation,
  renewal after expiry, and restore without licence state.
