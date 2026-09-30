<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Metadata for each stored snapshot of a fiscal year's books.
 *
 * **The SQLite file itself is not in this table.** The specification is explicit
 * that the file is stored as a file or object and PostgreSQL keeps only the path
 * and the metadata, in the same pattern as storing an uploaded image while
 * keeping its key. The file is written to storage; `object_key` points at it.
 *
 * A row is only written after the upload has been verified. There is deliberately
 * no "pending" state that could be mistaken for a stored backup.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('backup_revisions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('book_id')->constrained()->cascadeOnDelete();

            // For example `FY 2082/83`. Shown in Bikram Sambat form because
            // that is how the owner refers to the period.
            $table->string('fiscal_year_label');

            // Where the file was written, relative to the backups disk.
            $table->string('object_key')->unique();

            $table->unsignedBigInteger('file_size');

            // SHA-256 of the stored file, computed by the server. The client
            // sends its own and the two must agree.
            $table->string('checksum', 64);

            // The SQLite schema version of the uploaded books, so a restore can
            // tell whether migrations are needed.
            $table->unsignedInteger('database_version');

            // Revisions increase per book. An upload with a revision that does
            // not follow the latest is a conflict, not a silent overwrite.
            $table->unsignedBigInteger('revision');

            // `active` while the year is current, `archived` once concluded.
            $table->string('archive_status')->default('active');

            $table->timestamp('created_at')->nullable();
            $table->timestamp('archived_at')->nullable();

            $table->unique(['book_id', 'fiscal_year_label', 'revision']);
            $table->index(['book_id', 'fiscal_year_label']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('backup_revisions');
    }
};
