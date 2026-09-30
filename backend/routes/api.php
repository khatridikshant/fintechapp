<?php

use App\Http\Controllers\Api\BackupRevisionController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API routes
|--------------------------------------------------------------------------
|
| The desktop application is the primary business system. These routes exist
| for the cloud responsibilities the specification assigns to the server:
| identity, synchronisation, backup, and recovery.
|
| Every route here is authenticated. An unverified upload is never treated as a
| valid backup, so the verification lives in the controller rather than in a
| middleware that could be bypassed by a future route.
|
*/

Route::middleware('auth:sanctum')->group(function () {
    // A verified snapshot of one fiscal year's books, uploaded from the desktop.
    Route::post('/books/{book}/backup-revisions', [BackupRevisionController::class, 'store'])
        ->name('api.backup-revisions.store');

    // What has been stored for a book, newest first.
    Route::get('/books/{book}/backup-revisions', [BackupRevisionController::class, 'index'])
        ->name('api.backup-revisions.index');

    // Metadata for one stored revision. Deliberately never returns the file
    // itself: the desktop already has the file and the point of the endpoint is
    // to confirm the server holds it.
    Route::get('/backup-revisions/{revision}', [BackupRevisionController::class, 'show'])
        ->name('api.backup-revisions.show');
});
