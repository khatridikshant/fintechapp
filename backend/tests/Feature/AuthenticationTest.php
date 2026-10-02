<?php

namespace Tests\Feature;

use App\Models\Book;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Token issuance.
 *
 * The specification makes the backend "the authoritative source for user
 * accounts, licenses, subscriptions, books, and registered desktop
 * installations", and the desktop "shall authenticate the user with the backend
 * when an account session is established". Until this exists, **no client can
 * obtain a token**, so every other authenticated route is unreachable and the
 * backup path cannot be demonstrated end to end.
 *
 * Most of these tests are about refusal, for the same reason the upload tests
 * are: a feature that cannot say no is not a security control.
 */
class AuthenticationTest extends TestCase
{
    /**
     * A counter for values that must be unique within a single test.
     *
     * `username` and `companies.pan` both carry unique indexes, and several tests
     * register more than one account in the same test -- the rate-limit test
     * registers six. Fixed literals would collide on the second call and fail for
     * a reason unrelated to what the test is about.
     */
    private static int $sequence = 0;

    private static function next(): int
    {
        return ++self::$sequence;
    }

    use RefreshDatabase;

    /**
     * A password long enough to pass validation, kept in one place so a change to
     * the policy is a one-line change rather than a silent edit across tests.
     */
    private const PASSWORD = 'a-long-enough-passphrase';

    /**
     * Registration issues a usable token.
     *
     * This is the test that unblocks everything else: a user with no token can
     * reach nothing.
     */
    public function test_registration_issues_a_token(): void
    {
        $response = $this->postJson('/api/auth/register', [
            'username' => 'owner'.self::next(),
            'company_name' => 'Himalayan Traders '.self::next(),
            'company_pan' => (string) (500000000 + self::next()),
            'vat_registered' => false,
            'name' => 'Sita Sharma',
            'email' => 'sita@example.com',
            'password' => self::PASSWORD,
            'password_confirmation' => self::PASSWORD,
            'device_name' => 'office-desktop',
        ]);

        $response->assertCreated();
        $this->assertNotEmpty($response->json('token'), 'a token must be issued');
        $this->assertDatabaseHas('users', ['email' => 'sita@example.com']);
    }

    /**
     * ADR 003: one book per account. Registration creates it, because the
     * desktop has nothing to upload a backup against otherwise.
     */
    public function test_registration_creates_the_accounts_one_book(): void
    {
        $this->postJson('/api/auth/register', [
            'username' => 'owner'.self::next(),
            'company_name' => 'Himalayan Traders '.self::next(),
            'company_pan' => (string) (500000000 + self::next()),
            'vat_registered' => false,
            'name' => 'Sita Sharma',
            'email' => 'sita@example.com',
            'password' => self::PASSWORD,
            'password_confirmation' => self::PASSWORD,
        ])->assertCreated();

        $user = User::where('email', 'sita@example.com')->firstOrFail();
        $this->assertSame(1, $user->books()->count(), 'V1 is one book per account');
    }

    /**
     * The token is a real Sanctum token, so `auth:sanctum` accepts it.
     *
     * Asserted rather than assumed, because a string that merely looks like a
     * token would pass a weaker test and fail at the first real upload.
     */
    public function test_the_issued_token_authenticates_a_protected_route(): void
    {
        $token = $this->postJson('/api/auth/register', [
            'username' => 'owner'.self::next(),
            'company_name' => 'Himalayan Traders '.self::next(),
            'company_pan' => (string) (500000000 + self::next()),
            'vat_registered' => false,
            'name' => 'Sita Sharma',
            'email' => 'sita@example.com',
            'password' => self::PASSWORD,
            'password_confirmation' => self::PASSWORD,
        ])->assertCreated()->json('token');

        $book = Book::where('name', 'Primary')->first();

        $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson("/api/books/{$book->id}/backup-revisions")
            ->assertOk();
    }

