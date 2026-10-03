<?php

namespace Tests\Feature;

use App\Models\Book;
use App\Models\Company;
use App\Models\Licence;
use App\Models\RegisteredDesktopInstallation;
use App\Models\User;
use App\Support\LicenceSigner;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * The licence authorisation endpoint, and the signing it depends on.
 */
class LicenceAuthorisationTest extends TestCase
{
    use RefreshDatabase;

    private ?string $licenceSeed = null;

    protected function setUp(): void
    {
        parent::setUp();

        // **Forced here, not lazily.** The container builds its own `LicenceSigner`
        // from config when the endpoint is hit, so the key has to be configured
        // before the request rather than on first use by a helper. The generation
        // itself stays lazy so the framework's reflection reset of typed
        // properties cannot leave it uninitialised.
        $this->licenceSeed();
    }

    /**
     * A real Ed25519 seed, generated lazily and memoised for the test.
     *
     * A fresh keypair per test means no test can pass by reusing another's
     * signature, and libsodium needs no configuration at all -- which is why ADR
     * 014 chose it.
     */
    private function licenceSeed(): string
    {
        if ($this->licenceSeed === null) {
            $this->licenceSeed = random_bytes(LicenceSigner::SEED_BYTES);

            config([
                'financeapp.licence_private_key' => base64_encode($this->licenceSeed),
            ]);
        }

        return $this->licenceSeed;
    }

    private function signer(): LicenceSigner
    {
        return new LicenceSigner(base64_encode($this->licenceSeed));
    }

    /**
     * The endpoint URL with the installation passed as a **query parameter**.
     *
     * A GET has no body, so `getJson($uri, $data)` would send this as a query
     * string anyway -- but passing a second argument reads like a body and fails
     * validation confusingly, so the URL is explicit.
     */
    private function url(Book $book, ?string $installationId = null): string
    {
        $id = $installationId ?? (string) Str::uuid();

        return "/api/books/{$book->id}/licence-authorisation?installation_id={$id}";
    }

    public function test_it_signs_an_authorisation_for_the_callers_book(): void
    {
        [$user, $book, $licence] = $this->arrange();

        $response = $this->actingAs($user, 'sanctum')->getJson($this->url($book));

        $response->assertOk();
        $response->assertJsonStructure(['claims', 'signature', 'public_key']);

        // **The claims are verified against the public key**, not merely present.
        // An endpoint returning a plausible-looking blob would pass a
        // structure-only assertion, and every desktop would then fail closed with
        // nothing to point at.
        $claims = $this->parseClaims($response->json('claims'));

        $this->assertTrue(
            $this->signer()->verify($claims, $response->json('signature')),
            'the issued signature must verify against the issuing key',
        );
        $this->assertSame($licence->uuid, $claims['licence_id']);
        $this->assertSame('active', $claims['status']);
    }

    public function test_it_will_not_sign_for_someone_elses_book(): void
    {
        [, $book] = $this->arrange();
        $intruder = User::factory()->create();

        $this->actingAs($intruder, 'sanctum')
            ->getJson($this->url($book))
            ->assertNotFound();
    }

    public function test_it_requires_authentication(): void
    {
        [, $book] = $this->arrange();

        $this->getJson($this->url($book))->assertUnauthorized();
    }

    public function test_a_company_with_no_licence_gets_not_found(): void
    {
        // Indistinguishable from an unknown book, on purpose: confirming which
        // taxpayers are licensed is itself a disclosure.
        [$user, $book] = $this->arrange(withLicence: false);

        $this->actingAs($user, 'sanctum')
            ->getJson($this->url($book))
            ->assertNotFound();
    }

    public function test_it_requires_an_installation_id(): void
    {
        [$user, $book] = $this->arrange();

        $this->actingAs($user, 'sanctum')
            ->getJson("/api/books/{$book->id}/licence-authorisation")
            ->assertJsonValidationErrors('installation_id');
    }

    public function test_the_expiry_is_inside_the_signature(): void
    {
        // **The claim that matters.** A user editing the stored expiry must
        // invalidate the signature rather than extend their own entitlement.
        [$user, $book, $licence] = $this->arrange();
        $licence->update(['expires_at' => now()->addDays(30)]);

        $response = $this->actingAs($user, 'sanctum')->getJson($this->url($book));

        $claims = $this->parseClaims($response->json('claims'));
        $signature = $response->json('signature');

        // Tamper with the stored expiry only.
        $tampered = $claims;
        $tampered['expires_at'] = now()->addYears(50)->toIso8601String();

        $this->assertTrue(
            $this->signer()->verify($claims, $signature),
            'the genuine claims must verify',
        );
        $this->assertFalse(
            $this->signer()->verify($tampered, $signature),
            'an extended expiry must NOT verify',
        );
    }

    public function test_next_validation_is_never_later_than_expiry(): void
    {
        // A generous revalidation window must not keep an expired licence alive.
        [$user, $book, $licence] = $this->arrange();
        $licence->update([
            'expires_at' => now()->addDays(2),
            'revalidate_after_days' => 365,
        ]);

        $response = $this->actingAs($user, 'sanctum')->getJson($this->url($book));

        $claims = $this->parseClaims($response->json('claims'));

        $this->assertLessThanOrEqual(
            strtotime((string) $claims['expires_at']),
            strtotime((string) $claims['next_validation_at']),
            'revalidation must not outlast the licence',
        );
    }

