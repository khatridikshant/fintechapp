# backend/ — agent instructions

**The instructions for this repository live in the root `AGENTS.md`.** Read that
first, then `PROGRESS.md` section 7, then `docs/AI_RULES.md`. They apply to the
whole repository, backend included.

## Do not install Laravel Boost

This file previously held the Laravel installer's `laravel-boost-guidelines`
bootstrap, which instructed agents to run:

```sh
composer require laravel/boost --dev
php artisan boost:install
```

**Do not run those.** The product owner has declined Laravel Boost for this
repository. It would add a development dependency to a project whose dependency
list is deliberately controlled (`docs/AI_RULES.md`, "Dependency policy"), and it
rewrites this file when installed. The instructions above are recorded only so a
future agent recognises the template and does not re-add it.

`backend/CLAUDE.md` carries the same note.

## What applies here

- `docs/AI_RULES.md` is the development contract. Read it before changing code.
- Run `php artisan test` and `./vendor/bin/pint` before finishing any backend work.
- `php artisan test` runs on in-memory SQLite and needs no PostgreSQL.
- Laravel 13 configures models with **PHP attributes** (`#[Fillable([...])]`),
  not `$fillable` / `$hidden` properties.
- The one rule that must not be broken: **an unverified upload is never treated as
  a valid backup.** See `app/Services/BackupUploadVerifier.php`.