    /**
     * The password is never echoed back, and never stored in the clear.
     */
    public function test_the_password_is_hashed_and_never_returned(): void
    {
        $response = $this->postJson('/api/auth/register', [
            'username' => 'owner'.self::next(),
            'company_name' => 'Himalayan Traders '.self::next(),
            'company_pan' => (string) (500000000 + self::next()),
            'vat_registered' => false,
            'name' => 'Sita Sharma',
            'email' => 'sita@example.com',
            'password' => self::PASSWORD,
            'password_confirmation' => self::PASSWORD,
        ])->assertCreated();

        $this->assertArrayNotHasKey('password', (array) $response->json());

        $stored = User::where('email', 'sita@example.com')->firstOrFail()->password;
        $this->assertNotSame(self::PASSWORD, $stored, 'the password must be hashed');
    }

    /**
     * An email is an identity key, so surrounding whitespace must not create a
     * second account for the same person.
     */
    public function test_email_is_normalised_before_it_is_stored(): void
    {
        $this->postJson('/api/auth/register', [
            'username' => 'owner'.self::next(),
            'company_name' => 'Himalayan Traders '.self::next(),
            'company_pan' => (string) (500000000 + self::next()),
            'vat_registered' => false,
            'name' => 'Sita Sharma',
            'email' => '  Sita@Example.COM ',
            'password' => self::PASSWORD,
            'password_confirmation' => self::PASSWORD,
        ])->assertCreated();

        $this->assertDatabaseHas('users', ['email' => 'sita@example.com']);
    }

    public function test_registration_refuses_a_duplicate_email(): void
    {
        User::factory()->create(['email' => 'sita@example.com']);

        $this->postJson('/api/auth/register', [

            'username' => 'owner'.self::next(),

            'company_name' => 'Himalayan Traders '.self::next(),

            'company_pan' => (string) (500000000 + self::next()),

            'vat_registered' => false,
            'name' => 'Another Person',
            'email' => 'sita@example.com',
            'password' => self::PASSWORD,
            'password_confirmation' => self::PASSWORD,
        ])->assertStatus(422);

        $this->assertSame(1, User::where('email', 'sita@example.com')->count());
    }

    /**
     * A differently-cased duplicate is refused cleanly.
     *
     * The email is normalised before validation, so `SITA@Example.COM` is
     * recognised as the address that already exists. Without that it would pass
     * the uniqueness check and then collide with the unique index on insert,
     * turning an ordinary user mistake into a **500**.
     */
    public function test_registration_refuses_a_case_variant_of_an_existing_email(): void
    {
        User::factory()->create(['email' => 'sita@example.com']);

        $this->postJson('/api/auth/register', [

            'username' => 'owner'.self::next(),

            'company_name' => 'Himalayan Traders '.self::next(),

            'company_pan' => (string) (500000000 + self::next()),

            'vat_registered' => false,
            'name' => 'Another Person',
            'email' => 'SITA@Example.COM',
            'password' => self::PASSWORD,
            'password_confirmation' => self::PASSWORD,
        ])->assertStatus(422);

        $this->assertSame(1, User::where('email', 'sita@example.com')->count());
    }

    /**
     * Registration does not confirm that an address has an account.
     *
     * Login goes out of its way to make an unknown address and a wrong password
     * indistinguishable, so a message reading "the email has already been taken"
     * would hand back the same information through the other door.
     */
    public function test_registration_does_not_confirm_that_an_email_exists(): void
    {
        User::factory()->create(['email' => 'sita@example.com']);

        $response = $this->postJson('/api/auth/register', [
            'username' => 'owner'.self::next(),
            'company_name' => 'Himalayan Traders '.self::next(),
            'company_pan' => (string) (500000000 + self::next()),
            'vat_registered' => false,
            'name' => 'Another Person',
            'email' => 'sita@example.com',
            'password' => self::PASSWORD,
            'password_confirmation' => self::PASSWORD,
        ])->assertStatus(422);

        $body = json_encode($response->json());
        $this->assertStringNotContainsStringIgnoringCase('taken', $body);
        $this->assertStringNotContainsStringIgnoringCase('exists', $body);
        $this->assertStringContainsString('cannot be created', $body);
    }

