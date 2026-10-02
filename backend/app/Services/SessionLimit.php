<?php

namespace App\Services;

use App\Models\User;

/**
 * Keeps at most `max_devices` sessions alive per account.
 *
 * ## The rule
 *
 * On sign-in, keep the newest `max_devices` sessions and revoke everything older.
 * At the default of 1 that is strictly **newest-wins**: whoever signs in last owns
 * the account.
 *
 * ## Why the session itself is never revoked, only older ones
 *
 * **Login is authenticated by the password, not by a token.** So signing in always
 * succeeds, whatever state the previous sessions are in -- which means a token
 * left behind by a machine that no longer exists (reinstalled, replaced, stolen,
 * or simply never signed out) revokes *itself* on the next sign-in instead of
 * locking the owner out permanently.
 *
 * That is the property that makes a hard limit safe here. A limit that *refused*
 * sign-in when the allowance was already spent would strand the account behind a
 * session nobody could revoke, with no recovery and no diagnostic.
 *
 * ## Why the limit is data rather than a constant
 *
 * So that granting a second device is a data change rather than a code change.
 * It is fixed at 1 for now with nothing that can change it: an account holder who
 * could raise its own limit would make the limit not one.
 */
class SessionLimit
{
    /**
     * Apply the limit to [user], keeping [keepTokenId] alive.
     *
     * @param  int  $keepTokenId  the token just issued, which is never revoked
     * @return int the number of sessions revoked
     */
    public function apply(User $user, int $keepTokenId): int
    {
        $keep = max(1, (int) $user->max_devices);

        // Never revoke the token being issued. Revoking it would leave the caller
        // holding a token the server has already deleted, which reads as a
        // successful sign-in followed by a mysterious failure on the first upload.
        $others = $user->tokens()
            ->where('id', '!=', $keepTokenId)
            ->orderByDesc('id')
            ->pluck('id')
            ->all();

        if ($others === []) {
            return 0;
        }

        // The newest `keep - 1` of the rest survive, because the new token is
        // itself one of the `keep`.
        //
        // **Computed in PHP rather than with `skip()`/`offset()` on the query.**
        // An offset needs a limit beside it in SQLite, and asking the database for
        // "the first N of the rest" obscures a rule that is easier to read as a
        // list than as pagination.
        $survivors = array_slice($others, 0, $keep - 1);
        $revoke = array_values(array_diff($others, $survivors));

        if ($revoke === []) {
            return 0;
        }

        return $user->tokens()->whereIn('id', $revoke)->delete();
    }
}
