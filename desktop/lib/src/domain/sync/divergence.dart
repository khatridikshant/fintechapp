/// How the local books compare with what the server holds.
///
/// ## Why this exists
///
/// Two computers can hold different books. One records invoice #5, the other
/// records payment #6, and now there are two internally consistent databases that
/// are **not the same books**. Every upload of both is accepted, because each file
/// genuinely is a valid snapshot of *something*.
///
/// Revision numbers alone cannot detect this. What detects it is comparing
/// checksums: the server stores a SHA-256 for every revision, and the desktop
/// already computes one for every snapshot it sends. Three checksums are enough to
/// tell the four cases apart.
///
/// ## Why there is no merge
///
/// Because a wrong merge of accounting books is worse than a refusal. Document
/// numbering would collide, closing balances would be wrong, and any period already
/// filed would no longer match. So [Divergence.bothChanged] is a **stop**, not a
/// third option: the honest answer is that these two cannot be combined
/// automatically, and the user has to decide which is real.
enum Divergence {
  /// Nothing has happened on either side. The ordinary case, and it must be
  /// **silent** — a user should never be asked about a difference that does not
  /// exist.
  none,

  /// Only this computer changed since the last sync.
  ///
  /// An ordinary upload. Nothing to ask about.
  localOnly,

  /// Only the server changed since the last sync.
  ///
  /// Another computer stored a revision, and its books differ from what this one
  /// last sent. **This is the case where a genuine choice exists**: either this
  /// computer's books are stale and should be replaced, or they are right and
  /// should be pushed.
  serverOnly,

  /// **Both changed.** The dangerous case, and the reason the other three exist.
  ///
  /// This computer has edits that are nowhere else, and the server has books that
  /// are not this computer's. "Keep mine" destroys the other device's work; "take
  /// theirs" destroys this one's.
  ///
  /// **Never offered as a choice.** The application must stop and say so. The one
  /// thing it may do is preserve both and show what each contains.
  bothChanged;

  /// Whether a person has to decide something.
  ///
  /// **False for [localOnly], and that distinction is the point.** "Only this
  /// computer changed" needs no decision — the upload just happens. Treating it as
  /// needing attention would prompt the user to confirm work that has no
  /// alternative, and a prompt that is always answered the same way is a prompt
  /// people stop reading.
  ///
  /// So only [serverOnly] and [bothChanged] qualify.
  bool get needsAttention =>
      this == Divergence.serverOnly || this == Divergence.bothChanged;

  /// Whether proceeding would silently destroy another computer's work.
  ///
  /// The answer that must never be "yes, go ahead".
  bool get isDangerous => this == Divergence.bothChanged;

  /// Whether this can be handled without asking anybody anything.
  ///
  /// True for [none] and for [localOnly]: the correct action is the same either
  /// way, and it is the same action this application already takes.
  bool get isQuiet => !needsAttention;
}

/// The facts a comparison is made from.
///
/// ## Constructed only through [SyncComparison.from]
///
/// The constructor is private on purpose. Handing over the fields directly would
/// allow an object whose `divergence` contradicts its own checksums — which is
/// precisely the kind of contradiction this class exists to rule out.
class SyncComparison {
  SyncComparison._({
    required this.divergence,
    required this.localChecksum,
    required this.lastUploadedChecksum,
    required this.serverChecksum,
    required this.lastUploadedRevision,
    required this.serverRevision,
  });

  /// Classify from the checksums alone.
  ///
  /// ## Why checksums and not revisions
  ///
  /// A revision number says *when* the server last stored something, not whether its
  /// content differs from what this computer holds. Another device re-uploading
  /// identical bytes advances the revision and changes nothing. Comparing revisions
  /// would then claim a divergence that does not exist, and train the user to
  /// dismiss the warning.
  ///
  /// So "changed" means *the bytes differ*, every time.
  ///
  /// ## A null server checksum means "nothing stored yet"
  ///
  /// Not "the server holds something different". A first upload has nothing to
  /// compare against, and treating that as a conflict would make a brand-new account
  /// refuse its own first backup.
  ///
  /// ## A null local checksum means "cannot read the books"
  ///
  /// Reported as [Divergence.localOnly] because the only safe action is an upload:
  /// pushing cannot destroy anything the server holds, since there is nothing to
  /// compare it against. Claiming a conflict would block the user on a read error
  /// rather than on a real disagreement.
  factory SyncComparison.from({
    required String? localChecksum,
    required String? lastUploadedChecksum,
    required String? serverChecksum,
    int? lastUploadedRevision,
    int? serverRevision,
  }) {
    final Divergence divergence;

    if (serverChecksum == null) {
      // Nothing stored yet: this cannot disagree with anything.
      divergence = Divergence.localOnly;
    } else if (localChecksum == null) {
      // Could not read the local books. Upload is safe; refusing is not.
      divergence = Divergence.localOnly;
    } else if (lastUploadedChecksum == null) {
      // This device has never synced, so there is no common ancestor to compare
      // against. Both sides hold books and there is no way to tell which is "the
      // change".
      //
      // Treated as [Divergence.bothChanged] deliberately. **This is the first-sync
      // case, and it is exactly the scenario the whole feature exists for**: a
      // second computer joining an account that already has books. Reporting it as
      // "fine, upload away" would let the new device overwrite the existing books
      // with its own, and nothing would say so.
      divergence = Divergence.bothChanged;
    } else {
      final localChanged = localChecksum != lastUploadedChecksum;
      final serverChanged = serverChecksum != lastUploadedChecksum;

      divergence = switch ((localChanged, serverChanged)) {
        (false, false) => Divergence.none,
        (true, false) => Divergence.localOnly,
        (false, true) => Divergence.serverOnly,
        (true, true) => Divergence.bothChanged,
      };
    }

    return SyncComparison._(
      divergence: divergence,
      localChecksum: localChecksum,
      lastUploadedChecksum: lastUploadedChecksum,
      serverChecksum: serverChecksum,
      lastUploadedRevision: lastUploadedRevision,
      serverRevision: serverRevision,
    );
  }

  /// What the comparison found.
  final Divergence divergence;

  /// SHA-256 of the books as they are on this computer now.
  final String? localChecksum;

  /// SHA-256 of what this computer last had confirmed by the server.
  final String? lastUploadedChecksum;

  /// SHA-256 of the server's newest stored revision for this year.
  final String? serverChecksum;

  /// The revision this computer last pushed, or null if it never has.
  final int? lastUploadedRevision;

  /// The server's newest revision for this year.
  final int? serverRevision;

  /// Whether this computer has ever synced this year.
  bool get hasSyncedBefore => lastUploadedChecksum != null;

  /// Whether a person has to decide something.
  ///
  /// Delegated so callers read `comparison.needsAttention` rather than reaching
  /// through to the enum — the comparison is the thing a screen holds.
  bool get needsAttention => divergence.needsAttention;

  /// Whether proceeding would silently destroy another computer's work.
  bool get isDangerous => divergence.isDangerous;

  /// How many revisions the server is ahead by, if it is ahead at all.
  ///
  /// Null when there is nothing meaningful to say — never synced, or not behind.
  int? get revisionsBehind {
    final mine = lastUploadedRevision;
    final theirs = serverRevision;
    if (mine == null || theirs == null) return null;
    final behind = theirs - mine;
    return behind > 0 ? behind : null;
  }

  @override
  String toString() =>
      'SyncComparison(${divergence.name}, local=$localChecksum, '
      'lastUploaded=$lastUploadedChecksum, server=$serverChecksum)';
}
