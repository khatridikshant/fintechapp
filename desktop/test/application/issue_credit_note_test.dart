import 'dart:io';

import 'package:financeapp/src/application/issue_credit_note.dart';
import 'package:financeapp/src/application/issue_invoice.dart';
import 'package:financeapp/src/application/record_payment.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/billing/credit_note.dart';
import 'package:financeapp/src/domain/billing/customer.dart';
import 'package:financeapp/src/domain/billing/invoice.dart';
import 'package:financeapp/src/domain/billing/invoice_line.dart';
import 'package:financeapp/src/domain/billing/payment.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/reporting/trial_balance.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_credit_note_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_customer_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_document_number_sequence.dart';
import 'package:financeapp/src/infrastructure/database/drift_invoice_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_payment_repository.dart';
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

Future<void> seed(AppDatabase db) async {
  await DriftAccountRepository(db).saveAll(chart.all);
  await DriftCustomerRepository(db).save(testCustomer);
}

/// Issues an invoice with [vatRate] VAT. Defaults to none so the balance
/// arithmetic in these tests stays obvious.
Future<String> issueInvoice(
  AppDatabase db, {
  int totalRupees = 1000,
  int vatRate = 0,
  String id = 'INV-1',
}) async {
  final outcome = await IssueInvoice(
    fiscalYear: fiscalYear,
    customers: DriftCustomerRepository(db),
    numbers: DriftDocumentNumberSequence(db),
    journal: DriftJournalRepository(db),
    invoices: DriftInvoiceRepository(db),
    unitOfWork: DriftUnitOfWork(db),
  )(
    Invoice(
      id: id,
      issueDate: DateTime(2026, 1, 1),
      customerId: 'cust-1',
      lines: [line(1, totalRupees)],
      vatRateBasisPoints: vatRate,
    ),
  );

  expect(outcome, isA<InvoiceIssued>());
  return id;
}

IssueCreditNote creditNoteFor(AppDatabase db) => IssueCreditNote(
      fiscalYear: fiscalYear,
      invoices: DriftInvoiceRepository(db),
      payments: DriftPaymentRepository(db),
      creditNotes: DriftCreditNoteRepository(db),
      numbers: DriftDocumentNumberSequence(db),
      journal: DriftJournalRepository(db),
      unitOfWork: DriftUnitOfWork(db),
    );

RecordPayment paymentFor(AppDatabase db) => RecordPayment(
      fiscalYear: fiscalYear,
      invoices: DriftInvoiceRepository(db),
      payments: DriftPaymentRepository(db),
      creditNotes: DriftCreditNoteRepository(db),
      journal: DriftJournalRepository(db),
      unitOfWork: DriftUnitOfWork(db),
    );

CreditNote creditNoteOf(
  int amountRupees, {
  String id = 'CRN-1',
  String invoiceId = 'INV-1',
  int vatRate = 0,
  DateTime? date,
}) =>
    CreditNote(
      id: id,
      invoiceId: invoiceId,
      date: date ?? DateTime(2026, 2, 1),
      lines: [line(1, amountRupees)],
      vatRateBasisPoints: vatRate,
    );

