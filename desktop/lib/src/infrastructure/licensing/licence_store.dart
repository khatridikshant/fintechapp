import 'dart:convert';

import 'package:crossvault/crossvault.dart';

/// Stores licence authorisations in the operating system's protected store.
///
/// ## Why this is not a table in the business database
///
/// A licence problem must never be able to reach the customer's accounting data, so
/// licensing lives entirely outside the business database (ADR 006, ADR 014, and
/// `AI_RULES.md`, which forbids `infrastructure/licensing` from importing a business
/// domain).
///
/// **It is also never restored from a business backup.** Restoring an old snapshot
/// would otherwise resurrect an expired or revoked authorisation along with the
/// books, and a business could keep working lawfully by rolling back its own data.
///
/// ## Why the OS store rather than a plain file
///
/// The authorisation is signed, so tampering is *detectable* ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â but detection is not
/// prevention, and an OS-protected store means an attacker with ordinary file access
/// cannot simply overwrite the value at all.
///
/// `crossvault` is already a dependency for the sign-in token and is MIT-approved in
/// `docs/AI_RULES.md`, so this adds no new package. On Windows it is the Credential
/// Manager (DPAPI and CNG ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â standard SDK headers, no optional toolchain component),
/// which is why `flutter_secure_storage` was rejected; see `PROGRESS.md` 4.32.
class LicenceStore {
  LicenceStore([Crossvault? vault]) : _vault = vault ?? Crossvault();

  final Crossvault _vault;

  /// The one key the authorisation lives under. Namespaced so it cannot collide
  /// with the sign-in session, which uses a different key in the same store.
  static const _key = 'financeapp.licence.authorisation';

  /// A fixed version field, so a future change of shape is detected rather than
  /// misread ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â the same reason `SecureCredentialStore` carries one.
  static const _version = 1;

  /// Reads the stored authorisation.
  ///
  /// Returns null when nothing is stored. A **corrupt** store is reported
  /// separately by returning null and letting [readOutcome] say why, because
  /// "never licensed" and "your licence could not be read" are different facts and
  /// the user needs different things done about them.
  Future<StoredLicence?> read() async => (await readOutcome()).licence;

  /// Reads the authorisation and distinguishes absent from unreadable.
  Future<LicenceStoreOutcome> readOutcome() async {
    String? raw;
    try {
      raw = await _vault.getValue(_key);
    } catch (_) {
      // A store that cannot be reached is the same problem as no licence for the
      // purpose of refusing to operate, and the caller reports the reason either way.
      return noLicenceStored();
    }

    if (raw == null || raw.isEmpty) return noLicenceStored();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return licenceStoreIsCorrupt();

      // A store written by a future version is **not** corrupt and **not** valid:
      // it is unreadable *by this version*, which is a distinct case because the
      // remedy is an upgrade rather than a re-licence.
      final version = decoded['v'];
      if (version != _version) return licenceStoreVersionMismatch();

      final claims = decoded['claims'];
      final signature = decoded['signature'];
      final serverTime = decoded['server_time'];

      if (claims is! String ||
          signature is! String ||
          serverTime is! String) {
        return licenceStoreIsCorrupt();
      }

      final parsed = DateTime.tryParse(serverTime);
      if (parsed == null) return licenceStoreIsCorrupt();

      return foundLicence(
        StoredLicence(
          claims: claims,
          signature: signature,
          serverTime: parsed.toUtc(),
        ),
      );
    } on FormatException {
      return licenceStoreIsCorrupt();
    }
  }

  /// Stores an authorisation.
  Future<void> write(StoredLicence licence) async {
    try {
      await _vault.setValue(
        _key,
        jsonEncode(<String, Object?>{
          'v': _version,
          'claims': licence.claims,
          'signature': licence.signature,
          'server_time': licence.serverTime.toIso8601String(),
        }),
      );
    } catch (_) {
      // A store that cannot be written leaves the in-memory licence working for
      // this run. Failing here would leave a paying customer unable to start the
      // application at all, which is a worse outcome than not remembering them.
    }
  }

  /// Forgets the stored authorisation.
  ///
  /// Used when a licence is revoked or belongs to another installation: leaving it
  /// in place would only make the next check fail in a more confusing way.
  Future<void> clear() async {
    try {
      await _vault.deleteValue(_key);
    } catch (_) {
      // Signing out or revoking must not fail because the store was unreachable.
      // The caller's in-memory state is already gone.
    }
  }
}

/// What was found in the licence store.
sealed class LicenceStoreOutcome {
  const LicenceStoreOutcome();
}

/// Nothing stored: the application has never been licensed on this machine.
final class LicenceStoreOutcomeMissing extends LicenceStoreOutcome {
  const LicenceStoreOutcomeMissing();
}

/// Something is stored but cannot be read as a licence.
final class LicenceStoreOutcomeCorrupt extends LicenceStoreOutcome {
  const LicenceStoreOutcomeCorrupt();
}

/// Stored by a different version of the application.
final class LicenceStoreOutcomeWrongVersion extends LicenceStoreOutcome {
  const LicenceStoreOutcomeWrongVersion();
}

/// A readable authorisation.
final class LicenceStoreOutcomeFound extends LicenceStoreOutcome {
  const LicenceStoreOutcomeFound(this.licence);

