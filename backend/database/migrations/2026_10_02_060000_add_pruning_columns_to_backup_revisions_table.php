<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Records that a snapshot's file was pruned when its fiscal year was concluded.
 *
 * ## Why this exists
 *
 * A concluded year is immutable, so every snapshot of it is byte-identical and
 * only one is kept. The rows for the pruned snapshots are **not** deleted -- see
 * `ConcludedFiscalYearPruner` -- because deleting a row would destroy the record
 * that the copy ever existed.
 *
 * Without these two columns that record could only be inferred from a missing
 * file, which is indistinguishable from a file lost through corruption. The
 * difference matters: "pruned on this date, superseded by revision 5" and "the
 * file went missing" call for completely different responses.
 *
 * ## Nullable, and why
 *
 * Both are null for every revision that has not been pruned, which is all of
 * them until a year is concluded. `superseded_by_revision` is nullable rather
 * than defaulted so that a pruned row can always be joined back to the revision
 * that replaced it, and a live row is unambiguously not superseded.
 *
 * No foreign key on `superseded_by_revision`: it points within the same
 * (book, fiscal_year_label) group rather than at a row that must exist, and a
 * self-referencing key on a table whose rows are never deleted buys nothing.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('backup_revisions', function (Blueprint $table) {
            // The revision that replaced this one. Null while the snapshot stands.
            $table->unsignedBigInteger('superseded_by_revision')->nullable()->after('archived_at');

            // When the file was removed. Null while it still exists.
            $table->timestamp('pruned_at')->nullable()->after('superseded_by_revision');
        });
    }

    public function down(): void
    {
        Schema::table('backup_revisions', function (Blueprint $table) {
            $table->dropColumn(['superseded_by_revision', 'pruned_at']);
        });
    }
};
