import '../domain/billing/business_profile.dart';
import '../domain/billing/business_profile_repository.dart';

/// Loading and saving this business's own details.
///
/// ## Why a use case and not a repository handed to the screen
///
/// The architecture forbids a screen from holding a repository, and that rule is
/// right: a screen given a repository can save anything it likes, including a
/// profile that was never validated. The version that handed
/// `BusinessProfileRepository` straight to the Settings screen was caught by
/// `architecture_test.dart`, which is precisely what that test is for.
///
/// This use case is the seam. The screen asks it to load and to save, and the
/// domain's validating constructor still decides whether a PAN is well formed and
/// whether a VAT-registered business may have none.
class BusinessDetails {
  const BusinessDetails({required BusinessProfileRepository repository})
      : _repository = repository;

  final BusinessProfileRepository _repository;

  /// The saved profile, or null when the business is not set up yet.
  ///
  /// **Null is the normal first-run state.** A fresh installation must still start
  /// and still take backups; it simply cannot produce a valid tax invoice yet, and
  /// the Settings screen says so.
  Future<BusinessProfile?> load() => _repository.load();

  /// Saves [profile].
  ///
  /// Throws [ArgumentError] when the profile is invalid, and the message is the
  /// domain's own -- the screen shows it rather than inventing wording.
  Future<void> save(BusinessProfile profile) => _repository.save(profile);
}
