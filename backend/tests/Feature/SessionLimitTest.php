<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\SessionLimit;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * The newest-`max_devices` rule, tested without HTTP in the way.
 *
 * The policy exists so two computers cannot hold divergent books, which nothing
 * in this codebase could detect or reconcile. Two properties matter and both are
 * easy to break:
 *
 * 1. **The newest session survives.** Getting this backwards would sign the user
 *    out of the machine they just signed in on.
 * 2. **A stale session revokes itself.** Sign-in is authenticated by the password,
 *    not by a token, so signing in always succeeds -- which is what keeps a token
 *    left behind by a machine that no longer exists from locking the owner out
 *    permanently.
 */
class SessionLimitTest extends TestCase
{
    use RefreshDatabase;

    private function issue(User $user, string $device): int
    {
        return (int) $user->createToken($device)->accessToken->getKey();
    }

    public function test_a_single_session_is_left_alone(): void
    {
        $user = User::factory()->create();
        $first = $this->issue($user, 'office');

        app(SessionLimit::class)->apply($user, $first);

        $this->assertSame(1, $user->tokens()->count());
    }

    public function test_a_second_sign_in_revokes_the_first(): void
    {
        $user = User::factory()->create();
        $office = $this->issue($user, 'office');
        $laptop = $this->issue($user, 'laptop');

        $revoked = app(SessionLimit::class)->apply($user, $laptop);

        $this->assertSame(1, $revoked, 'the earlier session should have been revoked');
        $this->assertSame([$laptop], $user->tokens()->pluck('id')->all());
        $this->assertNotContains($office, $user->tokens()->pluck('id')->all());
    }

    public function test_the_token_being_issued_is_never_revoked(): void
    {
        // Getting this backwards signs the user out of the machine they just
        // signed in on, which reads as a mysterious failure on the first upload.
        $user = User::factory()->create();
        $office = $this->issue($user, 'office');
        $laptop = $this->issue($user, 'laptop');

        app(SessionLimit::class)->apply($user, $laptop);

        $this->assertTrue($user->tokens()->whereKey($laptop)->exists());
    }

    public function test_a_raised_limit_keeps_the_newest_n(): void
    {
        $user = User::factory()->create();
        $user->forceFill(['max_devices' => 2])->save();

        $first = $this->issue($user, 'one');
        $second = $this->issue($user, 'two');
        $third = $this->issue($user, 'three');

        app(SessionLimit::class)->apply($user, $third);

        // The newest two survive: `three`, and the one before it.
        $this->assertEqualsCanonicalizing(
            [$second, $third],
            $user->tokens()->pluck('id')->all(),
        );
        $this->assertNotContains($first, $user->tokens()->pluck('id')->all());
    }

    public function test_a_limit_of_one_is_the_default(): void
    {
        // The policy the product ships with. Asserted so a change to the column
        // default is a test failure rather than a silent behaviour change.
        $this->assertSame(1, (int) User::factory()->create()->fresh()->max_devices);
    }

    public function test_another_accounts_sessions_are_untouched(): void
    {
        // The limit is per account. A user signing in must not evict an unrelated
        // user, which is the failure mode of scoping the delete carelessly.
        $mine = User::factory()->create();
        $theirs = User::factory()->create();

        $theirToken = $this->issue($theirs, 'theirs');
        $myToken = $this->issue($mine, 'mine');

        app(SessionLimit::class)->apply($mine, $myToken);

        $this->assertTrue($theirs->tokens()->whereKey($theirToken)->exists());
    }
}
