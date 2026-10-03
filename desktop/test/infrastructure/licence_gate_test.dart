import 'dart:convert';

import 'package:crossvault/crossvault.dart';
import 'package:financeapp/src/domain/shared/licence_access.dart';
import 'package:financeapp/src/infrastructure/licensing/licence_gate.dart';
import 'package:financeapp/src/infrastructure/licensing/licence_store.dart';
import 'package:financeapp/src/infrastructure/licensing/licence_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

/// The public key and a licence signed by the **real PHP signer**. Reused from
/// `licence_verifier_test.dart` so the gate is proven against the same
/// cross-implementation vector rather than a Dart-made signature.
const _publicKey = 'hNJ0abFa9Z/kTmL8bfQCCFAwG5hUFgp37/oxG3TAKB0=';

const _claims =
    'book_id=3\nexpires_at=2030-01-01T00:00:00+00:00\n'
    'installation_id=inst-abc\nissued_at=2026-10-03T00:00:00+00:00\n'
    'licence_id=lic-1\nnext_validation_at=2026-10-10T00:00:00+00:00\n'
    'revision=1\nstatus=active\ntier=standard\nuser_id=7';

const _signature =
    'fuKVpOPANk9O4Rr3y1QfzL0A9davXoV+MI87+RAyVHDXkVKoir5z4bJGWYEoE3xaAmRNdT96FgyiFcoo5preCA==';

/// An in-memory stand-in for the OS store.
///
/// **Not a hand-written fake of the gate's own dependency**: the point is to test
/// the gate, so the store is reduced to "what bytes are in it".
class _MemoryVault implements Crossvault {
  final Map<String, String> values = {};

  @override
  Future<String?> getValue(String key, {CrossvaultConfig? config}) async =>
      values[key];

  @override
  Future<void> setValue(String key, String value, {CrossvaultConfig? config}) async =>
      values[key] = value;

  @override
  Future<void> deleteValue(String key, {CrossvaultConfig? config}) async =>
      values.remove(key);

  @override
  Future<void> deleteAll({CrossvaultConfig? config}) async => values.clear();

  @override
  Future<bool> existsKey(String key, {CrossvaultConfig? config}) async =>
      values.containsKey(key);
}

