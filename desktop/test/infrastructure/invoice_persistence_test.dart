import 'dart:io';

import 'package:financeapp/src/application/issue_invoice.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/billing/customer.dart';
import 'package:financeapp/src/domain/billing/document_type.dart';
import 'package:financeapp/src/domain/billing/invoice.dart';
import 'package:financeapp/src/domain/billing/invoice_line.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_customer_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_document_number_sequence.dart';
import 'package:financeapp/src/infrastructure/database/drift_invoice_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_unit_of_work.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const npr = 'NPR';
const chart = ChartOfAccounts();

Money rs(int majorUnits) => Money.minor(majorUnits * 100, npr);

final fiscalYear = const NepaliFiscalCalendar().forBsYear(2082);

final testCustomer = Customer(id: 'cust-1', name: 'Himalayan Traders');

InvoiceLine line(int quantity, int unitPriceRupees,
        {String description = 'item'}) =>
    InvoiceLine(
      description: description,
      quantity: quantity,
      unitPrice: rs(unitPriceRupees),
    );

Invoice invoiceOn(
  DateTime date, {
  String id = 'INV-1',
  String customerId = 'cust-1',
  List<InvoiceLine>? lines,
}) =>
    Invoice(
      id: id,
      issueDate: date,
      customerId: customerId,
      lines: lines ?? [line(1, 1000)],
    );

/// Seeds the chart of accounts and the customer.
Future<void> seed(AppDatabase db) async {
  await DriftAccountRepository(db).saveAll(chart.all);
  await DriftCustomerRepository(db).save(testCustomer);
}

