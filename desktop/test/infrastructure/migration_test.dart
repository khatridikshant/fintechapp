import 'package:drift_dev/api/migrations_native.dart';
import 'package:financeapp/src/application/issue_credit_note.dart';
import 'package:financeapp/src/application/issue_invoice.dart';
import 'package:financeapp/src/application/issue_purchase.dart';
import 'package:financeapp/src/application/post_inventory_movement.dart';
import 'package:financeapp/src/application/record_payment.dart';
import 'package:financeapp/src/domain/accounting/account_type.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/billing/credit_note.dart';
import 'package:financeapp/src/domain/billing/customer.dart';
import 'package:financeapp/src/domain/billing/document_type.dart';
import 'package:financeapp/src/domain/billing/invoice.dart';
import 'package:financeapp/src/domain/billing/invoice_line.dart';
import 'package:financeapp/src/domain/billing/payment.dart';
import 'package:financeapp/src/domain/billing/purchase.dart';
import 'package:financeapp/src/domain/billing/purchase_line.dart';
import 'package:financeapp/src/domain/billing/supplier.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/inventory/inventory_movement.dart';
import 'package:financeapp/src/domain/inventory/product.dart';
import 'package:financeapp/src/domain/reporting/trial_balance.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_credit_note_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_customer_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_document_number_sequence.dart';
import 'package:financeapp/src/infrastructure/database/drift_inventory_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_invoice_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_payment_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_purchase_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_supplier_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_unit_of_work.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../generated/schema.dart';
import '../generated/schema_v1.dart' as v1;
import '../generated/schema_v2.dart' as v2;
import '../generated/schema_v3.dart' as v3;
import '../generated/schema_v4.dart' as v4;
import '../generated/schema_v5.dart' as v5;
import '../generated/schema_v6.dart' as v6;
import '../generated/schema_v7.dart' as v7;
import '../generated/schema_v8.dart' as v8;
import '../generated/schema_v9.dart' as v9;

