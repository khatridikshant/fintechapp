<?php

namespace Tests\Feature;

use App\Models\Book;
use App\Models\Company;
use App\Models\Licence;
use App\Models\User;
use App\Support\LicenceSigner;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * The desktop's URL and parameter names, asserted against the real routes.
 *
 * **The point is to catch a drift, not to re-test signing.** `LicenceAuthorisationTest`
 * covers the signing; this pins the contract the two halves share, which is the
 * thing that breaks silently when either side is edited.
 */
class LicenceRouteContractTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_route_the_desktop_calls_exists(): void
    {
        // **The exact path in
        // `HttpLicenceAuthorisationClient`: /api/books/{book}/licence-authorisation.**
        // If the backend route moves and the desktop does not, the desktop gets a
        // 404 and reports "no licence" -- which sends the user to their supplier
        // when the fault is a renamed route.
        $routes = collect(app('router')->getRoutes())->map(
            fn ($r) => implode('|', $r->methods()).' '.$r->uri(),
        );

        $this->assertTrue(
            $routes->contains(fn ($r) => str_contains($r, 'api/books/{book}/licence-authorisation')),
            'the desktop calls api/books/{book}/licence-authorisation; '
            .'registered routes are: '.$routes->implode(', '),
        );
    }

    public function test_it_rejects_an_installation_id_that_is_not_a_uuid(): void
    {
        // **Why the desktop formats its installation id as a UUID.** An earlier
        // version produced 'inst-<32 hex>' -- stable and unique, but rejected by
        // this rule, so every sign-in would have failed with a 422 and no licence
        // would ever be issued. The failure looks like a server fault, so it is
        // pinned here from the server's side too.
        config(['financeapp.licence_private_key' => base64_encode(random_bytes(LicenceSigner::SEED_BYTES))]);

        $company = Company::factory()->create();
        $user = User::factory()->create(['company_id' => $company->id]);
        $book = Book::factory()->create(['user_id' => $user->id]);
        Licence::factory()->create(['company_id' => $company->id]);

        $this->actingAs($user, 'sanctum')->getJson(
            "/api/books/{$book->id}/licence-authorisation?installation_id=inst-abc123",
        )->assertJsonValidationErrors('installation_id');
    }

    public function test_it_accepts_the_uuid_form_the_desktop_sends(): void
    {
        config(['financeapp.licence_private_key' => base64_encode(random_bytes(LicenceSigner::SEED_BYTES))]);

        $company = Company::factory()->create();
        $user = User::factory()->create(['company_id' => $company->id]);
        $book = Book::factory()->create(['user_id' => $user->id]);
        Licence::factory()->create(['company_id' => $company->id]);

        $this->actingAs($user, 'sanctum')->getJson(
            // **The shape `_installationId()` produces**: 8-4-4-4-12 hex.
            "/api/books/{$book->id}/licence-authorisation?installation_id="
                .(string) Str::uuid(),
        )->assertOk();
    }
}
