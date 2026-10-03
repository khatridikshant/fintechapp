<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One paid period against a licence.
 *
 * ## Amounts are integer minor units
 *
 * BigInteger, never a float, for the same reason the whole project forbids `double`
 * for money: 0.1 + 0.2 is not 0.3 in binary floating point, and a subscription
 * total computed that way is a figure that cannot be reconciled with an invoice.
 *
 * ## `ended_at` rather than a delete
 *
 * Ending a subscription early records when, because "this was paid for and then
 * stopped" is itself a fact. Deleting the row would make a refunded period
 * indistinguishable from one that never existed.
 */
#[Fillable([
    'licence_id',
    'company_id',
    'starts_at',
    'ends_at',
    'amount_minor_units',
    'currency',
    'ended_at',
])]
class Subscription extends Model
{
    protected $casts = [
        'starts_at' => 'immutable_datetime',
        'ends_at' => 'immutable_datetime',
        'ended_at' => 'immutable_datetime',
        'amount_minor_units' => 'integer',
    ];

    public function licence(): BelongsTo
    {
        return $this->belongsTo(Licence::class);
    }

    /**
     * Whether this period covers the given moment.
     *
     * Half-open, `start <= t < end`, so adjacent periods never both claim the
     * same instant -- the boundary belongs to exactly one of them.
     */
    public function covers(\DateTimeInterface $at): bool
    {
        if ($this->ended_at !== null) {
            return false;
        }

        return $at >= $this->starts_at && $at < $this->ends_at;
    }
}
