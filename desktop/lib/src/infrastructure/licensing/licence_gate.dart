import '../../domain/shared/licence_access.dart';
import 'licence_store.dart';
import 'licence_verifier.dart';

/// Decides whether the application may open, from what is stored locally.
///
/// ## This is the gate the specification asks for
///
/// *"The desktop application shall authenticate the user with the backend when an
/// account session is established and shall obtain a cryptographically signed
/// license authorization **that allows the application to operate**"* Ã¢â‚¬â€ and then,
/// *"after successful authentication and license verification, the desktop
/// application shall be capable of operating normally without an active internet
/// connection."*
///
/// So the sequence is **one online sign-in, then offline operation**, not a network
/// call per launch. Signing in is what starts the offline window; the signed
/// licence says how long that window is and when the absolute end is.
///
/// This class performs **no network calls**. It answers from the stored
/// authorisation alone, which is the whole point: a licence problem must never
/// stop the application from starting in order to tell the user it cannot start.
///
/// ## What it never does
///
/// **It never touches accounting data.** The specification requires that *"license
/// enforcement shall not delete, corrupt, or modify the user's accounting data"*,
/// and a gate is exactly where that temptation lives. This class reads a licence
/// store and returns a verdict. That is all.
class LicenceGate {
  const LicenceGate({
    required this.verifier,
    required this.store,
    required this.installationId,
    this.offlineGracePeriod = const Duration(days: 7),
  });

  final LicenceVerifier verifier;
  final LicenceStore store;

  /// This machine's installation id. An authorisation for another one is refused.
  final String installationId;

  /// How long the application keeps working after the next validation date passes,
  /// while offline.
  ///
  /// ## Why a grace period at all
  ///
  /// The specification distinguishes two signed deadlines and requires them not be
  /// treated as the same concept:
  ///
  /// - **Expiry** is the end of the entitlement, and is *"an absolute local
  ///   enforcement boundary"*.
  /// - **Next validation** is when to check in again, and the specification says a
  ///   **temporary** loss of connectivity *"does not unnecessarily prevent normal
  ///   business operations"*.
  ///
  /// So expiry locks, and a passed validation date on its own does not Ã¢â‚¬â€ it starts
  /// this window instead. Without a window, a shop whose line drops out for a
  /// morning cannot invoice its customers, which is the failure the requirement
  /// exists to prevent.
  ///
  /// **A policy, not an accounting rule**, which is why it is a constructor
  /// argument rather than a constant buried in the logic.
  final Duration offlineGracePeriod;

  /// Reads the stored licence and decides.
  Future<LicenceAccess> evaluate({DateTime? now}) async {
    final at = now ?? DateTime.now();

    // **`readOutcome`, not `read`.** `read` collapses "corrupt" and "wrong
    // version" into `null`, which is the same value as "nothing stored" â€” and a
    // user whose licence file is damaged would then be told they have no licence,
    // which sends them to the wrong remedy entirely.
    final LicenceStoreOutcome outcome;
    try {
      outcome = await store.readOutcome();
    } on Object {
      return const Locked(
        reason: LicenceInvalidReason.storeCorrupt,
        message: 'The stored licence could not be read. Sign in again to '
            'restore access. Your accounting data has not been changed.',
      );
    }

    switch (outcome) {
      case LicenceStoreOutcomeCorrupt():
        return const Locked(
          reason: LicenceInvalidReason.storeCorrupt,
          message: 'The stored licence could not be read. Sign in again to '
              'restore access. Your accounting data has not been changed.',
        );

      case LicenceStoreOutcomeWrongVersion():
        return const Locked(
          reason: LicenceInvalidReason.storeCorrupt,
          message: 'This licence was written by a different version of the '
              'application. Update the application and sign in again. Your '
              'accounting data has not been changed.',
        );

      case LicenceStoreOutcomeMissing():
        return const Locked(
          reason: LicenceInvalidReason.notInstalled,
          message: 'Sign in to activate this copy of the application. Once you '
              'have, it works offline until it needs to check in again.',
        );

      case LicenceStoreOutcomeFound(:final licence):
        return _evaluateStored(licence, at);
    }
  }

  Future<LicenceAccess> _evaluateStored(StoredLicence stored, DateTime at) async {
    final verification = await verifier.verify(
      claimsPayload: stored.claims,
      signatureBase64: stored.signature,
      installationId: installationId,
      now: at,
    );

    if (!verification.mayOperate) {
      return Locked(
        reason: verification.reason ?? LicenceInvalidReason.badSignature,
        message: verification.message,
        licenceId: verification.licenceId,
        // True when the only thing wrong is that the app has not been online
        // recently. The screen offers "check again" for this case and not for a
        // revoked licence, because retrying the latter can never succeed.
        needsNetwork: verification.reason ==
                LicenceInvalidReason.revalidationDue ||
            verification.reason == LicenceInvalidReason.clockRollback,
      );
    }

// Genuine and unexpired. Now the second deadline, which the verifier deliberately
    // leaves to this layer.
    final nextValidation = verification.nextValidationAt;

    // **Past the offline grace period, the application locks.**
    //
    // A *passed* validation date does not lock by itself â€” that is the whole point
    // of the grace period. Once the window closes, though, the licence has gone
    // unchecked for too long and this installation can no longer demonstrate it is
    // entitled to operate. Locking then is what makes the periodic check mean
    // anything; a check that could be skipped indefinitely would not be a check.
    final graceEndsAt = nextValidation?.add(offlineGracePeriod);
    final withinGrace = graceEndsAt == null || at.isBefore(graceEndsAt);

    if (!withinGrace) {
      return const Locked(
        reason: LicenceInvalidReason.revalidationDue,
        message: 'This copy has not been able to check in for a while. Connect '
            'to the internet and sign in again to carry on using it. Your '
            'accounting data has not been changed.',
        needsNetwork: true,
      );
    }

    return Allowed(
      licenceId: verification.licenceId!,
      expiresAt: verification.expiresAt,
      nextValidationAt: nextValidation,
      // Surfaced so the UI can warn *before* the window closes rather than
      // locking someone without warning.
      offlineGraceEndsAt: graceEndsAt,
      withinOfflineGracePeriod: at.isBefore(
        nextValidation ?? at,
      ),
    );
  }
}
