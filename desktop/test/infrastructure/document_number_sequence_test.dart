import 'dart:io';

import 'package:financeapp/src/domain/billing/document_type.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/infrastructure/database/drift_document_number_sequence.dart';
import 'package:financeapp/src/infrastructure/database/drift_unit_of_work.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

final fy2082 = const NepaliFiscalCalendar().forBsYear(2082);
final fy2083 = const NepaliFiscalCalendar().forBsYear(2083);

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('financeapp_seq_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('Sequencing', () {
    test('the first allocated number is 1 and the next is 2', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final sequence = DriftDocumentNumberSequence(db);

      final first = await sequence.allocateNext(
          type: DocumentType.invoice, fiscalYear: fy2082);
      final second = await sequence.allocateNext(
          type: DocumentType.invoice, fiscalYear: fy2082);

      expect(first.sequence, 1);
      expect(first.value, 'INV-2082-83-0001');
      expect(second.sequence, 2);
      expect(second.value, 'INV-2082-83-0002');
    });

    test('repeated allocation never returns the same number', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final sequence = DriftDocumentNumberSequence(db);

      final seen = <String>{};
      for (var i = 0; i < 50; i++) {
        final allocated = await sequence.allocateNext(
            type: DocumentType.invoice, fiscalYear: fy2082);
        expect(seen.add(allocated.value), isTrue,
            reason: 'number ${allocated.value} was issued twice');
      }
      expect(seen.length, 50);
    });

    test('the sequence starts at 1 when nothing has been allocated', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final sequence = DriftDocumentNumberSequence(db);

      expect(
        await sequence.lastAllocatedSequence(
            type: DocumentType.invoice, fiscalYear: fy2082),
        0,
      );
    });
  });

  group('Sequences are independent', () {
    test('an invoice does not advance the credit note sequence', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final sequence = DriftDocumentNumberSequence(db);

      await sequence.allocateNext(
          type: DocumentType.invoice, fiscalYear: fy2082);
      await sequence.allocateNext(
          type: DocumentType.invoice, fiscalYear: fy2082);

      final creditNote = await sequence.allocateNext(
          type: DocumentType.creditNote, fiscalYear: fy2082);

      expect(creditNote.sequence, 1,
          reason: 'credit notes have their own controlled sequence');
      expect(creditNote.value, 'CRN-2082-83-0001');
    });

    test('every document type has an independent counter', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final sequence = DriftDocumentNumberSequence(db);

      await sequence.allocateNext(
          type: DocumentType.invoice, fiscalYear: fy2082);
      await sequence.allocateNext(
          type: DocumentType.invoice, fiscalYear: fy2082);
      await sequence.allocateNext(
          type: DocumentType.invoice, fiscalYear: fy2082);
      await sequence.allocateNext(
          type: DocumentType.creditNote, fiscalYear: fy2082);
      await sequence.allocateNext(
          type: DocumentType.debitNote, fiscalYear: fy2082);

      expect(
        await sequence.lastAllocatedSequence(
            type: DocumentType.invoice, fiscalYear: fy2082),
        3,
      );
      expect(
        await sequence.lastAllocatedSequence(
            type: DocumentType.creditNote, fiscalYear: fy2082),
        1,
      );
      expect(
        await sequence.lastAllocatedSequence(
            type: DocumentType.debitNote, fiscalYear: fy2082),
        1,
      );
    });

    test('a new fiscal year restarts at 1', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final sequence = DriftDocumentNumberSequence(db);

      await sequence.allocateNext(
          type: DocumentType.invoice, fiscalYear: fy2082);
      await sequence.allocateNext(
          type: DocumentType.invoice, fiscalYear: fy2082);

      final nextYear = await sequence.allocateNext(
          type: DocumentType.invoice, fiscalYear: fy2083);

      expect(nextYear.sequence, 1,
          reason: 'each fiscal year starts its own numbering at 1');
      expect(nextYear.value, 'INV-2083-84-0001');
    });
  });

  group('A draft does not consume a serial', () {
    test('peeking does not advance the sequence', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final sequence = DriftDocumentNumberSequence(db);

      // A user opens a draft form several times and abandons each one.
      for (var i = 0; i < 5; i++) {
        final preview = await sequence.peekNext(
            type: DocumentType.invoice, fiscalYear: fy2082);
        expect(preview.sequence, 1,
            reason: 'an abandoned draft must not burn a serial');
      }

      expect(
        await sequence.lastAllocatedSequence(
            type: DocumentType.invoice, fiscalYear: fy2082),
        0,
      );
    });

    test('peek then allocate gives the number that was previewed', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final sequence = DriftDocumentNumberSequence(db);

      final preview = await sequence.peekNext(
          type: DocumentType.invoice, fiscalYear: fy2082);
      final actual = await sequence.allocateNext(
          type: DocumentType.invoice, fiscalYear: fy2082);

      expect(actual.value, preview.value,
          reason: 'the number shown to the user must be the number issued');
    });

    test('peeking writes nothing to the database', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final sequence = DriftDocumentNumberSequence(db);

      await sequence.peekNext(type: DocumentType.invoice, fiscalYear: fy2082);

      expect(await db.select(db.documentSequences).get(), isEmpty,
          reason: 'a row exists only once a document is actually issued');
    });
  });

  group('Allocation composes with a unit of work', () {
    test('a failed operation does not consume the number', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final sequence = DriftDocumentNumberSequence(db);
      final unitOfWork = DriftUnitOfWork(db);

      // The document is issued and then something later in the same operation
      // fails. The serial must roll back with it, so the sequence has no
      // unexplained gap.
      await expectLater(
        unitOfWork.run(() async {
          final allocated = await sequence.allocateNext(
              type: DocumentType.invoice, fiscalYear: fy2082);
          expect(allocated.sequence, 1);
          throw StateError('issuance failed after allocating');
        }),
        throwsStateError,
      );

      expect(
        await sequence.lastAllocatedSequence(
            type: DocumentType.invoice, fiscalYear: fy2082),
        0,
        reason: 'the sequence row must have rolled back',
      );
      expect(await db.select(db.documentSequences).get(), isEmpty);

      // The next attempt receives the same number, so nothing was skipped.
      final retry = await sequence.allocateNext(
          type: DocumentType.invoice, fiscalYear: fy2082);
      expect(retry.sequence, 1);
      expect(retry.value, 'INV-2082-83-0001');
    });

    test('a committed operation keeps the allocation', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final sequence = DriftDocumentNumberSequence(db);
      final unitOfWork = DriftUnitOfWork(db);

      final allocated = await unitOfWork.run(() => sequence.allocateNext(
          type: DocumentType.invoice, fiscalYear: fy2082));

      expect(allocated.sequence, 1);
      expect(
        await sequence.lastAllocatedSequence(
            type: DocumentType.invoice, fiscalYear: fy2082),
        1,
      );
    });

    test('a rollback of one allocation does not disturb earlier committed ones',
        () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final sequence = DriftDocumentNumberSequence(db);
      final unitOfWork = DriftUnitOfWork(db);

      await sequence.allocateNext(
          type: DocumentType.invoice, fiscalYear: fy2082);
      await sequence.allocateNext(
          type: DocumentType.invoice, fiscalYear: fy2082);

      await expectLater(
        unitOfWork.run(() async {
          await sequence.allocateNext(
              type: DocumentType.invoice, fiscalYear: fy2082);
          throw StateError('failed');
        }),
        throwsStateError,
      );

      expect(
          await sequence.lastAllocatedSequence(
              type: DocumentType.invoice, fiscalYear: fy2082),
          2,
          reason: 'the two committed allocations must survive');
    });
  });

  group('Durability', () {
    test('the sequence survives closing and reopening the database', () async {
      final file = File(p.join(tempDir.path, 'accounting-FY-2082-83.db'));

      final db = openFileDatabase(file);
      final sequence = DriftDocumentNumberSequence(db);
      await sequence.allocateNext(
          type: DocumentType.invoice, fiscalYear: fy2082);
      await sequence.allocateNext(
          type: DocumentType.invoice, fiscalYear: fy2082);
      await db.close();

      final reopened = openFileDatabase(file);
      final reloaded = DriftDocumentNumberSequence(reopened);
      final next = await reloaded.allocateNext(
          type: DocumentType.invoice, fiscalYear: fy2082);
      await reopened.close();

      expect(next.sequence, 3,
          reason: 'numbering must continue, not restart, after a restart');
      expect(next.value, 'INV-2082-83-0003');
    });

    test('a stored sequence can be read back directly', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final sequence = DriftDocumentNumberSequence(db);

      await sequence.allocateNext(
          type: DocumentType.invoice, fiscalYear: fy2082);

      final rows = await db.select(db.documentSequences).get();
      expect(rows.length, 1);
      expect(rows.single.documentType, 'invoice');
      expect(rows.single.fiscalYearLabel, 'FY 2082/83');
      expect(rows.single.lastSequence, 1);
    });
  });

  group('The port is the only way in', () {
    test('a negative stored sequence is refused by the database', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      await expectLater(
        db.customStatement(
          'INSERT INTO document_sequences '
          '(document_type, fiscal_year_label, last_sequence) VALUES (?, ?, ?)',
          ['invoice', 'FY 2082/83', -1],
        ),
        throwsA(predicate((e) => e.toString().toLowerCase().contains('check'))),
      );
    });
  });
}
