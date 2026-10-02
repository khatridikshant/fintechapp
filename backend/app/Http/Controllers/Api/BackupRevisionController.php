<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\BackupRevision;
use App\Models\Book;
use App\Services\BackupUploadVerifier;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\Response;

/**
 * Receives verified snapshots of a fiscal year's books.
 *
 * The flow is deliberately ordered so that **nothing is stored until the upload
 * has been verified**:
 *
 * 1. Confirm the caller owns the book.
 * 2. Validate the declared metadata.
 * 3. Verify the received bytes against what the desktop declared.
 * 4. Only then write the file and record its metadata.
 *
 * A refusal at any step leaves nothing behind. There is no row that says
 * "uploaded but not yet checked", because such a row would be a backup the
 * desktop might later report as stored.
 */
class BackupRevisionController extends Controller
{
    public function __construct(
        private readonly BackupUploadVerifier $verifier,
    ) {}

    /**
     * Store a verified snapshot of one fiscal year.
     */
    public function store(Request $request, Book $book): JsonResponse
    {
        // 1. Ownership. Without this, any authenticated user could write into
        //    another user's book.
        $this->assertOwnership($request, $book);

        // 2. What the desktop said it is sending.
        $validated = $request->validate([
            'fiscal_year_label' => ['required', 'string', 'max:32'],
            'checksum' => ['required', 'string', 'size:64'],
            'file_size' => ['required', 'integer', 'min:1'],
            'database_version' => ['required', 'integer', 'min:1'],
            'revision' => ['required', 'integer', 'min:1'],
            'file' => ['required', 'file'],
        ]);

        /** @var UploadedFile $file */
        $file = $request->file('file');

        // 3. Verification. Nothing has been written yet.
        $verification = $this->verifier->verify(
            $file->getRealPath(),
            $validated['checksum'],
            (int) $validated['file_size'],
        );

        if (! $verification->isValid) {
            return response()->json([
                'message' => 'The upload was not accepted as a valid backup.',
                'reason' => $verification->reason,
            ], Response::HTTP_UNPROCESSABLE_ENTITY);
        }

        // 4. Store. The revision continues the sequence for this book and year,
        //    so two devices cannot silently overwrite one another's snapshots.
        $expectedRevision = (int) BackupRevision::query()
            ->where('book_id', $book->id)
            ->where('fiscal_year_label', $validated['fiscal_year_label'])
            ->max('revision') + 1;

        if ((int) $validated['revision'] !== $expectedRevision) {
            return response()->json([
                'message' => 'The revision does not follow the latest stored one.',
                'reason' => sprintf(
                    'Expected revision %d for this book and year, but the desktop sent %d. '
                    .'Another copy of the books has already stored a revision.',
                    $expectedRevision,
                    (int) $validated['revision'],
                ),
            ], Response::HTTP_CONFLICT);
        }

        $disk = Storage::disk('backups');
        $objectKey = sprintf(
            'books/%d/fiscal-years/%s/revisions/%d.db',
            $book->id,
            $this->slug($validated['fiscal_year_label']),
            $expectedRevision,
        );

        $disk->put($objectKey, fopen($file->getRealPath(), 'r'));

        $revision = BackupRevision::create([
            'book_id' => $book->id,
            'fiscal_year_label' => $validated['fiscal_year_label'],
            'object_key' => $objectKey,
            'file_size' => $verification->actualSize,
            'checksum' => $verification->actualChecksum,
            'database_version' => (int) $validated['database_version'],
            'revision' => $expectedRevision,
            'archive_status' => BackupRevision::STATUS_ACTIVE,
            'created_at' => now(),
        ]);

        return response()->json([
            'message' => 'The snapshot was verified and stored.',
            'revision' => $revision->revision,
            'fiscal_year_label' => $revision->fiscal_year_label,
            'checksum' => $revision->checksum,
            'file_size' => $revision->file_size,
            'created_at' => $revision->created_at?->toIso8601String(),
        ], Response::HTTP_CREATED);
    }