    public function test_a_revoked_installation_is_signed_as_revoked(): void
    {
        [$user, $book] = $this->arrange();
        $installationId = (string) Str::uuid();

        $this->actingAs($user, 'sanctum')
            ->getJson($this->url($book, $installationId))
            ->assertOk();

        RegisteredDesktopInstallation::query()
            ->where('installation_id', $installationId)
            ->update(['revoked_at' => now()]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson($this->url($book, $installationId));

        $claims = $this->parseClaims($response->json('claims'));

        $this->assertSame('revoked', $claims['status']);
    }

    public function test_a_returning_device_keeps_its_first_registered_date(): void
    {
        [$user, $book] = $this->arrange();
        $installationId = (string) Str::uuid();

        $this->actingAs($user, 'sanctum')
            ->getJson($this->url($book, $installationId));

        $first = RegisteredDesktopInstallation::query()
            ->where('installation_id', $installationId)
            ->first()
            ->first_registered_at;

        $this->travel(3)->days();

        $this->actingAs($user, 'sanctum')
            ->getJson($this->url($book, $installationId));

        $row = RegisteredDesktopInstallation::query()
            ->where('installation_id', $installationId)
            ->first();

        // **Not overwritten on update.** How long a machine has held a licence is
        // answered by this column, so an update that reset it would make the
        // answer wrong.
        $this->assertTrue($first->equalTo($row->first_registered_at));
    }

    public function test_the_installation_id_is_bound_into_the_signature(): void
    {
        // An authorisation issued for one machine must not verify for another.
        [$user, $book] = $this->arrange();
        $installationId = (string) Str::uuid();

        $response = $this->actingAs($user, 'sanctum')
            ->getJson($this->url($book, $installationId));

        $claims = $this->parseClaims($response->json('claims'));
        $this->assertSame($installationId, $claims['installation_id']);

        $tampered = $claims;
        $tampered['installation_id'] = (string) Str::uuid();

        $this->assertFalse(
            $this->signer()->verify($tampered, $response->json('signature')),
            'an authorisation must not transfer to another machine',
        );
    }

    public function test_a_signature_from_a_different_key_does_not_verify(): void
    {
        [$user, $book] = $this->arrange();

        $response = $this->actingAs($user, 'sanctum')->getJson($this->url($book));

        $otherSigner = new LicenceSigner(
            base64_encode(random_bytes(LicenceSigner::SEED_BYTES)),
        );

        $this->assertFalse(
            $otherSigner->verify(
                $this->parseClaims($response->json('claims')),
                $response->json('signature'),
            ),
            "a signature must not verify under someone else's key",
        );
    }

    public function test_a_tampered_signature_does_not_verify(): void
    {
        [$user, $book] = $this->arrange();

        $response = $this->actingAs($user, 'sanctum')->getJson($this->url($book));
        $claims = $this->parseClaims($response->json('claims'));

        $signature = base64_decode($response->json('signature'), true);
        // Flip one bit of the last byte.
        $signature[63] = chr(ord($signature[63]) ^ 0x01);

        $this->assertFalse(
            $this->signer()->verify($claims, base64_encode($signature)),
        );
    }

    public function test_claim_order_does_not_change_the_signed_bytes(): void
    {
        // **Order-independent by construction.** Claims are emitted in sorted key
        // order, so the same facts produce the same bytes however the caller built
        // the map. Without that, verification would fail at random depending on
        // insertion order.
        $this->assertSame(
            LicenceSigner::canonicalise(['b' => '2', 'a' => '1']),
            LicenceSigner::canonicalise(['a' => '1', 'b' => '2']),
        );
    }

    public function test_a_null_claim_is_distinct_from_an_empty_one(): void
    {
        // "no expiry" and "expires at the empty string" must not collide, or an
        // attacker could drop an expiry claim and keep a valid signature.
        $this->assertNotSame(
            LicenceSigner::canonicalise(['expires_at' => null]),
            LicenceSigner::canonicalise(['expires_at' => '']),
        );
    }

    /**
     * @return array{0: User, 1: Book, 2: Licence|null}
     */
    private function arrange(bool $withLicence = true): array
    {
        $company = Company::factory()->create();
        $user = User::factory()->create([
            'company_id' => $company->id,
        ]);
        $book = Book::factory()->create([
            'user_id' => $user->id,
        ]);

        $licence = $withLicence
            ? Licence::factory()->create([
                'company_id' => $company->id,
                'status' => 'active',
                'expires_at' => now()->addDays(30),
            ])
            : null;

        return [$user, $book, $licence];
    }

    /**
     * Turns the canonical signed string back into the claim map.
     *
     * `null` is a bare key and an empty value is `key=`, so the two are
     * distinguishable -- the property that stops "no expiry" and "expires at
     * nothing" colliding.
     *
     * @return array<string, string|null>
     */
    private function parseClaims(string $claims): array
    {
        $parsed = [];

        foreach (explode("\n", $claims) as $line) {
            if ($line === '') {
                continue;
            }

            $equals = strpos($line, '=');

            if ($equals === false) {
                $parsed[$line] = null;

                continue;
            }

            $parsed[substr($line, 0, $equals)] = substr($line, $equals + 1);
        }

        return $parsed;
    }
}
