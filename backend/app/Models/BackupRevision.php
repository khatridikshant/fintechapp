<?php

namespace App\Models;

use Database\Factories\BackupRevisionFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Metadata for one stored snapshot of a fiscal year's books.
 *
 * **The SQLite file is not in this table.** The file lives on storage and
 * `object_key` points at it, which is the pattern the specification describes for
 * uploaded files: keep the bytes in a file or object store, keep the metadata in
 * PostgreSQL.
 *
 * A row exists only after the upload has been verified. There is no pending
 * state, because a pending row that gets mistaken for a stored backup is exactly
 * the failure the specification forbids.
 */
#[Fillable([
    'book_id',
    'fiscal_year_label',
    'object_key',
    'file_size',
    'checksum',
    'database_version',
    'revision',
    'archive_status',
    'archived_at',
])]
class BackupRevision extends Model
{
    /** @use HasFactory<BackupRevisionFactory> */
    use HasFactory;

    /**
     * A stored snapshot has no `updated_at`.
     *
     * The specification's column list for this table is `book_id`,
     * `fiscal_year_label`, `object_key`, `file_size`, `checksum`,
     * `database_version`, `created_at`, `archived_at`, `revision`, and
     * `archive_status`. There is no `updated_at` in it, and one would be
     * misleading: a revision is an immutable record, never edited in place. A
     * change means a new revision.
     */
    public $timestamps = false;

    /**
     * The book this snapshot belongs to.
     */
    public function book(): BelongsTo
    {
        return $this->belongsTo(Book::class);
    }

    /**
     * A snapshot of a year that is still open for trading.
     */
    public const STATUS_ACTIVE = 'active';

    /**
     * A snapshot of a year that has been concluded and made immutable.
     */
    public const STATUS_ARCHIVED = 'archived';

    /**
     * The cast definitions.
     *
     * `created_at` and `archived_at` are cast so a caller gets a Carbon
     * instance rather than a string, and so `archived_at` comes back null for a
     * year still in progress instead of an empty date.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'file_size' => 'integer',
            'database_version' => 'integer',
            'revision' => 'integer',
            'created_at' => 'datetime',
            'archived_at' => 'datetime',
        ];
    }
}
