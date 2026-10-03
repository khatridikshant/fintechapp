<?php

namespace Database\Factories;

use App\Models\Company;
use App\Models\Licence;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Licence>
 */
class LicenceFactory extends Factory
{
    protected $model = Licence::class;

    /**
     * A licence granting the right to run the software.
     *
     * Defaults to **an unexpired active licence**, because that is the state a test
     * almost always wants. A test that needs an expired, suspended, or revoked
     * licence says so explicitly -- a fixture whose default is a working licence
     * means a test that forgets to set up its case tests nothing.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'uuid' => (string) Str::uuid(),
            'company_id' => Company::factory(),
            'tier' => 'standard',
            'status' => 'active',
            'expires_at' => now()->addYear(),
            // 30 days, so a licence that is never revalidated fails closed rather
            // than running forever on a stale authorisation.
            'revalidate_after_days' => 30,
            'revision' => 1,
        ];
    }

    /**
     * A licence that has run out.
     */
    public function expired(): static
    {
        return $this->state(fn (): array => [
            'expires_at' => now()->subDay(),
        ]);
    }

    /**
     * A licence with no expiry at all.
     *
     * `expires_at` null, which is distinct from an expiry of zero: it is what a
     * perpetual grant looks like, and inventing an expiry would lock a paying
     * customer out.
     */
    public function perpetual(): static
    {
        return $this->state(fn (): array => [
            'expires_at' => null,
            'revalidate_after_days' => null,
        ]);
    }

    public function suspended(): static
    {
        return $this->state(fn (): array => ['status' => 'suspended']);
    }
}
