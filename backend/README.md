# financeapp — backend

The Laravel 13 API. It holds the cloud responsibilities the specification assigns
to the server: **identity, books, backup metadata, licensing, and (later) sync and
restore.** It is never on the path of a normal business operation — the desktop
application must work with this service completely unreachable.

## Running it

```bash
composer install
cp .env.example .env
php artisan key:generate
```

Set `DB_PASSWORD` in `.env`, then create the database and migrate:

```bash
createdb -U postgres financeapp
php artisan migrate
php artisan serve
```

PostgreSQL is the configured database. **The test suite does not need it** — the
feature tests run on an isolated in-memory SQLite database, which is Laravel's own
convention, so `php artisan test` passes with no PostgreSQL installed.

## Testing

```bash
php artisan test     # expect: all green
./vendor/bin/pint    # formatting; run before committing
```

## API

All routes are in `routes/api.php`.

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| POST | `/api/auth/register` | none | Create an account, its one book, and a token |
| POST | `/api/auth/login` | none | Issue a token |
| GET | `/api/auth/me` | token | Who is signed in, and their books |
| POST | `/api/auth/logout` | token | Revoke **this** token only |
| POST | `/api/books/{book}/backup-revisions` | token | Upload a verified snapshot |
| GET | `/api/books/{book}/backup-revisions` | token | List what is stored, newest first |
| GET | `/api/backup-revisions/{revision}` | token | Metadata for one revision |

`register` and `login` are the **only** unauthenticated routes, and they must stay
outside the `auth:sanctum` group: no token can be obtained without them.

### The rule that governs uploads

**An unverified upload is never treated as a valid backup.** The upload is checked
four times, cheapest and safest first — SQLite magic header, declared size,
declared SHA-256, then SQLite's own `integrity_check` — and the first failure
stores nothing: no file, no row. There is deliberately no "uploaded but not yet
checked" state, because that row would be a backup the desktop might report as
stored.

The integrity check runs **last** on purpose: opening a received file with SQLite
means parsing data from outside, so it happens only after the file is known to be
a database whose checksum matches what a trusted client declared, and it is opened
read-only.

A revision that does not follow the latest is a **conflict (HTTP 409)**, not a
silent overwrite.

## Layout

```
app/Http/Controllers/Api/   AuthController, BackupRevisionController
app/Services/               BackupUploadVerifier — the four-step verification chain
app/Models/                 User, Book, BackupRevision
routes/api.php              All API routes
tests/Feature/              AuthenticationTest, BackupUploadTest
```

Laravel 13 puts model configuration in **PHP attributes** (`#[Fillable([...])]`,
`#[Hidden([...])]`), not the older `$fillable` / `$hidden` properties. Follow the
existing models.

## Not built yet

- **Licensing.** A backend-signed licence authorisation with expiry, a device
  binding, and an offline public-key check. Deliberately separate from the token
  endpoints above, which are authentication only.
- **Download and restore.** There is no endpoint that returns a stored snapshot, so
  the desktop cannot restore from the cloud.
- **Sync.** Not started.

See `../PROGRESS.md` for the current state and `../docs/` for the architecture and
the development contract.
