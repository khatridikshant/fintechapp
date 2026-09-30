import 'dart:io';

import 'package:financeapp/src/application/issue_invoice.dart';
import 'package:financeapp/src/application/record_payment.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/billing/customer.dart';
import 'package:financeapp/src/domain/billing/invoice.dart';
import 'package:financeapp/src/domain/billing/invoice_line.dart';
import 'package:financeapp/src/domain/billing/payment.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/reporting/trial_balance.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_customer_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_credit_note_repository.dart';
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

/// Seeds accounts and the customer.
Future<void> seed(AppDatabase db) async {
  await DriftAccountRepository(db).saveAll(chart.all);
  await DriftCustomerRepository(db).save(testCustomer);
}

/// Issues an invoice for [totalRupees] with no VAT, and returns its id.
Future<String> issueInvoice(
  AppDatabase db, {
  int totalRupees = 1130,
  String id = 'INV-1',
  DateTime? date,
}) async {
  final useCase = IssueInvoice(
    fiscalYear: fiscalYear,
    customers: DriftCustomerRepository(db),
    numbers: DriftDocumentNumberSequence(db),
    journal: DriftJournalRepository(db),
    invoices: DriftInvoiceRepository(db),
    unitOfWork: DriftUnitOfWork(db),
  );

  final outcome = await useCase(
    Invoice(
      id: id,
      issueDate: date ?? DateTime(2026, 1, 1),
      customerId: 'cust-1',
      lines: [
        InvoiceLine(
          description: 'item',
          quantity: 1,
          unitPrice: rs(totalRupees),
        ),
      ],
      vatRateBasisPoints: 0,
    ),
  );

  expect(outcome, isA<InvoiceIssued>());
  return id;
}

RecordPayment recordPaymentFor(AppDatabase db) => RecordPayment(
      fiscalYear: fiscalYear,
      invoices: DriftInvoiceRepository(db),
      payments: DriftPaymentRepository(db),
      creditNotes: DriftCreditNoteRepository(db),
      journal: DriftJournalRepository(db),
      unitOfWork: DriftUnitOfWork(db),
    );

