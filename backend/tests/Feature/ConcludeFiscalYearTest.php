<?php

namespace Tests\Feature;

use App\Models\BackupRevision;
use App\Models\Book;
use App\Models\User;
use App\Services\ConcludedFiscalYearPruner;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Pruning a concluded fiscal year down to one snapshot.
 *
 * The property under test throughout is the ordering: **the survivor is verified
 * before anything is deleted.** Every refusal test asserts that the other files
 * are still present afterwards, because a prune that deleted first and checked
 * afterwards could take a year from one good copy to none.
 */
class ConcludeFiscalYearTest extends TestCase
{
    use RefreshDatabase;

    private const YEAR = 'FY 2081/82';

    private User $owner;

    private Book $book;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('backups');

        $this->owner = User::factory()->create();
        $this->book = Book::factory()->create(['user_id' => $this->owner->id]);
    }

    /**
     * Store one snapshot on disk and in the database, with a checksum that
     * genuinely matches the bytes written.
     */
    private function storeRevision(int $revision, string $fiscalYear = self::YEAR): BackupRevision
    {
        $contents = "snapshot of {$fiscalYear} revision {$revision}";
        $slug = str_replace([' ', '/'], '-', $fiscalYear);
        $objectKey = sprintf(
            'books/%d/fiscal-years/%s/revisions/%d.db',
            $this->book->id,
            $slug,
            $revision,
        );

        Storage::disk('backups')->put($objectKey, $contents);

        return BackupRevision::factory()->create([
            'book_id' => $this->book->id,
            'fiscal_year_label' => $fiscalYear,
            'object_key' => $objectKey,
            'file_size' => strlen($contents),
            'checksum' => hash('sha256', $contents),
            'revision' => $revision,
        ]);
    }

    private function pruner(): ConcludedFiscalYearPruner
    {
        return app(ConcludedFiscalYearPruner::class);
    }

    public function test_it_keeps_the_latest_snapshot_and_removes_the_rest(): void
    {
        $first = $this->storeRevision(1);
        $second = $this->storeRevision(2);
        $third = $this->storeRevision(3);

        $result = $this->pruner()->prune($this->book, self::YEAR);

        $this->assertSame(3, $result['kept_revision']);
        $this->assertSame([1, 2], $result['removed_revisions']);

        // Only the latest file remains on disk.
        Storage::disk('backups')->assertMissing($first->object_key);
        Storage::disk('backups')->assertMissing($second->object_key);
        Storage::disk('backups')->assertExists($third->object_key);
    }

    public function test_pruned_revisions_are_tombstoned_not_deleted(): void
    {
        $first = $this->storeRevision(1);
        $last = $this->storeRevision(2);

        $this->pruner()->prune($this->book, self::YEAR);

        // The row survives, so the record that the copy existed is not lost.
        $first->refresh();
        $this->assertSame(BackupRevision::STATUS_PRUNED, $first->archive_status);
        $this->assertSame(2, $first->superseded_by_revision);
        $this->assertNotNull($first->pruned_at);

        $last->refresh();
        $this->assertSame(BackupRevision::STATUS_ARCHIVED, $last->archive_status);
        $this->assertNotNull($last->archived_at);
        $this->assertNull($last->pruned_at);
    }

    public function test_nothing_is_deleted_when_the_survivor_is_corrupt(): void
    {
        $first = $this->storeRevision(1);
        $second = $this->storeRevision(2);

        // The stored file no longer matches the checksum recorded for it. Pruning
        // here would destroy the only other good copy.
        Storage::disk('backups')->put($second->object_key, 'rotted after storage');

        try {
            $this->pruner()->prune($this->book, self::YEAR);
            $this->fail('A corrupt survivor must stop the prune.');
        } catch (\RuntimeException $e) {
            $this->assertStringContainsString('Nothing has been deleted', $e->getMessage());
        }

        // **Both** files are still there. The first one was never at risk, and
        // this is the assertion that proves the check runs before the deletion.
        Storage::disk('backups')->assertExists($first->object_key);
        Storage::disk('backups')->assertExists($second->object_key);
        $this->assertSame(
            BackupRevision::STATUS_ACTIVE,
            $first->refresh()->archive_status,
            'A refused prune must not mark anything as archived.',
        );
    }

    public function test_nothing_is_deleted_when_the_survivor_file_is_missing(): void
    {
        $first = $this->storeRevision(1);
        $second = $this->storeRevision(2);

        Storage::disk('backups')->delete($second->object_key);

        try {
            $this->pruner()->prune($this->book, self::YEAR);
            $this->fail('A missing survivor must stop the prune.');
        } catch (\RuntimeException $e) {
            $this->assertStringContainsString('Nothing has been deleted', $e->getMessage());
        }

        Storage::disk('backups')->assertExists($first->object_key);
    }

    public function test_a_year_with_no_stored_snapshot_is_refused(): void
    {
        // Concluding a year that was never backed up cannot mean "keep one copy",
        // because there are none.
        $this->expectException(\RuntimeException::class);
        $this->expectExceptionMessage('nothing to conclude');

        $this->pruner()->prune($this->book, self::YEAR);
    }

    public function test_a_single_snapshot_is_marked_archived_without_deleting_anything(): void
    {
        $only = $this->storeRevision(1);

        $result = $this->pruner()->prune($this->book, self::YEAR);

        $this->assertSame(1, $result['kept_revision']);
        $this->assertSame([], $result['removed_revisions']);
        $this->assertSame(0, $result['bytes_reclaimed']);

        Storage::disk('backups')->assertExists($only->object_key);
        $this->assertSame(
            BackupRevision::STATUS_ARCHIVED,
            $only->refresh()->archive_status,
        );
    }

    public function test_pruning_one_year_leaves_another_year_untouched(): void
    {
        // Two fiscal years are separate groups. Concluding one must not reach
        // into the other, which is the mistake a query without the year filter
        // would make.
        $oldA = $this->storeRevision(1, 'FY 2080/81');
        $oldB = $this->storeRevision(2, 'FY 2080/81');
        $newer = $this->storeRevision(1, self::YEAR);

        $this->pruner()->prune($this->book, 'FY 2080/81');

        Storage::disk('backups')->assertExists($oldB->object_key);
        Storage::disk('backups')->assertMissing($oldA->object_key);
        Storage::disk('backups')->assertExists($newer->object_key);
        $this->assertSame(
            BackupRevision::STATUS_ACTIVE,
            $newer->refresh()->archive_status,
        );
    }

    public function test_pruning_reports_how_much_disk_it_reclaimed(): void
    {
        $this->storeRevision(1);
        $this->storeRevision(2);
        $this->storeRevision(3);

        $result = $this->pruner()->prune($this->book, self::YEAR);

        $this->assertGreaterThan(0, $result['bytes_reclaimed']);
    }

    /**
     * 422, not 403, and that is the existing convention.
     *
     * `assertOwnership` throws a `ValidationException`, so every ownership refusal
     * in this API answers 422. Matching it keeps the surface consistent; 403 would
     * be more accurate HTTP semantics for an authorisation failure, but changing it
     * is a separate decision that would touch every existing test. Worth doing
     * deliberately rather than one endpoint at a time.
     */
    public function test_another_users_book_cannot_be_concluded(): void
    {
        $stranger = User::factory()->create();
        $theirBook = Book::factory()->create(['user_id' => $stranger->id]);

        $contents = 'not yours';
        $objectKey = sprintf('books/%d/fiscal-years/x/revisions/1.db', $theirBook->id);
        Storage::disk('backups')->put($objectKey, $contents);
        BackupRevision::factory()->create([
            'book_id' => $theirBook->id,
            'fiscal_year_label' => self::YEAR,
            'object_key' => $objectKey,
            'checksum' => hash('sha256', $contents),
            'revision' => 1,
        ]);

        $response = $this->actingAs($this->owner, 'sanctum')
            ->postJson("/api/books/{$theirBook->id}/fiscal-years/conclude", ['fiscal_year_label' => self::YEAR]);

        $response->assertStatus(422);
        Storage::disk('backups')->assertExists($objectKey);
    }

    public function test_the_endpoint_concludes_a_year_for_its_owner(): void
    {
        $first = $this->storeRevision(1);
        $second = $this->storeRevision(2);

        $response = $this->actingAs($this->owner, 'sanctum')
            ->postJson("/api/books/{$this->book->id}/fiscal-years/conclude", ['fiscal_year_label' => self::YEAR]);

        $response->assertOk()
            ->assertJsonPath('kept_revision', 2)
            ->assertJsonPath('removed_revisions', [1]);

        Storage::disk('backups')->assertMissing($first->object_key);
        Storage::disk('backups')->assertExists($second->object_key);
    }

    public function test_the_endpoint_refuses_a_year_with_nothing_stored(): void
    {
        $response = $this->actingAs($this->owner, 'sanctum')
            ->postJson("/api/books/{$this->book->id}/fiscal-years/conclude", ['fiscal_year_label' => self::YEAR]);

        $response->assertStatus(422);
    }
}
