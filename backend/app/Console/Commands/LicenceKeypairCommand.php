<?php

namespace App\Console\Commands;

use App\Support\LicenceSigner;
use Illuminate\Console\Command;

/**
 * Generates the Ed25519 keypair the licence signer uses.
 *
 * ## Why this exists
 *
 * The private key must never reach the desktop (ADR 006, ADR 014), so there has
 * to be a moment where it is generated and kept on the server. Doing that by hand
 * with the wrong length or the wrong encoding produces a licence signer that
 * fails at runtime rather than at setup, so it is a command.
 *
 * ## What it prints
 *
 * Both halves, clearly labelled, and the public key base64 is the value that gets
 * compiled into the desktop as a constant. It is printed rather than generated
 * silently so the constant comes from real output rather than from a value typed
 * by hand.
 */
class LicenceKeypairCommand extends Command
{
    protected $signature = 'financeapp:licence-keypair
                            {--show : Print the existing public key instead of generating a new pair}';

    protected $description = 'Generate the Ed25519 keypair used to sign licence authorisations';

    public function handle(): int
    {
        if ($this->option('show')) {
            try {
                $signer = new LicenceSigner;
            } catch (\Throwable $e) {
                $this->error($e->getMessage());

                return self::FAILURE;
            }

            $this->line('Public key (compile into the desktop): '.$signer->publicKeyBase64());

            return self::SUCCESS;
        }

        $pair = sodium_crypto_sign_keypair();

        $this->error('A new keypair invalidates every licence already issued.');
        $this->warn('Only generate one now if no licence has been issued yet, or if you are prepared to reissue every licence.');

        if (! $this->confirm('Generate a new keypair anyway?', false)) {
            $this->line('Cancelled. Nothing was changed.');

            return self::SUCCESS;
        }

        $seed = sodium_crypto_sign_secretkey($pair);
        $seedOnly = mb_substr($seed, 0, LicenceSigner::SEED_BYTES);

        $this->newLine();
        $this->info('FINANCEAPP_LICENCE_PRIVATE_KEY (private -- backend/.env only, never commit):');
        $this->line(base64_encode($seedOnly));
        $this->newLine();
        $this->info('Public key (compile into the desktop as a constant):');
        $this->line(base64_encode(sodium_crypto_sign_publickey($pair)));
        $this->newLine();
        $this->comment(
            'Rotate by shipping a new desktop build: the public key is compiled in, '
            .'so changing it server-side alone would make every installed copy reject every licence.'
        );

        return self::SUCCESS;
    }
}