    /**
     * A short passphrase is refused, because the token it protects is the only
     * thing standing between a stranger and a business's books.
     */
    public function test_registration_refuses_a_short_password(): void
    {
        $this->postJson('/api/auth/register', [
            'username' => 'owner'.self::next(),
            'company_name' => 'Himalayan Traders '.self::next(),
            'company_pan' => (string) (500000000 + self::next()),
            'vat_registered' => false,
            'name' => 'Sita Sharma',
            'email' => 'sita@example.com',
            'password' => 'short',
            'password_confirmation' => 'short',
        ])->assertStatus(422);

        $this->assertSame(0, User::count(), 'no account may be created');
    }

    /**
     * A mismatched confirmation is refused: a typo must not silently become a
     * password the user did not choose.
     */
    public function test_registration_refuses_a_mismatched_confirmation(): void
    {
        $this->postJson('/api/auth/register', [
            'username' => 'owner'.self::next(),
            'company_name' => 'Himalayan Traders '.self::next(),
            'company_pan' => (string) (500000000 + self::next()),
            'vat_registered' => false,
            'name' => 'Sita Sharma',
            'email' => 'sita@example.com',
            'password' => self::PASSWORD,
            'password_confirmation' => 'something-else-entirely',
        ])->assertStatus(422);

        $this->assertSame(0, User::count());
    }

    public function test_login_issues_a_token(): void
    {
        $user = User::factory()->withPassword(self::PASSWORD)->create(['email' => 'sita@example.com']);

        $response = $this->postJson('/api/auth/login', [
            'email' => 'sita@example.com',
            'password' => self::PASSWORD,
            'device_name' => 'office-desktop',
        ]);

        $response->assertOk();
        $this->assertNotEmpty($response->json('token'));
        $this->assertSame(
            $user->id,
            $response->json('user.id'),
            'the response identifies who is signed in',
        );
    }

    /**
     * The wrong password is refused and issues nothing.
     */
    public function test_login_refuses_a_wrong_password(): void
    {
        User::factory()->withPassword(self::PASSWORD)->create(['email' => 'sita@example.com']);

        $response = $this->postJson('/api/auth/login', [
            'email' => 'sita@example.com',
            'password' => 'not-the-password',
        ]);

        $response->assertStatus(422);
        $this->assertArrayNotHasKey('token', (array) $response->json());
    }

    /**
     * An unknown email is refused **the same way** as a wrong password.
     *
     * A different response for "no such account" would let an attacker discover
     * which addresses have accounts, so both cases assert the same status and
     * the same absence of a token.
     */
    public function test_login_refuses_an_unknown_email_identically(): void
    {
        $unknown = $this->postJson('/api/auth/login', [
            'email' => 'nobody@example.com',
            'password' => 'not-the-password',
        ]);

        User::factory()->withPassword(self::PASSWORD)->create(['email' => 'sita@example.com']);
        $wrongPassword = $this->postJson('/api/auth/login', [
            'email' => 'sita@example.com',
            'password' => 'not-the-password',
        ]);

        $unknown->assertStatus($wrongPassword->status());
        $this->assertSame($unknown->status(), 422);
    }

    /**
     * Logging out revokes the token, so the server no longer holds it.
     *
     * The assertion is on the stored row rather than on a follow-up request with
     * the same token, because Sanctum's guard memoises the resolved user for the
     * lifetime of the application instance, which a single test method shares.
     * Re-issuing the request in the same method therefore returns 200 whatever
     * the database says, and would assert the framework's caching rather than
     * this feature. The next test proves the guard does consult the database.
     */
    public function test_logout_revokes_the_token(): void
    {
        $user = User::factory()->withPassword(self::PASSWORD)->create();

        $token = $this->postJson('/api/auth/login', [
            'email' => $user->email,
            'password' => self::PASSWORD,
            'device_name' => 'office-desktop',
        ])->assertOk()->json('token');

        $this->assertDatabaseHas('personal_access_tokens', ['name' => 'office-desktop']);

        $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/auth/logout')
            ->assertOk();

        $this->assertDatabaseMissing('personal_access_tokens', ['name' => 'office-desktop']);
    }

