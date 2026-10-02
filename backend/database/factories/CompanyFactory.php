<?php

namespace Database\Factories;

use App\Models\Company;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Company>
 */
class CompanyFactory extends Factory
{
    protected $model = Company::class;

    /**
     * A nine-digit PAN, unique per factory call.
     *
     * `pan` is unique in the database, so a fixed value would collide the moment
     * two companies are created in one test -- and a collision there is a failure
     * about the test rather than about the code.
     *
     * Generated from a counter rather than randomly so the value looks like a PAN
     * (nine digits, no leading zero) and stays reproducible in a failure message.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        static $next = 0;
        $next++;

        return [
            'name' => fake()->company(),
            'pan' => str_pad((string) (100000000 + $next), 9, '0', STR_PAD_LEFT),
            'vat_registered' => false,
        ];
    }

    /**
     * A business registered for VAT.
     */
    public function vatRegistered(): static
    {
        return $this->state(fn (array $attributes): array => [
            'vat_registered' => true,
        ]);
    }
}
