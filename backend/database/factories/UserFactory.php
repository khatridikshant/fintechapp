<?php

namespace Database\Factories;

use App\Models\Company;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    /**
     * The current password being used by the factory.
     */
    protected static ?string $password;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'name' => fake()->name(),
            'email' => fake()->unique()->safeEmail(),
            // **Unique**, because users.username has a unique index. unique() is
            // necessary rather than merely tidy: two factories created in one test
            // would otherwise collide on a NOT NULL and UNIQUE column and fail for a
            // reason that has nothing to do with the test.
            'username' => fake()->unique()->userName(),
            'email_verified_at' => now(),
            // A company, because company_id is set for every registered account.
            // Nullable in the schema only so the column could be added without
            // stranding existing rows mid-migration.
            'company_id' => Company::factory(),
            'password' => static::$password ??= Hash::make('password'),
            'remember_token' => Str::random(10),
        ];
    }

    /**
     * Indicate that the model's email address should be unverified.
     */
    public function unverified(): static
    {
        return $this->state(fn (array $attributes) => [
            'email_verified_at' => null,
        ]);
    }

    /**
     * A user with a known password.
     *
     * Login tests need to present a real credential, and the default `'password'`
     * is too short to satisfy the registration policy, so it cannot be used to
     * stand in for a passphrase. The model's `hashed` cast does the hashing, so
     * the plaintext is passed in.
     */
    public function withPassword(string $password): static
    {
        return $this->state(fn (array $attributes) => [
            'password' => $password,
        ]);
    }
}