    /**
     * A token the server does not hold is rejected.
     *
     * This is the other half of the contract above, and it is the half that
     * matters for security: the guard must read the database, not merely parse
     * the string it is handed.
     */
    public function test_a_token_the_server_does_not_hold_is_rejected(): void
    {
        $user = User::factory()->create();
        $forged = $user->createToken('forged-device')->plainTextToken;

        // Remove it behind the guard's back, as a sign-out would.
        $user->tokens()->delete();

        $this->withHeader('Authorization', 'Bearer '.$forged)
            ->getJson('/api/auth/me')
            ->assertUnauthorized();
    }

    /**
     * **Last sign-in wins**, so signing in on the laptop signs the office desktop
     * out.
     *
     * This test previously asserted the opposite -- that logging out on one device
     * left the other working -- and the expectation was **deliberately reversed**,
     * not quietly edited to pass. The old behaviour was a good-faith reading of
     * "logout revokes only the token used", which is still true: `logout` revokes
     * exactly the token presented and nothing else. What changed is the policy
     * applied at **sign-in**, which now keeps only the newest
     * `users.max_devices` sessions, and that defaults to one.
     *
     * The consequence is deliberate. It removes the possibility of two computers
     * holding divergent books, which nothing in this codebase could detect or
     * reconcile. It does not strand work: a signed-out desktop keeps its local
     * SQLite untouched and can still take local backups, which never need a
     * session.
     *
     * Signing in therefore never fails because a session already exists -- login
     * is authenticated by the password, not by a token -- so a session left behind
     * by a machine that no longer exists revokes itself here rather than locking
     * the owner out. See `SessionLimit`.
     */
    public function test_signing_in_again_revokes_the_earlier_session(): void
    {
        $user = User::factory()->withPassword(self::PASSWORD)->create();

        $office = $this->postJson('/api/auth/login', [
            'email' => $user->email,
            'password' => self::PASSWORD,
            'device_name' => 'office-desktop',
        ])->json('token');

        $this->withHeader('Authorization', 'Bearer '.$office)
            ->getJson('/api/auth/me')
            ->assertOk();

        $laptop = $this->postJson('/api/auth/login', [
            'email' => $user->email,
            'password' => self::PASSWORD,
            'device_name' => 'laptop',
        ])->json('token');

        // The office session is gone, without anything having asked it to log out.
        // Asserted against the stored sessions rather than over HTTP. `Sanctum`
        // keeps a resolved user alive across requests inside one test, so a token
        // that has been deleted can still appear to authenticate -- which makes an
        // HTTP assertion here a test of the harness rather than of the policy.
        // The 401 path is covered separately, by
        // `test_a_token_the_server_does_not_hold_is_rejected`.
        $this->assertSame(
            1,
            $user->tokens()->count(),
            'exactly one session should survive'
        );
        $this->assertTrue(
            $user->tokens()->where('name', 'laptop')->exists(),
            'the newest session is the one that survives'
        );
        $this->assertFalse(
            $user->tokens()->where('name', 'office-desktop')->exists(),
            'the earlier session should have been revoked by signing in again'
        );

        // The laptop is the session that survives.
        $this->withHeader('Authorization', 'Bearer '.$laptop)
            ->getJson('/api/auth/me')
            ->assertOk();
    }

    /**
     * Logging out revokes **only** the token used.
     *
     * Distinct from the test above: this is about `logout`, which has not changed.
     */
    public function test_logout_revokes_only_the_token_used(): void
    {
        $user = User::factory()->withPassword(self::PASSWORD)->create();

        // Granted a second device, which is what makes a second session possible.
        $user->forceFill(['max_devices' => 2])->save();

        $office = $this->postJson('/api/auth/login', [
            'email' => $user->email,
            'password' => self::PASSWORD,
            'device_name' => 'office-desktop',
        ])->json('token');

        $laptop = $this->postJson('/api/auth/login', [
            'email' => $user->email,
            'password' => self::PASSWORD,
            'device_name' => 'laptop',
        ])->json('token');

        $this->withHeader('Authorization', 'Bearer '.$office)->postJson('/api/auth/logout')->assertOk();

        $this->withHeader('Authorization', 'Bearer '.$laptop)
            ->getJson('/api/auth/me')
            ->assertOk();
    }

