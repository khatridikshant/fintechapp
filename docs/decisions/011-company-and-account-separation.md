# ADR 011 — Companies are separate from accounts

**Status:** Accepted
**Implementation status:** built on the server, carried by the desktop, untested
against live PostgreSQL. See the note at the end.

## Context

`users` held only `name`, `email` and `password`. Everything that identifies a
*business* — its registered name, its PAN, whether it is registered for VAT —
existed only inside the uploaded SQLite, which the server treats as an opaque blob
it never parses.

That produced three concrete gaps.

1. **The server could not tell a user who they were.** Showing "your registered
   business name and PAN" required downloading and parsing a backup.
2. **Two accounts could claim the same taxpayer.** Nothing was checkable, because
   the value being checked was never server-side.
3. **Nothing could be filed on a user's behalf.** A VAT return needs the taxpayer's
   identity, and the server did not have it.

The trigger was a conversation about using the application on two computers, which
surfaced a deeper modelling problem: `books.user_id` made the *person who signs in*
and the *business being accounted for* the same thing. That works only while one
person keeps one set of books.

## Decision

A `companies` table, with `users.company_id` pointing at it.

```
users                companies
  id            FK→     id
  company_id ──────────► name
  name                 pan            (9 digits, unique)
  username             vat_registered (boolean)
  max_devices
```

A company is a legal entity; a user is the person who signs in. They come apart as
soon as an owner and an accountant share the books, or an accountant acts for
several clients.

### `pan` is unique, and the check is on the PAN rather than the name

A name repeats and changes — on marriage, or when a trading name is adopted. The
PAN cannot. Two accounts sharing a PAN is a real integrity failure; two accounts
sharing a name is not.

### Nine digits, validated at registration

A mistyped PAN that reaches an invoice looks valid, and the invoice is what the tax
authority sees. The rule matches `NepaliPan` in the desktop domain; if one changes,
the other must.

### `vat_registered` is a stated flag, never inferred

The registration threshold is set by law and reported inconsistently across
sources, so no threshold is implemented. The owner states it. It is server-side
rather than a local setting because it decides what a *valid* invoice is: a
VAT-registered business charging no VAT is not a valid tax invoice.

### The duplicate-PAN error does not confirm that a PAN exists

It returns the same generic wording as a duplicate email, for the reason
`AuthController::login` returns one message for both an unknown address and a
wrong password: confirming which taxpayers are customers is itself a disclosure.

### V1 gives one company to one account

Matching the one-book-per-account limit in ADR 003. Neither is a constraint of the
tables — `Company::users()` and `User::books()` are both plural — so lifting either
is a change to registration and the desktop, not a migration.

## Consequences

- **The account no longer represents a business.** Every reference to "the user's
  business" in code now means "the company the account acts for", which is one more
  hop but stops the person being mistaken for the entity.
- **`username` was added but is not yet usable to sign in.** Login still takes an
  email. The column exists so a unique display name can be captured before there
  is data; making it a credential changes the authentication contract and needs its
  own tests. **This is a loose end, not a decision.**
- **The PAN is now server-held data.** It was previously only ever inside the
  user's own file. That is what makes uniqueness and filing possible, and it is
  also a change in where a sensitive value lives — see the open question in
  `docs/BACKUP_AND_RETENTION.md` about encryption at rest, which this makes more
  pressing rather than less.
- **The desktop carries the company for display only.** Nothing decides anything
  from it. `vat_registered` is nullable there on purpose: `false` means "not
  registered", `null` means "the server did not say".

## Not decided here

- **Membership and roles.** One company, many people, with an owner who cannot be
  removed and an accountant who cannot manage access. That is the next step and it
  is a new authorisation axis, not a foreign key.
- **Which copy of the PAN is authoritative.** The local `business.db` still holds
  business details for printing on invoices, and it can still be edited. If the two
  diverge, there are two answers to "what is this business's PAN". The clean
  resolution is that PAN and registered name become read-only locally after
  registration — but that affects the invoice screen, and is a product decision.
- **Token expiry.** `sanctum.php` sets `expiration` to null, so a leaked token
  never dies on its own. Unrelated to this ADR but found while building it.

## The `max_devices` decision, recorded alongside

`users.max_devices`, default 1, not user-settable. On sign-in the newest
`max_devices` sessions survive and older ones are revoked.

The rule is a column rather than a constant so granting a second device is a data
change. It is not user-settable because an account holder who could raise its own
limit would make the limit not one.

The important property is that **login is authenticated by the password, not by a
token**, so signing in always succeeds. A session left behind by a machine that no
longer exists therefore revokes *itself* on the next sign-in, rather than locking
the owner out permanently with no way to revoke anything. A limit that *refused*
sign-in when the allowance was spent would fail that way, which is why it was not
chosen.

What it costs: two people sharing one login will evict each other. That is the
intended behaviour, and it is the reason `max_devices` exists.