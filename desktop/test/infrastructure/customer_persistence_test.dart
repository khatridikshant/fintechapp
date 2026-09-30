import 'dart:io';

import 'package:financeapp/src/domain/billing/customer.dart';
import 'package:financeapp/src/infrastructure/database/drift_customer_repository.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('financeapp_customer_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('Customer persistence', () {
    test('round-trips every field', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final customers = DriftCustomerRepository(db);

      await customers.save(
        Customer(
          id: 'cust-1',
          name: 'Himalayan Traders',
          panNumber: '123456789',
          phone: '9800000000',
          address: 'Pokhara, Kaski',
        ),
      );

      final loaded = await customers.byId('cust-1');
      expect(loaded, isNotNull);
      expect(loaded!.id, 'cust-1');
      expect(loaded.name, 'Himalayan Traders');
      expect(loaded.panNumber, '123456789');
      expect(loaded.phone, '9800000000');
      expect(loaded.address, 'Pokhara, Kaski');
    });

    test('round-trips absent optional fields as absent, not as empty strings',
        () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final customers = DriftCustomerRepository(db);

      await customers.save(Customer(id: 'cust-1', name: 'Walk-in Customer'));

      final loaded = await customers.byId('cust-1');
      expect(loaded!.panNumber, isNull);
      expect(loaded.phone, isNull);
      expect(loaded.address, isNull);
      expect(loaded.hasPanNumber, isFalse);
    });

    test('an unknown id returns null rather than throwing', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      expect(await DriftCustomerRepository(db).byId('nobody'), isNull);
    });

    test('saving the same id updates rather than duplicating', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final customers = DriftCustomerRepository(db);

      await customers.save(Customer(id: 'cust-1', name: 'Old Name'));
      await customers.save(Customer(id: 'cust-1', name: 'New Name'));

      final all = await customers.all();
      expect(all, hasLength(1));
      expect(all.single.name, 'New Name');
    });

    test('customers are listed by name', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final customers = DriftCustomerRepository(db);

      await customers.saveAll([
        Customer(id: 'cust-2', name: 'Zenith Suppliers'),
        Customer(id: 'cust-1', name: 'Annapurna Traders'),
        Customer(id: 'cust-3', name: 'Mountain Goods'),
      ]);

      expect(
        (await customers.all()).map((c) => c.name),
        ['Annapurna Traders', 'Mountain Goods', 'Zenith Suppliers'],
      );
    });

    test('the database refuses a customer with a blank name', () async {
      // The domain already prevents this, so the check fires only for a write
      // that bypassed the domain. That is exactly what it exists to catch.
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      await expectLater(
        db.customStatement(
          'INSERT INTO customers (id, name) VALUES (?, ?)',
          ['cust-bad', '   '],
        ),
        throwsA(predicate((e) => e.toString().toLowerCase().contains('check'))),
      );
    });

    test('a customer survives closing and reopening the database', () async {
      final file = File(p.join(tempDir.path, 'accounting-FY-2082-83.db'));

      final db = openFileDatabase(file);
      await DriftCustomerRepository(db).save(
        Customer(id: 'cust-1', name: 'Himalayan Traders', phone: '9800000000'),
      );
      await db.close();

      final reopened = openFileDatabase(file);
      final loaded = await DriftCustomerRepository(reopened).byId('cust-1');
      await reopened.close();

      expect(loaded, isNotNull);
      expect(loaded!.name, 'Himalayan Traders');
      expect(loaded.phone, '9800000000');
      expect(loaded.panNumber, isNull);
    });
  });
}
