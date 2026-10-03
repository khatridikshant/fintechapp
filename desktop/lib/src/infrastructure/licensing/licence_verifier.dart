import 'dart:convert';

import '../../domain/shared/licence_access.dart';
import 'package:cryptography/cryptography.dart';

/// Verifies a licence authorisation signed by the backend.
///
/// ## The one thing this class does
///
/// It answers "is this licence genuine, and is it still valid?" **with no network
/// access at all**, which is the entire reason the signature exists (ADR 006). The
/// desktop holds only the public key; the private key never leaves the server, so a
/// user who edits the stored expiry invalidates the signature rather than extending
/// their own entitlement.
///
/// ## Why every field is inside the signed payload
///
/// The signature covers the licence id, the user, the book, the installation, the
/// status, the expiry, the next validation deadline, and the revision. Anything
/// outside it could be changed without detection, so the verifier **refuses an
/// authorisation carrying a claim it does not recognise** rather than ignoring it.
/// Ignoring an unknown claim is how a new field gets added without anyone
/// re-checking that it is protected.
class LicenceVerifier {
  const LicenceVerifier({required this.publicKey});

  /// The base64 Ed25519 public key compiled into this build.
  ///
  /// **Compiled in, not fetched.** That is what removes a network round trip from
  /// the path between "I have a licence" and "this licence is genuine". The cost is
  /// that rotating the key needs a new desktop build, which ADR 014 records as the
  /// accepted trade.
  final String publicKey;

  static final Ed25519 _algorithm = Ed25519();

  /// The claims the verifier requires. Anything else is refused.
  static const requiredClaims = <String>{
    'licence_id',
    'user_id',
    'book_id',
    'installation_id',
    'status',
    // **Signed and required.** The plan tier decides what the holder is entitled
    // to, so leaving it unsigned would let a user edit their own plan. It is also
    // why the verifier refuses unknown claims: the server sends `tier`, and a
    // verifier that ignored it would silently permit a plan change.
    'tier',
    'expires_at',
    'next_validation_at',
    'revision',
    'issued_at',
  };

  /// Verifies [signatureBase64] over [claimsPayload], both exactly as received.
  ///
  /// Returns a [LicenceVerification] rather than a bool, because "invalid" and
  /// "expired" need different words on screen and a bool cannot tell them apart.
  /// Telling a customer whose licence simply ran out that the licence is "invalid"
  /// is telling them something false.
  Future<LicenceVerification> verify({
    required String claimsPayload,
    required String signatureBase64,
    required String installationId,
    DateTime? now,
  }) async {
    final claims = parseClaims(claimsPayload);

    // The missing/extra checks run **before** the signature, because a payload
    // carrying an unrecognised claim is wrong regardless of who signed it.
    final missing = requiredClaims.difference(claims.keys.toSet());
    if (missing.isNotEmpty) {
      return LicenceVerification.invalid(
        reason: LicenceInvalidReason.missingClaims,
        message: 'The licence is missing ${missing.join(', ')}.',
      );
    }

    final unknown = claims.keys.toSet().difference(requiredClaims);
    if (unknown.isNotEmpty) {
      return LicenceVerification.invalid(
        reason: LicenceInvalidReason.unrecognisedClaims,
        message: 'The licence carries claims this version does not understand '
            '(${unknown.join(', ')}). Refusing it is safer than ignoring them.',
      );
    }

    final List<int> signatureBytes;
    final List<int> keyBytes;
    try {
      signatureBytes = base64Decode(signatureBase64);
      keyBytes = base64Decode(publicKey);
    } on FormatException {
      return const LicenceVerification.invalid(
        reason: LicenceInvalidReason.malformed,
        message: 'The licence could not be read because it is not valid base64.',
      );
    }

    // **Any failure is "not authentic", never an exception to propagate.** A
    // licence check that can throw would need every caller to catch it, and a
    // caller that forgets would crash instead of refusing to open the books.
    var authentic = false;
    try {
      authentic = await _algorithm.verify(
        // **The raw UTF-8 bytes of the claims string, not base64-decoded.** The
        // server signs `canonicalise($claims)` as plain text and sends that same
        // text; base64 here is only how this vector was pasted into a test file.
        // Verifying over decoded bytes produced a licence that was genuinely
        // signed and still failed -- caught only because the test vector was made
        // by the PHP signer rather than by this package.
        utf8.encode(claimsPayload),
        signature: Signature(
          signatureBytes,
          publicKey: SimplePublicKey(keyBytes, type: KeyPairType.ed25519),
        ),
      );
    } on Object {
      authentic = false;
    }

    if (!authentic) {
      return const LicenceVerification.invalid(
        reason: LicenceInvalidReason.badSignature,
        message: 'The licence signature does not match. It was not issued for '
            'this installation, or it has been altered.',
      );
    }

    // Past this point the claims are authentic, so they are trustworthy data.
    if (claims['installation_id'] != installationId) {
      // **Checked even though it is signed**, because a valid signature proves the
      // licence was issued *for some machine*. Without this an authorisation
      // copied from one installation to another would verify perfectly.
      return const LicenceVerification.invalid(
        reason: LicenceInvalidReason.wrongInstallation,
        message: 'This licence was issued to a different installation.',
      );
    }

    const revoked = _revokedStatus;
    if (claims['status'] == revoked) {
      return const LicenceVerification.invalid(
        reason: LicenceInvalidReason.revoked,
        message: 'This licence has been revoked.',
      );
    }

    if (claims['status'] == _suspendedStatus) {
      return const LicenceVerification.invalid(
        reason: LicenceInvalidReason.suspended,
        message: 'This licence is suspended. Contact your supplier to have it '
            'reinstated.',
      );
    }

    final at = (now ?? DateTime.now()).toUtc();

    // **Expiry before revalidation.** An expired licence is the most common reason
    // the application will refuse to run, so it is checked first and the message is
    // the accurate one even when both deadlines have passed.
    final expiresAt = parseTimestamp(claims['expires_at']);
    if (expiresAt != null && !at.isBefore(expiresAt)) {
      return LicenceVerification.invalid(
        reason: LicenceInvalidReason.expired,
        message: 'This licence expired on ${expiresAt.toLocal()} and needs '
            'renewing.',
      );
    }

    // **The next-validation date is NOT an expiry, and is deliberately not
    // refused here.** The specification requires the two to be treated as
    // different concepts: expiry is "an absolute local enforcement boundary", while
    // the validation date is when to check in again, and a temporary loss of
    // connectivity "does not unnecessarily prevent normal business operations".
    //
    // A first version refused it here, which made a shop whose line dropped out
    // for a few days unable to trade. The deadline is returned as data and the
    // grace period is applied by `LicenceGate`, which is the layer that owns the
    // policy.
    final nextValidation = parseTimestamp(claims['next_validation_at']);

    return LicenceVerification.valid(
      licenceId: claims['licence_id']!,
      expiresAt: expiresAt,
      nextValidationAt: nextValidation,
    );
  }

