import 'package:financeapp/src/domain/sync/divergence.dart';
import 'package:flutter_test/flutter_test.dart';

/// Classifying whether two copies of the same books have drifted apart.
///
/// ## The hand-computed table these pin
///
/// With `lastUploaded` as the common ancestor:
///
/// | local | server | result |
/// |---|---|---|
/// | A | A | `none` — nothing happened |
/// | B | A | `localOnly` — an ordinary upload |
/// | A | C | `serverOnly` — a real choice exists |
/// | B | C | `bothChanged` — must stop |
///
/// The cases that matter most are the ones no code path currently exercises,
/// because nothing in the application produces them yet: `serverOnly` and
/// `bothChanged` can only arise from a second computer, and there is no merge to
/// perform. They are specified here so that when the UI is built it cannot invent
/// its own behaviour.
void main() {
  const a = 'aaaa';
  const b = 'bbbb';
  const c = 'cccc';

  SyncComparison compare({
    String? local = a,
    String? lastUploaded = a,
    String? server = a,
    int? lastUploadedRevision = 1,
    int? serverRevision = 1,
  }) =>
      SyncComparison.from(
        localChecksum: local,
        lastUploadedChecksum: lastUploaded,
        serverChecksum: server,
        lastUploadedRevision: lastUploadedRevision,
        serverRevision: serverRevision,
      );

  group('the four cases', () {
    test('identical on both sides means nothing happened', () {
      expect(compare().divergence, Divergence.none);
    });

    test('only this computer changed is an ordinary upload', () {
      final result = compare(local: b, server: a);

      expect(result.divergence, Divergence.localOnly);
      expect(result.needsAttention, isFalse,
          reason: 'nothing to ask the user about');
    });

    test('only the server changed is the case where a choice exists', () {
      final result = compare(local: a, server: c);

      expect(result.divergence, Divergence.serverOnly);
      expect(result.needsAttention, isTrue);
      expect(result.isDangerous, isFalse);
    });

    test('both changed must stop', () {
      final result = compare(local: b, server: c);

      expect(result.divergence, Divergence.bothChanged);
      expect(result.isDangerous, isTrue);
    });
  });

  group('why checksums and not revisions', () {
    test('a re-upload of identical bytes is not a divergence', () {
      // Another device storing the *same* books advances the revision and changes
      // nothing. Comparing revision numbers would call this a conflict, and a user
      // who is told about conflicts that are not conflicts stops reading them.
      final result = compare(
        local: a,
        lastUploaded: a,
        server: a,
        lastUploadedRevision: 1,
        serverRevision: 9,
      );

      expect(result.divergence, Divergence.none);
    });

    test('a genuine difference is still caught across many revisions', () {
      final result = compare(
        local: a,
        lastUploaded: a,
        server: c,
        lastUploadedRevision: 1,
        serverRevision: 40,
      );

      expect(result.divergence, Divergence.serverOnly);
    });
  });

  group('the edges, which are where the damage is', () {
    test('a first sync on a new account is an ordinary upload', () {
      // Nothing stored yet cannot disagree with anything. A brand-new account
      // refusing its own first backup would be an absurd first impression.
      final result = compare(server: null, lastUploaded: null);

      expect(result.divergence, Divergence.localOnly);
      expect(result.needsAttention, isFalse);
    });

    test('a second computer joining books that already exist must stop', () {
      // **The scenario the whole feature exists for.** This device has never
      // synced, so there is no common ancestor, and the server already holds books.
      // Treating this as a routine upload would let the newcomer overwrite them
      // with its own — silently, and from the server's point of view successfully.
      final result = compare(
        local: b,
        lastUploaded: null,
        server: c,
        lastUploadedRevision: null,
        serverRevision: 4,
      );

      expect(result.divergence, Divergence.bothChanged);
      expect(result.hasSyncedBefore, isFalse);
      expect(result.isDangerous, isTrue);
    });

    test('books this computer cannot read are an upload, not a refusal', () {
      // A read error must not masquerade as a conflict: refusing here would block
      // the user on something that uploading would fix.
      final result = compare(local: null, server: c);

      expect(result.divergence, Divergence.localOnly);
    });

    test('a server holding nothing is never a conflict', () {
      final result = compare(local: b, server: null);

      expect(result.divergence, Divergence.localOnly);
    });
  });

  group('reporting the gap', () {
    test('says how far behind the server is', () {
      final result = compare(
        local: a,
        server: c,
        lastUploadedRevision: 2,
        serverRevision: 5,
      );

      expect(result.revisionsBehind, 3);
    });

    test('says nothing when this computer is not behind', () {
      expect(
        compare(lastUploadedRevision: 5, serverRevision: 2).revisionsBehind,
        isNull,
      );
      expect(
        compare(lastUploadedRevision: 3, serverRevision: 3).revisionsBehind,
        isNull,
      );
    });

    test('says nothing when it has never synced', () {
      // "You are 0 revisions behind" would be a lie, and a confusing one.
      expect(
        compare(lastUploadedRevision: null, serverRevision: 7).revisionsBehind,
        isNull,
      );
    });
  });

  test('the classification cannot contradict its own checksums', () {
    // The constructor is private, so `divergence` is always derived. This test
    // documents that the type cannot be hand-built into an inconsistent state,
    // which is what a public constructor would have allowed.
    final result = compare(local: b, server: c);

    expect(result.localChecksum, b);
    expect(result.serverChecksum, c);
    expect(result.lastUploadedChecksum, a);
    expect(result.divergence, Divergence.bothChanged);
  });
}
