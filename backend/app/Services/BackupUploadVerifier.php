<?php

namespace App\Services;

/**
 * The outcome of checking a received snapshot.
 *
 * A result object rather than a boolean, because a refusal has to be able to
 * say *why*, and "the upload was invalid" is not something a user can act on.
 */
final class BackupVerification
{
    private function __construct(
        public readonly bool $isValid,
        public readonly ?string $reason,
        public readonly ?string $actualChecksum,
        public readonly ?int $actualSize,
    ) {}

    public static function valid(string $checksum, int $size): self
    {
        return new self(true, null, $checksum, $size);
    }

    public static function invalid(string $reason, ?string $actualChecksum = null, ?int $actualSize = null): self
    {
        return new self(false, $reason, $actualChecksum, $actualSize);
    }
}

/**
 * Checks that a received snapshot is genuinely a sound SQLite database.
 *
 * The specification is unambiguous: **an unverified upload is never treated as a
 * valid backup.** So every check below is mandatory, and the first one to fail
 * stops the upload. Nothing is written to storage and no metadata row is created
 * unless all four pass.
 *
 * Order matters, and is cheapest-and-safest first:
 *
 * 1. **Magic header.** Only a file beginning `SQLite format 3\0` is a database.
 *    Checked first so nothing else ever touches a file that is not one.
 * 2. **Size.** The size the client declared must be the size that arrived.
 * 3. **Checksum.** The SHA-256 the client computed must match the bytes received.
 *    This is the strong check: it catches a truncated transfer, a corrupted
 *    sector, and a substituted file.
 * 4. **Integrity.** SQLite itself is asked whether the file is undamaged.
 *
 * ## A note on step 4
 *
 * Opening a received file with SQLite means parsing data from outside. That is
 * why it is the **last** check, why the file is opened read-only, and why every
 * failure is caught and turned into a refusal rather than allowed to surface.
 * By the time this step runs, the file has already been confirmed to be a
 * SQLite database whose SHA-256 matches what a trusted client said it sent.
 */
final class BackupUploadVerifier
{
    private const SQLITE_MAGIC = "SQLite format 3\0";

    private const MAGIC_LENGTH = 16;

    /**
     * Verify a received snapshot against what the client declared.
     *
     * @param  string  $declaredChecksum  SHA-256 the desktop computed.
     * @param  int  $declaredSize  Size the desktop recorded.
     */
    public function verify(string $path, string $declaredChecksum, int $declaredSize): BackupVerification
    {
        if (! is_readable($path)) {
            return BackupVerification::invalid('The uploaded file could not be read.');
        }

        // 1. Only a SQLite database is a candidate.
        $header = file_get_contents($path, false, null, 0, self::MAGIC_LENGTH);
        if ($header === false || ! str_starts_with((string) $header, self::SQLITE_MAGIC)) {
            return BackupVerification::invalid(
                'The uploaded file is not a SQLite database.'
            );
        }

        // 2. The declared size must match what arrived.
        $actualSize = (int) filesize($path);
        if ($actualSize !== $declaredSize) {
            return BackupVerification::invalid(
                sprintf(
                    'The upload is %d bytes but the desktop recorded %d. The file '
                    .'was truncated or changed in transit.',
                    $actualSize,
                    $declaredSize,
                ),
                null,
                $actualSize,
            );
        }

        // 3. The declared checksum must match the bytes received.
        $actualChecksum = hash_file('sha256', $path);
        if ($actualChecksum === false) {
            return BackupVerification::invalid('The uploaded file could not be checksummed.');
        }
        if (! hash_equals(strtolower($declaredChecksum), strtolower($actualChecksum))) {
            return BackupVerification::invalid(
                'The upload does not match the checksum the desktop recorded. '
                .'It was corrupted or replaced in transit.',
                $actualChecksum,
                $actualSize,
            );
        }

        // 4. SQLite's own opinion of the file.
        return $this->integrityCheck($path, $actualChecksum, $actualSize);
    }

    /**
     * Ask SQLite whether the file is undamaged.
     *
     * Opened read-only, and every failure is contained. A file that cannot be
     * opened, or that reports damage, is refused rather than stored.
     */
    private function integrityCheck(string $path, string $checksum, int $size): BackupVerification
    {
        try {
            $pdo = new \PDO('sqlite:'.$path, null, null, [
                \PDO::ATTR_ERRMODE => \PDO::ERRMODE_EXCEPTION,
                \PDO::ATTR_TIMEOUT => 5,
            ]);

            // Belt and braces: refuse to write even if something later tries to.
            $pdo->exec('PRAGMA query_only = ON');

            $result = $pdo->query('PRAGMA integrity_check')?->fetch(\PDO::FETCH_ASSOC);

            if (! is_array($result) || ($result['integrity_check'] ?? null) !== 'ok') {
                return BackupVerification::invalid(
                    'SQLite reports the uploaded file as damaged.',
                    $checksum,
                    $size,
                );
            }
        } catch (\Throwable $e) {
            return BackupVerification::invalid(
                'The uploaded file could not be opened as a database: '.$e->getMessage(),
                $checksum,
                $size,
            );
        }

        return BackupVerification::valid($checksum, $size);
    }
}
