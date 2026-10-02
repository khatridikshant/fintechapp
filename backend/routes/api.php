<?php

use App\Http\Controllers\Api\AuthController;
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

// Registration and sign-in. These are the only unauthenticated routes in the
// whole API, and they must sit outside the guard below: no token can be obtained
// without one of them, so requiring a token here would make every route
// unreachable.
//
// **They are rate limited, explicitly.** `bootstrap/app.php` leaves
// `withMiddleware` empty, and the framework only puts `throttle:api` on the `api`
// group when `throttleApi()` is called, so without this these two routes would
// accept unlimited requests: unbounded account and book creation, unrestricted
// credential guessing, and bcrypt CPU exhaustion. Six attempts a minute per
// client is generous for a person and useless for a script.
Route::post('/auth/register', [AuthController::class, 'register'])
    ->middleware('throttle:6,1')
    ->name('api.auth.register');
Route::post('/auth/login', [AuthController::class, 'login'])
    ->middleware('throttle:6,1')
    ->name('api.auth.login');

Route::middleware('auth:sanctum')->group(function () {
    // Signed-in identity, and sign-out. `me` exists so the desktop can check a
    // stored token before relying on it.
    Route::get('/auth/me', [AuthController::class, 'me'])
        ->name('api.auth.me');
    Route::post('/auth/logout', [AuthController::class, 'logout'])
        ->name('api.auth.logout');

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

    // The snapshot itself. This is the missing half of recovery: without it an
    // upload is write-only and a lost computer stays unrecoverable. It carries the
    // verified checksum in a header so the desktop can check it before writing
    // anything over its books.
    Route::get('/backup-revisions/{revision}/download', [BackupRevisionController::class, 'download'])
        ->name('api.backup-revisions.download');

    // Conclude a fiscal year and reduce it to one snapshot.
    //
    // Called by the desktop **after** it has archived the year and opened the next
    // one. A concluded year is immutable, so every snapshot of it is identical and
    // the extras are duplicates rather than history -- keeping them costs disk and
    // preserves nothing. The server keeps the latest and tombstones the rest.
    //
    // **The label travels in the body, not the path.** Every fiscal year label in
    // this application contains a slash -- "FY 2082/83" -- and a slash inside a URL
    // path segment is a separator, so the router never matches the route and the
    // request 404s. Percent-encoding does not help, because the router decodes
    // before it matches. Putting it in the body sidesteps the problem rather than
    // slugging it and having to unslug it, which would be a second way to be wrong.
    Route::post('/books/{book}/fiscal-years/conclude', [BackupRevisionController::class, 'concludeYear'])
        ->name('api.fiscal-years.conclude');
});
