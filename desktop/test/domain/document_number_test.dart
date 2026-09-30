import 'package:financeapp/src/domain/billing/document_number.dart';
import 'package:financeapp/src/domain/billing/document_type.dart';
import 'package:financeapp/src/domain/fiscal/fiscal_year.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

final fy2082 = const NepaliFiscalCalendar().forBsYear(2082);
final fy2083 = const NepaliFiscalCalendar().forBsYear(2083);

DocumentNumber number(DocumentType type, FiscalYear year, int sequence) =>
    DocumentNumber.of(type: type, fiscalYear: year, sequence: sequence);

void main() {
  group('DocumentNumber formatting', () {
    test('the first invoice of a fiscal year is INV-2082-83-0001', () {
      expect(
        number(DocumentType.invoice, fy2082, 1).value,
        'INV-2082-83-0001',
      );
    });

    test('matches the documented example', () {
      // ADR 005 documents the shape as INV-2082-83-1042.
      expect(
        number(DocumentType.invoice, fy2082, 1042).value,
        'INV-2082-83-1042',
      );
    });

    test('each document type uses its own prefix', () {
      expect(number(DocumentType.invoice, fy2082, 1).value, startsWith('INV-'));
      expect(
          number(DocumentType.creditNote, fy2082, 1).value, startsWith('CRN-'));
      expect(
          number(DocumentType.debitNote, fy2082, 1).value, startsWith('DBN-'));
    });

    test('the fiscal year part is derived from the label', () {
      expect(number(DocumentType.invoice, fy2083, 7).value, 'INV-2083-84-0007');
    });

    test('the sequence is zero padded to four digits', () {
      expect(number(DocumentType.invoice, fy2082, 1).value, endsWith('-0001'));
      expect(number(DocumentType.invoice, fy2082, 42).value, endsWith('-0042'));
      expect(
          number(DocumentType.invoice, fy2082, 9999).value, endsWith('-9999'));
    });

    test('a sequence longer than four digits is not truncated', () {
      // Losing digits would create a duplicate number, which ADR 005 forbids
      // outright. Better a longer number than a repeated one.
      expect(
        number(DocumentType.invoice, fy2082, 12345).value,
        endsWith('-12345'),
      );
    });

    test('toString is the formatted number', () {
      expect(
        number(DocumentType.invoice, fy2082, 5).toString(),
        'INV-2082-83-0005',
      );
    });
  });

  group('DocumentNumber validation', () {
    test('a sequence of zero is rejected', () {
      expect(
          () => number(DocumentType.invoice, fy2082, 0), throwsArgumentError);
    });

    test('a negative sequence is rejected', () {
      expect(
          () => number(DocumentType.invoice, fy2082, -1), throwsArgumentError);
    });

    test('a malformed fiscal year label is refused, not sliced', () {
      // A label that does not match the expected shape would otherwise produce
      // a plausible-looking but wrong document number, which is worse than a
      // loud failure.
      final broken = FiscalYear(
        label: '2082-83',
        start: DateTime(2025, 7, 17),
        end: DateTime(2026, 7, 16),
      );

      expect(
        () => number(DocumentType.invoice, broken, 1).value,
        throwsArgumentError,
      );
    });

    test('a label with the wrong ISO year length is refused', () {
      final broken = FiscalYear(
        label: 'FY 82/83',
        start: DateTime(2025, 7, 17),
        end: DateTime(2026, 7, 16),
      );

      expect(
        () => number(DocumentType.invoice, broken, 1).value,
        throwsArgumentError,
      );
    });
  });

  group('DocumentNumber identity', () {
    test('compares by type, fiscal year, and sequence', () {
      expect(
        number(DocumentType.invoice, fy2082, 1),
        number(DocumentType.invoice, fy2082, 1),
      );
      expect(
        number(DocumentType.invoice, fy2082, 1).hashCode,
        number(DocumentType.invoice, fy2082, 1).hashCode,
      );
    });

    test('differs when any part differs', () {
      final base = number(DocumentType.invoice, fy2082, 1);

      expect(base, isNot(number(DocumentType.creditNote, fy2082, 1)));
      expect(base, isNot(number(DocumentType.invoice, fy2083, 1)));
      expect(base, isNot(number(DocumentType.invoice, fy2082, 2)));
    });

    test('the same sequence in two fiscal years produces different numbers',
        () {
      expect(
        number(DocumentType.invoice, fy2082, 1).value,
        isNot(number(DocumentType.invoice, fy2083, 1).value),
      );
    });
  });

  group('DocumentType', () {
    test('resolves a persisted name', () {
      expect(DocumentType.fromName('invoice'), DocumentType.invoice);
      expect(DocumentType.fromName('creditNote'), DocumentType.creditNote);
      expect(DocumentType.fromName('nonsense'), isNull);
    });

    test('every type has a prefix and a label', () {
      for (final type in DocumentType.values) {
        expect(type.prefix, isNotEmpty);
        expect(type.label, isNotEmpty);
      }
    });
  });
}