/// Wires the use case over [db].
IssueInvoice useCaseFor(AppDatabase db) => IssueInvoice(
      fiscalYear: fiscalYear,
      customers: DriftCustomerRepository(db),
      numbers: DriftDocumentNumberSequence(db),
      journal: DriftJournalRepository(db),
      invoices: DriftInvoiceRepository(db),
      unitOfWork: DriftUnitOfWork(db),
    );

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('financeapp_invoice_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('An issued invoice round-trips', () {
    test('the header comes back identical', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      final invoices = DriftInvoiceRepository(db);

      final issued = await useCaseFor(db)(
        invoiceOn(DateTime(2026, 1, 15), id: 'INV-A'),
      ) as InvoiceIssued;

      final loaded = await invoices.byId('INV-A');
      expect(loaded, isNotNull);
      expect(loaded!.id, 'INV-A');
      expect(loaded.number.value, 'INV-2082-83-0001');
      expect(loaded.number.sequence, 1);
      expect(loaded.number.fiscalYear.label, 'FY 2082/83');
      expect(loaded.invoice.customerId, 'cust-1');
      expect(loaded.invoice.issueDate, DateTime(2026, 1, 15));
      expect(loaded.invoice.currency, npr);
      expect(loaded.journalEntryId, issued.journalEntry.id);
    });

    test('the hand-computed totals survive', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      final invoices = DriftInvoiceRepository(db);

      await useCaseFor(db)(invoiceOn(DateTime(2026, 1, 15), id: 'INV-A'));

      final loaded = await invoices.byId('INV-A');
      expect(loaded!.invoice.subtotal.minorUnits, 100000);
      expect(loaded.invoice.vat.minorUnits, 13000);
      expect(loaded.invoice.total.minorUnits, 113000);
    });

    test('every line comes back with its description, quantity and price',
        () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      final invoices = DriftInvoiceRepository(db);

      await useCaseFor(db)(
        invoiceOn(
          DateTime(2026, 1, 15),
          id: 'INV-A',
          lines: [
            line(2, 300, description: 'Keyboard'),
            line(1, 400, description: 'Mouse'),
          ],
        ),
      );

      final loaded = await invoices.byId('INV-A');
      expect(loaded!.invoice.lines, hasLength(2));
      expect(loaded.invoice.lines[0].description, 'Keyboard');
      expect(loaded.invoice.lines[0].quantity, 2);
      expect(loaded.invoice.lines[0].unitPrice.minorUnits, 30000);
      expect(loaded.invoice.lines[0].lineTotal.minorUnits, 60000);
      expect(loaded.invoice.lines[1].description, 'Mouse');
    });

    test('line order is preserved', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      final invoices = DriftInvoiceRepository(db);

      await useCaseFor(db)(
        invoiceOn(
          DateTime(2026, 1, 15),
          id: 'INV-A',
          lines: [
            line(1, 10, description: 'first'),
            line(1, 20, description: 'second'),
            line(1, 30, description: 'third'),
          ],
        ),
      );

      final loaded = await invoices.byId('INV-A');
      expect(
        loaded!.invoice.lines.map((l) => l.description),
        ['first', 'second', 'third'],
        reason: 'lines must print in the order they were entered',
      );
    });

    test('a zero-rated invoice round-trips', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      final invoices = DriftInvoiceRepository(db);

      await useCaseFor(db)(
        Invoice(
          id: 'INV-Z',
          issueDate: DateTime(2026, 1, 15),
          customerId: 'cust-1',
          lines: [line(1, 1000)],
          vatRateBasisPoints: 0,
        ),
      );

      final loaded = await invoices.byId('INV-Z');
      expect(loaded!.invoice.vatRateBasisPoints, 0);
      expect(loaded.invoice.vat.isZero, isTrue);
      expect(loaded.invoice.total.minorUnits, 100000);
    });

    test('an unknown invoice id returns null', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      expect(await DriftInvoiceRepository(db).byId('nobody'), isNull);
    });
  });

  group('Stored totals match recomputed totals', () {
    test('the denormalised columns equal the derived values', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      await useCaseFor(db)(
        invoiceOn(
          DateTime(2026, 1, 15),
          id: 'INV-A',
          lines: [line(3, 249), line(5, 17)],
        ),
      );

      final loaded = await DriftInvoiceRepository(db).byId('INV-A');
      final row = (await db.select(db.invoices).get()).single;

      // The stored totals are a denormalisation for listing and printing.
      // Recomputation stays authoritative, and these must not diverge.
      expect(row.subtotalMinorUnits, loaded!.invoice.subtotal.minorUnits);
      expect(row.vatMinorUnits, loaded.invoice.vat.minorUnits);
      expect(row.totalMinorUnits, loaded.invoice.total.minorUnits);
      expect(
        row.subtotalMinorUnits + row.vatMinorUnits,
        row.totalMinorUnits,
        reason: 'the stored totals must be internally consistent too',
      );
    });
  });

  group('Listing', () {
    test('invoices are listed in issue order', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      await useCaseFor(db)(invoiceOn(DateTime(2026, 2, 1), id: 'INV-B'));
      await useCaseFor(db)(invoiceOn(DateTime(2026, 1, 1), id: 'INV-A'));
      await useCaseFor(db)(invoiceOn(DateTime(2026, 3, 1), id: 'INV-C'));

      final all = await DriftInvoiceRepository(db).all();
      expect(all.map((i) => i.id), ['INV-A', 'INV-B', 'INV-C']);
    });

    test('invoices can be listed by customer', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      final customers = DriftCustomerRepository(db);
      await customers.save(Customer(id: 'cust-2', name: 'Other Customer'));

      final useCase = useCaseFor(db);
      await useCase(invoiceOn(DateTime(2026, 1, 1), id: 'INV-A'));
      await useCase(
        invoiceOn(DateTime(2026, 1, 2), id: 'INV-B', customerId: 'cust-2'),
      );

      final invoices = DriftInvoiceRepository(db);
      expect(
        (await invoices.forCustomer('cust-1')).map((i) => i.id),
        ['INV-A'],
      );
      expect(
        (await invoices.forCustomer('cust-2')).map((i) => i.id),
        ['INV-B'],
      );
      expect(await invoices.forCustomer('cust-3'), isEmpty);
    });
  });

  group('The database refuses bad invoice rows', () {
    test('an invoice for a customer who does not exist is rejected', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      // Post a real entry so the journal foreign key is satisfiable, then try to
      // attach an invoice to a customer that was never saved.
      await db.into(db.journalEntries).insert(
            JournalEntriesCompanion.insert(
              id: 'JE-X',
              date: DateTime(2026, 1, 15),
              description: 'dummy',
              currency: npr,
            ),
          );

      await expectLater(
        db.into(db.invoices).insert(
              InvoicesCompanion.insert(
                id: 'INV-BAD',
                number: 'INV-2082-83-0999',
                sequence: 999,
                fiscalYearLabel: 'FY 2082/83',
                customerId: 'cust-does-not-exist',
                issueDate: DateTime(2026, 1, 15),
                currency: npr,
                vatRateBasisPoints: 1300,
                subtotalMinorUnits: 100000,
                vatMinorUnits: 13000,
                totalMinorUnits: 113000,
                journalEntryId: 'JE-X',
              ),
            ),
        throwsA(
          predicate((e) => e.toString().toLowerCase().contains('foreign key')),
        ),
      );
    });

    test('an invoice without its journal entry is rejected', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      await expectLater(
        db.into(db.invoices).insert(
              InvoicesCompanion.insert(
                id: 'INV-ORPHAN',
                number: 'INV-2082-83-0998',
                sequence: 998,
                fiscalYearLabel: 'FY 2082/83',
                customerId: 'cust-1',
                issueDate: DateTime(2026, 1, 15),
                currency: npr,
                vatRateBasisPoints: 1300,
                subtotalMinorUnits: 100000,
                vatMinorUnits: 13000,
                totalMinorUnits: 113000,
                journalEntryId: 'JE-DOES-NOT-EXIST',
              ),
            ),
        throwsA(
          predicate((e) => e.toString().toLowerCase().contains('foreign key')),
        ),
      );
    });

    test('a line without its invoice is rejected', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      await expectLater(
        db.into(db.invoiceLines).insert(
              InvoiceLinesCompanion.insert(
                invoiceId: 'INV-DOES-NOT-EXIST',
                lineNumber: 1,
                description: 'orphan',
                quantity: 1,
                unitPriceMinorUnits: 100,
                currency: npr,
              ),
            ),
        throwsA(
          predicate((e) => e.toString().toLowerCase().contains('foreign key')),
        ),
      );
    });

    test('a line with a zero quantity is rejected', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await useCaseFor(db)(invoiceOn(DateTime(2026, 1, 15), id: 'INV-A'));

      await expectLater(
        db.into(db.invoiceLines).insert(
              InvoiceLinesCompanion.insert(
                invoiceId: 'INV-A',
                lineNumber: 2,
                description: 'bad',
                quantity: 0,
                unitPriceMinorUnits: 100,
                currency: npr,
              ),
            ),
        throwsA(predicate((e) => e.toString().toLowerCase().contains('check'))),
      );
    });
  });

  group('Money is stored exactly', () {
    test('invoice money columns are INTEGER, never REAL', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      Future<Map<String, String>> columnsOf(String table) async {
        final rows = await db
            .customSelect("SELECT name, type FROM pragma_table_info('$table')")
            .get();
        return {
          for (final row in rows)
            row.read<String>('name'): row.read<String>('type'),
        };
      }

      final invoiceColumns = await columnsOf('invoices');
      for (final column in [
        'subtotal_minor_units',
        'vat_minor_units',
        'total_minor_units',
        'vat_rate_basis_points',
      ]) {
        expect(invoiceColumns[column]?.toUpperCase(), 'INTEGER',
            reason: '$column must be INTEGER or amounts can silently drift');
      }

      final lineColumns = await columnsOf('invoice_lines');
      expect(lineColumns['unit_price_minor_units']?.toUpperCase(), 'INTEGER');
      expect(lineColumns['quantity']?.toUpperCase(), 'INTEGER');
    });

    test('an amount with paisa precision round-trips exactly', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      // Rs 1,284,500.07, which binary floating point cannot hold exactly.
      await useCaseFor(db)(
        invoiceOn(
          DateTime(2026, 1, 15),
          id: 'INV-EXACT',
          lines: [
            InvoiceLine(
              description: 'precise',
              quantity: 1,
              unitPrice: const Money.minor(128450007, npr),
            ),
          ],
        ),
      );

      final loaded = await DriftInvoiceRepository(db).byId('INV-EXACT');
      expect(loaded!.invoice.subtotal.minorUnits, 128450007);
      expect(loaded.invoice.lines.single.unitPrice.minorUnits, 128450007);
    });
  });

  group('All three writes are one operation', () {
    test('a failed invoice write rolls back the entry and the serial',
        () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      // A pre-existing invoice already holds number 0001. It was inserted
      // directly, so the document sequence was never advanced and still reads 0.
      //
      // The journal entry is written with real lines, because an entry without
      // them is not a valid double entry and reading it back would throw.
      await db.customStatement(
        'INSERT INTO journal_entries (id, date, description, currency) '
        'VALUES (?, ?, ?, ?)',
        [
          'JE-INV-INV-OLD',
          DateTime(2026, 1, 1).millisecondsSinceEpoch ~/ 1000,
          'earlier invoice',
          npr
        ],
      );
      for (final line in [
        ['acct-receivable', 113000, 0],
        ['acct-sales-revenue', 0, 113000],
      ]) {
        await db.customStatement(
          'INSERT INTO journal_lines '
          '(journal_entry_id, account_id, debit_minor_units, credit_minor_units, currency) '
          'VALUES (?, ?, ?, ?, ?)',
          ['JE-INV-INV-OLD', ...line, npr],
        );
      }
      await db.into(db.invoices).insert(
            InvoicesCompanion.insert(
              id: 'INV-OLD',
              number: 'INV-2082-83-0001',
              sequence: 1,
              fiscalYearLabel: 'FY 2082/83',
              customerId: 'cust-1',
              issueDate: DateTime(2026, 1, 1),
              currency: npr,
              vatRateBasisPoints: 1300,
              subtotalMinorUnits: 100000,
              vatMinorUnits: 13000,
              totalMinorUnits: 113000,
              journalEntryId: 'JE-INV-INV-OLD',
            ),
          );

      final journal = DriftJournalRepository(db);
      final numbers = DriftDocumentNumberSequence(db);

      // Issuing a new invoice allocates sequence 1, so it produces the same
      // number 0001, which is unique. The journal entry is written first and
      // succeeds; the invoice insert then fails on the number.
      await expectLater(
        useCaseFor(db)(invoiceOn(DateTime(2026, 1, 15), id: 'INV-NEW')),
        throwsA(anything),
      );

      expect(
        await journal.byId('JE-INV-INV-NEW'),
        isNull,
        reason: 'the journal entry written before the failure must roll back',
      );
      expect(await journal.all(), hasLength(1),
          reason: 'only the pre-existing entry may remain');
      expect(
        await numbers.lastAllocatedSequence(
            type: DocumentType.invoice, fiscalYear: fiscalYear),
        0,
        reason: 'the rolled-back attempt must not have burnt a serial',
      );
      expect(await db.select(db.invoiceLines).get(), isEmpty,
          reason: 'no orphan lines may survive');
    });

    test('storing an invoice twice under the same id is refused', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      final invoices = DriftInvoiceRepository(db);

      final issued = await useCaseFor(db)(
        invoiceOn(DateTime(2026, 1, 15), id: 'INV-A'),
      ) as InvoiceIssued;

      // An issued invoice is a legal document. Replacing it silently would
      // destroy the original.
      await expectLater(
        invoices.save(issued.issued),
        throwsA(anything),
      );

      expect((await invoices.all()), hasLength(1));
    });
  });

  group('Durability', () {
    test('an invoice survives closing and reopening the database', () async {
      final file = File(p.join(tempDir.path, 'accounting-FY-2082-83.db'));

      final db = openFileDatabase(file);
      await seed(db);
      await useCaseFor(db)(
        invoiceOn(
          DateTime(2026, 1, 15),
          id: 'INV-A',
          lines: [line(2, 300, description: 'Keyboard')],
        ),
      );
      await db.close();

      final reopened = openFileDatabase(file);
      final loaded = await DriftInvoiceRepository(reopened).byId('INV-A');
      await reopened.close();

      expect(loaded, isNotNull);
      expect(loaded!.number.value, 'INV-2082-83-0001');
      // Hand-computed: 2 x Rs 300.00 = Rs 600.00 = 60,000 paisa,
      // VAT 13% = 7,800 paisa, total = 67,800 paisa.
      expect(loaded.invoice.subtotal.minorUnits, 60000);
      expect(loaded.invoice.vat.minorUnits, 7800);
      expect(loaded.invoice.total.minorUnits, 67800);
      expect(loaded.invoice.lines.single.description, 'Keyboard');
      expect(loaded.invoice.lines.single.quantity, 2);
    });
  });

  group('DocumentNumber reconstruction', () {
    test('a malformed stored number is refused rather than misread', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      await db.into(db.journalEntries).insert(
            JournalEntriesCompanion.insert(
              id: 'JE-BAD',
              date: DateTime(2026, 1, 15),
              description: 'dummy',
              currency: npr,
            ),
          );
      await db.into(db.invoices).insert(
            InvoicesCompanion.insert(
              id: 'INV-BAD',
              number: 'XYZ-2082-83-0001',
              sequence: 1,
              fiscalYearLabel: 'FY 2082/83',
              customerId: 'cust-1',
              issueDate: DateTime(2026, 1, 15),
              currency: npr,
              vatRateBasisPoints: 1300,
              subtotalMinorUnits: 100000,
              vatMinorUnits: 13000,
              totalMinorUnits: 113000,
              journalEntryId: 'JE-BAD',
            ),
          );
      // A valid line, so that reconstruction reaches the number check rather
      // than failing earlier for a missing line.
      await db.into(db.invoiceLines).insert(
            InvoiceLinesCompanion.insert(
              invoiceId: 'INV-BAD',
              lineNumber: 1,
              description: 'item',
              quantity: 1,
              unitPriceMinorUnits: 100000,
              currency: npr,
            ),
          );

      await expectLater(
        DriftInvoiceRepository(db).byId('INV-BAD'),
        throwsA(isA<StateError>()),
      );
    });

    test('a malformed fiscal year label is refused', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      await db.into(db.journalEntries).insert(
            JournalEntriesCompanion.insert(
              id: 'JE-BAD2',
              date: DateTime(2026, 1, 15),
              description: 'dummy',
              currency: npr,
            ),
          );
      await db.into(db.invoices).insert(
            InvoicesCompanion.insert(
              id: 'INV-BAD2',
              number: 'INV-9999-00-0001',
              sequence: 1,
              fiscalYearLabel: 'nonsense',
              customerId: 'cust-1',
              issueDate: DateTime(2026, 1, 15),
              currency: npr,
              vatRateBasisPoints: 1300,
              subtotalMinorUnits: 100000,
              vatMinorUnits: 13000,
              totalMinorUnits: 113000,
              journalEntryId: 'JE-BAD2',
            ),
          );
      await db.into(db.invoiceLines).insert(
            InvoiceLinesCompanion.insert(
              invoiceId: 'INV-BAD2',
              lineNumber: 1,
              description: 'item',
              quantity: 1,
              unitPriceMinorUnits: 100000,
              currency: npr,
            ),
          );

      await expectLater(
        DriftInvoiceRepository(db).byId('INV-BAD2'),
        throwsArgumentError,
      );
    });
  });
}
