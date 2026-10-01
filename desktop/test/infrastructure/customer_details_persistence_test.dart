import 'package:drift/native.dart';
import 'package:financeapp/src/domain/billing/customer.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_customer_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// The customer-identity fields **must survive a round trip through storage**.
///
/// This is the test that would have caught the bug it now guards: the domain
/// carried `code`, `isVatRegistered`, and `businessName`, the repository accepted
/// a `Customer`, and nothing warned when they were not written. A customer saved
/// with a code and read back without one looks fine on screen and is wrong in the
/// books.
void main() {
  late AppDatabase db;
  late DriftCustomerRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftCustomerRepository(db);
  });

  tearDown(() async => db.close());

  test('a business code survives a round trip', () async {
    await repository.save(Customer(
      id: 'c-1',
      code: 'C-0001',
      name: 'Himalayan Traders',
      panNumber: '301234567',
    ));

    expect((await repository.byId('c-1'))?.code, 'C-0001');
  });

  test('VAT registration survives a round trip', () async {
    await repository.save(Customer(
      id: 'c-1',
      name: 'Himalayan Traders',
      panNumber: '301234567',
      isVatRegistered: true,
    ));

    // The single most important assertion here: if this read back false, the
    // application would stop asking for the PAN that lets this customer claim
    // input credit.
    expect((await repository.byId('c-1'))?.isVatRegistered, isTrue);
  });

  test('a registered business name survives a round trip', () async {
    await repository.save(Customer(
      id: 'c-1',
      name: 'Ram',
      businessName: 'Himalayan Traders Pvt. Ltd.',
      panNumber: '301234567',
    ));

    expect((await repository.byId('c-1'))?.businessName,
        'Himalayan Traders Pvt. Ltd.');
    expect((await repository.byId('c-1'))?.nameForBill,
        'Himalayan Traders Pvt. Ltd.');
  });

  test('every field survives together, not one at a time', () async {
    // Saved separately, each field could pass while the combination failed -- for
    // instance if the detail row were keyed wrongly.
    await repository.save(Customer(
      id: 'c-1',
      code: 'C-0042',
      name: 'Himalayan Traders',
      panNumber: '301234567',
      isVatRegistered: true,
      businessName: 'Himalayan Traders Pvt. Ltd.',
      phone: '01-4225000',
      address: 'New Road',
    ));

    final stored = await repository.byId('c-1');
    expect(stored?.code, 'C-0042');
    expect(stored?.isVatRegistered, isTrue);
    expect(stored?.businessName, 'Himalayan Traders Pvt. Ltd.');
    expect(stored?.panNumber, '301234567');
    expect(stored?.phone, '01-4225000');
    expect(stored?.address, 'New Road');
  });

  test('a customer with no details is still returned', () async {
    // A customer whose detail row is absent must not vanish from the list. An
    // inner join would drop them, and a customer who cannot be found cannot be
    // invoiced.
    await db.into(db.customers).insert(CustomersCompanion.insert(
          id: 'legacy-1',
          name: 'Recorded Before Details Existed',
        ));

    final found = await repository.byId('legacy-1');
    expect(found, isNotNull);
    expect(found?.code, isNull);
    expect(found?.isVatRegistered, isFalse,
        reason: 'unknown VAT status must be treated as unregistered, so the '
            'application asks rather than assumes');
  });

  test('saving twice updates rather than duplicating', () async {
    await repository.save(Customer(
      id: 'c-1',
      name: 'Himalayan Traders',
      panNumber: '301234567',
    ));
    await repository.save(Customer(
      id: 'c-1',
      name: 'Himalayan Traders',
      panNumber: '301234567',
      isVatRegistered: true,
    ));

    expect((await repository.byId('c-1'))?.isVatRegistered, isTrue);
    expect(await repository.all(), hasLength(1));
  });

  test('bulk save stores details for everyone', () async {
    await repository.saveAll([
      Customer(id: 'a', name: 'Alpha', panNumber: '301234567', code: 'C-0001'),
      Customer(id: 'b', name: 'Beta', panNumber: '301234568', code: 'C-0002'),
    ]);

    final all = await repository.all();
    expect(all, hasLength(2));
    expect(all.map((Customer c) => c.code),
        containsAll(<String>['C-0001', 'C-0002']));
  });

  test('two customers cannot share a business code', () async {
    await repository.save(Customer(
      id: 'a',
      name: 'Alpha',
      panNumber: '301234567',
      code: 'C-0001',
    ));

    // The database refuses it rather than the application, so two customers can
    // never be quotable as the same reference.
    expect(
      () => repository.save(Customer(
        id: 'b',
        name: 'Beta',
        panNumber: '301234568',
        code: 'C-0001',
      )),
      throwsA(anything),
    );
  });

  test('many customers may have no PAN at all', () async {
    // Most customers are individuals with no business PAN, so absence must not
    // read as a duplicate.
    await repository.saveAll([
      Customer(id: 'a', name: 'Walk-in One'),
      Customer(id: 'b', name: 'Walk-in Two'),
      Customer(id: 'c', name: 'Walk-in Three'),
    ]);

    expect(await repository.all(), hasLength(3));
  });
}
