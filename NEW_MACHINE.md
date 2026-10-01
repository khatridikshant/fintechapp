# Starting on another device

Everything needed to get this project running from a fresh clone. Written
because moving machines is where setup knowledge is lost.

**The repository is designed so a fresh clone is enough** — but three things live
only on the machine you are leaving, and one of them cannot be recovered from
GitHub. Read the next section before you switch.

---

## Before you leave the old machine

Do these first. They are the only steps that cannot be redone from the repository.

1. **Note the PostgreSQL password.** It is in `backend/.env` as `DB_PASSWORD`,
   and `.env` is deliberately **not** committed. If you lose it you will have to
   reset the database user's password on the new machine, which is recoverable but
   annoying.

   ```bash
   # on the OLD machine
   grep DB_PASSWORD backend/.env
   ```

   On Windows PowerShell:

   ```powershell
   Select-String -Path backend\.env -Pattern '^DB_'
   ```

2. **Nothing else needs copying.** `vendor/`, `build/`, and `.dart_tool/` all
   rebuild from the lockfiles. Do not copy them; they are large and
   platform-specific.

3. **Know that `.kilo/` does not transfer.** It is gitignored and holds local
   agent/tooling state. Agent Manager worktrees and sessions stay on the old
   machine.

---

## Prerequisites on the new machine

| Tool | Version | Notes |
| --- | --- | --- |
| PHP | 8.4+ | With the `pdo_pgsql` extension enabled |
| Composer | 2.x | |
| Flutter | stable | Dart 3.5+ |
| PostgreSQL | 17 | Must be running before `php artisan migrate` |
| Native build tools | — | Visual Studio with the **C++ workload** on Windows, Xcode on macOS, GTK dev headers + clang on Linux |
| **C++ ATL for Windows builds** | — | **Not needed.** See below. |

The native build tools are only needed to *run or build* the desktop application.
`flutter test` works without them.

### No optional Visual Studio components are required

`flutter build windows` needs only the standard C++ workload — MSVC, CMake, and a
Windows SDK. **No optional component is required**, and that is deliberate: the
sign-in token is stored with `crossvault`, which uses only `wincred.h`,
`ncrypt.h` and `bcrypt.h`, all standard Windows SDK headers.

Two earlier dependencies were rejected precisely because they were not:

| Package | Why it was rejected |
| --- | --- |
| `flutter_secure_storage` | One `#include <atlstr.h>` needs the **optional** C++ ATL component. |
| `webauthn_secure_storage` | Needs the Windows App SDK (`<winrt/...>`), and uses `<experimental/coroutine>`, which the current MSVC rejects. |

If you add a Flutter plugin, **read its native sources before adopting it** — and
for a federated plugin open the `_windows` sub-package, not the umbrella, which
can look clean while the native code carries an `#include` on something optional.
A green `flutter test` is not evidence the application builds, because it never
compiles C++.

See `docs/AI_RULES.md` and `PROGRESS.md` sections 4.33 and 7.24.

---

## The steps

Verbatim, in order. Windows equivalents follow.

```bash
git clone https://github.com/khatridikshant/fintechapp.git
cd fintechapp/backend
composer install
cp .env.example .env
php artisan key:generate
# set DB_PASSWORD in .env, then:
createdb -U postgres financeapp
php artisan migrate

cd ../desktop
flutter pub get
flutter test      # expect: All tests passed!
```

### The same steps on Windows PowerShell

The repository is developed on Windows, so the shell needs different spellings
for three of those commands:

```powershell
git clone https://github.com/khatridikshant/fintechapp.git
cd fintechapp\backend
composer install
Copy-Item .env.example .env
php artisan key:generate
# now edit .env and set DB_PASSWORD=
& "C:\Program Files\PostgreSQL\17\bin\createdb.exe" -U postgres financeapp
php artisan migrate

cd ..\desktop
flutter pub get
flutter test
```

---

## Verifying the setup

Setup is not finished when the commands stop erroring. Confirm each of these.

