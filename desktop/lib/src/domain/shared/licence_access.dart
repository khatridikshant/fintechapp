/// Whether the application may open its books.
///
/// ## Why this lives in the domain, and not in `infrastructure/licensing`
///
/// The presentation layer has to render this verdict, so the type has to be
/// somewhere the presentation layer is allowed to read. `architecture_test.dart`
/// enforces that the presentation layer never imports `infrastructure/`, and it is
/// right: a screen that imports a licence verifier has imported a signature
/// checker, and from there it is one refactor away from signing something.
///
/// So the **verdict** is a domain value type, and the code that produces it stays
/// behind this port. Exactly the shape every repository already has here: an
/// interface in the domain, the implementation in `infrastructure/`.
///
/// What is deliberately **not** here: the verifier, the store, the public key, or
/// anything that reads a signature. Those are implementation. A screen learns
/// *whether* it may operate, never how that was decided.
library;

/// Whether the application may be used, and why.
///
/// One class with two named shapes rather than a hierarchy, because the outcome is
/// a single fact a screen acts on: show the books, or show sign-in.
sealed class LicenceAccess {
  const LicenceAccess();

  /// Whether normal business operations may proceed.
  bool get mayOperate => this is Allowed;

  /// Which screen the application shows.
  String get screenName => switch (this) {
        Allowed() => 'application',
        Locked() => 'sign-in',
      };

  /// A sentence a user can act on. Never a class name.
  String get message => switch (this) {
        Allowed() => 'Licence valid. No further action is needed.',
        Locked(:final message) => message,
      };
}

/// A verified, current licence. The application may operate.
final class Allowed extends LicenceAccess {
  const Allowed({
    required this.licenceId,
    required this.expiresAt,
    required this.nextValidationAt,
    required this.offlineGraceEndsAt,
    required this.withinOfflineGracePeriod,
  });

  final String licenceId;

  /// The absolute local boundary. Null means perpetual.
  final DateTime? expiresAt;

  /// When the application should next check in, signed by the server.
  final DateTime? nextValidationAt;

  /// When the offline window closes.
  final DateTime? offlineGraceEndsAt;

  /// Whether we are inside that window. False means "still working, but say so".
  final bool withinOfflineGracePeriod;

  /// Days left before the licence expires, or null when perpetual.
  ///
  /// Rounded **down**, so a licence with 30 hours left reports 1 day rather than 2
  /// and the UI never implies more time than there is.
  int? daysUntilExpiry(DateTime now) {
    final end = expiresAt;
    if (end == null) return null;
    final days = end.difference(now).inHours ~/ 24;
    return days < 0 ? 0 : days;
  }

  @override
  String toString() => 'LicenceAccess.allowed($licenceId, expiry $expiresAt)';
}

/// No usable licence. The application must not open its books.
final class Locked extends LicenceAccess {
  const Locked({
    required this.reason,
    required this.message,
    this.licenceId,
    this.needsNetwork = false,
  });

  final LicenceInvalidReason reason;

  @override
  final String message;

  final String? licenceId;

  /// Whether signing in again is worth offering.
  ///
  /// True for a passed revalidation and a detected clock rollback. **False for an
  /// expired, revoked or suspended licence**, where another attempt cannot help and
  /// a retry button that never works is worse than none.
  final bool needsNetwork;

  @override
  String toString() => 'LicenceAccess.locked($reason)';
}

/// Why a licence cannot be used.
///
/// ## The distinction that matters most to a user
///
/// [notLicensed] and [storeCorrupt] both mean "you cannot open the books", and the
/// remedies are entirely different: register a licence versus report that
/// something is wrong. Collapsing them sends the user to the wrong place.
enum LicenceInvalidReason {
  /// A required claim was absent.
  missingClaims,

  /// A claim this version does not understand was present.
  unrecognisedClaims,

  /// The signature or key could not be read at all.
  malformed,

  /// The signature did not verify.
  badSignature,

  /// Genuine, but issued to a different installation.
  wrongInstallation,

  /// Genuine, but past its expiry.
  expired,

  /// Genuine, but due for online revalidation.
  revalidationDue,

  /// Revoked by the supplier.
  revoked,

  /// Suspended, and expected to return.
  suspended,

  /// The clock appears to have been moved backwards.
  clockRollback,

  /// Nothing is stored, so the application has never been licensed here.
  notInstalled,

  /// Something is stored but it cannot be read.
  storeCorrupt,

  /// The licence is valid and the application may open. Not a failure.
  valid,
}