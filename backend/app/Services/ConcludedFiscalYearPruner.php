<?php

namespace App\Services;

use App\Models\BackupRevision;
use App\Models\Book;
use Illuminate\Contracts\Filesystem\Factory as FilesystemFactory;
use Illuminate\Contracts\Filesystem\Filesystem;
use Illuminate\Database\Eloquent\Collection;

/**
 * Reduces a concluded fiscal year to the single snapshot that is kept.
 *
 * ## Why one is enough
 *
 * A concluded year is **immutable**. The desktop opens it with `PRAGMA
 * query_only = ON`, so SQLite itself refuses every write. Nothing in those books
 * can change after the close, which means every snapshot of that year is
 * byte-identical to every other one.
 *
 * So the extra revisions are not history. They are duplicates created by
 * re-uploading a file that was already frozen, and keeping them costs disk
 * without preserving anything. This class removes them.
 *
 * ## The one rule that matters
 *
 * **Nothing is deleted until the survivor has been re-verified on disk.** The
 * survivor's bytes are re-hashed and compared against the checksum recorded when
 * it was stored. If the file is missing, unreadable, or has changed, this throws
 * and deletes nothing at all.
 *
 * That ordering is the whole safety property. Deleting first and verifying
 * afterwards would allow a corrupt survivor to take the year from one good copy
 * to none.
 *
 * ## Tombstones, not deletions
 *
 * The rows for pruned revisions are **kept and marked**, not deleted. The files
 * are gone, but the record that revision 2 existed, and when it was pruned, and
 * by which revision it was superseded, survives. Deleting the row would destroy
 * the ability to answer "what happened to that copy?", which is precisely the
 * question an auditor asks. The row costs nothing.
 *
 * The download endpoint already treats a missing file as `410 Gone`, so a
 * tombstone behaves correctly: it still lists, and still refuses to restore.
 */
class ConcludedFiscalYearPruner
{
    /**
     * The filesystem **factory**, not a `Filesystem`.
     *
     * A `Filesystem` cannot be injected here, because the container resolves
     * that contract to the *default* disk -- and the snapshots live on the named
     * `backups` disk. Injecting the factory and asking for `disk('backups')` is
     * the only way to be sure the right place is read and written. This was a real
     * bug, found by a test that stored files on the faked `backups` disk and then
     * watched the pruner report every one of them as missing.
     */
    public function __construct(
        private readonly FilesystemFactory $filesystems,
    ) {
        //
    }

    /**
     * Mark the year concluded and prune it to a single snapshot.
     *
     * @return array{kept_revision:int, removed_revisions:list<int>, bytes_reclaimed:int}
     *
     * @throws \RuntimeException when the survivor cannot be verified. Nothing has
     *                           been deleted when this is thrown.
     */
    public function prune(Book $book, string $fiscalYearLabel): array
    {
        $disk = $this->filesystems->disk('backups');

        /** @var Collection<int, BackupRevision> $revisions */
        $revisions = BackupRevision::query()
            ->where('book_id', $book->id)
            ->where('fiscal_year_label', $fiscalYearLabel)
            ->orderBy('revision')
            ->get();

        if ($revisions->isEmpty()) {
            // Concluding a year that was never backed up is refused rather than
            // quietly treated as success. An archive that does not exist cannot
            // be reduced to one copy.
            throw new \RuntimeException(sprintf(
                'No snapshot of %s has been stored for this book, so there is '
                .'nothing to conclude. Upload the year before concluding it.',
                $fiscalYearLabel,
            ));
        }

        // The latest revision is the one that survives. For a concluded year this
        // is not a judgement call about which history matters: every snapshot is
        // byte-identical, so any of them would do.
        /** @var BackupRevision $survivor */
        $survivor = $revisions->last();
        $superseded = $revisions->slice(0, $revisions->count() - 1);

        // Verify BEFORE deleting anything. See the class docblock.
        $this->assertRestorable($disk, $survivor);

        $bytesReclaimed = 0;
        foreach ($superseded as $revision) {
            // The row is kept as a tombstone; only the file goes.
            $bytesReclaimed += $revision->file_size;
            if ($disk->exists($revision->object_key)) {
                $disk->delete($revision->object_key);
            }
            $revision->forceFill([
                'archive_status' => BackupRevision::STATUS_PRUNED,
                'superseded_by_revision' => $survivor->revision,
                'pruned_at' => now(),
            ])->save();
        }

        // The survivor becomes the archived record of the year.
        $survivor->forceFill([
            'archive_status' => BackupRevision::STATUS_ARCHIVED,
            'archived_at' => now(),
        ])->save();

        return [
            'kept_revision' => $survivor->revision,
            'removed_revisions' => $superseded->pluck('revision')->all(),
            'bytes_reclaimed' => $bytesReclaimed,
        ];
    }

    /**
     * Prove the survivor is still exactly what was stored.
     *
     * Re-hashed from disk rather than trusting the database. A checksum column
     * can agree with itself while the file beside it has rotted; only reading
     * the bytes can tell the difference.
     */
    private function assertRestorable(Filesystem $disk, BackupRevision $revision): void
    {
        if (! $disk->exists($revision->object_key)) {
            throw new \RuntimeException(sprintf(
                'Revision %d of %s cannot be kept because its file is missing '
                .'from the server. Nothing has been deleted.',
                $revision->revision,
                $revision->fiscal_year_label,
            ));
        }

        $path = $disk->path($revision->object_key);
        $contents = @file_get_contents($path);

        if ($contents === false) {
            throw new \RuntimeException(sprintf(
                'Revision %d of %s cannot be kept because its file could not be '
                .'read. Nothing has been deleted.',
                $revision->revision,
                $revision->fiscal_year_label,
            ));
        }

        $actual = hash('sha256', $contents);

        if ($actual !== $revision->checksum) {
            throw new \RuntimeException(sprintf(
                'Revision %d of %s cannot be kept because the stored file now '
                .'hashes to %s rather than the %s recorded for it. Nothing has '
                .'been deleted.',
                $revision->revision,
                $revision->fiscal_year_label,
                $actual,
                $revision->checksum,
            ));
        }
    }
}