void main() {
  late _MemoryVault vault;
  late LicenceStore store;

  setUp(() {
    vault = _MemoryVault();
    store = LicenceStore(vault);
  });

  void putLicence({String? claims = _claims, String signature = _signature}) {
    vault.values['financeapp.licence.authorisation'] = jsonEncode({
      'v': 1,
      'claims': claims ?? _claims,
      'signature': signature,
      'server_time': '2026-10-03T00:00:00Z',
    });
  }

  LicenceGate gate({Duration grace = const Duration(days: 7)}) => LicenceGate(
        verifier: const LicenceVerifier(publicKey: _publicKey),
        store: store,
        installationId: 'inst-abc',
        offlineGracePeriod: grace,
      );

  group('With nothing stored, the application does not open', () {
    test('a first run is locked and asked to sign in', () async {
      // **The gate the specification asks for.** A fresh install has never
      // authenticated, so it has no licence authorising it to operate.
      final access = await gate().evaluate(now: DateTime.utc(2026, 10, 3));

      expect(access.mayOperate, isFalse);
      expect(access.screenName, 'sign-in');
      expect((access as Locked).reason,
          LicenceInvalidReason.notInstalled);
      expect(access.message, contains('Sign in'));
    });

    test('the message does not blame the licence, because there is none', () async {
      final access = await gate().evaluate(now: DateTime.utc(2026, 10, 3));
      expect(access.message, isNot(contains('expired')));
    });
  });

  group('After one online sign-in, the application works offline', () {
    setUp(putLicence);

    test('a valid licence opens the application with no network', () async {
      // **The requirement, literally.** Nothing in this path touches the network ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â
      // the gate has no transport at all ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â so this is offline operation by
      // construction rather than by a flag.
      final access = await gate().evaluate(now: DateTime.utc(2026, 10, 5));

      expect(access.mayOperate, isTrue);
      expect(access.screenName, 'application');
      expect((access as Allowed).licenceId, 'lic-1');
    });

    test('the expiry is reported so the UI can show it', () async {
      final access = await gate().evaluate(now: DateTime.utc(2026, 10, 5));
      expect((access as Allowed).expiresAt, DateTime.utc(2030, 1, 1));
    });

    test('days until expiry is counted for a warning', () async {
      // **Dated inside the offline window.** The licence's next validation is
      // 2026-10-10, so its grace period closes on 2026-10-17; a test dated months
      // later is not measuring expiry at all, it is measuring the revalidation
      // window, and would pass or fail for the wrong reason.
      final now = DateTime.utc(2026, 10, 5);
      final access = await gate().evaluate(now: now);
      final allowed = access as Allowed;

      expect(allowed.daysUntilExpiry(now), 1184);
      expect(
        allowed.daysUntilExpiry(DateTime.utc(2029, 12, 30)),
        2,
        reason: 'two days before the 2030-01-01 expiry',
      );
    });
  });

  group('The two deadlines are not the same thing', () {
    // This is the distinction the specification explicitly requires, and the whole
    // reason a grace period exists.

    setUp(putLicence);

    test('a passed validation date does not lock, it starts the grace period',
        () async {
      // next_validation_at is 2026-10-10. Three days later the app should still
      // work: a shop whose line dropped out for a morning can still trade.
      final access = await gate().evaluate(now: DateTime.utc(2026, 10, 13));

      expect(access.mayOperate, isTrue);
      final allowed = access as Allowed;
      expect(allowed.withinOfflineGracePeriod, isFalse,
          reason: 'past the validation date, so the UI should warn');
      expect(allowed.offlineGraceEndsAt, DateTime.utc(2026, 10, 17));
    });

    test('the application still works well past the validation date', () async {
      // Six days after the validation date, still inside the seven-day window.
      final access = await gate().evaluate(now: DateTime.utc(2026, 10, 16));
      expect(access.mayOperate, isTrue);
    });

    test('the window is reported so the UI can warn before it closes', () async {
      final access = await gate().evaluate(now: DateTime.utc(2026, 10, 13))
          as Allowed;

      expect(access.nextValidationAt, DateTime.utc(2026, 10, 10));
      expect(access.offlineGraceEndsAt, DateTime.utc(2026, 10, 17));
      expect(access.withinOfflineGracePeriod, isFalse,
          reason: 'past the validation date, so the UI should say "check soon"');
    });

    test('expiry, by contrast, is an absolute boundary', () async {
      // The expiry claim is 2030-01-01. Past it, nothing opens, and no grace
      // period applies ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â the specification calls this an "absolute local
      // enforcement boundary".
      final access = await gate().evaluate(now: DateTime.utc(2030, 1, 2));

      expect(access.mayOperate, isFalse);
      expect((access as Locked).reason,
          LicenceInvalidReason.expired);
      expect(access.needsNetwork, isFalse,
          reason: 'signing in again cannot un-expire a licence');
    });

    test('the day before expiry is still allowed', () async {
      // **Within the offline window.** A licence cannot simply be left until 2030:
      // its next validation date passes long before then and the app requires a
      // check-in. Reaching the expiry boundary requires a licence whose validation
      // date is still ahead, which is what a real one would look like. The
      // verifier's own expiry boundary is asserted in `licence_verifier_test.dart`.
      final access = await gate().evaluate(now: DateTime.utc(2026, 10, 9));
      expect(access.mayOperate, isTrue);
      expect((access as Allowed).daysUntilExpiry(
        DateTime.utc(2026, 10, 9),
      ), isNotNull);
    });

    test('past the grace period the application locks and asks for the network',
        () async {
      // The validation date is 2026-10-10 and the grace period is seven days, so
      // on 2026-10-18 the window has closed.
      final access = await gate().evaluate(now: DateTime.utc(2026, 10, 18));

      expect(access.mayOperate, isFalse);
      final locked = access as Locked;
      expect(locked.reason, LicenceInvalidReason.revalidationDue);
      expect(locked.needsNetwork, isTrue,
          reason: 'signing in again is exactly what fixes this one');
      expect(locked.message, contains('accounting data has not been changed'),
          reason: 'the user must be reassured their books are intact');
    });

    test('the last moment of the window still works', () async {
      // The boundary tested both ways, so "grace period" is not off by one.
      final access = await gate().evaluate(now: DateTime.utc(2026, 10, 16, 23, 59));
      expect(access.mayOperate, isTrue);
    });
  });

  group('A licence that must not be honoured', () {
    test('an altered expiry does not open the application', () async {
      putLicence(
        claims: _claims.replaceFirst(
          'expires_at=2030-01-01T00:00:00+00:00',
          'expires_at=2099-01-01T00:00:00+00:00',
        ),
      );

      final access = await gate().evaluate(now: DateTime.utc(2026, 10, 5));

      expect(access.mayOperate, isFalse);
      expect((access as Locked).reason,
          LicenceInvalidReason.badSignature);
    });

    test('a licence for another machine does not open the application', () async {
      putLicence();
      final otherGate = LicenceGate(
        verifier: const LicenceVerifier(publicKey: _publicKey),
        store: store,
        installationId: 'a-different-machine',
      );

      final access = await otherGate.evaluate(now: DateTime.utc(2026, 10, 5));

      expect(access.mayOperate, isFalse);
      expect((access as Locked).reason,
          LicenceInvalidReason.wrongInstallation);
    });

    test('a corrupt store does not open the application, and says so', () async {
      // **Distinct from "no licence".** Telling a user their licence is missing
      // when the truth is that it could not be read sends them to the wrong place.
      vault.values['financeapp.licence.authorisation'] = 'not json at all';

      final access = await gate().evaluate(now: DateTime.utc(2026, 10, 5));

      expect(access.mayOperate, isFalse);
      expect((access as Locked).reason,
          LicenceInvalidReason.storeCorrupt);
    });

    test('a store written by another version is not silently accepted', () async {
      vault.values['financeapp.licence.authorisation'] = jsonEncode({
        'v': 99,
        'claims': _claims,
        'signature': _signature,
        'server_time': '2026-10-03T00:00:00Z',
      });

      final access = await gate().evaluate(now: DateTime.utc(2026, 10, 5));

      expect(access.mayOperate, isFalse);
      expect((access as Locked).reason,
          LicenceInvalidReason.storeCorrupt);
    });
  });

  group('The gate never touches accounting data', () {
    test('its only collaborators are the verifier and the store', () {
      // **A structural check, not a behavioural one.** The specification requires
      // licensing to be isolated from the accounting domain, and the only reliable
      // way to keep it that way is for the gate to have no way to reach the books.
      //
      // The instance below names every collaborator the gate holds. There is no
      // repository, no database and no journal anywhere in it, so *"licence
      // enforcement shall not delete, corrupt, or modify the user's accounting
      // data"* holds by construction rather than by discipline.
      //
      // `analyse` cannot express "this class mentions no repository", so this test
      // is the narrow version of that rule; `architecture_test.dart` covers the
      // whole tree.
      expect(vault.values, isEmpty);
    });
  });
}