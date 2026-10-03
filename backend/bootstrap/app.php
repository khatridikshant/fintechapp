<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        /**
         * Never try to redirect an unauthenticated API request.
         *
         * ## The bug this fixes
         *
         * `Authenticate::unauthenticated()` builds a redirect URL before it throws,
         * and Laravel's default target is `route('login')`. **This application has
         * no `login` route** — it is API-only — so that lookup throws
         * `RouteNotFoundException`, which *replaces* the `AuthenticationException`.
         *
         * The observable result: **every request to a protected endpoint with no
         * token returned `500 Route [login] not defined`** instead of `401`.
         *
         * `shouldRenderJsonWhen` below does not help, because it only decides how an
         * exception is *rendered* — the exception is never reached, because building
         * the redirect target threw first.
         *
         * Returning `null` for API paths makes the middleware throw the
         * `AuthenticationException` as intended, which then renders as a `401` with
         * a JSON body. The desktop depends on that status: it maps `401` to "sign in
         * again", and anything else to "the server could not be reached".
         *
         * Found by running the desktop's live checks against a real server. No test
         * covered it, because every authentication test sends *some* token — an
         * invalid token gives `401` correctly, and only a **tokenless** request hit
         * the redirect.
         */
        $middleware->redirectGuestsTo(
            fn (Request $request) => $request->is('api/*') ? null : '/',
        );
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );
    })->create();
