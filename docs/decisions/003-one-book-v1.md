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

---

## Amendment, 2026-10-03 — the single-installation rule is now enforced

The decision above stated *one active desktop installation per account* as an
assumption. **It is now enforced by the server**, and this amendment records how,
because the mechanism is not the obvious one.

### The rule

`users.max_devices`, defaulting to **1** and not user-settable. On every successful
sign-in, `SessionLimit` keeps the newest `max_devices` sessions for that account
and revokes the rest. At 1 that is strictly **newest-wins**: whichever computer
signs in last owns the account.

Making it a column rather than a hardcoded rule means granting a second device is
a **data change**, not a code change — which is what an accountant working from home
and the office will need.

### Why revoke rather than refuse

Two shapes were considered, and the safer-looking one is the dangerous one.

**Refusing** a sign-in when the allowance is spent leaves the account locked behind
a token nobody can revoke. A session belonging to a machine that no longer exists —
reinstalled, replaced, stolen, or simply never signed out — permanently consumes the
only slot. The owner is locked out of their own account with **no device list to
revoke from and no expiry to clear it**, and the only remedy is a hand-written
`DELETE`.

**Revoking older sessions** cannot lock anyone out, because of one property:
**login is authenticated by the password, not by a token.** Sign-in therefore always
succeeds, and a stale session revokes *itself* on the next sign-in rather than
stranding the account. That property is the whole reason for the shape, and it is
not obvious from the code.

### What it does and does not achieve

**Does:** makes two machines holding one account simultaneously the exception rather
than the norm, so divergent books become rare.

**Does not:** make divergence impossible. A computer that **signed out without
syncing** is invisible to any count of live tokens — nothing in the session model
represents unsynced local work. Two devices can still diverge, and when they do the
only trace is a `409` on upload, which reads like a backup hiccup rather than what
it is.

**Detecting that is the deferred work, and it is not the session limit's job.**
`Divergence` and `SyncComparison` in `domain/sync/divergence.dart` classify the four
cases by comparing three checksums; the screen and use case that act on it are not
built yet. `ADR 007`'s assumption — *"one book, one active installation"* — is
therefore **weakened but not discharged**, and this amendment is where that should
be recorded rather than discovered later.

### Not in scope here

- **Signing out silently is still bad.** A kicked device should say *"you were
  signed out because this account was signed in on another computer; your books on
  this computer are unchanged."* That message is not built.
- **Token expiry remains unset.** `sanctum.php` has `'expiration' => null`, so a
  leaked token never dies on its own. Unrelated to this rule, and still open.
- **Merge remains out of scope.** For double entry with document numbering, a wrong
  merge is worse than a refusal.
