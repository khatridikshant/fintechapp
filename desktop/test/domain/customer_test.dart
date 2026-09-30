import 'package:financeapp/src/domain/billing/customer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Customer construction', () {
    test('accepts the required fields and no optional ones', () {
      final customer = Customer(id: 'cust-1', name: 'Himalayan Traders');

      expect(customer.id, 'cust-1');
      expect(customer.name, 'Himalayan Traders');
      expect(customer.panNumber, isNull);
      expect(customer.phone, isNull);
      expect(customer.address, isNull);
      expect(customer.hasPanNumber, isFalse);
    });

    test('accepts every optional field', () {
      final customer = Customer(
        id: 'cust-1',
        name: 'Himalayan Traders',
        panNumber: '123456789',
        phone: '9800000000',
        address: 'Pokhara, Kaski',
      );

      expect(customer.panNumber, '123456789');
      expect(customer.phone, '9800000000');
      expect(customer.address, 'Pokhara, Kaski');
      expect(customer.hasPanNumber, isTrue);
    });

    test('a blank id is rejected', () {
      expect(() => Customer(id: '', name: 'X'), throwsArgumentError);
      expect(() => Customer(id: '   ', name: 'X'), throwsArgumentError);
    });

    test('a blank name is rejected', () {
      expect(() => Customer(id: 'cust-1', name: ''), throwsArgumentError);
      expect(() => Customer(id: 'cust-1', name: '   '), throwsArgumentError);
    });

    test('a blank optional field becomes null, not an empty string', () {
      // "Not provided" must have exactly one representation. Storing both null
      // and '' would make every later query test two cases and eventually miss
      // one of them.
      final customer = Customer(
        id: 'cust-1',
        name: 'Himalayan Traders',
        panNumber: '',
        phone: '   ',
        address: '\t',
      );

      expect(customer.panNumber, isNull);
      expect(customer.phone, isNull);
      expect(customer.address, isNull);
      expect(customer.hasPanNumber, isFalse);
    });

    test('surrounding whitespace is trimmed', () {
      final customer = Customer(
        id: '  cust-1  ',
        name: '  Himalayan Traders  ',
        panNumber: '  123456789  ',
      );

      expect(customer.id, 'cust-1');
      expect(customer.name, 'Himalayan Traders');
      expect(customer.panNumber, '123456789');
    });
  });

  group('Customer identity', () {
    test('two customers are equal when their ids match', () {
      final a = Customer(id: 'cust-1', name: 'Himalayan Traders');
      final b = Customer(
        id: 'cust-1',
        name: 'Himalayan Traders Pvt Ltd',
        phone: '9800000000',
      );

      // The name is an attribute, not identity. Renaming a customer must not
      // break the invoices and journal entries that reference them.
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different ids are different customers', () {
      expect(
        Customer(id: 'cust-1', name: 'A'),
        isNot(Customer(id: 'cust-2', name: 'A')),
      );
    });
  });
}