Payment paymentOf(
  int amountRupees, {
  String id = 'PAY-1',
  String invoiceId = 'INV-1',
  DateTime? date,
}) =>
    Payment(
      id: id,
      invoiceId: invoiceId,
      date: date ?? DateTime(2026, 2, 1),
      amount: rs(amountRupees),
      account: ChartOfAccounts.bank,
    );

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('financeapp_payment_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('Recording a payment', () {
    test('a full settlement leaves nothing outstanding', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db);

      final outcome = await recordPaymentFor(db)(paymentOf(1130));

      expect(outcome, isA<PaymentRecorded>());
      final recorded = outcome as PaymentRecorded;
      expect(recorded.balance.outstanding.isZero, isTrue);
      expect(recorded.balance.isSettled, isTrue);
      expect(recorded.balance.received.minorUnits, 113000);
    });

    test('posts Dr Bank and Cr Accounts Receivable', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db);

      final recorded =
          await recordPaymentFor(db)(paymentOf(500)) as PaymentRecorded;
      final lines = recorded.journalEntry.lines;

      expect(lines, hasLength(2));
      expect(lines[0].account.id, ChartOfAccounts.bank.id);
      expect(lines[0].isDebit, isTrue);
      expect(lines[0].debit.minorUnits, 50000);
      expect(lines[1].account.id, ChartOfAccounts.receivable.id);
      expect(lines[1].isCredit, isTrue);
      expect(lines[1].credit.minorUnits, 50000);
      expect(recorded.journalEntry.isBalanced, isTrue);
    });

    test('a partial payment leaves the hand-computed remainder', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 1130);

      // Hand-computed: Rs 1,130 - Rs 500 = Rs 630 = 63,000 paisa.
      final recorded =
          await recordPaymentFor(db)(paymentOf(500)) as PaymentRecorded;

      expect(recorded.balance.outstanding.minorUnits, 63000);
      expect(recorded.balance.isPartiallyPaid, isTrue);
    });

    test('several partial payments accumulate to settled', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 1000);
      final useCase = recordPaymentFor(db);

      await useCase(paymentOf(300, id: 'PAY-1'));
      await useCase(paymentOf(200, id: 'PAY-2'));
      final last =
          await useCase(paymentOf(500, id: 'PAY-3')) as PaymentRecorded;

      expect(last.balance.received.minorUnits, 100000);
      expect(last.balance.outstanding.isZero, isTrue);
    });

    test('the receivable reaches zero once the invoice is settled', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 1130);
      await recordPaymentFor(db)(paymentOf(1130));

      final journal = DriftJournalRepository(db);
      final report =
          TrialBalance.from(entries: await journal.all(), currency: npr);
      final byCode = {for (final row in report.rows) row.account.code: row};

      expect(report.isBalanced, isTrue,
          reason: 'the ledger must still balance after a settlement');
      expect(byCode['1030']!.balance.isZero, isTrue,
          reason: 'the customer no longer owes anything');
      expect(byCode['1010']!.balance.minorUnits, 113000,
          reason: 'the money is in the bank');
    });

    test('the payment is readable back from the database', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db);

      await recordPaymentFor(db)(paymentOf(500));
      final loaded = await DriftPaymentRepository(db).byId('PAY-1');

      expect(loaded, isNotNull);
      expect(loaded!.invoiceId, 'INV-1');
      expect(loaded.amount.minorUnits, 50000);
      expect(loaded.date, DateTime(2026, 2, 1));
      expect(loaded.account.id, ChartOfAccounts.bank.id);
    });
  });

  group('An overpayment is refused', () {
    test('exactly the outstanding amount is accepted', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 1000);

      final outcome = await recordPaymentFor(db)(paymentOf(1000));

      expect(outcome, isA<PaymentRecorded>());
      expect(
        (outcome as PaymentRecorded).balance.outstanding.isZero,
        isTrue,
      );
    });

    test('one paisa more is refused', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 1000);

      // Rs 1,000 owed, Rs 1,000.01 offered.
      final outcome = await recordPaymentFor(db)(
        Payment(
          id: 'PAY-OVER',
          invoiceId: 'INV-1',
          date: DateTime(2026, 2, 1),
          amount: Money.minor(100001, npr),
          account: ChartOfAccounts.bank,
        ),
      );

      expect(outcome, isA<PaymentRejected>());
      final rejected = outcome as PaymentRejected;
      expect(
        rejected.reason,
        RecordPaymentRejectionReason.exceedsOutstanding,
      );
      expect(rejected.outstanding!.minorUnits, 100000);
      expect(rejected.message, contains('more than'));
    });

    test('a refusal writes nothing at all', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 1000);
      final journal = DriftJournalRepository(db);

      await recordPaymentFor(db)(paymentOf(1001, id: 'PAY-OVER'));

      expect(await DriftPaymentRepository(db).byId('PAY-OVER'), isNull);
      expect(await db.select(db.payments).get(), isEmpty);
      expect(
        await journal.byId('JE-PAY-PAY-OVER'),
        isNull,
        reason: 'no journal entry may be written for a refused payment',
      );
      // Only the invoice's own entry remains.
      expect(await journal.all(), hasLength(1));
    });

    test('a second payment exceeding the remainder is refused', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 1000);
      final useCase = recordPaymentFor(db);

      await useCase(paymentOf(600, id: 'PAY-1'));

      // Rs 400 remains, so Rs 401 must be refused.
      final outcome = await useCase(paymentOf(401, id: 'PAY-2'));

      expect(outcome, isA<PaymentRejected>());
      expect(
        (outcome as PaymentRejected).outstanding!.minorUnits,
        40000,
      );
      expect(await DriftPaymentRepository(db).all(), hasLength(1));
    });

    test('a payment that exactly clears the remainder is accepted', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 1000);
      final useCase = recordPaymentFor(db);

      await useCase(paymentOf(600, id: 'PAY-1'));
      final second =
          await useCase(paymentOf(400, id: 'PAY-2')) as PaymentRecorded;

      expect(second.balance.outstanding.isZero, isTrue);
      expect(await DriftPaymentRepository(db).all(), hasLength(2));
    });
  });

  group('Other refusals', () {
    test('a payment for an invoice that does not exist is refused', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      final outcome = await recordPaymentFor(db)(
        paymentOf(500, invoiceId: 'INV-NOBODY'),
      );

      expect(outcome, isA<PaymentRejected>());
      expect(
        (outcome as PaymentRejected).reason,
        RecordPaymentRejectionReason.unknownInvoice,
      );
      expect(outcome.message, contains('INV-NOBODY'));
      expect(await db.select(db.payments).get(), isEmpty);
      expect(await DriftJournalRepository(db).all(), isEmpty);
    });

    test('a payment dated before the fiscal year is refused', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db);

      final outcome = await recordPaymentFor(db)(
        paymentOf(
          500,
          date: fiscalYear.startDate.subtract(const Duration(days: 1)),
        ),
      );

      expect(outcome, isA<PaymentRejected>());
      expect(
        (outcome as PaymentRejected).reason,
        RecordPaymentRejectionReason.outsideFiscalYear,
      );
      expect(outcome.message, contains('FY 2082/83'));
      expect(await db.select(db.payments).get(), isEmpty);
    });

    test('a payment dated after the fiscal year is refused', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db);

      final outcome = await recordPaymentFor(db)(
        paymentOf(
          500,
          date: fiscalYear.endDate.add(const Duration(days: 1)),
        ),
      );

      expect(outcome, isA<PaymentRejected>());
      expect(await db.select(db.payments).get(), isEmpty);
    });

    test('a payment on the last day of the fiscal year is accepted', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db);

      final outcome = await recordPaymentFor(db)(
        paymentOf(500, date: fiscalYear.endDate),
      );

      expect(outcome, isA<PaymentRecorded>());
    });

    test('recording the same payment id twice is refused', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 2000);
      final useCase = recordPaymentFor(db);

      await useCase(paymentOf(500, id: 'PAY-1'));

      // Reusing the id must not double-count against the invoice.
      await expectLater(
        useCase(paymentOf(500, id: 'PAY-1')),
        throwsA(anything),
      );

      final payments = await DriftPaymentRepository(db).all();
      expect(payments, hasLength(1),
          reason: 'the outstanding balance must count the payment once');
    });
  });

  group('The database refuses bad payment rows', () {
    test('a payment for an invoice that does not exist is rejected', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      await expectLater(
        db.into(db.payments).insert(
              PaymentsCompanion.insert(
                id: 'PAY-ORPHAN',
                invoiceId: 'INV-NOBODY',
                date: DateTime(2026, 2, 1),
                amountMinorUnits: 50000,
                currency: npr,
                accountId: ChartOfAccounts.bank.id,
              ),
            ),
        throwsA(
          predicate((e) => e.toString().toLowerCase().contains('foreign key')),
        ),
      );
    });

    test('a payment into an account that does not exist is rejected', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db);

      await expectLater(
        db.into(db.payments).insert(
              PaymentsCompanion.insert(
                id: 'PAY-BADACCT',
                invoiceId: 'INV-1',
                date: DateTime(2026, 2, 1),
                amountMinorUnits: 50000,
                currency: npr,
                accountId: 'acct-does-not-exist',
              ),
            ),
        throwsA(
          predicate((e) => e.toString().toLowerCase().contains('foreign key')),
        ),
      );
    });

    test('a zero or negative amount is rejected', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db);

      for (final amount in [0, -1]) {
        await expectLater(
          db.into(db.payments).insert(
                PaymentsCompanion.insert(
                  id: 'PAY-$amount',
                  invoiceId: 'INV-1',
                  date: DateTime(2026, 2, 1),
                  amountMinorUnits: amount,
                  currency: npr,
                  accountId: ChartOfAccounts.bank.id,
                ),
              ),
          throwsA(
              predicate((e) => e.toString().toLowerCase().contains('check'))),
        );
      }
    });
  });

  group('Money is stored exactly', () {
    test('the payments amount column is INTEGER, never REAL', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      final rows = await db
          .customSelect("SELECT name, type FROM pragma_table_info('payments')")
          .get();
      final types = {
        for (final row in rows)
          row.read<String>('name'): row.read<String>('type'),
      };

      expect(types['amount_minor_units']?.toUpperCase(), 'INTEGER',
          reason: 'a REAL column would silently corrupt money at the storage '
              'boundary');
    });

    test('an amount with paisa precision round-trips exactly', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await issueInvoice(db, totalRupees: 2000000);

      await recordPaymentFor(db)(
        Payment(
          id: 'PAY-EXACT',
          invoiceId: 'INV-1',
          date: DateTime(2026, 2, 1),
          amount: const Money.minor(128450007, npr),
          account: ChartOfAccounts.bank,
        ),
      );

      final loaded = await DriftPaymentRepository(db).byId('PAY-EXACT');
      expect(loaded!.amount.minorUnits, 128450007);
    });
  });

  group('Durability', () {
    test('a payment survives closing and reopening the database', () async {
      final file = File(p.join(tempDir.path, 'accounting-FY-2082-83.db'));

      final db = openFileDatabase(file);
      await seed(db);
      await issueInvoice(db, totalRupees: 1130);
      await recordPaymentFor(db)(paymentOf(500));
      await db.close();

      final reopened = openFileDatabase(file);
      final loaded = await DriftPaymentRepository(reopened).byId('PAY-1');
      final outstanding =
          await DriftPaymentRepository(reopened).forInvoice('INV-1');
      await reopened.close();

      expect(loaded, isNotNull);
      expect(loaded!.amount.minorUnits, 50000);
      expect(outstanding, hasLength(1));
      expect(
        outstanding.fold<int>(0, (sum, p) => sum + p.amount.minorUnits),
        50000,
        reason: 'the outstanding balance must be reconstructible after a '
            'restart, since it is derived rather than stored',
      );
    });
  });
}
