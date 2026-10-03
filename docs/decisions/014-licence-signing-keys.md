# ADR 014 — Licence signing keys and the verification boundary

**Status:** Accepted

## Context

ADR 006 decided the architecture: the backend signs a licence authorisation with a
**private** key, the desktop holds only the **public** key, and verification is
local so an expired licence can be detected with no internet connection.

It did not decide **which algorithm**, **where the server's private key lives**, or
**what happens when verification fails**. Those three are decisions, and getting
the first one wrong makes the second two moot.

## Decision

### Ed25519, signed and verified by `cryptography` on the desktop

| | |
| --- | --- |
| Algorithm | Ed25519 (RFC 8032, EdDSA over Curve25519) |
| Server signer | **PHP libsodium, built in** — `sodium_crypto_sign_detached` |
| Desktop verifier | `package:cryptography`, Apache-2.0 |

**The server needs no new dependency at all.** PHP ships libsodium, verified
present on this machine: `sodium_crypto_sign_detached` and
`sodium_crypto_sign_keypair` both exist. So the signing side is native.

**Asymmetric is not optional.** A symmetric HMAC would satisfy "signed" in the
loosest sense while requiring the desktop to hold the same secret the server signs
with — and a user who extracts it can mint an authorisation that verifies forever.
That is precisely the attack ADR 006 exists to prevent, so HMAC was rejected
despite needing no dependency at all.

Two Ed25519 Dart packages were considered: `cryptography` and `ed25519_edwards`.
**`cryptography` was chosen**, on the owner's decision. The reasons, recorded so
they are not re-litigated without evidence:

- It is a **mature, actively maintained project** (2.9.0, dint.dev, published
  changelog) rather than a 39-day-old 0.3.x release from an unverified uploader.
  A signing library is the last place to accept thin maintenance.
- It is **Apache-2.0**, which `AI_RULES.md` permits.

Both were Apache-2.0, so **licence was not a differentiator** — an earlier draft of
this ADR claimed `cryptography` was BSD-3, which was wrong. Recorded because
`PROGRESS.md` 7.23 is about exactly this class of error: a confident claim about a
crypto fact, made from memory, that would have kept a real defect.

**`cryptography_flutter` is deliberately NOT adopted.** It delegates to platform
APIs and would add a native dependency for performance this application does not
need: it verifies one small signature at sign-in, not bulk data.

**The native surface was read before adoption, as `AI_RULES.md` requires:**
cryptography 2.9.0 contains **no native sources at all** — no `.c`, `.cpp`,
`.hpp`, `.swift`, `.java`, no `CMakeLists.txt`, no platform folders, and no
`DynamicLibrary.open`. Its only `dart:ffi` import is in
`argon2_impl_default.dart`, which this application never touches; the Ed25519 path
(`src/dart/ed25519_impl.dart`) imports only `dart:typed_data`. **Pure Dart, so no
optional Visual Studio component** — the trap that cost this project an evening
twice, in `flutter_secure_storage` and `webauthn_secure_storage`.

### The private key lives in the gitignored `backend/.env`

`FINANCEAPP_LICENCE_PRIVATE_KEY` holds the base64 32-byte seed. `backend/.env` is
already gitignored, already holds the PostgreSQL password, and is already the place
a secret belongs. A separate key file would need a deployment decision about where
that path lives on someone else's machine.

**The public key is compiled into the desktop** as a constant. That is not a
secret — it is the whole point of asymmetric verification — and compiling it means
the desktop has no network call in the path between "I have a licence" and "this
licence is genuine".

A `php artisan financeapp:licence-keypair` command generates the pair and prints
the public key, so the constant in the desktop can be set from real output rather
than from a value typed by hand.

### What is signed, and what is not

The signature covers a **canonical serialisation of the licence claims**: licence
id, user id, book id, status, expiry, issued-at, next-validation-at, revision, and
the device id where device binding applies. **Every one of those fields is
authenticated**, so a user editing the stored expiry to a later date invalidates
the signature and the licence fails closed.

**Expiry and next-validation are distinct and both are signed**, because ADR 006
requires it and because conflating them is the obvious mistake: expiry is an
absolute local boundary, next-validation is a periodic revalidation deadline with an
offline grace period.

### Verification failure locks the application and never touches business data

An invalid signature, a corrupted store, or a passed expiry **stops normal business
operations**. It **never deletes, modifies, or corrupts the accounting database** —
that is a hard requirement in both ADR 006 and specification section 2073, and a
licence problem must not be able to destroy a customer's books.

**Licensing state lives outside the business database** and is never restored from
a business backup, so restoring an old snapshot cannot resurrect an expired licence.
This mirrors ADR 006 and specification section 2075.

### Clock rollback is tamper detection, and is described as such

The last trusted server time is stored and compared against later local time.
Rollback detection **locks the licence pending revalidation**.

`AI_RULES.md` forbids presenting this as an absolute guarantee, and it is not one:
a user with full control of the machine can defeat it. It is recorded as tamper
detection. Claiming otherwise would be the more serious error.

## Consequences

- **The desktop can decide, with no network, whether the application may run.** That
  is the requirement the whole design exists for.
- **Signing is a server-only operation.** The private key never leaves the backend,
  so a compromised desktop cannot mint licences.
- **Rotating the key means shipping a new desktop build**, because the public key is
  compiled in. That is the accepted cost of removing a network call from the
  verification path; a key-rotation endpoint is a later decision.
- **`cryptography` enters the licence screen automatically** via Flutter's
  `showLicensePage`, which is why the licences screen aggregates rather than lists.
- **Licensing lives in `infrastructure/licensing/`** and imports no business domain,
  as ADR 006 and `AI_RULES.md` both require. A licence check must never be able to
  reach the accounting engine.