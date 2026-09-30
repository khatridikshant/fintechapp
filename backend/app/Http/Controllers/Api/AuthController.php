<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Book;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

/**
 * Issues and revokes the tokens the desktop application authenticates with.
 *
 * The specification makes the backend "the authoritative source for user
 * accounts", so this is the only place a desktop identity is created. Until it
 * exists no client can obtain a token, and every other authenticated route is
 * unreachable.
 *
 * **This is token issuance only, not licensing.** The specification also requires
 * a cryptographically signed licence authorisation carrying subscription status,
 * expiry, and a device binding, verified offline against a public key. That is a
 * separate capability and is deliberately not approximated here, because a
 * half-built licence check that looks authoritative is worse than none.
 */
class AuthController extends Controller
{
    /**
     * The shortest password accepted.
     *
     * A passphrase rather than a password: it is easier to remember and longer,
     * which is the property that actually resists guessing.
     */
    private const MIN_PASSWORD_LENGTH = 12;

    /**
     * The name given to a token when the desktop does not say which device it is.
     *
     * ADR 003 allows one active desktop installation per account, so the server
     * has to be able to name what is asking. "unknown" is a placeholder, not a
     * silent default that hides a missing field.
     */
    private const UNKNOWN_DEVICE = 'unknown-device';

    /**
     * A bcrypt hash of a value no password will match.
     *
     * Used to spend the same work on an unknown account as on a real one, so the
     * two cannot be told apart by how long the answer takes. It is a **real
     * bcrypt hash held as a literal**, not a placeholder and not `Hash::make()`:
     * hashing at request time would add cost to only one branch, and a malformed
     * string makes `password_verify` return immediately (measured: ~0.04 ms
     * against ~191 ms for a real hash), which would defeat the purpose entirely.
     */
    private const DUMMY_PASSWORD_HASH =
        '$2y$12$qpMkYxp3sNWQ02842ZH0H.aObGQTm5j8nJI/iEOpOTqLKmPjHU.ni';

    /**
     * `  Sita@Example.COM ` becomes `sita@example.com`, **before validation**.
     *
     * Applied to the request rather than to the value on its way into the
     * database, so the `email` rule, the `unique` rule, and the stored value all
     * see the same string. Normalising only at insertion would let a
     * differently-cased duplicate pass the uniqueness check and then violate the
     * unique index — a 500 instead of a clean refusal.
     *
     * A `FormRequest` would express this as `prepareForValidation`, but these
     * endpoints validate inline like the rest of the API, and `$request->validate()`
     * does not call that hook.
     */
    private function normaliseEmailOn(Request $request): void
    {
        if ($request->has('email')) {
            $request->merge([
                'email' => strtolower(trim((string) $request->input('email'))),
            ]);
        }
    }

    /**
     * Create an account and sign the first installation in.
     */
    public function register(Request $request): JsonResponse
    {
        $this->normaliseEmailOn($request);

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:'.self::MIN_PASSWORD_LENGTH, 'confirmed'],
            'device_name' => ['nullable', 'string', 'max:255'],
        ], [
            // **Deliberately does not say "already taken".** Login was written so
            // that an unknown address and a wrong password are indistinguishable,
            // and a registration error confirming that an address exists would
            // hand back exactly that information. This wording reveals only that
            // the details were refused. A 422-versus-201 difference still shows
            // *something* was wrong, so making registration fully
            // non-enumerating would need an email-verification flow, which is not
            // built and is not pretended to be.
            'email.unique' => 'An account cannot be created with those details.',
        ]);

        $user = User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'password' => $validated['password'],
        ]);

        // ADR 003: one book per account. Created here because the desktop has
        // nothing to upload a backup against until a book exists.
        $book = $user->books()->create(['name' => 'Primary']);

        return response()->json([
            'token' => $this->issue($user, $validated['device_name'] ?? null),
            'user' => $this->describe($user),
            'book' => $this->describeBook($book),
        ], 201);
    }

    /**
     * Sign in and issue a token.
     */
    public function login(Request $request): JsonResponse
    {
        $this->normaliseEmailOn($request);

        $validated = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
            'device_name' => ['nullable', 'string', 'max:255'],
        ]);

        $user = User::where('email', $validated['email'])->first();

        // **The unknown account and the wrong password must be indistinguishable,
        // including in how long they take.** Short-circuiting on a missing user
        // would return without paying bcrypt, so an unknown address would answer
        // measurably faster than a real one with a wrong password — the same
        // information the identical message is there to withhold. Comparing
        // against a fixed dummy hash costs the same work either way.
        $matches = Hash::check(
            $validated['password'],
            $user?->password ?? self::DUMMY_PASSWORD_HASH,
        );

        if (! $user || ! $matches) {
            throw ValidationException::withMessages([
                'email' => ['These credentials do not match our records.'],
            ]);
        }

        return response()->json([
            'token' => $this->issue($user, $validated['device_name'] ?? null),
            'user' => $this->describe($user),
            'book' => $this->describeBook($user->books()->first()),
        ]);
    }

    /**
     * Revoke the token this request used, and only this one.
     *
     * Signing out of the office desktop must not sign the user out of the
     * laptop, so every other token is left alone.
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Signed out.']);
    }

    /**
     * Who is signed in, and which books they may act on.
     *
     * The desktop calls this to check a stored token is still good. Discovering
     * a revoked token here is a prompt to sign in; discovering it by attempting
     * an upload is a failed backup.
     */
    public function me(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            'user' => $this->describe($user),
            'books' => $user->books()->get()->map(fn (Book $book) => $this->describeBook($book)),
        ]);
    }

    /**
     * Mint a token for this installation.
     */
    private function issue(User $user, ?string $deviceName): string
    {
        return $user->createToken($deviceName ?: self::UNKNOWN_DEVICE)->plainTextToken;
    }

    /**
     * The user as the desktop sees them. The password is never included: it is
     * hashed, and returning it even hashed would be pointless exposure.
     *
     * @return array<string, mixed>
     */
    private function describe(User $user): array
    {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function describeBook(?Book $book): ?array
    {
        return $book ? ['id' => $book->id, 'name' => $book->name] : null;
    }
}
