import 'package:financeapp/src/application/business_details.dart';
import 'package:financeapp/src/domain/billing/business_profile.dart';
import 'package:financeapp/src/infrastructure/database/business_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_business_profile_repository.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The business's own details must survive a round trip, and the VAT flag must
/// come back exactly as set.
///
/// The VAT flag is the one value here that **changes behaviour** -- it decides
/// whether invoices charge 13%. If it silently read back `false`, a registered
/// business would invoice without VAT and nothing would say so.
void main() {
  late BusinessDatabase db;
  late BusinessDetails details;

  setUp(() {
    db = BusinessDatabase(openInMemoryExecutor());
    details = BusinessDetails(repository: DriftBusinessProfileRepository(db));
  });

  tearDown(() async => db.close());

  test('a fresh installation has no profile, and that is not an error',
      () async {
    // The normal first-run state. The application must still start and still take
    // backups; it simply cannot produce a valid tax invoice yet.
    expect(await details.load(), isNull);
  });

  test('every field survives a round trip', () async {
    await details.save(BusinessProfile(
      name: 'Sharma Electronics Pvt. Ltd.',
      panNumber: '301234567',
      isVatRegistered: true,
      address: 'New Road, Kathmandu',
      phone: '01-4225000',
      email: 'accounts@sharma.example.np',
      bankDetails: 'Nabil Bank, New Road',
    ));

    final stored = await details.load();
    expect(stored?.name, 'Sharma Electronics Pvt. Ltd.');
    expect(stored?.panNumber, '301234567');
    expect(stored?.isVatRegistered, isTrue);
    expect(stored?.address, 'New Road, Kathmandu');
    expect(stored?.phone, '01-4225000');
    expect(stored?.email, 'accounts@sharma.example.np');
    expect(stored?.bankDetails, 'Nabil Bank, New Road');
  });

  test('the VAT flag comes back exactly as set', () async {
    await details.save(BusinessProfile(
      name: 'Not Registered',
      panNumber: '301234567',
      isVatRegistered: false,
    ));
    expect((await details.load())?.isVatRegistered, isFalse);

    await details.save(BusinessProfile(
      name: 'Registered',
      panNumber: '301234567',
      isVatRegistered: true,
    ));
    expect((await details.load())?.isVatRegistered, isTrue);
  });

  test('there is one profile, not a growing list', () async {
    await details.save(BusinessProfile(name: 'First', panNumber: '301234567'));
    await details.save(BusinessProfile(name: 'Second', panNumber: '301234568'));

    expect((await details.load())?.name, 'Second');
    expect(await db.select(db.businessProfiles).get(), hasLength(1));
  });

  test('a PAN may be absent, because many businesses have not registered',
      () async {
    await details.save(BusinessProfile(name: 'Small Shop'));
    expect((await details.load())?.hasPan, isFalse);
  });

  test('a malformed PAN is refused rather than stored', () async {
    // Storing it would put an invalid PAN on every printed invoice, where it
    // looks compliant and is not.
    expect(
      () => details.save(BusinessProfile(name: 'X', panNumber: '30123A567')),
      throwsArgumentError,
    );
    expect(await details.load(), isNull);
  });

  test('a VAT-registered business must have a PAN', () async {
    // In Nepal the VAT number is the PAN with a registration flag set.
    expect(
      () => details.save(BusinessProfile(name: 'X', isVatRegistered: true)),
      throwsArgumentError,
    );
  });

  test('a blank name is refused', () async {
    expect(
      () => details.save(BusinessProfile(name: '   ')),
      throwsArgumentError,
    );
  });
}
