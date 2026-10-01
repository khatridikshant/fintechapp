import 'package:financeapp/src/application/create_customer.dart';
import 'package:financeapp/src/domain/billing/customer.dart';
import 'package:financeapp/src/domain/billing/customer_repository.dart';
import 'package:financeapp/src/domain/shared/unit_of_work.dart';
import 'package:financeapp/src/domain/billing/customer_code_sequence.dart';
import 'package:financeapp/src/presentation/app_services.dart';
import 'package:financeapp/src/presentation/finance_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A customer with the given fields, for a fake to hand back.
Customer _customer({
  required String id,
  required String name,
  required String code,
  String? panNumber,
  bool isVatRegistered = false,
  String? phone,
  String? address,
  String? businessName,
}) =>
    Customer(
      id: id,
      code: code,
      name: name,
      panNumber: panNumber,
      isVatRegistered: isVatRegistered,
      phone: phone,
      address: address,
      businessName: businessName,
    );

/// Widget tests for the New Customer screen.
///
/// The screen decides **nothing** about the business, so these check that it hands
/// what was typed to the use case untouched, that the domain's own refusal is
/// what the user sees, and that a PAN typed on a keyboard without a hyphen works.
void main() {
  Future<void> open(WidgetTester tester, CreateCustomer createCustomer) async {
    tester.view.physicalSize = const Size(1600, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      FinanceApp(services: AppServices(createCustomer: createCustomer)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customers'));
    await tester.pumpAndSettle();
  }

  group('before saving', () {
    testWidgets('offers every field a customer needs', (tester) async {
      await open(tester, _FakeCreateCustomer());

      for (final key in <String>[
        'customer-name-field',
        'customer-business-name-field',
        'customer-pan-field',
        'customer-phone-field',
        'customer-address-field',
        'customer-vat-field',
        'customer-save-button',
      ]) {
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget,
            reason: '$key must be on the form');
      }
    });

    testWidgets(
        'says a business gets a reference and an individual need not '
        'have a PAN', (tester) async {
      await open(tester, _FakeCreateCustomer());

      expect(find.textContaining('reference such as'), findsOneWidget);
      expect(find.textContaining('do not need a PAN'), findsOneWidget);
    });

    testWidgets('will not save without a name', (tester) async {
      final fake = _FakeCreateCustomer();
      await open(tester, fake);

      await tester
          .tap(find.byKey(const ValueKey<String>('customer-save-button')));
      await tester.pumpAndSettle();

      expect(fake.calls, isEmpty);
      expect(find.text('Enter a name'), findsOneWidget);
    });
  });

  group('saving', () {
    testWidgets('passes what was typed to the use case', (tester) async {
      final fake = _FakeCreateCustomer();
      await open(tester, fake);

      await tester.enterText(
        find.byKey(const ValueKey<String>('customer-name-field')),
        'Himalayan Traders',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('customer-address-field')),
        'New Road, Kathmandu',
      );
      await tester
          .tap(find.byKey(const ValueKey<String>('customer-save-button')));
      await tester.pumpAndSettle();

      expect(fake.calls, hasLength(1));
      expect(fake.calls.single['name'], 'Himalayan Traders');
      expect(fake.calls.single['address'], 'New Road, Kathmandu');
    });

    testWidgets('strips the hyphens from a typed PAN', (tester) async {
      // On a soft keyboard nobody types the hyphens, and a PAN typed with them
      // must still be the same PAN.
      final fake = _FakeCreateCustomer();
      await open(tester, fake);

      await tester.enterText(
        find.byKey(const ValueKey<String>('customer-name-field')),
        'XYZ Suppliers',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('customer-pan-field')),
        '301-234-567',
      );
      await tester
          .tap(find.byKey(const ValueKey<String>('customer-save-button')));
      await tester.pumpAndSettle();

      expect(fake.calls.single['panNumber'], '301234567');
    });

    testWidgets('sends no PAN at all when the field is empty', (tester) async {
      final fake = _FakeCreateCustomer();
      await open(tester, fake);

      await tester.enterText(
        find.byKey(const ValueKey<String>('customer-name-field')),
        'Ram Bahadur',
      );
      await tester
          .tap(find.byKey(const ValueKey<String>('customer-save-button')));
      await tester.pumpAndSettle();

      expect(fake.calls.single['panNumber'], isNull);
    });

    testWidgets('shows the reference so it can be quoted straight away',
        (tester) async {
      await open(tester, _FakeCreateCustomer());

      await tester.enterText(
        find.byKey(const ValueKey<String>('customer-name-field')),
        'Himalayan Traders',
      );
      await tester
          .tap(find.byKey(const ValueKey<String>('customer-save-button')));
      await tester.pumpAndSettle();

      // Specific, because `C-0001` also appears in the hint text above the form.
      expect(find.text('Saved as C-0001'), findsOneWidget);
    });

    testWidgets('clears the form so the next customer does not duplicate it',
        (tester) async {
      await open(tester, _FakeCreateCustomer());

      await tester.enterText(
        find.byKey(const ValueKey<String>('customer-name-field')),
        'Himalayan Traders',
      );
      await tester
          .tap(find.byKey(const ValueKey<String>('customer-save-button')));
      await tester.pumpAndSettle();

      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('customer-name-field')),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.controller.text, isEmpty);
    });
  });

  group('refusals', () {
    testWidgets("shows the domain's own reason, not a second wording",
        (tester) async {
      await open(
        tester,
        _FakeCreateCustomer(refuseWith: 'A PAN is nine digits'),
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('customer-name-field')),
        'Himalayan Traders',
      );
      await tester
          .tap(find.byKey(const ValueKey<String>('customer-save-button')));
      await tester.pumpAndSettle();

      expect(find.text('A PAN is nine digits'), findsOneWidget);
    });

    testWidgets('catches a wrong-length PAN before the use case is called',
        (tester) async {
      final fake = _FakeCreateCustomer();
      await open(tester, fake);

      await tester.enterText(
        find.byKey(const ValueKey<String>('customer-name-field')),
        'Himalayan Traders',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('customer-pan-field')),
        '30123',
      );
      await tester
          .tap(find.byKey(const ValueKey<String>('customer-save-button')));
      await tester.pumpAndSettle();

      expect(fake.calls, isEmpty);
      expect(find.text('A PAN is nine digits'), findsOneWidget);
    });
  });
}