| Check | Command | Expected |
| --- | --- | --- |
| Desktop tests | `flutter test` (in `desktop/`) | `All tests passed!` — **762 tests** |
| Desktop lint | `flutter analyze` | `No issues found!` |
| Desktop build | `flutter build windows --debug` | `financeapp.exe` produced — **no optional component needed**, see above |
| Backend tests | `php artisan test` (in `backend/`) | 35 passed, 97 assertions |
| Backend lint | `./vendor/bin/pint --test` | passed |
| Database | `php artisan db:show` | connects, shows `financeapp` |

**The backend test suite does not need PostgreSQL.** Laravel runs its feature
tests on an in-memory SQLite database, so `php artisan test` passes on a machine
with no PostgreSQL at all. Only `migrate`, `db:show`, and actually serving the API
need the real database.

---

## What is committed, and what is not

Committed on purpose, so a clone is reproducible:

| File | Why it matters |
| --- | --- |
| `backend/composer.lock` | Pins exact backend package versions. |
| `desktop/pubspec.lock` | Pins exact Dart package versions. |
| `backend/.env.example` | The template for the `.env` you create locally. Already `pgsql`, `APP_NAME=financeapp`. |
| `desktop/lib/src/infrastructure/database/app_database.g.dart` | Generated drift code. Committed, so the project **compiles without running `build_runner`** first. |
| `desktop/drift_schemas/`, `desktop/test/generated/` | Schema snapshots and migration-test helpers. **Not build output** — deleting them breaks the migration tests. |
| `desktop/windows/`, `linux/`, `macos/` | Flutter's native folders, including the Windows runner C++. Committed, so no `flutter create` is needed. |

Deliberately not committed:

| Path | Why | Rebuild with |
| --- | --- | --- |
| `backend/vendor/` | Dependencies: huge, and resolved by the lockfile. | `composer install` |
| `backend/.env` | Holds `APP_KEY` and the **database password**. Never commit it. | `Copy-Item .env.example .env` + `php artisan key:generate` |
| `backend/database/database.sqlite` | Unused leftover; the backend is PostgreSQL. | not needed |
| `backend/storage/app/backups/` | Uploaded backup files: real customer data. | not needed |
| `desktop/.dart_tool/`, `desktop/build/` | Generated build state. | `flutter pub get` |
| `.kilo/` | Local agent/tooling state. | not needed |

---

## Regenerating drift code (only after a schema change)

Not needed for a fresh clone — the generated file is committed. Needed only when
`app_database.dart`'s schema changes:

```bash
cd desktop
dart run build_runner build --delete-conflicting-outputs
# The dump needs a FULL FILENAME. Pointing it at the directory fails with
# "the schema version could not be read from the database class".
dart run drift_dev schema dump \
  lib/src/infrastructure/database/app_database.dart \
  drift_schemas/drift_schema_v10.json
dart run drift_dev schema generate drift_schemas/ test/generated/
```

Then commit all three outputs, and bump `currentSchemaVersion` in
`app_database.dart`. **Add a new table rather than a new column** wherever the
change can: adding a column changes the shape `createTable` produces for every
older database and breaks the migration tests, while a new table is simply absent
from every earlier snapshot. `customer_details` is the worked example (ADR 010).

---

## Gotchas worth knowing before you are bitten

- **Never use `Set-Content`, `Out-File`, or `Get-Content | Set-Content` on a `.md`
  file from PowerShell on Windows.** PowerShell 5.1 writes them with a codec that
  replaces em dashes with a lone `0x97` byte, which is invalid UTF-8. The damage is
  already in one commit (`ae3c63c`). Use an editor that writes UTF-8. See
  `PROGRESS.md` section 7.19.
- **Do not splice `PROGRESS.md` by line number in a shell.** Doing so destroyed
  1,300 lines of it once. Use the editor tools. Same section, 7.19.
- **This documentation has never been exercised on a second machine.** Every
  result in the verification table above was produced on one Windows machine.
  Treat a first setup on a new device as unverified until the two test commands
  pass there.
- **"Up to date on GitHub" is not the same as "runnable".** The code is pushed;
  the database, `.env`, and uploaded backups are local by design.

---

## See also

- `GIT_REPO.md` — the remote, and the `fintechapp` / `financeapp` name difference.
- `PROGRESS.md` section 8 — the command reference and the toolchain actually in use.
- `README.md` — the project overview.
- `AGENTS.md` — what to read before changing code.
