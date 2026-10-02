<?php

namespace Tests\Feature;

use App\Models\BackupRevision;
use App\Models\Book;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * The server half of recovery.
 *
 * An upload with no download leaves the off-machine copy **write-only**, so a lost
 * computer is still unrecoverable — which is the whole reason the cloud exists.
 *
 * So most of these tests are about refusal. A download that serves a file without
 * checking it is worse than no download at all, because the desktop would restore
 * from bytes that cannot be trusted.
 */
class BackupDownloadTest extends TestCase
{
    use RefreshDatabase;

    private User $owner;

    private Book $book;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('backups');

        $this->owner = User::factory()->create();
        $this->book = Book::factory()->create(['user_id' => $this->owner->id]);

        Sanctum::actingAs($this->owner);
    }

    /**
     * A real SQLite file, so the stored bytes are a genuine database.
     */
    private function realSqliteFile(): UploadedFile
    {
        $path = tempnam(sys_get_temp_dir(), 'bk').'.db';
        $pdo = new \PDO('sqlite:'.$path);
        $pdo->exec('CREATE TABLE probe (id INTEGER PRIMARY KEY, note TEXT)');
        $pdo->exec("INSERT INTO probe (note) VALUES ('a business year')");
        $pdo = null;

        return new UploadedFile($path, 'accounting-FY-2082-83.db', 'application/octet-stream', null, true);
    }

    /**
     * Stores a real snapshot and returns the revision it became.
     */
    private function storedRevision(): BackupRevision
    {
        $file = $this->realSqliteFile();

        $this->postJson(
            "/api/books/{$this->book->id}/backup-revisions",
            [
                'fiscal_year_label' => 'FY 2082/83',
                'checksum' => hash_file('sha256', $file->getRealPath()),
                'file_size' => (int) filesize($file->getRealPath()),
                'database_version' => 9,
                'revision' => 1,
                'file' => $file,
            ],
        )->assertCreated();

        return BackupRevision::query()->firstOrFail();
    }

    public function test_a_stored_snapshot_can_be_downloaded(): void
    {
        $revision = $this->storedRevision();

        $response = $this->get("/api/backup-revisions/{$revision->id}/download");

        $response->assertOk();

        $body = $response->getContent();
        $this->assertNotEmpty($body, 'a download must carry the file, not metadata');
        $this->assertSame(
            $revision->checksum,
            hash('sha256', $body),
            'the bytes served must be the bytes that were verified',
        );
    }

    /**
     * The desktop needs the checksum **before** it writes anything over its books.
     * A header, because the desktop is fetching a stream, not a JSON body.
     */
    public function test_the_download_carries_the_checksum_the_desktop_can_verify(): void
    {
        $revision = $this->storedRevision();

        $response = $this->get("/api/backup-revisions/{$revision->id}/download");

        $response->assertOk();
        $this->assertSame(
            $revision->checksum,
            $response->headers->get('X-Backup-Checksum'),
        );
        $this->assertSame('1', $response->headers->get('X-Backup-Revision'));
        $this->assertSame('FY 2082/83', $response->headers->get('X-Backup-Fiscal-Year'));
        $this->assertSame(
            (string) $revision->file_size,
            $response->headers->get('Content-Length'),
        );
    }

    /**
     * The failure that matters: a file changed on the server since it was
     * verified. Serving it would have the desktop restore from bytes that no
     * longer match what was checked at upload time.
     */
    public function test_a_snapshot_that_changed_since_it_was_stored_is_refused(): void
    {
        $revision = $this->storedRevision();

        // Different bytes, same record.
        Storage::disk('backups')->put($revision->object_key, 'not the file you stored');

        $response = $this->get("/api/backup-revisions/{$revision->id}/download");

        $response->assertStatus(409);
        $this->assertStringContainsString(
            'no longer matches',
            $response->json()['message'],
        );
    }

    /**
     * A record pointing at a file that is not there must not serve a truncated
     * download, because the desktop could not tell the difference.
     */
    public function test_a_record_whose_file_is_missing_is_refused(): void
    {
        $revision = $this->storedRevision();
        Storage::disk('backups')->delete($revision->object_key);

        $response = $this->get("/api/backup-revisions/{$revision->id}/download");

        $response->assertStatus(410);
        $this->assertStringContainsString('missing', $response->json()['message']);
    }

    /**
     * Another user cannot fetch these books.
     *
     * Expected as **422**, not 403, because `assertOwnership` raises a
     * validation error and every other endpoint in this API does the same.
     * Matching the established behaviour is deliberate: making downloads
     * different would mean two conventions in one API.
     */
    public function test_another_users_backup_cannot_be_downloaded(): void
    {
        $revision = $this->storedRevision();

        // Sign in as somebody else entirely.
        Sanctum::actingAs(User::factory()->create());

        $this->get("/api/backup-revisions/{$revision->id}/download")->assertStatus(422);
    }

    public function test_a_signed_out_caller_cannot_download(): void
    {
        $revision = $this->storedRevision();

        // Drop the identity `setUp` established, so this request carries no
        // token. `Sanctum::actingAs(null)` is not supported, so the guard is
        // cleared directly.
        $this->app['auth']->forgetGuards();

        $this->getJson("/api/backup-revisions/{$revision->id}/download")
            ->assertUnauthorized();
    }

    /**
     * The checksum travels with the file, so the desktop can verify before it
     * writes. Asserted separately from the body because a correct body with a
     * missing header would still leave the desktop unable to check it.
     */
    public function test_the_checksum_in_the_header_matches_the_body(): void
    {
        $revision = $this->storedRevision();

        $response = $this->get("/api/backup-revisions/{$revision->id}/download");

        $body = $response->getContent();
        $this->assertSame(
            hash('sha256', $body),
            $response->headers->get('X-Backup-Checksum'),
            'the header must describe these exact bytes, or the desktop is verifying nothing',
        );
    }
}
