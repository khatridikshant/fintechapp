<?php

namespace App\Support;

use RuntimeException;
use SodiumException;

/**
 * Signs and verifies licence authorisations with Ed25519.
 *
 * ## Why Ed25519 and not an HMAC
 *
 * ADR 006 requires the desktop to hold only a *public* key, so that a user who
 * inspects the application cannot mint their own valid licence. An HMAC cannot
 * do this: verification and signing need the same secret, so any installation that
 * can check a signature can also produce one.
 *
 * ## Why this class adds no dependency
 *
 * PHP ships libsodium. `sodium_crypto_sign_detached` and
 * `sodium_crypto_sign_keypair` were both verified present on this machine before
 * this was written, so the signing side needs no Composer package at all. Only the
 * desktop verifier needs a Dart dependency (ADR 014).
 *
 * ## What is signed, and why it is a canonical string
 *
 * Every field that decides whether the licence is valid is inside the signed
 * payload: licence id, user, book, status, expiry, next validation, revision, and
 * device. A user editing the stored expiry therefore invalidates the signature
 * rather than extending their own entitlement.
 *
 * The payload is built as **ordered `key=value` lines joined by newlines**, not as
 * JSON. JSON's key order is not guaranteed, so two encoders could produce
 * different bytes for identical claims and verification would fail at random. An
 * explicit ordered format makes the signed bytes a pure function of the claims.
 */
class LicenceSigner
{
    /** Bytes in an Ed25519 seed (the private key). */
    public const SEED_BYTES = SODIUM_CRYPTO_SIGN_SEEDBYTES;

    /** Bytes in an Ed25519 public key. */
    public const PUBLIC_KEY_BYTES = SODIUM_CRYPTO_SIGN_PUBLICKEYBYTES;

    /** Bytes in an Ed25519 detached signature. */
    public const SIGNATURE_BYTES = SODIUM_CRYPTO_SIGN_BYTES;

    private string $privateKey;

    private string $publicKey;

    public function __construct(?string $privateKey = null, ?string $publicKey = null)
    {
        // Read from config first, then env, so a test can inject a keypair without
        // writing to the process environment (which is global and would leak
        // between tests).
        $privateKey ??= (string) (config('financeapp.licence_private_key')
            ?: env('FINANCEAPP_LICENCE_PRIVATE_KEY'));

        // Absent is reported as a missing key rather than silently producing an
        // invalid signature: a server that cannot sign must fail loudly, or it
        // would hand out authorisations no desktop can verify, and every client
        // would fail closed at once with nothing to point at.
        if ($privateKey === '') {
            throw new RuntimeException(
                'FINANCEAPP_LICENCE_PRIVATE_KEY is not set. Run '
                .'php artisan financeapp:licence-keypair and put the value in .env.'
            );
        }

        $seed = self::base64Decode($privateKey, 'FINANCEAPP_LICENCE_PRIVATE_KEY');

        if (strlen($seed) !== self::SEED_BYTES) {
            throw new RuntimeException(
                'FINANCEAPP_LICENCE_PRIVATE_KEY must be '
                .self::SEED_BYTES
                .' bytes base64-encoded (a 32-byte Ed25519 seed); got '
                .strlen($seed)
                .' bytes.'
            );
        }

        // `sodium_crypto_sign_seed_keypair` returns **96 bytes** -- the 32-byte seed
        // with the 32-byte public key appended -- not the 64-byte secret key that
        // `sodium_crypto_sign_detached` requires. Passing the pair straight
        // through therefore fails at signing time with a length error and nothing
        // else, so the secret key is extracted explicitly.
        $pair = sodium_crypto_sign_seed_keypair($seed);

        $secretKey = sodium_crypto_sign_secretkey($pair);

        // Derived from the seed rather than supplied separately, so the two can
        // never disagree. A separate public key in .env would be one more thing to
        // get wrong, and the failure would be every desktop rejecting every licence.
        $this->privateKey = $secretKey;
        $this->publicKey = sodium_crypto_sign_publickey($pair);

        if ($publicKey !== null && $publicKey !== '' && self::base64Decode($publicKey, 'public key') !== $this->publicKey) {
            throw new RuntimeException(
                'The supplied licence public key does not match the private key. '
                .'These must be a pair from the same keypair command.'
            );
        }
    }

    /**
     * The base64 public key, for compiling into the desktop build.
     */
    public function publicKeyBase64(): string
    {
        return base64_encode($this->publicKey);
    }

    /**
     * Signs a set of claims.
     *
     * @param  array<string, scalar|null>  $claims
     * @return array{claims: string, signature: string, public_key: string}
     */
    public function sign(array $claims): array
    {
        $payload = self::canonicalise($claims);

        try {
            $signature = sodium_crypto_sign_detached($payload, $this->privateKey);
        } catch (SodiumException $e) {
            // Should be unreachable once the key length is validated, but a signing
            // failure must not be returned as an unsigned authorisation.
            throw new RuntimeException('Licence signing failed: '.$e->getMessage(), 0, $e);
        }

        return [
            'claims' => $payload,
            'signature' => base64_encode($signature),
            'public_key' => $this->publicKeyBase64(),
        ];
    }

    /**
     * Verifies a signed authorisation. Used by the tests, and available for any
     * server-side audit of what was issued.
     *
     * Returns false rather than throwing on a bad signature, because a caller
     * checking a token must treat "not genuine" as an ordinary answer.
     *
     * @param  array<string, scalar|null>  $claims
     */
    public function verify(array $claims, string $signatureBase64): bool
    {
        $signature = self::base64Decode($signatureBase64, 'signature');

        if (strlen($signature) !== self::SIGNATURE_BYTES) {
            return false;
        }

        try {
            // **Note the argument order.** `sodium_crypto_sign_detached` takes
            // (message, secret_key) but `sodium_crypto_sign_verify_detached` takes
            // (signature, message, public_key) -- signature *first*. The asymmetry
            // is real and is easy to get backwards; passing the message first
            // fails with a confusing "signature must be 64 bytes long" error
            // rather than a wrong-argument error, because the message happens to be
            // the wrong length.
            return sodium_crypto_sign_verify_detached(
                $signature,
                self::canonicalise($claims),
                $this->publicKey,
            );
        } catch (SodiumException) {
            return false;
        }
    }

    /**
     * Builds the exact bytes that get signed.
     *
     * ## Ordered, and null-distinct from empty
     *
     * Keys are emitted in **sorted** order so two runs with the same claims in a
     * different insertion order still sign identical bytes. A `null` is written as
     * a bare key with no `=`, which is distinct from `key=` for an empty string —
     * so "no expiry" and "expires at the empty string" cannot collide, and an
     * attacker cannot drop an expiry claim and keep a valid signature.
     *
     * @param  array<string, scalar|null>  $claims
     */
    public static function canonicalise(array $claims): string
    {
        ksort($claims);

        $parts = [];
        foreach ($claims as $key => $value) {
            $parts[] = $value === null ? $key : $key.'='.$value;
        }

        return implode("\n", $parts);
    }

    /**
     * Decodes base64 strictly, so a truncated or corrupted key is reported rather
     * than silently accepted as a shorter one.
     */
    private static function base64Decode(string $value, string $what): string
    {
        $decoded = base64_decode(strtr($value, '-_', '+/'), true);

        if ($decoded === false) {
            throw new RuntimeException(
                'The licence '.$what.' is not valid base64.'
            );
        }

        return $decoded;
    }
}
