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
