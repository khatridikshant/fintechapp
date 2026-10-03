<?php

namespace App\Models;

use Database\Factories\CompanyFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * A registered business.
 *
 * ## Why this is separate from `User`
 *
 * A company is a legal entity and a user is the person who signs in. The two come
 * apart as soon as more than one person touches the books -- an owner and an
 * accountant, or an accountant acting for several clients. Keeping the PAN on
 * `users` would encode "one taxpayer per person" into the schema, which is not a
 * fact about businesses.
 *
 * V1 gives one company to one account, matching the one-book-per-account limit in
 * ADR 003. Neither is a constraint of these tables; both are facts about how far
 * the product currently goes.
 *
 * ## Why the PAN is here at all
 *
 * Until now the PAN existed only inside the uploaded SQLite, which the server
 * treats as an opaque blob. That had three consequences: the server could not show
 * a user their registered business name, could not detect two accounts claiming
 * the same taxpayer, and could not file anything on their behalf. Holding the PAN
 * server-side is what makes any of those possible, and it is why `pan` is unique.
 */
#[Fillable(['name', 'pan', 'vat_registered'])]
class Company extends Model
{
    /** @use HasFactory<CompanyFactory> */
    use HasFactory;

    /**
     * The accounts acting for this company.
     *
     * Plural for the same reason `User::books()` is: one account today, several
     * later, and no migration when that happens.
     */
    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }

    /**
     * The licences held for this business.
     *
     * Normally one, but not constrained to one: a `licences` table rather than
     * columns on `companies` is what lets a licence be suspended or revoked
     * without deleting the history of what was granted.
     */
    public function licences(): HasMany
    {
        return $this->hasMany(Licence::class);
    }

    public function subscriptions(): HasMany
    {
        return $this->hasMany(Subscription::class);
    }

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            /**
             * A real boolean, not `'0'`/`'1'` strings.
             *
             * This is not cosmetic: a VAT-registered business charging no VAT is
             * not a valid tax invoice, so code that tests this flag must not be
             * reading `"0"`, which is truthy in PHP.
             */
            'vat_registered' => 'boolean',
        ];
    }
}