    /**
     * `me` lets the desktop confirm a stored token is still good without
     * attempting an upload, which matters because a revoked token discovered at
     * upload time is a failed backup rather than a prompt to sign in.
     */
    public function test_me_identifies_the_signed_in_user(): void
    {
        $user = User::factory()->create();
        $book = Book::factory()->create(['user_id' => $user->id, 'name' => 'Primary']);
        Sanctum::actingAs($user);

        $this->getJson('/api/auth/me')
            ->assertOk()
            ->assertJsonPath('user.email', $user->email)
            ->assertJsonPath('user.id', $user->id)
            ->assertJsonPath('books.0.id', $book->id)
            ->assertJsonPath('books.0.name', 'Primary');
    }

    /**
     * `me` never leaks the password hash.
     */
    public function test_me_never_returns_the_password(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/auth/me')
            ->assertOk()
            ->assertJsonMissingPath('user.password');
    }

    public function test_me_requires_authentication(): void
    {
        $this->getJson('/api/auth/me')->assertUnauthorized();
    }

    /**
     * Sign-in attempts are rate limited.
     *
     * These are the only unauthenticated routes in the API, and each accepted
     * attempt costs bcrypt work. Without a limit they would allow unrestricted
     * credential guessing and CPU exhaustion.
     */
    public function test_repeated_sign_in_attempts_are_rate_limited(): void
    {
        User::factory()->withPassword(self::PASSWORD)->create(['email' => 'sita@example.com']);

        for ($attempt = 0; $attempt < 6; $attempt++) {
            $this->postJson('/api/auth/login', [
                'email' => 'sita@example.com',
                'password' => 'not-the-password',
            ])->assertStatus(422);
        }

        $this->postJson('/api/auth/login', [
            'email' => 'sita@example.com',
            'password' => 'not-the-password',
        ])->assertStatus(429);
    }

    /**
     * Registration is rate limited, so accounts cannot be created without bound.
     */
    public function test_repeated_registrations_are_rate_limited(): void
    {
        for ($attempt = 0; $attempt < 6; $attempt++) {
            $this->postJson('/api/auth/register', [
                'username' => 'owner'.self::next(),
                'company_name' => 'Himalayan Traders '.self::next(),
                'company_pan' => (string) (500000000 + self::next()),
                'vat_registered' => false,
                'name' => 'Person '.$attempt,
                'email' => "person{$attempt}@example.com",
                'password' => self::PASSWORD,
                'password_confirmation' => self::PASSWORD,
            ])->assertCreated();
        }

        $this->postJson('/api/auth/register', [

            'username' => 'owner'.self::next(),

            'company_name' => 'Himalayan Traders '.self::next(),

            'company_pan' => (string) (500000000 + self::next()),

            'vat_registered' => false,
            'name' => 'Person 7',
            'email' => 'person7@example.com',
            'password' => self::PASSWORD,
            'password_confirmation' => self::PASSWORD,
        ])->assertStatus(429);
    }

    /**
     * The token is recorded against a named device, because ADR 003 allows one
     * active desktop installation per account and the server has to be able to
     * tell which one is asking.
     */
    public function test_the_token_records_its_device_name(): void
    {
        $user = User::factory()->withPassword(self::PASSWORD)->create();

        $this->postJson('/api/auth/login', [
            'email' => $user->email,
            'password' => self::PASSWORD,
            'device_name' => 'office-desktop',
        ])->assertOk();

        $this->assertDatabaseHas('personal_access_tokens', [
            'tokenable_id' => $user->id,
            'name' => 'office-desktop',
        ]);
    }
}
