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
 * The server half of backup.
 *
 * The specification's rule is absolute: **the server shall never treat an
 * unverified upload as a valid backup.** So most of these tests are about
 * refusal, because a backup feature is only worth having if it says no.
 */
class BackupUploadTest extends TestCase
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
     * A real SQLite file, so verification runs against a genuine database
     * rather than a blob with the right magic bytes.
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

    private function declaredFor(UploadedFile $file): array
    {
        return [
            'fiscal_year_label' => 'FY 2082/83',
            'checksum' => hash_file('sha256', $file->getRealPath()),
            'file_size' => (int) filesize($file->getRealPath()),
            'database_version' => 9,
            'revision' => 1,
        ];
    }

    public function test_a_verified_snapshot_is_stored_with_its_metadata(): void
    {
        $file = $this->realSqliteFile();

        $response = $this->postJson(
            "/api/books/{$this->book->id}/backup-revisions",
            $this->declaredFor($file) + ['file' => $file],
        );

        $response->assertCreated();

        $this->assertDatabaseHas('backup_revisions', [
            'book_id' => $this->book->id,
            'fiscal_year_label' => 'FY 2082/83',
            'revision' => 1,
            'database_version' => 9,
            'archive_status' => BackupRevision::STATUS_ACTIVE,
        ]);

        $stored = BackupRevision::query()->firstOrFail();
        Storage::disk('backups')->assertExists($stored->object_key);

        $this->assertSame(
            hash_file('sha256', $file->getRealPath()),
            $stored->checksum,
            'the server must record the checksum of the bytes it actually holds',
        );
    }

    public function test_an_upload_that_fails_its_checksum_is_refused_and_stored_nowhere(): void
    {
        $file = $this->realSqliteFile();
        $declared = $this->declaredFor($file);
        $declared['checksum'] = str_repeat('a', 64);

        $response = $this->postJson(
            "/api/books/{$this->book->id}/backup-revisions",
            $declared + ['file' => $file],
        );

        $response->assertStatus(422);
        $this->assertDatabaseCount('backup_revisions', 0);
        $this->assertEmpty(Storage::disk('backups')->allFiles());
    }

    public function test_a_truncated_upload_is_refused(): void
    {
        $file = $this->realSqliteFile();
        $declared = $this->declaredFor($file);
        // The desktop recorded a larger size than arrived.
        $declared['file_size'] = $declared['file_size'] + 500;

        $response = $this->postJson(
            "/api/books/{$this->book->id}/backup-revisions",
            $declared + ['file' => $file],
        );

        $response->assertStatus(422);
        $this->assertDatabaseCount('backup_revisions', 0);
    }

    public function test_a_file_that_is_not_a_database_is_refused(): void
    {
        $path = tempnam(sys_get_temp_dir(), 'bk');
        file_put_contents($path, str_repeat('this is not a database. ', 64));
        $file = new UploadedFile($path, 'books.db', 'application/octet-stream', null, true);

        $response = $this->postJson(
            "/api/books/{$this->book->id}/backup-revisions",
            [
                'fiscal_year_label' => 'FY 2082/83',
                'checksum' => hash_file('sha256', $path),
                'file_size' => (int) filesize($path),
                'database_version' => 9,
                'revision' => 1,
                'file' => $file,
            ],
        );

        $response->assertStatus(422);
        $this->assertStringContainsString('not a SQLite database', $response->json('reason'));
        $this->assertDatabaseCount('backup_revisions', 0);
    }

    public function test_a_damaged_database_is_refused(): void
    {
        $file = $this->realSqliteFile();
        // Corrupt the middle of the file, then declare the checksum of the
        // damaged bytes. This is the case that only the integrity check
        // catches: a valid header and a matching checksum, but broken content.
        $path = $file->getRealPath();
        $bytes = (string) file_get_contents($path);
        $mid = intdiv(strlen($bytes), 2);
        $bytes[$mid] = chr(ord($bytes[$mid]) ^ 0xFF);
        file_put_contents($path, $bytes);

        $response = $this->postJson(
            "/api/books/{$this->book->id}/backup-revisions",
            $this->declaredFor($file) + ['file' => $file],
        );

        $response->assertStatus(422);
        $this->assertDatabaseCount('backup_revisions', 0);
    }

    public function test_an_unauthenticated_upload_is_refused(): void
    {
        // Drop the authenticated user set up in setUp, rather than passing null
        // to actingAs, which is not a valid call.
        $this->app['auth']->forgetGuards();

        $file = $this->realSqliteFile();

        $response = $this->postJson(
            "/api/books/{$this->book->id}/backup-revisions",
            $this->declaredFor($file) + ['file' => $file],
        );

        $response->assertStatus(401);
        $this->assertDatabaseCount('backup_revisions', 0);
        $this->assertEmpty(Storage::disk('backups')->allFiles());
    }

    public function test_another_users_book_cannot_be_written_to(): void
    {
        $stranger = User::factory()->create();
        $theirBook = Book::factory()->create(['user_id' => $stranger->id]);
        $file = $this->realSqliteFile();

        $response = $this->postJson(
            "/api/books/{$theirBook->id}/backup-revisions",
            $this->declaredFor($file) + ['file' => $file],
        );

        $response->assertStatus(422);
        $this->assertDatabaseCount('backup_revisions', 0);
    }

    public function test_a_revision_that_does_not_follow_the_latest_is_a_conflict(): void
    {
        $file = $this->realSqliteFile();

        $this->postJson(
            "/api/books/{$this->book->id}/backup-revisions",
            $this->declaredFor($file) + ['file' => $file],
        )->assertCreated();

        // A second upload claiming to be revision 1 again, rather than 2.
        $second = $this->realSqliteFile();
        $declared = $this->declaredFor($second);
        $declared['revision'] = 1;

        $response = $this->postJson(
            "/api/books/{$this->book->id}/backup-revisions",
            $declared + ['file' => $second],
        );

        $response->assertStatus(409);
        $this->assertDatabaseCount('backup_revisions', 1);
    }

    public function test_revisions_continue_in_sequence(): void
    {
        for ($revision = 1; $revision <= 3; $revision++) {
            $file = $this->realSqliteFile();
            $declared = $this->declaredFor($file);
            $declared['revision'] = $revision;

            $this->postJson(
                "/api/books/{$this->book->id}/backup-revisions",
                $declared + ['file' => $file],
            )->assertCreated();
        }

        $this->assertDatabaseHas('backup_revisions', ['revision' => 3]);
        $this->assertDatabaseCount('backup_revisions', 3);
    }

    public function test_stored_revisions_can_be_listed_for_a_book(): void
    {
        $file = $this->realSqliteFile();
        $this->postJson(
            "/api/books/{$this->book->id}/backup-revisions",
            $this->declaredFor($file) + ['file' => $file],
        )->assertCreated();

        $response = $this->getJson("/api/books/{$this->book->id}/backup-revisions");

        $response->assertOk();
        $this->assertCount(1, $response->json('data'));
        $this->assertSame('FY 2082/83', $response->json('data.0.fiscal_year_label'));
        $this->assertSame(1, $response->json('data.0.revision'));
    }

    public function test_listing_another_users_book_is_refused(): void
    {
        $stranger = User::factory()->create();
        $theirBook = Book::factory()->create(['user_id' => $stranger->id]);

        $this->getJson("/api/books/{$theirBook->id}/backup-revisions")
            ->assertStatus(422);
    }
}
