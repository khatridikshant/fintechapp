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
    'superseded_by_revision',
    'pruned_at',
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
     *
     * **What "immutable" means here, precisely**, because pruning now writes to
     * these rows. The *snapshot* is immutable: its bytes, checksum, size, schema
     * version and revision number never change, and no code path may alter them.
     * A different snapshot is a different row.
     *
     * The *lifecycle* columns are the sanctioned exception, and they are why
     * `updated_at` is absent rather than merely unused: `archive_status` and
     * `archived_at` record whether the year is still trading, and
     * `superseded_by_revision` and `pruned_at` record that this row's file was
     * removed because the year was concluded and its snapshots were duplicates.
     * None of that changes what was stored. An `updated_at` would blur exactly
     * that line, by implying the snapshot itself had been edited.
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
     * A snapshot whose file has been pruned because its year was concluded.
     *
     * **The row survives; only the file is gone.** The distinction matters: a
     * tombstone can still answer "revision 2 existed and was superseded by
     * revision 5", which is the question an auditor asks, whereas a deleted row
     * answers nothing. The download endpoint already reports `410 Gone` for a
     * missing file, so a tombstone lists honestly and refuses to restore.
     */
    public const STATUS_PRUNED = 'pruned';

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
            'superseded_by_revision' => 'integer',
            'pruned_at' => 'datetime',
        ];
    }
}
