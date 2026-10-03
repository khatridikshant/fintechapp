<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One device that has been registered against a licence.
 *
 * ## Revoked, never deleted
 *
 * A revoked installation is kept with `revoked_at` set rather than removed. If a
 * revoked machine were simply deleted, the next authorisation request would
 * re-register it and count as a brand-new device -- so revoking it would silently
 * do nothing the second time.
 *
 * ## `installation_id` is the installation's own identifier
 *
 * Supplied by the desktop, unique across the server, and never trusted as
 * identity on its own: it is still checked against the licence's device allowance
 * before an authorisation is signed.
 */
#[Fillable([
    'licence_id',
    'company_id',
    'installation_id',
    'device_name',
    'first_registered_at',
    'last_seen_at',
    'revoked_at',
])]
class RegisteredDesktopInstallation extends Model
{
    protected $casts = [
        'first_registered_at' => 'immutable_datetime',
        'last_seen_at' => 'immutable_datetime',
        'revoked_at' => 'immutable_datetime',
    ];

    public function licence(): BelongsTo
    {
        return $this->belongsTo(Licence::class);
    }

    /**
     * Whether this machine may still run the application.
     */
    public function isLive(): bool
    {
        return $this->revoked_at === null;
    }
}
