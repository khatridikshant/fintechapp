<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

/**
 * Companies, and the account columns that point at them.
 *
 * ## Why a `companies` table and not columns on `users`
 *
 * A company is a legal entity. It is not the person who signs in, and the two
 * come apart the moment more than one person touches the books: an owner and an
 * accountant, or an accountant with several clients. Keeping the PAN on `users`
 * would make "one PAN per person" a fact about the schema rather than a fact
 * about the business.
 *
 * The columns live here together so the alternative is a deliberate decision in
 * an ADR, not the path of least resistance.
 *
 * ## What this does NOT change
 *
 * `books.user_id` still points at `users`. This migration is additive: one book per
 * account per ADR 003, unchanged. So an account has exactly one company, which is
 * the V1 limit rather than a constraint of the table -- `users.company_id` would
 * happily hold a different row for a different user, and membership of many
 * companies by one user is the next step, not this one.
 *
 * ## `pan` is unique
 *
 * Two accounts cannot share a taxpayer's PAN. This is the one integrity rule that
 * only becomes possible once the company is server-side: while the PAN lived
 * inside the uploaded SQLite the server had no way to compare two of them.
 *
 * The check is on the PAN and not on the company name, because a name repeats and
 * changes -- on marriage, or on a trading name being adopted. The PAN cannot.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('companies', function (Blueprint $table) {
            $table->id();

            // The registered name, as it appears on tax documents. Not the
            // trading name, and not derived from the account's email.
            $table->string('name');

            /**
             * The Permanent Account Number: nine digits, and unique across all
             * companies on this server.
             *
             * **Nine digits is validated here, not merely on length.** A mistyped
             * PAN that reaches an invoice looks valid, and the invoice is what the
             * tax authority sees. The rule matches `NepaliPan` in the desktop
             * domain -- if one changes, the other must.
             */
            $table->string('pan', 9)->unique();

            /**
             * Whether this business is registered for VAT.
             *
             * A boolean rather than a number, because that is what it is: the
             * registration threshold is decided by law and reported inconsistently
             * across sources, so the flag is **stated by the owner** rather than
             * inferred. See `docs/INVENTORY_EXPLAINED.md` and the Nepal rules note
             * in `PROGRESS.md` for why no threshold is implemented.
             *
             * This changes what a valid invoice is -- a VAT-registered business
             * charging no VAT is not a valid tax invoice -- so it is server-side
             * rather than a local setting.
             */
            $table->boolean('vat_registered')->default(false);

            $table->timestamps();
        });

        Schema::table('users', function (Blueprint $table) {
            // The company this account acts for. Nullable so the column can be
            // added without stranding an existing account mid-migration; every
            // new registration sets it.
            $table->foreignId('company_id')
                ->nullable()
                ->after('id')
                ->constrained()
                ->nullOnDelete();

            /**
             * How many devices may hold a session at once.
             *
             * **Fixed at 1 for now, with no way to change it.** It is a parameter
             * rather than a hardcoded rule so that granting a second device later
             * is a data change rather than a code change.
             *
             * Enforced as: on login, keep the newest `max_devices` sessions and
             * revoke everything older. At 1 that is strictly newest-wins, so signing
             * in always succeeds -- login is authenticated by password, not by
             * token -- and any stale session from a machine that no longer exists
             * revokes itself on the next sign-in.
             *
             * **Not user-settable.** If an account holder could raise its own limit,
             * the limit would not be one.
             */
            $table->unsignedSmallInteger('max_devices')->default(1);
        });

        /**
         * `username`, added last, and added in two steps.
         *
         * **Adding it NOT NULL in one go fails against a database that already has
         * accounts.** PostgreSQL rejects the statement outright because existing
         * rows have no value to put in the column:
         *
         *     ERROR: column "username" of relation "users" contains null values
         *
         * The in-memory test database cannot catch this, because `RefreshDatabase`
         * migrates an *empty* schema and every user is created afterwards by a
         * factory that supplies the field. It was found by running this against the
         * live database, which already held nineteen accounts.
         *
         * So: add it nullable, backfill from the email address, then constrain.
         * Backfilling rather than defaulting is what makes the constraint safe --
         * a default would have to be generated in the database and would then remain
         * as the value for every future insert that forgot the column.
         */
        Schema::table('users', function (Blueprint $table) {
            $table->string('username')->nullable()->after('email');
        });

        /**
         * Backfill, in PHP rather than in SQL.
         *
         * **Because the SQL to do this is not portable.** The obvious form --
         * `split_part(email, '@', 1)` -- is PostgreSQL-only, and this migration is
         * run against SQLite as well, by the test suite. Using it meant the
         * migration passed on an empty database and failed the moment it met a
         * real one, in two different ways before this version worked on both.
         *
         * Chunked rather than loaded whole: the point of a backfill is that the
         * table may be large, and reading every row into memory to write it back
         * one at a time is how a migration takes the site down.
         */
        DB::table('users')
            ->select('id', 'email')
            ->whereNull('username')
            ->orWhere('username', '')
            ->orderBy('id')
            ->chunk(200, function ($rows): void {
                foreach ($rows as $row) {
                    DB::table('users')
                        ->where('id', $row->id)
                        ->update([
                            /**
                             * The local part of the email, before the `@`.
                             *
                             * **Only a placeholder.** The account holder has not
                             * chosen this name; it exists so the unique
                             * constraint can be enforced, and it is replaceable
                             * later. It is deliberately not the whole address --
                             * `owner@example.com` and `owner@other.com` would then
                             * collide, and the backfill would fail rather than
                             * produce a duplicate.
                             */
                            'username' => Str::before((string) $row->email, '@'),
                        ]);
                }
            });

        // The local part is unique per account in practice, but two accounts could
        // legitimately share one -- an owner with two addresses at the same
        // domain. Anything still duplicated after the backfill gets a suffix, so
        // the constraint below cannot fail on data that already exists.
        //
        // Grouped in a subquery rather than with a `HAVING` on an aggregate alias,
        // because PostgreSQL will not let `HAVING` refer to the name given to
        // `count(*)` in the select list. The alias works in SQLite, so this
        // difference only shows against the live database.
        $duplicates = DB::table('users')
            ->select('username')
            ->whereIn('username', function ($query): void {
                $query->select('username')
                    ->from('users')
                    ->groupBy('username')
                    ->havingRaw('count(*) > 1');
            })
            ->pluck('username');

        foreach ($duplicates as $index => $username) {
            $suffix = $index + 1;
            DB::table('users')
                ->where('username', $username)
                ->update(['username' => $username.'-'.$suffix]);
        }

        Schema::table('users', function (Blueprint $table) {
            // Now that every row has a value, the column can be required. This is
            // what makes "one account, one username" enforceable rather than hoped
            // for.
            $table->string('username')->nullable(false)->change();
        });

        Schema::table('users', function (Blueprint $table) {
            $table->unique('username');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropForeign(['company_id']);
            $table->dropColumn(['company_id', 'username', 'max_devices']);
        });

        Schema::dropIfExists('companies');
    }
};
