import 'package:drift/drift.dart' show Value;

import '../../domain/billing/business_profile.dart';
import '../../domain/billing/business_profile_repository.dart';
import 'business_database.dart';

/// Stores this business's details in a single row of its own database.
class DriftBusinessProfileRepository implements BusinessProfileRepository {
  DriftBusinessProfileRepository(this.db);

  final BusinessDatabase db;

  /// The fixed key for the one profile V1 has.
  static const String singletonKey = 'primary';

  @override
  Future<BusinessProfile?> load() async {
    final row = await (db.select(db.businessProfiles)
          ..where((t) => t.id.equals(singletonKey)))
        .getSingleOrNull();
    if (row == null) return null;

    return BusinessProfile(
      name: row.name,
      panNumber: row.pan,
      isVatRegistered: row.isVatRegistered,
      address: row.address,
      phone: row.phone,
      email: row.email,
      bankDetails: row.bankDetails,
    );
  }

  @override
  Future<void> save(BusinessProfile profile) async {
    await db.into(db.businessProfiles).insertOnConflictUpdate(
          BusinessProfilesCompanion.insert(
            id: singletonKey,
            name: profile.name,
            pan: Value(profile.panNumber),
            isVatRegistered: Value(profile.isVatRegistered),
            address: Value(profile.address),
            phone: Value(profile.phone),
            email: Value(profile.email),
            bankDetails: Value(profile.bankDetails),
          ),
        );
  }
}