/// Migration tests.
///
/// A migration is the one change that can destroy a user's books. Nothing here
/// drops or recreates a table; every step must be additive, and the tests below
/// prove that data written by every previous release is still readable
/// afterwards.
///
/// The old rows are inserted with raw SQL on purpose. The generated schema
/// snapshots contain no companion classes, and writing the old shape by hand is
/// also a more honest fixture: it is exactly the SQL a previous release would
/// have produced, not the current code's idea of it.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  /// The chart of accounts, as every release has written it.
  Future<void> seedAccounts(Object db) async {
    final database = db as dynamic;
    for (final row in [
      ['acct-bank', '1010', 'Bank', 'asset'],
      ['acct-receivable', '1030', 'Accounts Receivable', 'asset'],
      ['acct-rent', '5010', 'Office Rent', 'expense'],
      ['acct-sales-revenue', '4010', 'Sales Revenue', 'income'],
      ['acct-vat-payable', '2020', 'VAT Payable', 'liability'],
    ]) {
      await database.customStatement(
        'INSERT INTO accounts (id, code, name, type) VALUES (?, ?, ?, ?)',
        row,
      );
    }
  }

  /// A journal entry with its lines, as the v1 and v2 releases wrote it.
  Future<void> seedJournal(Object db, DateTime postedOn) async {
    final database = db as dynamic;
    await database.customStatement(
      'INSERT INTO journal_entries (id, date, description, currency) '
      'VALUES (?, ?, ?, ?)',
      ['JE-1', postedOn.millisecondsSinceEpoch ~/ 1000, 'Office rent', 'NPR'],
    );
    for (final line in [
      ['JE-1', 'acct-rent', 50000, 0],
      ['JE-1', 'acct-bank', 0, 50000],
    ]) {
      await database.customStatement(
        'INSERT INTO journal_lines '
        '(journal_entry_id, account_id, debit_minor_units, credit_minor_units, currency) '
        'VALUES (?, ?, ?, ?, ?)',
        [...line, 'NPR'],
      );
    }
  }

  /// A customer, as the v3 release onwards wrote it.
  Future<void> seedCustomer(Object db) async {
    final database = db as dynamic;
    await database.customStatement(
      'INSERT INTO customers (id, name, pan_number) VALUES (?, ?, ?)',
      ['cust-1', 'Himalayan Traders', '123456789'],
    );
  }

  /// A payment against the seeded invoice, as the v5 release wrote it.
  Future<void> seedPayment(Object db) async {
    final database = db as dynamic;
    await database.customStatement(
      'INSERT INTO payments '
      '(id, invoice_id, date, amount_minor_units, currency, account_id) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [
        'PAY-1',
        'INV-A',
        DateTime(2026, 1, 20).millisecondsSinceEpoch ~/ 1000,
        50000,
        'NPR',
        'acct-receivable',
      ],
    );
  }

  /// A product, as the v7 release wrote it.
  Future<void> seedProduct(Object db) async {
    final database = db as dynamic;
    await database.customStatement(
      'INSERT INTO products '
      '(id, name, sale_price_minor_units, currency, stock_tracking_enabled) '
      'VALUES (?, ?, ?, ?, ?)',
      ['prod-1', 'Keyboard', 20000, 'NPR', 1],
    );
  }

  /// A movement as v7 wrote it: the shape before the journal entry link existed.
  Future<void> seedMovementWithoutEntry(Object db) async {
    final database = db as dynamic;
    await database.customStatement(
      'INSERT INTO inventory_movements '
      '(id, product_id, date, reason, quantity, value_minor_units, currency) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        'MV-1',
        'prod-1',
        DateTime(2026, 1, 10).millisecondsSinceEpoch ~/ 1000,
        'openingStock',
        10,
        100000,
        'NPR',
      ],
    );
  }

  /// An issued invoice with one line, as the v4 release wrote it.
  ///
  /// The invoice is for Rs 1,130 with no VAT, so a payment of Rs 500 must leave
  /// Rs 630 outstanding.
  Future<void> seedInvoice(Object db) async {
    final database = db as dynamic;
    await database.customStatement(
      'INSERT INTO journal_entries (id, date, description, currency) '
      'VALUES (?, ?, ?, ?)',
      [
        'JE-INV-INV-A',
        DateTime(2026, 1, 15).millisecondsSinceEpoch ~/ 1000,
        'Invoice INV-2082-83-0001',
        'NPR'
      ],
    );
    for (final line in [
      ['acct-receivable', 113000, 0],
      ['acct-sales-revenue', 0, 113000],
    ]) {
      await database.customStatement(
        'INSERT INTO journal_lines '
        '(journal_entry_id, account_id, debit_minor_units, credit_minor_units, currency) '
        'VALUES (?, ?, ?, ?, ?)',
        ['JE-INV-INV-A', ...line, 'NPR'],
      );
    }
    await database.customStatement(
      'INSERT INTO invoices '
      '(id, number, sequence, fiscal_year_label, customer_id, issue_date, currency, '
      'vat_rate_basis_points, subtotal_minor_units, vat_minor_units, total_minor_units, '
      'journal_entry_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        'INV-A',
        'INV-2082-83-0001',
        1,
        'FY 2082/83',
        'cust-1',
        DateTime(2026, 1, 15).millisecondsSinceEpoch ~/ 1000,
        'NPR',
        0,
        113000,
        0,
        113000,
        'JE-INV-INV-A',
      ],
    );
    await database.customStatement(
      'INSERT INTO invoice_lines '
      '(invoice_id, line_number, description, quantity, unit_price_minor_units, currency) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      ['INV-A', 1, 'item', 1, 113000, 'NPR'],
    );
  }

  group('Schema versions', () {
    test('the current database matches the v9 snapshot', () async {
      final db = AppDatabase(await verifier.startAt(8));
      await verifier.migrateAndValidate(db, 9);
      await db.close();
    });

    test('every older version still migrates cleanly', () async {
      for (final from in [1, 2, 3, 4, 5, 6, 7, 8]) {
        final db = AppDatabase(await verifier.startAt(from));
        await verifier.migrateAndValidate(db, 9);
        await db.close();
      }
    });

    test('a v1 database migrates all the way to v9 in one open', () async {
      // Every step must run, not just the last one. A database several versions
      // behind is the normal case after a release has been skipped.
      final db = AppDatabase(await verifier.startAt(1));
      await verifier.migrateAndValidate(db, 9);

      expect(await db.select(db.documentSequences).get(), isEmpty);
      expect(await db.select(db.customers).get(), isEmpty);
      expect(await db.select(db.invoices).get(), isEmpty);
      expect(await db.select(db.invoiceLines).get(), isEmpty);
      expect(await db.select(db.payments).get(), isEmpty);
      expect(await db.select(db.creditNotes).get(), isEmpty);
      expect(await db.select(db.creditNoteLines).get(), isEmpty);
      expect(await db.select(db.products).get(), isEmpty);
      expect(await db.select(db.inventoryMovements).get(), isEmpty);

      await db.close();
    });
  });

  group('Upgrading to v9', () {
    test('relaxes the movement constraint without disturbing the tables',
        () async {
      final schema = await verifier.schemaAt(8);

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      expect(await db.select(db.inventoryMovements).get(), isEmpty);
      expect(await db.select(db.products).get(), isEmpty);
      expect(await db.select(db.creditNotes).get(), isEmpty);
      expect(await db.select(db.payments).get(), isEmpty);
      expect(await db.select(db.invoices).get(), isEmpty);
      expect(await db.select(db.accounts).get(), isEmpty);

      await db.close();
    });

    test('v8 movements survive the constraint change', () async {
      // The CHECK on inventory_movements is relaxed, which SQLite cannot do in
      // place, so the table is rebuilt. This proves the existing rows come
      // across intact â€” including the ones with a null journal entry.
      final schema = await verifier.schemaAt(8);

      final previous = v8.DatabaseAtV8(schema.newConnection());
      await seedAccounts(previous);
      await seedProduct(previous);
      await seedMovementWithoutEntry(previous);
      await previous.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      final movements = await db.select(db.inventoryMovements).get();
      expect(movements, hasLength(1));
      expect(movements.single.quantity, 10);
      expect(movements.single.valueMinorUnits, 100000);
      expect(movements.single.reason, 'openingStock');
      expect(movements.single.journalEntryId, isNull,
          reason: 'the rebuild must preserve the null as it was');

      await db.close();
    });

    test('the upgraded database can record a value-only write-down', () async {
      final schema = await verifier.schemaAt(8);

      final previous = v8.DatabaseAtV8(schema.newConnection());
      await seedAccounts(previous);
      await seedProduct(previous);
      await seedMovementWithoutEntry(previous);
      // The v8 fixture has no adjustment account; the write-down needs it.
      await previous.customStatement(
        'INSERT INTO accounts (id, code, name, type) VALUES (?, ?, ?, ?)',
        [
          'acct-inventory-adjustments',
          '5070',
          'Inventory Adjustments',
          'expense'
        ],
      );
      await previous.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      // The new constraint is the whole point of this migration: a row with no
      // quantity change is now allowed, which the old CHECK rejected.
      await db.customStatement(
        'INSERT INTO inventory_movements '
        '(id, product_id, date, reason, quantity, value_minor_units, currency) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          'MV-WD',
          'prod-1',
          DateTime(2026, 2, 1).millisecondsSinceEpoch ~/ 1000,
          'writeDown',
          0,
          -20000,
          'NPR',
        ],
      );

      final rows = await db.select(db.inventoryMovements).get();
      expect(rows, hasLength(2));
      final writeDown = rows.firstWhere((r) => r.id == 'MV-WD');
      expect(writeDown.quantity, 0);
      expect(writeDown.valueMinorUnits, -20000);

      // And the stock reflects it: 10 units still held, value reduced to Rs 800.
      final product = Product(
        id: 'prod-1',
        name: 'Keyboard',
        salePrice: Money.minor(20000, 'NPR'),
      );
      final stock = await DriftInventoryRepository(db).stockOf(product);
      expect(stock.quantity, 10);
      expect(stock.value.minorUnits, 80000);

      await db.close();
    });

    test('a fresh v9 database can still be created', () async {
      final db = AppDatabase(await verifier.startAt(9));
      await verifier.migrateAndValidate(db, 9);

      expect(await db.select(db.inventoryMovements).get(), isEmpty);

      await db.close();
    });
  });

  group('Upgrading to v8', () {
    test('adds the journal entry link to movements', () async {
      final schema = await verifier.schemaAt(7);

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      expect(await db.select(db.inventoryMovements).get(), isEmpty);

      await db.close();
    });

    test('v7 movements survive, with no journal entry invented for them',
        () async {
      // This migration is an ADD COLUMN, a different shape from the previous
      // create-table steps. The old rows must keep their data and must NOT be
      // given a fabricated entry: they were written before posting existed, and
      // inventing an entry would put a made-up figure in the books.
      final schema = await verifier.schemaAt(7);

      final previous = v7.DatabaseAtV7(schema.newConnection());
      await seedAccounts(previous);
      await seedProduct(previous);
      await seedMovementWithoutEntry(previous);
      await previous.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      final products = await db.select(db.products).get();
      expect(products, hasLength(1));

      final movements = await db.select(db.inventoryMovements).get();
      expect(movements, hasLength(1));
      expect(movements.single.quantity, 10);
      expect(movements.single.valueMinorUnits, 100000);
      expect(movements.single.reason, 'openingStock');
      expect(movements.single.journalEntryId, isNull,
          reason: 'a pre-existing movement must not be given an entry it never '
              'had');

      await db.close();
    });

    test('the upgraded database can post a new movement', () async {
      final schema = await verifier.schemaAt(7);

      final previous = v7.DatabaseAtV7(schema.newConnection());
      await seedAccounts(previous);
      await seedProduct(previous);
      await seedMovementWithoutEntry(previous);
      await previous.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      // The posting needs the accounts the inventory mapping uses, which the
      // shared fixture does not seed.
      for (final row in [
        ['acct-inventory', '1040', 'Inventory', 'asset'],
        ['acct-payable', '2010', 'Accounts Payable', 'liability'],
      ]) {
        await db.customStatement(
          'INSERT INTO accounts (id, code, name, type) VALUES (?, ?, ?, ?)',
          row,
        );
      }

      // A schema that validates but does not work is only a shape.
      final product = Product(
        id: 'prod-1',
        name: 'Keyboard',
        salePrice: Money.minor(20000, 'NPR'),
      );
      final outcome = await PostInventoryMovement(
        fiscalYear: const NepaliFiscalCalendar().forBsYear(2082),
        inventory: DriftInventoryRepository(db),
        journal: DriftJournalRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      )(
        InventoryMovement.receipt(
          id: 'MV-2',
          productId: product.id,
          date: DateTime(2026, 1, 20),
          reason: MovementReason.purchase,
          quantity: 5,
          value: Money.minor(50000, 'NPR'),
        ),
      );

      expect(outcome, isA<InventoryMovementPosted>());

      // The new movement carries its entry, and the old one still does not.
      final rows = await db.select(db.inventoryMovements).get();
      expect(rows, hasLength(2));
      final posted = rows.firstWhere((r) => r.id == 'MV-2');
      expect(posted.journalEntryId, 'JE-MV-MV-2');
      expect(rows.firstWhere((r) => r.id == 'MV-1').journalEntryId, isNull);

      // 10 units worth 1,000 plus 5 worth 500.
      final stock = await DriftInventoryRepository(db).stockOf(product);
      expect(stock.quantity, 15);
      expect(stock.value.minorUnits, 150000);

      // And the ledger agrees with the stock for the posted movement.
      final report = TrialBalance.from(
        entries: await DriftJournalRepository(db).all(),
        currency: 'NPR',
      );
      final inventoryRow =
          report.rows.firstWhere((r) => r.account.code == '1040');
      expect(inventoryRow.balance.minorUnits, 50000,
          reason:
              'only the posted movement reached the ledger; the pre-existing '
              'one never did, and pretending otherwise would be a lie');

      await db.close();
    });

    test('a fresh v8 database can still be created', () async {
      final db = AppDatabase(await verifier.startAt(8));
      await verifier.migrateAndValidate(db, 9);

      expect(await db.select(db.inventoryMovements).get(), isEmpty);

      await db.close();
    });
  });

  group('Upgrading to v7', () {
    test('adds products and movements without disturbing the existing tables',
        () async {
      final schema = await verifier.schemaAt(6);

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      expect(await db.select(db.products).get(), isEmpty);
      expect(await db.select(db.inventoryMovements).get(), isEmpty);
      expect(await db.select(db.creditNotes).get(), isEmpty);
      expect(await db.select(db.payments).get(), isEmpty);
      expect(await db.select(db.invoices).get(), isEmpty);
      expect(await db.select(db.customers).get(), isEmpty);
      expect(await db.select(db.accounts).get(), isEmpty);
      expect(await db.select(db.journalEntries).get(), isEmpty);
      expect(await db.select(db.documentSequences).get(), isEmpty);

      await db.close();
    });

    test('v6 data survives the upgrade to v7', () async {
      final schema = await verifier.schemaAt(6);

      final previous = v6.DatabaseAtV6(schema.newConnection());
      await seedAccounts(previous);
      await seedCustomer(previous);
      await seedInvoice(previous);
      await seedPayment(previous);
      await previous.customStatement(
        'INSERT INTO document_sequences '
        '(document_type, fiscal_year_label, last_sequence) VALUES (?, ?, ?)',
        ['invoice', 'FY 2082/83', 7],
      );
      await previous.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      expect(await db.select(db.accounts).get(), hasLength(5));
      expect(await db.select(db.customers).get(), hasLength(1));
      expect(await db.select(db.invoices).get(), hasLength(1));
      expect(await db.select(db.invoiceLines).get(), hasLength(1));
      expect(await db.select(db.payments).get(), hasLength(1));

      final sequences = await db.select(db.documentSequences).get();
      expect(sequences.single.lastSequence, 7,
          reason: 'the invoice sequence must not restart, or numbers would be '
              'reissued');

      await db.close();
    });

    test('the upgraded database can record stock', () async {
      final schema = await verifier.schemaAt(6);

      final previous = v6.DatabaseAtV6(schema.newConnection());
      await seedAccounts(previous);
      await previous.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      // A schema that validates but does not work is only a shape.
      final inventory = DriftInventoryRepository(db);
      final product = Product(
        id: 'prod-1',
        name: 'Keyboard',
        salePrice: Money.minor(20000, 'NPR'),
      );
      await inventory.saveProduct(product);
      await inventory.applyMovement(
        product,
        InventoryMovement.receipt(
          id: 'MV-1',
          productId: 'prod-1',
          date: DateTime(2026, 1, 10),
          reason: MovementReason.openingStock,
          quantity: 10,
          value: Money.minor(100000, 'NPR'),
        ),
      );

      final stock = await inventory.stockOf(product);
      expect(stock.quantity, 10);
      expect(stock.value.minorUnits, 100000);
      expect(stock.costPerUnit.minorUnits, 10000);
      expect(await db.select(db.inventoryMovements).get(), hasLength(1));

      await db.close();
    });

    test('a fresh v7 database can still be created', () async {
      final db = AppDatabase(await verifier.startAt(7));
      await verifier.migrateAndValidate(db, 9);

      expect(await db.select(db.products).get(), isEmpty);

      await db.close();
    });
  });

  group('Upgrading to v6', () {
    test('adds credit notes without disturbing the existing tables', () async {
      final schema = await verifier.schemaAt(5);

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      expect(await db.select(db.creditNotes).get(), isEmpty);
      expect(await db.select(db.creditNoteLines).get(), isEmpty);
      expect(await db.select(db.payments).get(), isEmpty);
      expect(await db.select(db.invoices).get(), isEmpty);
      expect(await db.select(db.invoiceLines).get(), isEmpty);
      expect(await db.select(db.customers).get(), isEmpty);
      expect(await db.select(db.accounts).get(), isEmpty);
      expect(await db.select(db.journalEntries).get(), isEmpty);
      expect(await db.select(db.journalLines).get(), isEmpty);
      expect(await db.select(db.documentSequences).get(), isEmpty);

      await db.close();
    });

    test('v5 data survives the upgrade to v6', () async {
      final schema = await verifier.schemaAt(5);

      final previous = v5.DatabaseAtV5(schema.newConnection());
      await seedAccounts(previous);
      await seedCustomer(previous);
      await seedInvoice(previous);
      await seedPayment(previous);
      await previous.customStatement(
        'INSERT INTO document_sequences '
        '(document_type, fiscal_year_label, last_sequence) VALUES (?, ?, ?)',
        ['invoice', 'FY 2082/83', 7],
      );
      await previous.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      expect(await db.select(db.accounts).get(), hasLength(5));
      expect(await db.select(db.customers).get(), hasLength(1));
      expect(await db.select(db.invoices).get(), hasLength(1));
      expect(await db.select(db.invoiceLines).get(), hasLength(1));

      final payments = await db.select(db.payments).get();
      expect(payments, hasLength(1));
      expect(payments.single.amountMinorUnits, 50000,
          reason: 'the recorded payment must survive five upgrades');

      final sequences = await db.select(db.documentSequences).get();
      expect(sequences, hasLength(1));
      expect(sequences.single.lastSequence, 7,
          reason: 'the invoice sequence must not restart, or numbers would be '
              'reissued');

      await db.close();
    });

    test('the upgraded database can issue a credit note', () async {
      final schema = await verifier.schemaAt(5);

      final previous = v5.DatabaseAtV5(schema.newConnection());
      await seedAccounts(previous);
      await seedCustomer(previous);
      await seedInvoice(previous);
      await previous.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      // A schema that validates but does not work is only a shape.
      final outcome = await IssueCreditNote(
        fiscalYear: const NepaliFiscalCalendar().forBsYear(2082),
        invoices: DriftInvoiceRepository(db),
        payments: DriftPaymentRepository(db),
        creditNotes: DriftCreditNoteRepository(db),
        numbers: DriftDocumentNumberSequence(db),
        journal: DriftJournalRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      )(
        CreditNote(
          id: 'CRN-1',
          invoiceId: 'INV-A',
          date: DateTime(2026, 2, 1),
          lines: [
            InvoiceLine(
              description: 'returned',
              quantity: 1,
              unitPrice: Money.minor(50000, 'NPR'),
            ),
          ],
          vatRateBasisPoints: 0,
        ),
      );

      expect(outcome, isA<CreditNoteIssued>());
      final issued = outcome as CreditNoteIssued;
      expect(issued.number.value, 'CRN-2082-83-0001');
      // The seeded invoice is Rs 1,130; crediting Rs 500 leaves Rs 630.
      expect(issued.balance.outstanding.minorUnits, 63000);
      expect(issued.balance.uncredited.minorUnits, 63000);
      expect(await db.select(db.creditNotes).get(), hasLength(1));
      expect(await db.select(db.creditNoteLines).get(), hasLength(1));

      await db.close();
    });

    test('a fresh v6 database can still be created', () async {
      final db = AppDatabase(await verifier.startAt(6));
      await verifier.migrateAndValidate(db, 9);

      expect(await db.select(db.creditNotes).get(), isEmpty);

      await db.close();
    });
  });

  group('Upgrading to v5', () {
    test('adds payments without disturbing the existing tables', () async {
      final schema = await verifier.schemaAt(4);

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      expect(await db.select(db.payments).get(), isEmpty);
      expect(await db.select(db.invoices).get(), isEmpty);
      expect(await db.select(db.invoiceLines).get(), isEmpty);
      expect(await db.select(db.customers).get(), isEmpty);
      expect(await db.select(db.accounts).get(), isEmpty);
      expect(await db.select(db.journalEntries).get(), isEmpty);
      expect(await db.select(db.journalLines).get(), isEmpty);
      expect(await db.select(db.documentSequences).get(), isEmpty);

      await db.close();
    });

    test('v4 data survives the upgrade to v5', () async {
      final schema = await verifier.schemaAt(4);

      final previous = v4.DatabaseAtV4(schema.newConnection());
      await seedAccounts(previous);
      await seedJournal(previous, DateTime(2026, 1, 15));
      await previous.customStatement(
        'INSERT INTO document_sequences '
        '(document_type, fiscal_year_label, last_sequence) VALUES (?, ?, ?)',
        ['invoice', 'FY 2082/83', 7],
      );
      await previous.customStatement(
        'INSERT INTO customers (id, name, pan_number) VALUES (?, ?, ?)',
        ['cust-1', 'Himalayan Traders', '123456789'],
      );
      await seedInvoice(previous);
      await previous.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      expect(await db.select(db.accounts).get(), hasLength(5));
      expect(await db.select(db.customers).get(), hasLength(1));
      expect(await db.select(db.invoices).get(), hasLength(1));
      expect(await db.select(db.invoiceLines).get(), hasLength(1));
      expect(await db.select(db.documentSequences).get(), hasLength(1));

      final entry = (await db.select(db.journalEntries).get()).first;
      expect(entry.date, DateTime(2026, 1, 15),
          reason: 'the posting date must survive four upgrades untouched');

      await db.close();
    });

    test('the upgraded database can record a payment', () async {
      final schema = await verifier.schemaAt(4);

      final previous = v4.DatabaseAtV4(schema.newConnection());
      await seedAccounts(previous);
      await seedJournal(previous, DateTime(2026, 1, 15));
      await previous.customStatement(
        'INSERT INTO customers (id, name) VALUES (?, ?)',
        ['cust-1', 'Himalayan Traders'],
      );
      await seedInvoice(previous);
      await previous.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      // A schema that validates but does not work is only a shape.
      final outcome = await RecordPayment(
        fiscalYear: const NepaliFiscalCalendar().forBsYear(2082),
        invoices: DriftInvoiceRepository(db),
        payments: DriftPaymentRepository(db),
        creditNotes: DriftCreditNoteRepository(db),
        journal: DriftJournalRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      )(
        Payment(
          id: 'PAY-1',
          invoiceId: 'INV-A',
          date: DateTime(2026, 2, 1),
          amount: Money.minor(50000, 'NPR'),
          account: ChartOfAccounts.bank,
        ),
      );

      expect(outcome, isA<PaymentRecorded>());
      // The seeded invoice is for Rs 1,130 with no VAT, so Rs 500 leaves Rs 630.
      expect(
          (outcome as PaymentRecorded).balance.outstanding.minorUnits, 63000);
      expect(await db.select(db.payments).get(), hasLength(1));

      await db.close();
    });

    test('a fresh v5 database can still be created', () async {
      final db = AppDatabase(await verifier.startAt(5));
      await verifier.migrateAndValidate(db, 9);

      expect(await db.select(db.payments).get(), isEmpty);

      await db.close();
    });
  });

  group('Upgrading to v4', () {
    test('adds invoices without disturbing the existing tables', () async {
      final schema = await verifier.schemaAt(3);

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      for (final rows in [
        await db.select(db.invoices).get(),
        await db.select(db.invoiceLines).get(),
        await db.select(db.customers).get(),
        await db.select(db.accounts).get(),
        await db.select(db.journalEntries).get(),
        await db.select(db.journalLines).get(),
        await db.select(db.documentSequences).get(),
      ]) {
        expect(rows, isEmpty);
      }

      await db.close();
    });

    test('v3 data survives the upgrade to v4', () async {
      final schema = await verifier.schemaAt(3);

      final previous = v3.DatabaseAtV3(schema.newConnection());
      await seedAccounts(previous);
      await seedJournal(previous, DateTime(2026, 1, 15));
      await previous.customStatement(
        'INSERT INTO document_sequences '
        '(document_type, fiscal_year_label, last_sequence) VALUES (?, ?, ?)',
        ['invoice', 'FY 2082/83', 7],
      );
      await previous.customStatement(
        'INSERT INTO customers (id, name, pan_number) VALUES (?, ?, ?)',
        ['cust-1', 'Himalayan Traders', '123456789'],
      );
      await previous.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      expect(await db.select(db.accounts).get(), hasLength(5));

      final entries = await db.select(db.journalEntries).get();
      expect(entries, hasLength(1));
      expect(entries.single.date, DateTime(2026, 1, 15));

      final lines = await db.select(db.journalLines).get();
      final debits = lines.fold<int>(0, (s, l) => s + l.debitMinorUnits);
      final credits = lines.fold<int>(0, (s, l) => s + l.creditMinorUnits);
      expect(debits, 50000);
      expect(credits, 50000, reason: 'the surviving entry must still balance');

      final customers = await db.select(db.customers).get();
      expect(customers, hasLength(1));
      expect(customers.single.name, 'Himalayan Traders');
      expect(customers.single.panNumber, '123456789');

      final sequences = await db.select(db.documentSequences).get();
      expect(sequences.single.lastSequence, 7,
          reason: 'the invoice sequence must not restart, or numbers would be '
              'reissued');

      await db.close();
    });

    test('the upgraded database can issue and read back an invoice', () async {
      final schema = await verifier.schemaAt(3);

      final previous = v3.DatabaseAtV3(schema.newConnection());
      await seedAccounts(previous);
      await previous.customStatement(
        'INSERT INTO customers (id, name) VALUES (?, ?)',
        ['cust-1', 'Himalayan Traders'],
      );
      await previous.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      // A schema that validates but does not work is only a shape. Exercise the
      // new tables on the upgraded database.
      final issued = await IssueInvoice(
        fiscalYear: const NepaliFiscalCalendar().forBsYear(2082),
        customers: DriftCustomerRepository(db),
        numbers: DriftDocumentNumberSequence(db),
        journal: DriftJournalRepository(db),
        invoices: DriftInvoiceRepository(db),
        unitOfWork: DriftUnitOfWork(db),
      )(
        Invoice(
          id: 'INV-A',
          issueDate: DateTime(2026, 1, 15),
          customerId: 'cust-1',
          lines: [
            InvoiceLine(
              description: 'Keyboard',
              quantity: 2,
              unitPrice: Money.minor(30000, 'NPR'),
            ),
          ],
        ),
      );

      expect(issued, isA<InvoiceIssued>());
      expect((issued as InvoiceIssued).number.value, 'INV-2082-83-0001');

      final loaded = await DriftInvoiceRepository(db).byId('INV-A');
      expect(loaded, isNotNull);
      expect(loaded!.number.value, 'INV-2082-83-0001');
      // 2 x Rs 300 = 60,000 paisa, VAT 13% = 7,800, total = 67,800.
      expect(loaded.invoice.total.minorUnits, 67800);
      expect(loaded.invoice.lines.single.description, 'Keyboard');

      await db.close();
    });

    test('a fresh v4 database can still be created', () async {
      final db = AppDatabase(await verifier.startAt(4));
      await verifier.migrateAndValidate(db, 9);

      expect(await db.select(db.invoices).get(), isEmpty);

      await db.close();
    });
  });

  group('Upgrading to v3', () {
    test('adds customers without disturbing the existing tables', () async {
      final schema = await verifier.schemaAt(2);

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      expect(await db.select(db.customers).get(), isEmpty);
      expect(await db.select(db.accounts).get(), isEmpty);
      expect(await db.select(db.journalEntries).get(), isEmpty);
      expect(await db.select(db.journalLines).get(), isEmpty);
      expect(await db.select(db.documentSequences).get(), isEmpty);

      await db.close();
    });

    test('v2 data survives the upgrade to v3', () async {
      final schema = await verifier.schemaAt(2);

      final previous = v2.DatabaseAtV2(schema.newConnection());
      await seedAccounts(previous);
      await seedJournal(previous, DateTime(2026, 1, 15));
      await previous.customStatement(
        'INSERT INTO document_sequences '
        '(document_type, fiscal_year_label, last_sequence) VALUES (?, ?, ?)',
        ['invoice', 'FY 2082/83', 7],
      );
      await previous.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      final accounts = await db.select(db.accounts).get();
      expect(accounts, hasLength(5), reason: 'the chart must survive');
      expect(
        accounts.firstWhere((a) => a.id == 'acct-bank').type,
        AccountType.asset,
      );

      final entries = await db.select(db.journalEntries).get();
      expect(entries, hasLength(1));
      expect(entries.single.date, DateTime(2026, 1, 15),
          reason: 'the posting date must survive two upgrades untouched');

      final lines = await db.select(db.journalLines).get();
      expect(lines, hasLength(2));
      final debits = lines.fold<int>(0, (s, l) => s + l.debitMinorUnits);
      final credits = lines.fold<int>(0, (s, l) => s + l.creditMinorUnits);
      expect(debits, 50000);
      expect(credits, 50000, reason: 'the surviving entry must still balance');

      final sequences = await db.select(db.documentSequences).get();
      expect(sequences, hasLength(1));
      expect(sequences.single.lastSequence, 7,
          reason: 'the invoice sequence must not restart, or numbers would be '
              'reissued');

      await db.close();
    });

    test('a v1 database reaches v3 with all of its data intact', () async {
      final schema = await verifier.schemaAt(1);

      final previous = v1.DatabaseAtV1(schema.newConnection());
      await seedAccounts(previous);
      await seedJournal(previous, DateTime(2026, 3, 2));
      await previous.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      expect(await db.select(db.accounts).get(), hasLength(5));
      expect(await db.select(db.journalEntries).get(), hasLength(1));
      expect(await db.select(db.journalLines).get(), hasLength(2));
      expect(await db.select(db.customers).get(), isEmpty,
          reason: 'the new table exists and is empty after a two-step upgrade');

      await db.close();
    });

    test('the upgraded database is fully usable', () async {
      final schema = await verifier.schemaAt(2);

      final previous = v2.DatabaseAtV2(schema.newConnection());
      await seedAccounts(previous);
      await seedJournal(previous, DateTime(2026, 1, 15));
      await previous.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      // A schema that validates but does not work is only a shape. Exercise the
      // new table on the upgraded database.
      final customers = DriftCustomerRepository(db);
      await customers.save(
        Customer(
            id: 'cust-1', name: 'Himalayan Traders', panNumber: '123456789'),
      );

      final reloaded = await customers.byId('cust-1');
      expect(reloaded, isNotNull);
      expect(reloaded!.name, 'Himalayan Traders');
      expect(reloaded.panNumber, '123456789');

      // The pre-existing tables still work too.
      expect(await db.select(db.accounts).get(), hasLength(5));
      final sequence = DriftDocumentNumberSequence(db);
      final allocated = await sequence.allocateNext(
        type: DocumentType.invoice,
        fiscalYear: const NepaliFiscalCalendar().forBsYear(2082),
      );
      expect(allocated.value, 'INV-2082-83-0001');

      await db.close();
    });

    test('a fresh v3 database can still be created', () async {
      final db = AppDatabase(await verifier.startAt(3));
      await verifier.migrateAndValidate(db, 9);

      expect(await db.select(db.customers).get(), isEmpty);

      await db.close();
    });
  });

  /// Migration to the current version, covering v10 through v16.
  ///
  /// ## Why this group exists separately, and why it starts at v9
  ///
  /// The tests above all stop at v9, which is where the generated snapshots ran
  /// out when they were written. Steps v10 to v16 were added afterwards and had no
  /// migration test at all.
  ///
  /// **Snapshots for v13 to v16 were deliberately not created.** `drift_dev schema
  /// dump` captures the *current* schema and stamps it with whatever version is
  /// declared, so dumping at v13 produces a byte-identical copy of the v16 schema:
  /// four identical files that each assert a shape no real v13 database ever had.
  /// That is the "fixture was fiction" trap in `PROGRESS.md` 7.33, and a migration
  /// test that validates against fiction is worse than none, because it reports
  /// green.
  ///
  /// So this migrates a **real v9 database** â€” built from a real snapshot â€” all the
  /// way to the current version, which exercises every new step against data an
  /// earlier release actually wrote.
  group('Migrating to the current version', () {
    Future<AppDatabase> migratedFromV9() async {
      final schema = await verifier.schemaAt(9);
      final previous = v9.DatabaseAtV9(schema.newConnection());
      await seedAccounts(previous);
      await seedJournal(previous, DateTime(2026, 1, 15));
      await seedCustomer(previous);
      await seedInvoice(previous);
      await previous.close();

      // **No explicit open().** Constructing the database and reading from it is
      // what triggers drift's upgrade, which is the behaviour under test: a real
      // application never calls open by hand either.
      final db = AppDatabase(schema.newConnection());
      await db.select(db.accounts).get();
      return db;
    }

    test('a v9 database reaches the current version with its data intact',
        () async {
      final db = await migratedFromV9();

      // Everything v9 held must still be there, unchanged.
      expect(await db.select(db.accounts).get(), hasLength(5));
      expect(await db.select(db.customers).get(), hasLength(1));
      expect(await db.select(db.invoices).get(), hasLength(1));
      expect(await db.select(db.invoiceLines).get(), hasLength(1));

      final entry = (await db.select(db.journalEntries).get()).first;
      expect(entry.date, DateTime(2026, 1, 15),
          reason: 'the posting date must survive seven upgrades untouched');

      await db.close();
    });

    test('every table added since v9 exists and is empty', () async {
      final db = await migratedFromV9();

      // **New tables, not altered ones.** The tables that existed at v9 must be
      // untouched, so a v9 database simply has no rows in these.
      expect(await db.select(db.customerDetails).get(), isEmpty);
      expect(await db.select(db.invoiceSellers).get(), isEmpty);
      expect(await db.select(db.customerCodeSequences).get(), isEmpty);
      expect(await db.select(db.suppliers).get(), isEmpty);
      expect(await db.select(db.productCategories).get(), isEmpty);
      expect(await db.select(db.productCategoryAssignments).get(), isEmpty);
      expect(await db.select(db.purchases).get(), isEmpty);
      expect(await db.select(db.purchaseLines).get(), isEmpty);
      expect(await db.select(db.supplierPayments).get(), isEmpty);
      expect(await db.select(db.productSuppliers).get(), isEmpty);

      await db.close();
    });

    test('the migrated database can actually record a purchase', () async {
      // **A migration that validates but does not work is only a shape.** The
      // upgraded database must be usable for the feature the new tables exist for,
      // which means the foreign keys resolve and the code is still at the declared
      // version.
      final db = await migratedFromV9();

      // **Only the three accounts a purchase posts to.** The v9 fixture already
      // holds `acct-rent` at code 5010, which is also the real chart's code for
      // Office Rent, so saving the whole chart here would fail on a UNIQUE code
      // collision that is an artefact of the fixture rather than a real defect.
      await DriftAccountRepository(db).saveAll([
        ChartOfAccounts.inventory,
        ChartOfAccounts.inputVatRecoverable,
        ChartOfAccounts.payable,
      ]);
      await DriftSupplierRepository(db).save(
        Supplier(id: 'sup-1', name: 'Kamala Traders', pan: '601234567'),
      );
      await DriftInventoryRepository(db).saveProduct(
        Product(
            id: 'p-1', name: 'Chair', salePrice: Money.minor(200000, 'NPR')),
      );

      final outcome = await IssuePurchase(
        fiscalYear: const NepaliFiscalCalendar().forBsYear(2082),
        suppliers: DriftSupplierRepository(db),
        purchases: DriftPurchaseRepository(db),
        numbers: DriftDocumentNumberSequence(db),
        journal: DriftJournalRepository(db),
        unitOfWork: DriftUnitOfWork(db),
        inventory: DriftInventoryRepository(db),
      )(
        Purchase(
          id: 'P-1',
          issueDate: DateTime(2026, 2, 1),
          supplierId: 'sup-1',
          lines: [
            PurchaseLine(
              description: 'Chair',
              quantity: 10,
              unitPrice: Money.minor(100000, 'NPR'),
              productId: 'p-1',
            ),
          ],
        ),
      );

      expect(outcome, isA<PurchaseIssued>());

      await db.close();
    });

    test('a supplier written without is_active reads as active', () async {
      // **The direction of the default is the whole point of this test.**
      //
      // `is_active` was added at v17, so a row written before that step has no value
      // for it -- either because the column was just added by the migration, or
      // because the writer did not mention it. The column defaults to **1**, so such a
      // supplier reads as active and keeps working.
      //
      // The opposite default would fail silently and catastrophically: the supplier
      // would exist, its name would appear, every lookup would succeed -- and no new
      // purchase could be recorded against it, with nothing on screen to say why.
      // A schema change must never be able to stop a business trading.
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      // **Raw SQL with no `is_active`**, because that is exactly the shape of the row
      // this default exists to cover. Going through the repository would always write
      // the flag explicitly and would therefore prove nothing.
      await db.customStatement(
        "INSERT INTO suppliers (id, name) "
        "VALUES ('sup-old', 'Kamala Traders')",
      );

      final row = await (db.select(db.suppliers)
            ..where((t) => t.id.equals('sup-old')))
          .getSingle();
      expect(row.isActive, 1,
          reason: 'a supplier with no is_active must default to active');

      // And the repository agrees, so the domain reads it as usable.
      final suppliers = DriftSupplierRepository(db);
      expect((await suppliers.byId('sup-old'))?.isActive, isTrue);
      expect(
          (await suppliers.byId('sup-old'))?.canBeBilledOnNewPurchase, isTrue);
    });
  });
}
