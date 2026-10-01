import 'package:financeapp/src/application/business_details.dart';
import 'package:financeapp/src/domain/billing/business_profile.dart';
import 'package:financeapp/src/domain/billing/business_profile_repository.dart';
import 'package:financeapp/src/presentation/app_services.dart';
import 'package:financeapp/src/presentation/finance_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for the business-details panel.
///
/// What matters on this screen is not the layout but three things a user must be
/// told: **the invoice is not valid without a PAN**, **the business is not set up
/// yet**, and **the VAT box decides whether invoices charge VAT at all**.
void main() {
  Future<void> openSettings(
    WidgetTester tester, {
    required BusinessProfileRepository store,
  }) async {
    tester.view.physicalSize = const Size(1600, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      FinanceApp(
        services: AppServices(
          businessDetails: BusinessDetails(repository: store),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
  }

  group('before the business is set up', () {
    testWidgets('says the application cannot yet make a valid tax invoice',
        (tester) async {
      await openSettings(tester, store: _InMemory());

      expect(
        find.textContaining('cannot produce a valid tax invoice'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Nepali law requires your name, address and PAN'),
        findsOneWidget,
      );
    });

    testWidgets('will not save without a business name', (tester) async {
      final store = _InMemory();
      await openSettings(tester, store: store);

      await tester
          .tap(find.byKey(const ValueKey<String>('business-save-button')));
      await tester.pumpAndSettle();

      expect(store.saves, 0);
      expect(find.text('Enter the registered business name'), findsOneWidget);
    });
  });

  group('saving', () {
    testWidgets('saves the details that were typed', (tester) async {
      final store = _InMemory();
      await openSettings(tester, store: store);

      await tester.enterText(
        find.byKey(const ValueKey<String>('business-name-field')),
        'Sharma Electronics Pvt. Ltd.',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('business-pan-field')),
        '301234567',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('business-address-field')),
        'New Road, Kathmandu',
      );
      await tester
          .tap(find.byKey(const ValueKey<String>('business-vat-field')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey<String>('business-save-button')));
      await tester.pumpAndSettle();

      expect(store.saves, 1);
      expect(store.profile?.name, 'Sharma Electronics Pvt. Ltd.');
      expect(store.profile?.panNumber, '301234567');
      expect(store.profile?.isVatRegistered, isTrue);
      expect(find.text('Business details saved.'), findsOneWidget);
    });

    testWidgets('leaves the VAT box alone when it is not ticked',
        (tester) async {
      final store = _InMemory();
      await openSettings(tester, store: store);

      await tester.enterText(
        find.byKey(const ValueKey<String>('business-name-field')),
        'Small Shop',
      );
      await tester
          .tap(find.byKey(const ValueKey<String>('business-save-button')));
      await tester.pumpAndSettle();

      expect(store.profile?.isVatRegistered, isFalse);
    });

    testWidgets("shows the domain's reason when the PAN is refused",
        (tester) async {
      final store = _InMemory();
      await openSettings(tester, store: store);

      await tester.enterText(
        find.byKey(const ValueKey<String>('business-name-field')),
        'Sharma Electronics',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('business-pan-field')),
        '30123A567',
      );
      await tester
          .tap(find.byKey(const ValueKey<String>('business-save-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('is not a valid PAN'), findsOneWidget);
      expect(store.saves, 0);
    });

    testWidgets('refuses VAT registration without a PAN, and says why',
        (tester) async {
      final store = _InMemory();
      await openSettings(tester, store: store);

      await tester.enterText(
        find.byKey(const ValueKey<String>('business-name-field')),
        'Sharma Electronics',
      );
      await tester
          .tap(find.byKey(const ValueKey<String>('business-vat-field')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey<String>('business-save-button')));
      await tester.pumpAndSettle();

      expect(
          find.textContaining('VAT-registered but has no PAN'), findsOneWidget);
      expect(store.saves, 0);
    });
  });

  group('with a profile already saved', () {
    testWidgets('shows the saved values in the form', (tester) async {
      await openSettings(
        tester,
        store: _InMemory(BusinessProfile(
          name: 'Sharma Electronics Pvt. Ltd.',
          panNumber: '301234567',
          isVatRegistered: true,
          address: 'New Road, Kathmandu',
        )),
      );

      expect(find.text('Sharma Electronics Pvt. Ltd.'), findsOneWidget);
      expect(find.text('301234567'), findsOneWidget);
      // The setup warning is gone once there is a profile.
      expect(
        find.textContaining('cannot produce a valid tax invoice'),
        findsNothing,
      );
    });

    testWidgets('shows the VAT box already ticked when it was', (tester) async {
      await openSettings(
        tester,
        store: _InMemory(BusinessProfile(
          name: 'Sharma Electronics',
          panNumber: '301234567',
          isVatRegistered: true,
        )),
      );

      final tile = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey<String>('business-vat-field')),
      );
      expect(tile.value, isTrue);
    });
  });
}

/// A repository backed by a field, so a test can inspect what was saved.
///
/// At top level rather than inside `main`, because a local class declaration
/// inside a function body does not parse here.
class _InMemory implements BusinessProfileRepository {
  _InMemory([this.profile]);

  BusinessProfile? profile;
  int saves = 0;

  @override
  Future<BusinessProfile?> load() async => profile;

  @override
  Future<void> save(BusinessProfile next) async {
    profile = next;
    saves++;
  }
}