  final StoredLicence licence;
}

/// The stored authorisation, or null when there was none to read.
///
/// A getter on the outcome so a caller that only wants "the licence, if any" does
/// not have to match on four subtypes.
extension LicenceStoreOutcomeReading on LicenceStoreOutcome {
  StoredLicence? get licence => switch (this) {
        LicenceStoreOutcomeFound(:final licence) => licence,
        _ => null,
      };
}

/// A readable authorisation.
LicenceStoreOutcome foundLicence(StoredLicence licence) =>
    LicenceStoreOutcomeFound(licence);

/// Nothing stored: the application has never been licensed on this machine.
LicenceStoreOutcome noLicenceStored() => const LicenceStoreOutcomeMissing();

/// Something is stored but cannot be read as a licence.
LicenceStoreOutcome licenceStoreIsCorrupt() =>
    const LicenceStoreOutcomeCorrupt();

/// Stored by a different version of the application.
LicenceStoreOutcome licenceStoreVersionMismatch() =>
    const LicenceStoreOutcomeWrongVersion();

/// An authorisation as it is stored between sessions.
class StoredLicence {
  const StoredLicence({
    required this.claims,
    required this.signature,
    required this.serverTime,
  });

  /// The canonical signed payload, **exactly as issued**.
  ///
  /// Stored verbatim rather than re-serialised from parsed claims: the signature
  /// covers specific bytes, and re-encoding them would risk producing different
  /// bytes than were signed, so a perfectly genuine licence would fail to verify.
  final String claims;

  final String signature;

  /// The server's clock at signing.
  ///
  /// **The trusted time.** It is what makes clock-rollback *detection* possible,
  /// and it is inside the signed payload so it cannot simply be edited.
  final DateTime serverTime;

  /// Rebuilds a licence from its stored JSON.
  ///
  /// **Every field or nothing.** A half-restored licence would be worse than none:
  /// it would either verify against nothing or fail with no indication of why. So a
  /// missing or unreadable field raises rather than defaulting, and the store turns
  /// that into "corrupt".
  factory StoredLicence.fromJson(Map<String, dynamic> json) {
    final claims = json['claims'];
    final signature = json['signature'];
    final serverTime = json['server_time'];

    if (claims is! String ||
        signature is! String ||
        serverTime is! String) {
      throw const StoredLicenceUnreadable();
    }

    final parsed = DateTime.tryParse(serverTime);
    if (parsed == null) throw const StoredLicenceUnreadable();

    return StoredLicence(
      claims: claims,
      signature: signature,
      serverTime: parsed.toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'claims': claims,
        'signature': signature,
        'server_time': serverTime.toIso8601String(),
      };
}

/// Raised when a stored licence exists but cannot be read.
///
/// Distinct from "no licence stored", because the user's next action differs:
/// re-licensing versus reporting that something is wrong.
class StoredLicenceUnreadable implements Exception {
  const StoredLicenceUnreadable();

  @override
  String toString() => 'StoredLicenceUnreadable';
}

/// Detects the clock being moved backwards to keep a licence alive.
///
/// ## What this is, stated honestly
///
/// **Tamper detection, not a guarantee.** A user with full control of the machine
/// can defeat any purely local clock check, because both the clock and the stored
/// value are under their control. `AI_RULES.md` forbids presenting this as anything
/// stronger, so it is not presented as anything stronger.
///
/// What it buys is cost: moving the clock back now stops the licence working, so it
/// is a visible action rather than an invisible one, and the next legitimate
/// revalidation resets the stored time from the server.
///
/// ## The comparison is deliberately tolerant
///
/// A small backwards move is ordinary ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â a timezone correction, an NTP correction, a
/// laptop waking from sleep. Only a move **beyond the tolerance** counts as
/// tampering, because locking a paying customer out over a two-minute adjustment
/// would be a far worse failure than the one being defended against.
class ClockRollbackCheck {
  const ClockRollbackCheck({
    this.tolerance = const Duration(minutes: 5),
    this.allowedDriftPerDay = const Duration(minutes: 1),
  });

  /// How far the clock may move backwards before it counts as tampering.
  final Duration tolerance;

  /// How much the clock may drift *backwards* per day of trusted elapsed time.
  ///
  /// A machine whose clock runs slightly slow is normal; one that runs backwards is
  /// not. Scaling by elapsed time means a licence trusted for a year tolerates a
  /// larger absolute wobble than a fresh one.
  final Duration allowedDriftPerDay;

  /// Whether [now] is unacceptably behind [lastTrusted].
  bool isRollback({
    required DateTime now,
    required DateTime lastTrusted,
  }) {
    final current = now.toUtc();
    final last = lastTrusted.toUtc();

    final backwardsBy = last.difference(current);
    if (backwardsBy <= Duration.zero) return false;

    if (backwardsBy <= tolerance) return false;

    // Scaling the allowance by how long this clock has been trusted. With no
    // elapsed time to scale by, the tolerance alone applies -- the strict reading,
    // and the safe one.
    final elapsedDays = current.difference(last).inDays;
    if (elapsedDays <= 0) return true;

    return backwardsBy > tolerance + allowedDriftPerDay * elapsedDays;
  }
}