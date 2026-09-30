<?php

namespace Database\Factories;

use App\Models\BackupRevision;
use App\Models\Book;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<BackupRevision>
 */
class BackupRevisionFactory extends Factory
{
    /**
     * Metadata for a stored snapshot.
     *
     * The SQLite file itself is **not** in the database; the file lives on the
     * `backups` disk and this row points at it.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $fiscalYear = 'FY 2082/83';
        $slug = 'FY-2082-83';
        $revision = 1;

        return [
            'book_id' => Book::factory(),
            'fiscal_year_label' => $fiscalYear,
            'object_key' => sprintf(
                'books/%%d/fiscal-years/%s/revisions/%d.db',
                $slug,
                $revision,
            ),
            'file_size' => 65536,
            // 64 hex characters, as SHA-256 always produces.
            'checksum' => hash('sha256', (string) fake()->uuid()),
            'database_version' => 9,
            'revision' => $revision,
            'archive_status' => BackupRevision::STATUS_ACTIVE,
            'created_at' => now(),
            'archived_at' => null,
        ];
    }
}
