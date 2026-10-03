<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Book;
use App\Models\Licence;
use App\Models\RegisteredDesktopInstallation;
use App\Support\LicenceSigner;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Issues signed licence authorisations for desktop installations.
 *
 * ## Why the response is signed rather than merely authenticated
 *
 * The desktop must decide, with no network, whether it may run. An HTTPS response
 * proves the request was not intercepted in transit; it says nothing about what the
 * server would say tomorrow. A signature over the claims means a stored
 * authorisation stays verifiable offline, and a user who edits the stored expiry
 * cannot make it verify (ADR 006, ADR 014).
 *
 * ## What is signed
 *
 * Every field that decides whether the licence is valid: id, user, book, status,
 * expiry, next validation, revision, and the installation. A device is bound into
 * the claims so an authorisation issued for one machine does not verify on another.
 *
 * ## Refusals never leak who holds a licence
 *
 * A request for a company with no licence gets the same wording as one for a
 * company that does not exist, for the same reason `AuthController::login` returns
 * one message for both an unknown address and a wrong password: confirming which
 * taxpayers are licensed is itself a disclosure.
 */
class LicenceAuthorisationController extends Controller
{
    public function __construct(private readonly LicenceSigner $signer) {}

    /**
     * Return a signed authorisation for the caller's company and book.
     */
    public function show(Request $request, Book $book): JsonResponse
    {
        // 1. Ownership, before anything is read or signed. Without this, any
        //    authenticated user could obtain an authorisation for another user's
        //    book.
        $user = $request->user();
        abort_unless($book->user_id === $user->id, 404);

        $validated = $request->validate([
            'installation_id' => ['required', 'uuid'],
            'device_name' => ['nullable', 'string', 'max:128'],
        ]);

        /** @var Licence|null $licence */
        $licence = Licence::query()
            ->where('company_id', $user->company_id)
            // Suspended and cancelled licences are not returned as valid; a
            // revoked one is returned as *revoked* rather than as "no licence", so
            // the desktop can say why it stopped working instead of reporting a
            // licence that never existed.
            ->whereIn('status', ['active', 'suspended', 'revoked'])
            ->orderByDesc('revision')
            ->first();

        if ($licence === null) {
            // Indistinguishable from "no such book", on purpose.
            return response()->json(['message' => 'Not found.'], 404);
        }

        $installation = $this->registerInstallation(
            $licence,
            $validated['installation_id'],
            $validated['device_name'] ?? null,
        );

        $claims = [
            'licence_id' => $licence->uuid,
            'user_id' => (string) $user->id,
            'book_id' => (string) $book->id,
            'installation_id' => $installation->installation_id,
            'status' => $installation->revoked_at !== null ? 'revoked' : $licence->status,
            'tier' => $licence->tier,
            // ISO-8601 with an explicit offset, because an unsigned local time
            // would be ambiguous across a timezone change. `null` for a perpetual
            // licence, which is distinct from an empty string.
            'expires_at' => $licence->expires_at?->toIso8601String(),
            'next_validation_at' => $this->nextValidationAt($licence),
            'revision' => $licence->revision,
            // The server's own clock at signing. The desktop uses this as the
            // trusted time for its rollback detection.
            'issued_at' => now()->toIso8601String(),
        ];

        $signed = $this->signer->sign($claims);

        return response()->json([
            'claims' => $signed['claims'],
            'signature' => $signed['signature'],
            'public_key' => $signed['public_key'],
        ]);
    }

    /**
     * When the desktop must next revalidate.
     *
     * **Never later than the expiry**, because a licence that has expired must not
     * be kept alive by a generous revalidation window. Whichever is sooner wins.
     */
    private function nextValidationAt(Licence $licence): ?string
    {
        $days = $licence->revalidate_after_days;

        if ($days === null) {
            // No revalidation window means the licence is valid until it expires,
            // so the deadline *is* the expiry.
            return $licence->expires_at?->toIso8601String();
        }

        $candidate = now()->addDays($days);

        if ($licence->expires_at !== null && $candidate->gt($licence->expires_at)) {
            return $licence->expires_at->toIso8601String();
        }

        return $candidate->toIso8601String();
    }

    /**
     * Register this installation against the licence, or find it already recorded.
     *
     * ## `firstOrNew`, not `updateOrCreate`
     *
     * `updateOrCreate` **does** overwrite every attribute it is given, so passing
     * `first_registered_at => now()` would reset it on every revalidation and the
     * column would answer "when did this device last talk to us" while claiming to
     * answer "when was this device first licensed" -- which is the question a
     * support call about a long-held licence actually asks.
     *
     * So the row is found or created first, and `first_registered_at` is set only
     * when it is genuinely new.
     */
    private function registerInstallation(
        Licence $licence,
        string $installationId,
        ?string $deviceName,
    ): RegisteredDesktopInstallation {
        $installation = RegisteredDesktopInstallation::query()
            ->firstOrNew(['installation_id' => $installationId]);

        $isNew = ! $installation->exists;

        $installation->licence_id = $licence->id;
        $installation->company_id = $licence->company_id;

        if ($deviceName !== null) {
            $installation->device_name = $deviceName;
        }

        if ($isNew) {
            $installation->first_registered_at = now();
        }

        $installation->last_seen_at = now();
        $installation->save();

        return $installation;
    }
}
