import 'package:financeapp/src/application/create_customer.dart';
import 'package:financeapp/src/domain/billing/customer_code.dart';
import 'package:financeapp/src/domain/billing/customer_code_sequence.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_customer_code_sequence.dart';
import 'package:financeapp/src/infrastructure/database/drift_customer_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_unit_of_work.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Creating a customer, which is the first thing a business must be able to do.
///
/// Two things are asserted beyond "it saves": the **code is allocated inside the
/// transaction**, and the **id is random**. Both were design decisions in ADR 010,
/// and both are easy to regress silently.
void main() {
  late AppDatabase db;
  late DriftCustomerRepository customers;
  late CustomerCodeSequence codes;
  late CreateCustomer createCustomer;

  setUp(() {
    db = openInMemoryDatabase();
    customers = DriftCustomerRepository(db);
    codes = DriftCustomerCodeSequence(db);
    createCustomer = CreateCustomer(
      customers: customers,
      codes: codes,
      unitOfWork: DriftUnitOfWork(db),
    );
  });

  tearDown(() async => db.close());

  test('a new customer is saved and given a code', () async {
    final outcome = await createCustomer(name: 'Himalayan Traders');

    expect(outcome, isA<CustomerCreated>());
    final created = outcome;
    expect(created.customer.name, 'Himalayan Traders');
    expect(created.customer.code, isNotNull);

    final stored = await customers.byId(created.customer.id);
    expect(stored?.name, 'Himalayan Traders');
    expect(stored?.code, created.customer.code);
  });

  test('codes are sequential and formatted as C-0001', () async {
    final first = await createCustomer(name: 'Alpha');
    final second = await createCustomer(name: 'Beta');

    expect(first.customer.code, 'C-0001');
    expect(second.customer.code, 'C-0002');
  });

  test('codes keep counting across fiscal years', () async {
    // **The point of a separate sequence.** Document numbers restart each fiscal
    // year; a customer code must not, or the same code would name two different
    // customers and an old invoice would become ambiguous.
    await createCustomer(name: 'Alpha');

    final codes = await DriftCustomerCodeSequence(db).lastAllocated();

    expect(codes, 1);
  });

  test('the id is random, not derived from anything a person types', () async {
    // Two customers created the same second must not collide, and a code like
    // C-0001 must not determine the id: ids also have to not collide if two
    // installations ever sync. See ADR 010.
    final first = await createCustomer(name: 'Same Name');
    final second = await createCustomer(name: 'Same Name');

    expect(first.customer.id, isNot(second.customer.id));
    expect(first.customer.id, isNot(startsWith('C-')));
  });

  test('a customer with no PAN is allowed, because many are individuals',
      () async {
    final outcome = await createCustomer(name: 'Ram Bahadur');

    expect(outcome.customer.hasPan, isFalse);
    expect(outcome.customer.panNumber, isNull);
  });

  test('a PAN is kept when given', () async {
    final outcome = await createCustomer(
      name: 'XYZ Suppliers',
      panNumber: '301234567',
    );

    expect(outcome.customer.panNumber, '301234567');
  });

  test('a malformed PAN is refused before anything is written', () async {
    var rejected = false;
    try {
      await createCustomer(name: 'X', panNumber: '30123A567');
    } on CustomerRejected {
      rejected = true;
    }

    expect(rejected, isTrue);
    expect(await customers.all(), isEmpty);
    expect(await codes.lastAllocated(), 0,
        reason: 'a refused customer must not burn a code');
  });

  test('an empty name is refused and nothing is written', () async {
    var rejected = false;
    try {
      await createCustomer(name: '   ');
    } on CustomerRejected {
      rejected = true;
    }

    expect(rejected, isTrue);
    expect(await customers.all(), isEmpty);
    expect(await codes.lastAllocated(), 0);
  });

  test('VAT registration without a PAN is refused', () async {
    // In Nepal the VAT number *is* the PAN with a flag set, so there is nothing
    // to register against.
    var rejected = false;
    try {
      await createCustomer(name: 'Registered Firm', isVatRegistered: true);
    } on CustomerRejected {
      rejected = true;
    }

    expect(rejected, isTrue);
    expect(await customers.all(), isEmpty);
  });

  test('every customer gets a different code', () async {
    final made = <String>{};
    for (var i = 0; i < 5; i++) {
      final outcome = await createCustomer(name: 'Customer $i');
      made.add(outcome.customer.code!);
    }

    expect(made, hasLength(5));
  });

  test('a code is never handed out twice', () async {
    final codes = <String>{};
    for (var i = 0; i < 3; i++) {
      final outcome = await createCustomer(name: 'Customer $i');
      expect(codes.add(outcome.customer.code!), isTrue,
          reason: 'two customers quotable as the same reference is unusable');
    }
  });

  test('the formatted code zero-pads so it sorts and reads consistently', () {
    expect(const CustomerCode(1).value, 'C-0001');
    expect(const CustomerCode(42).value, 'C-0042');
    expect(const CustomerCode(1234).value, 'C-1234');
    expect(const CustomerCode(0).value, 'C-0000');
  });
}
