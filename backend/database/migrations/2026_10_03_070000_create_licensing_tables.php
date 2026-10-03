<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Licensing: licences, subscriptions, and registered desktop installations.
 *
 * ## Why this exists
 *
 * ADR 006 requires a licence authorisation signed by a private key the desktop
 * never holds, verified locally so an expired licence can be detected offline.
 * That needs somewhere to record three facts the desktop cannot work out for
 * itself: which licence an installation is running under, how long it is good
 * for, and which devices have been registered against it.
 *
 * ## Nothing here is in the accounting data
 *
 * The desktop keeps its own licence state outside the business database and never
 * restores it from a business backup (ADR 006, specification section 2075), so
 * restoring an old snapshot cannot resurrect an expired licence. These tables are
 * the server's half of that same rule.
 *
 * ## `licences` is not `subscriptions`
 *
 * A licence is the durable right to run the software for a company. A subscription
 * is one payment period against it, and a licence has many over its life. Keeping
 * them apart means a licence's `expires_at` is a fact about the licence rather
 * than being overwritten every time a payment lands, so the current entitlement
 * is answerable without summing periods.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('licences', function (Blueprint $table) {
            $table->id();

            // A random, public identifier. This is what the desktop shows and
            // quotes, so it must never be the primary key: a sequential id would
            // let one holder guess the next holder's licence.
            $table->uuid('uuid')->unique();

            $table->foreignId('company_id')
                ->constrained()
                ->cascadeOnDelete();

            // The plan is data, not a branch in code, so a new tier does not
            // require a deployment.
            $table->string('tier', 32)->default('standard');

            $table->string('status', 16)->default('active');

            // The current entitlement. Nullable, because a perpetual licence has
            // no expiry and inventing one would lock a paying customer out.
            $table->timestampTz('expires_at')->nullable();

            // How often the desktop must revalidate while offline is still allowed
            // to run. Separate from expiry on purpose: expiry is an absolute local
            // boundary, this is a periodic revalidation deadline with a grace
            // period. Conflating them is the obvious mistake (ADR 014).
            $table->unsignedInteger('revalidate_after_days')->nullable();

            // Bumped on every change to the signed claims, so a desktop can tell a
            // newer authorisation from a replayed older one.
            $table->unsignedInteger('revision')->default(1);

            $table->timestampsTz();

            $table->index(['company_id', 'status']);
        });

        Schema::create('subscriptions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('licence_id')->constrained()->cascadeOnDelete();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();

            $table->timestampTz('starts_at');
            $table->timestampTz('ends_at');

            // What was paid, in the smallest currency unit. BigInteger, never a
            // float: money is never a floating-point value anywhere in this
            // project.
            $table->unsignedBigInteger('amount_minor_units');
            $table->char('currency', 3)->default('NPR');

            // Recorded rather than deleted when a subscription ends early, because
            // the record that something was paid for is itself a fact.
            $table->timestampTz('ended_at')->nullable();
            $table->timestampsTz();

            $table->index(['company_id', 'ends_at']);
        });

        Schema::create('registered_desktop_installations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('licence_id')->constrained()->cascadeOnDelete();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();

            // The desktop's installation identifier. Unique, so one installation
            // cannot be registered twice and count as two devices.
            $table->uuid('installation_id')->unique();

            // Recorded for support and for revoking a machine that is gone. Nullable
            // because the first authorisation predates knowing it.
            $table->string('device_name')->nullable();

            $table->timestampTz('first_registered_at');
            $table->timestampTz('last_seen_at');

            // Set when the installation is revoked. Kept rather than deleted, so a
            // revoked device cannot come back by being re-registered silently.
            $table->timestampTz('revoked_at')->nullable();

            $table->timestampsTz();

            $table->index(['licence_id', 'revoked_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('registered_desktop_installations');
        Schema::dropIfExists('subscriptions');
        Schema::dropIfExists('licences');
    }
};