Payment paymentOf(int amountRupees, {String id = 'PAY-1'}) => Payment(
      id: id,
      invoiceId: 'INV-1',
      date: DateTime(2026, 2, 1),
      amount: rs(amountRupees),
      account: ChartOfAccounts.bank,
    );

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('financeapp_credit_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('Issuing a credit note', () {
    test('posts the three reversal lines with hand-computed amounts', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      // Rs 1,000 + 13% VAT = subtotal 100,000, VAT 13,000, total 113,000.
      await issueInvoice(db,
          totalRupees: 1000, vatRate: CreditNote.standardVatRate);

      final outcome = await creditNoteFor(db)(
        creditNoteOf(1000, vatRate: CreditNote.standardVatRate),
      );

      expect(outcome, isA<CreditNoteIssued>());
      final issued = outcome as CreditNoteIssued;
      final lines = issued.journalEntry.lines;

      expect(lines, hasLength(3));

      final sales = lines
          .firstWhere((l) => l.account.id == ChartOfAccounts.salesRevenue.id);
      expect(sales.isDebit, isTrue,
          reason: 'crediting revenue reduces it, so it is debited');
      expect(sales.debit.minorUnits, 100000);

      final vat = lines
          .firstWhere((l) => l.account.id == ChartOfAccounts.vatPayable.id);
      expect(vat.isDebit, isTrue);
      expect(vat.debit.minorUnits, 13000);

      final receivable = lines
          .firstWhere((l) => l.account.id == ChartOfAccounts.receivable.id);
      expect(receivable.isCredit, isTrue);
      expect(receivable.credit.minorUnits, 113000);

      expect(issued.journalEntry.totalDebits.minorUnits, 113000);
      expect(issued.journalEntry.totalCredits.minorUnits, 113000);
      expect(issued.journalEntry.isBalanced, isTrue);
    });

    test('a zero-rated credit note posts two lines, not three', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db);

      final issued =
          await creditNoteFor(db)(creditNoteOf(400)) as CreditNoteIssued;

      expect(issued.journalEntry.lines, hasLength(2),
          reason: 'a zero VAT line must be omitted, not posted as zero');
      expect(issued.journalEntry.isBalanced, isTrue);
    });

    test('uses its own CRN sequence, independent of invoices', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      await issueInvoice(db, id: 'INV-A');
      await issueInvoice(db, id: 'INV-B');
      await issueInvoice(db, id: 'INV-C');

      final issued = await creditNoteFor(db)(
        creditNoteOf(100, invoiceId: 'INV-A'),
      ) as CreditNoteIssued;

      expect(issued.number.value, 'CRN-2082-83-0001',
          reason: 'three invoices must not advance the credit note sequence');
    });

    test('numbers credit notes sequentially', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 2000);
      final useCase = creditNoteFor(db);

      final first =
          await useCase(creditNoteOf(300, id: 'CRN-A')) as CreditNoteIssued;
      final second =
          await useCase(creditNoteOf(300, id: 'CRN-B')) as CreditNoteIssued;

      expect(first.number.value, 'CRN-2082-83-0001');
      expect(second.number.value, 'CRN-2082-83-0002');
    });

    test('the outstanding balance falls by the credited amount', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 1000);

      final issued =
          await creditNoteFor(db)(creditNoteOf(400)) as CreditNoteIssued;

      expect(issued.balance.credited.minorUnits, 40000);
      expect(issued.balance.outstanding.minorUnits, 60000);
      expect(issued.balance.uncredited.minorUnits, 60000);
    });

    test('the credit note is readable back from the database', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 1000);

      await creditNoteFor(db)(creditNoteOf(400, id: 'CRN-X'));

      final loaded = await DriftCreditNoteRepository(db).byId('CRN-X');
      expect(loaded, isNotNull);
      expect(loaded!.creditNote.invoiceId, 'INV-1');
      expect(loaded.number.value, 'CRN-2082-83-0001');
      expect(loaded.creditNote.total.minorUnits, 40000);
      expect(loaded.creditNote.lines.single.description, 'item');
      expect(loaded.journalEntryId, 'JE-CRN-CRN-X');
    });

    test('the trial balance still balances after a credit note', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 1000, vatRate: 1300);
      await creditNoteFor(db)(creditNoteOf(500, vatRate: 1300));

      final report = TrialBalance.from(
        entries: await DriftJournalRepository(db).all(),
        currency: npr,
      );
      final byCode = {for (final row in report.rows) row.account.code: row};

      expect(report.isBalanced, isTrue);
      // Issued 113,000 receivable, credited 56,500, so 56,500 remains.
      expect(byCode['1030']!.balance.minorUnits, 56500);
      // Sales: 100,000 issued less 50,000 credited = 50,000.
      expect(byCode['4010']!.balance.minorUnits, 50000);
      // VAT: 13,000 issued less 6,500 credited = 6,500 owed to the authority.
      expect(byCode['2020']!.balance.minorUnits, 6500);
    });
  });

  group('Credits and payments reach zero, in either order', () {
    test('credit first, then payment', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 1000);

      await creditNoteFor(db)(creditNoteOf(400));
      final paid = await paymentFor(db)(paymentOf(600)) as PaymentRecorded;

      expect(paid.balance.credited.minorUnits, 40000);
      expect(paid.balance.received.minorUnits, 60000);
      expect(paid.balance.outstanding.isZero, isTrue);
      expect(paid.balance.isSettled, isTrue);
    });

    test('payment first, then credit', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 1000);

      await paymentFor(db)(paymentOf(400));
      final credited =
          await creditNoteFor(db)(creditNoteOf(600)) as CreditNoteIssued;

      expect(credited.balance.received.minorUnits, 40000);
      expect(credited.balance.credited.minorUnits, 60000);
      expect(credited.balance.outstanding.isZero, isTrue);
      expect(credited.balance.isSettled, isTrue);
    });
  });

  group('A credit note cannot exceed what is uncredited', () {
    test('exactly the uncredited amount is accepted', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 1000);

      final outcome = await creditNoteFor(db)(creditNoteOf(1000));

      expect(outcome, isA<CreditNoteIssued>());
      expect((outcome as CreditNoteIssued).balance.uncredited.isZero, isTrue);
      expect(outcome.balance.isFullyCredited, isTrue);
    });

    test('one paisa more is refused', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 1000);

      final outcome = await creditNoteFor(db)(
        CreditNote(
          id: 'CRN-OVER',
          invoiceId: 'INV-1',
          date: DateTime(2026, 2, 1),
          lines: [
            InvoiceLine(
              description: 'over',
              quantity: 1,
              unitPrice: Money.minor(100001, npr),
            ),
          ],
          vatRateBasisPoints: 0,
        ),
      );

      expect(outcome, isA<CreditNoteRejected>());
      final rejected = outcome as CreditNoteRejected;
      expect(
        rejected.reason,
        CreditNoteRejectionReason.exceedsUncredited,
      );
      expect(rejected.uncredited!.minorUnits, 100000);
      expect(rejected.message, contains('more than'));
    });

    test('a refusal writes nothing at all', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 1000);
      final journal = DriftJournalRepository(db);

      await creditNoteFor(db)(creditNoteOf(1001, id: 'CRN-OVER'));

      expect(await DriftCreditNoteRepository(db).byId('CRN-OVER'), isNull);
      expect(await db.select(db.creditNotes).get(), isEmpty);
      expect(await db.select(db.creditNoteLines).get(), isEmpty);
      expect(await journal.byId('JE-CRN-CRN-OVER'), isNull);

      // The invoice legitimately created an `invoice` sequence row. What must
      // not exist is a `creditNote` row, because the refusal happened before
      // any allocation.
      final sequences = await db.select(db.documentSequences).get();
      expect(
        sequences.where((s) => s.documentType == 'creditNote'),
        isEmpty,
        reason: 'a refused credit note must not consume a CRN serial',
      );

      // Only the invoice's own entry remains.
      expect(await journal.all(), hasLength(1));
    });

    test('a second credit note beyond the remainder is refused', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 1000);
      final useCase = creditNoteFor(db);

      await useCase(creditNoteOf(600, id: 'CRN-1'));

      // Rs 400 remains uncredited, so Rs 401 must be refused.
      final outcome = await useCase(creditNoteOf(401, id: 'CRN-2'));

      expect(outcome, isA<CreditNoteRejected>());
      expect(
        (outcome as CreditNoteRejected).uncredited!.minorUnits,
        40000,
      );
      expect(await DriftCreditNoteRepository(db).all(), hasLength(1));
    });

    test('a payment cannot exceed what remains after a credit note', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 1000);
      await creditNoteFor(db)(creditNoteOf(400));

      // Only Rs 600 is still owed, so Rs 700 must be refused.
      final outcome = await paymentFor(db)(paymentOf(700));

      expect(outcome, isA<PaymentRejected>());
      expect(
        (outcome as PaymentRejected).outstanding!.minorUnits,
        60000,
        reason: 'the overpayment check must account for credit notes, or a '
            'customer could pay more than they owe',
      );
    });

    test('a fully credited invoice cannot be paid at all', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 1000);
      await creditNoteFor(db)(creditNoteOf(1000));

      final outcome = await paymentFor(db)(paymentOf(1));

      expect(outcome, isA<PaymentRejected>());
      expect((outcome as PaymentRejected).outstanding!.isZero, isTrue);
    });
  });

  group('Other refusals', () {
    test('a credit note for an invoice that does not exist is refused',
        () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      final outcome = await creditNoteFor(db)(
        creditNoteOf(100, invoiceId: 'INV-NOBODY'),
      );

      expect(outcome, isA<CreditNoteRejected>());
      expect(
        (outcome as CreditNoteRejected).reason,
        CreditNoteRejectionReason.unknownInvoice,
      );
      expect(await db.select(db.creditNotes).get(), isEmpty);
      expect(await DriftJournalRepository(db).all(), isEmpty);
    });

    test('a credit note dated outside the fiscal year is refused', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db);

      for (final date in [
        fiscalYear.startDate.subtract(const Duration(days: 1)),
        fiscalYear.endDate.add(const Duration(days: 1)),
      ]) {
        final outcome = await creditNoteFor(db)(creditNoteOf(100, date: date));

        expect(outcome, isA<CreditNoteRejected>());
        expect(
          (outcome as CreditNoteRejected).reason,
          CreditNoteRejectionReason.outsideFiscalYear,
        );
      }

      expect(await db.select(db.creditNotes).get(), isEmpty);
    });

    test('a credit note on the last day of the fiscal year is accepted',
        () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db);

      final outcome = await creditNoteFor(db)(
        creditNoteOf(100, date: fiscalYear.endDate),
      );

      expect(outcome, isA<CreditNoteIssued>());
    });
  });

  group('Money is stored exactly', () {
    test('the credit note money columns are INTEGER, never REAL', () async {
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

      final noteColumns = await columnsOf('credit_notes');
      for (final column in [
        'subtotal_minor_units',
        'vat_minor_units',
        'total_minor_units',
        'vat_rate_basis_points',
      ]) {
        expect(noteColumns[column]?.toUpperCase(), 'INTEGER',
            reason: '$column must be INTEGER');
      }

      final lineColumns = await columnsOf('credit_note_lines');
      expect(lineColumns['unit_price_minor_units']?.toUpperCase(), 'INTEGER');
    });

    test('stored totals equal recomputed totals', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 1000, vatRate: 1300);
      await creditNoteFor(db)(creditNoteOf(1000, vatRate: 1300));

      final row = (await db.select(db.creditNotes).get()).single;
      final loaded = await DriftCreditNoteRepository(db).byId('CRN-1');

      expect(row.subtotalMinorUnits, loaded!.creditNote.subtotal.minorUnits);
      expect(row.vatMinorUnits, loaded.creditNote.vat.minorUnits);
      expect(row.totalMinorUnits, loaded.creditNote.total.minorUnits);
      expect(
        row.subtotalMinorUnits + row.vatMinorUnits,
        row.totalMinorUnits,
      );
    });

    test('the database rejects a credit note without its invoice', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      await expectLater(
        db.into(db.creditNotes).insert(
              CreditNotesCompanion.insert(
                id: 'CRN-ORPHAN',
                number: 'CRN-2082-83-0999',
                sequence: 999,
                fiscalYearLabel: 'FY 2082/83',
                invoiceId: 'INV-NOBODY',
                date: DateTime(2026, 2, 1),
                currency: npr,
                vatRateBasisPoints: 0,
                subtotalMinorUnits: 10000,
                vatMinorUnits: 0,
                totalMinorUnits: 10000,
                journalEntryId: 'JE-CRN-ORPHAN',
              ),
            ),
        throwsA(
          predicate((e) => e.toString().toLowerCase().contains('foreign key')),
        ),
      );
    });
  });

  group('Durability', () {
    test('a credit note survives closing and reopening the database', () async {
      final file = File(p.join(tempDir.path, 'accounting-FY-2082-83.db'));

      final db = openFileDatabase(file);
      await seed(db);
      await issueInvoice(db, totalRupees: 1000);
      await creditNoteFor(db)(creditNoteOf(400));
      await db.close();

      final reopened = openFileDatabase(file);
      final loaded = await DriftCreditNoteRepository(reopened).byId('CRN-1');
      final notes =
          await DriftCreditNoteRepository(reopened).forInvoice('INV-1');
      await reopened.close();

      expect(loaded, isNotNull);
      expect(loaded!.number.value, 'CRN-2082-83-0001');
      expect(loaded.creditNote.total.minorUnits, 40000);
      expect(loaded.creditNote.lines.single.description, 'item');
      expect(notes, hasLength(1),
          reason: 'the uncredited amount must be reconstructible after a '
              'restart, since it is derived rather than stored');
    });
  });
}