  static const _revokedStatus = 'revoked';
  static const _suspendedStatus = 'suspended';

  /// Turns the canonical `key=value` payload back into a claim map.
  ///
  /// **Must mirror `LicenceSigner::canonicalise` on the server exactly.** A bare key
  /// is a null and `key=` is an empty string; those are different facts â€” "no
  /// expiry" and "expires at nothing" â€” and collapsing them would let an expiry be
  /// dropped without the signature being re-checked.
  static Map<String, String?> parseClaims(String payload) {
    final claims = <String, String?>{};

    for (final line in payload.split('\n')) {
      if (line.isEmpty) continue;

      final separator = line.indexOf('=');
      if (separator == -1) {
        claims[line] = null;
        continue;
      }

      claims[line.substring(0, separator)] = line.substring(separator + 1);
    }

    return claims;
  }

  /// Parses an ISO-8601 timestamp, or null when the claim is absent.
  ///
  /// **Absent is not the same as unparseable.** A null expiry means perpetual and is
  /// fine. A value that is present but unreadable is a different fact, and the
  /// required-claim check upstream is what keeps a malformed timestamp from being
  /// silently read as "never expires" â€” this function cannot make that distinction
  /// on its own, which is why it is only ever reached with the claim verified.
  static DateTime? parseTimestamp(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }
}

/// Whether a licence authorises the application to run.
///
/// **One class with named constructors rather than a sealed hierarchy.** The outcome
/// is a single fact â€” permitted or not, with a reason and a sentence â€” and a
/// hierarchy over it would add a type to match on without adding a case a caller
/// could actually handle differently.
class LicenceVerification {
  const LicenceVerification.valid({
    required this.licenceId,
    required this.expiresAt,
    required this.nextValidationAt,
  })  : mayOperate = true,
        reason = null,
        message = 'Licence valid.';

  const LicenceVerification.invalid({
    required this.reason,
    required this.message,
  })  : mayOperate = false,
        licenceId = null,
        expiresAt = null,
        nextValidationAt = null;

  /// Whether normal business operations may proceed.
  final bool mayOperate;

  /// Why the licence is unusable, or null when it is valid.
  final LicenceInvalidReason? reason;

  /// A sentence a user can act on. Never a class name.
  final String message;

  final String? licenceId;

  /// When the licence runs out, or null for a perpetual one.
  final DateTime? expiresAt;

  /// When the desktop must next revalidate online, or null if never required.
  final DateTime? nextValidationAt;

  /// Whether this licence is perpetual, which the UI can state plainly rather than
  /// showing a blank expiry.
  bool get isPerpetual => mayOperate && expiresAt == null;

  @override
  String toString() => mayOperate
      ? 'LicenceVerification.valid($licenceId)'
      : 'LicenceVerification.invalid($reason)';
}
