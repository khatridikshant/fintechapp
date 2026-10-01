import 'business_profile.dart';

/// Port for storing this business's details.
///
/// **A singleton**, not a collection. ADR 003 allows one book per account in V1,
/// so there is one business and one row. An interface that returns "the profile"
/// rather than "a profile by id" states that plainly, and a future multi-business
/// version changes this port rather than every caller.
abstract interface class BusinessProfileRepository {
  /// The saved profile, or null when the business has not been set up yet.
  ///
  /// **Null is the normal first-run state**, not an error. A fresh installation
  /// has no business name, no PAN, and no VAT status, and the application must
  /// still start and still take backups -- it simply cannot produce a valid tax
  /// invoice until the details are entered.
  Future<BusinessProfile?> load();

  /// Saves [profile], replacing whatever was there.
  ///
  /// [BusinessProfile] should be constructed before this is called, because the
  /// database will not catch a missing name and cannot judge whether a PAN is
  /// valid.
  Future<void> save(BusinessProfile profile);
}
