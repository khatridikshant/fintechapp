<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

/**
 * The durable right to run the software for a company.
 *
 * ## A licence is not a subscription
 *
 * A subscription is one payment period; a licence is the right those periods add
 * up to. They are separate tables (ADR 014) so that `expires_at` is a fact about
 * the licence rather than something overwritten every time a payment lands, which
 * makes the current entitlement answerable without summing periods.
 *
 * ## `uuid` is the public identifier, never the id
 *
 * The sequential primary key would let one holder guess another's licence by
 * counting. The uuid is what the desktop stores and quotes.
 *
 * ## Status is data, not a branch in code
 *
 * `active`, `suspended`, `revoked`: a suspended licence is one that has stopped
 * working but is expected to return, so it is distinguished from a revoked one.
 * Both stop the desktop; they differ in what a human is told.
 */
#[Fillable([
    'uuid',
    'company_id',
    'tier',
    'status',
    'expires_at',
    'revalidate_after_days',
    'revision',
])]
class Licence extends Model
{
    /** @use HasFactory<LicenceFactory> */
    use HasFactory;

    protected $casts = [
        'expires_at' => 'immutable_datetime',
        'revalidate_after_days' => 'integer',
        'revision' => 'integer',
    ];

    /**
     * Fills the public `uuid` when a row is created without one.
     *
     * **The key stays an auto-increment integer and the uuid is a separate
     * column.** Making the uuid the primary key was tried and removed: with
     * `HasUuids` plus `keyType = 'string'` against a bigint auto-increment `id`,
     * Eloquent would try to treat the missing uuid as the key and the row would
     * not insert at all.
     *
     * The two are separated anyway, which is the reason this model wants a uuid:
     * a sequential id must never be the public identifier, or one holder could
     * guess another's licence by counting.
     */
    protected static function booted(): void
    {
        static::creating(function (Licence $licence): void {
            $licence->uuid ??= (string) Str::uuid();
        });
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    public function subscriptions(): HasMany
    {
        return $this->hasMany(Subscription::class);
    }

    public function installations(): HasMany
    {
        return $this->hasMany(RegisteredDesktopInstallation::class);
    }
}