/// Records what was passed to the use case, and can be told to refuse.
/// Records what was passed to the use case, and can be told to refuse.
///
/// `implements` rather than `extends`, so the three dependencies do not have to be
/// faked for a test that only cares what the screen passes in.
class _FakeCreateCustomer implements CreateCustomer {
  _FakeCreateCustomer({this.refuseWith});

  final String? refuseWith;
  final List<Map<String, Object?>> calls = <Map<String, Object?>>[];

  @override
  CustomerRepository get customers => throw UnimplementedError();

  @override
  CustomerCodeSequence get codes => throw UnimplementedError();

  @override
  UnitOfWork get unitOfWork => throw UnimplementedError();

  @override
  Future<CustomerCreated> call({
    required String name,
    String? panNumber,
    bool isVatRegistered = false,
    String? phone,
    String? address,
    String? businessName,
  }) async {
    calls.add(<String, Object?>{
      'name': name,
      'panNumber': panNumber,
      'isVatRegistered': isVatRegistered,
      'phone': phone,
      'address': address,
      'businessName': businessName,
    });

    if (refuseWith != null) throw CustomerRejected(refuseWith!);

    return CustomerCreated(
      _customer(
        id: 'cus-1',
        code: 'C-0001',
        name: name,
        panNumber: panNumber,
        isVatRegistered: isVatRegistered,
        phone: phone,
        address: address,
        businessName: businessName,
      ),
    );
  }
}
