<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Licence signing key
    |--------------------------------------------------------------------------
    |
    | The base64 Ed25519 seed the server signs licence authorisations with.
    |
    | **The private key lives here and nowhere else.** The desktop holds only the
    | matching public key, compiled in, which is what lets it verify a licence
    | offline without being able to mint one (ADR 006, ADR 014).
    |
    | Generate a pair with `php artisan financeapp:licence-keypair`, which prints
    | the value to paste here. Keep it out of version control: `backend/.env` is
    | already ignored.
    |
    | Rotating this invalidates every licence already issued, so it is changed only
    | with a new desktop build to carry the new public key.
    |
    */

    'licence_private_key' => env('FINANCEAPP_LICENCE_PRIVATE_KEY'),

];