    /**
     * Everything stored for a book, newest first.
     */
    public function index(Request $request, Book $book): JsonResponse
    {
        $this->assertOwnership($request, $book);

        $revisions = BackupRevision::query()
            ->where('book_id', $book->id)
            ->orderByDesc('created_at')
            ->get()
            ->map(fn (BackupRevision $revision) => [
                'id' => $revision->id,
                'fiscal_year_label' => $revision->fiscal_year_label,
                'revision' => $revision->revision,
                'checksum' => $revision->checksum,
                'file_size' => $revision->file_size,
                'database_version' => $revision->database_version,
                'archive_status' => $revision->archive_status,
                'created_at' => $revision->created_at?->toIso8601String(),
                'archived_at' => $revision->archived_at?->toIso8601String(),
            ]);

        return response()->json(['data' => $revisions]);
    }

    /**
     * Metadata for one stored revision.
     */
    public function show(Request $request, BackupRevision $revision): JsonResponse
    {
        $this->assertOwnership($request, $revision->book);

        return response()->json([
            'data' => [
                'id' => $revision->id,
                'fiscal_year_label' => $revision->fiscal_year_label,
                'revision' => $revision->revision,
                'checksum' => $revision->checksum,
                'file_size' => $revision->file_size,
                'database_version' => $revision->database_version,
                'archive_status' => $revision->archive_status,
                'created_at' => $revision->created_at?->toIso8601String(),
                'archived_at' => $revision->archived_at?->toIso8601String(),
            ],
        ]);
    }

    /**
     * Download one stored snapshot.
     *
     * The missing half of recovery: an upload with no download leaves the
     * off-machine copy **write-only**, so a lost computer is still unrecoverable.
     *
     * Three things happen before a byte is sent, in this order:
     *
     * 1. Ownership is checked, so no user can fetch another user's books.
     * 2. The object must actually exist on the disk. A row pointing at a missing
     *    file is a broken record, and downloading it would hand the desktop a
     *    truncated file that looks like a snapshot.
     * 3. The bytes are hashed **as they are read**, and compared with what the
     *    upload verified. A file that has changed on the server since it was
     *    stored is refused, because the checksum is what makes a restore
     *    trustworthy.
     *
     * The checksum is sent as a header so the desktop can verify before it writes
     * anything over its books.
     */
    public function download(Request $request, BackupRevision $revision): Response
    {
        $this->assertOwnership($request, $revision->book);

        $disk = Storage::disk('backups');

        if (! $disk->exists($revision->object_key)) {
            return response()->json([
                'message' => 'The stored file is missing from the server.',
                'reason' => 'A revision record exists but the snapshot it points at is '
                    .'not there, so there is nothing that can safely be restored.',
            ], Response::HTTP_GONE);
        }

        $path = $disk->path($revision->object_key);
        $contents = file_get_contents($path);

        if ($contents === false) {
            return response()->json([
                'message' => 'The stored file could not be read.',
            ], Response::HTTP_GOES_AWAY);
        }

        $actual = hash('sha256', $contents);
        if ($actual !== $revision->checksum) {
            return response()->json([
                'message' => 'The stored file no longer matches its checksum.',
                'reason' => sprintf(
                    'The server holds a file whose SHA-256 is %s, but %s was '
                    .'recorded when it was stored. It has changed since, so it '
                    .'cannot be trusted as a restore source.',
                    $actual,
                    $revision->checksum,
                ),
            ], Response::HTTP_CONFLICT);
        }

        return response($contents, Response::HTTP_OK, [
            'Content-Type' => 'application/octet-stream',
            'Content-Length' => (string) strlen($contents),
            'X-Backup-Checksum' => $actual,
            'X-Backup-Revision' => (string) $revision->revision,
            'X-Backup-Fiscal-Year' => $revision->fiscal_year_label,
            'Content-Disposition' => sprintf(
                'attachment; filename="backup-%s-r%d.db"',
                $this->slug($revision->fiscal_year_label),
                $revision->revision,
            ),
        ]);
    }

    /**
     * Refuse a book the caller does not own.
     *
     * Done here rather than in middleware so a future route cannot forget it.
     */
    private function assertOwnership(Request $request, Book $book): void
    {
        if ($book->user_id !== $request->user()?->id) {
            throw ValidationException::withMessages([
                'book' => 'You do not have access to this book.',
            ]);
        }
    }

    /**
     * `FY 2082/83` becomes `FY-2082-83`, safe to use as a path segment.
     */
    private function slug(string $fiscalYearLabel): string
    {
        return preg_replace('/[^A-Za-z0-9]+/', '-', $fiscalYearLabel) ?? $fiscalYearLabel;
    }
}
