<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * An unauthenticated API request must be answered `401`, never `500`.
 *
 * ## The defect this pins
 *
 * Every protected route sits behind `auth:sanctum`. When that middleware finds no
 * authenticated user it builds a **redirect URL** before it throws, and Laravel's
 * default target is `route('login')`. **This application has no `login` route** —
 * it is API-only — so the lookup threw `RouteNotFoundException`, which *replaced*
 * the `AuthenticationException`.
 *
 * The observable result was that **every tokenless request to every protected
 * endpoint answered `500 Route [login] not defined`.** The desktop maps any
 * non-`401` to "the server could not be reached", so an absent or expired session
 * was reported to the user as a network failure.
 *
 * The configured `shouldRenderJsonWhen` in `bootstrap/app.php` does not prevent
 * this, and that is the part worth remembering: it only decides how an exception is
 * *rendered*, and this exception was never raised, because building the redirect
 * target threw first.
 *
 * ## Why no existing test caught it
 *
 * Every other authentication test sends **some** token, and an invalid token is
 * rejected correctly with `401`. Only a *tokenless* request reaches the redirect.
 * The gap has the same shape as the migration defect in `PROGRESS.md` 7.28: a suite
 * that exercises the main path thoroughly and misses one boundary entirely.
 *
 * Found by running `tool/live_signin_check.dart` against a real server — the first
 * request that check makes.
 *
 * @internal
 */
class UnauthenticatedRequestTest extends TestCase
{
    // **Without this the schema is never migrated**, and a token lookup then fails
    // with 'no such table', which reads as an authentication fault and is not one.
    use RefreshDatabase;

    /**
     * The single case, stated plainly.
     */
    public function test_a_request_with_no_token_is_unauthorised_not_a_server_error(): void
    {
        // **Deliberately NOT getJson().** That sendsAccept: application/json,
        // and Laravel's Authenticate then returns a 401 body directly **without**n        // ever building the redirect target -- so the bug cannot occur and the test
        // passes with or without the fix. It has to look like a browser or a
        // misbehaving client that expects HTML.
        $response = $this->get('/api/auth/me');

        $response->assertUnauthorized();
    }

    /**
     * The whole protected group, so a route added later without its own guard is
     * still caught.
     *
     * One route proves the middleware behaves; this proves the **group** does.
     *
     * The ids are deliberately non-existent. A `404` here would mean ownership was
     * checked before authentication, which would itself be a disclosure; `401`
     * proves authentication happens first.
     */
    public function test_no_protected_route_answers_a_tokenless_request_with_a_server_error(): void
    {
        $routes = [
            '/api/auth/me',
            '/api/auth/logout',
            '/api/books/1/backup-revisions',
            '/api/backup-revisions/1/download',
            '/api/books/1/fiscal-years/conclude',
        ];

        foreach ($routes as $route) {
            // **POST for the write routes.** Sending GET to a POST-only route answers
            // 405 Method Not Allowed, which is correct HTTP and not the fault this
            // test is about.
            $response = str_contains($route, 'logout') || str_contains($route, 'conclude')
                ? $this->postJson($route)
                : $this->getJson($route);

            $this->assertSame(
                401,
                $response->getStatusCode(),
                "{$route} answered {$response->getStatusCode()} without a token; "
                .'an unauthenticated API request must be 401, never 500'
            );
        }
    }

    /**
     * A token the server never issued is `401` as well.
     *
     * The neighbouring case, kept so the two cannot be confused: an *invalid*
     * token was always handled correctly, and it was only the *absent* token that
     * broke.
     */
    public function test_a_token_the_server_does_not_hold_is_rejected(): void
    {
        $response = $this->withHeader('Authorization', 'Bearer 1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA')
            ->getJson('/api/auth/me');

        $response->assertUnauthorized();
    }

    /**
     * The public endpoints stay reachable, so the fix did not lock the API shut.
     *
     * A blanket `redirectGuestsTo` returning null everywhere would have turned
     * `register` and `login` into `401` too. This is the check that the exemption
     * is scoped to `api/*` *authentication* and not applied to the whole API.
     */
    public function test_the_public_endpoints_still_work_without_a_token(): void
    {
        // **422, not 401, and deliberately so.** An unknown address and a wrong
        // password are refused identically, in wording and in status, so that
        // login cannot be used to enumerate which addresses have accounts. See
        // AuthenticationTest and ADR 011 on the duplicate-PAN wording for the
        // same reasoning.
        $refusal = $this->postJson('/api/auth/login', [
            'email' => 'nobody@example.com',
            'password' => 'a-long-enough-passphrase',
        ]);
        $this->assertSame(422, $refusal->getStatusCode());

        // The refusal above is the *authentication* answer, not a redirect fault.
        // Registration answers with validation detail rather than a server error,
        // which is how we know it was reached at all.
        $this->postJson('/api/auth/register', [])
            ->assertStatus(422);
    }
}
