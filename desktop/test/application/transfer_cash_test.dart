import 'package:financeapp/src/application/post_journal_entry.dart';
import 'package:financeapp/src/application/transfer_cash.dart';
import 'package:financeapp/src/domain/accounting/account.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_unit_of_work.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Moving money between the business's own cash accounts.
///
/// ## What this pins
///
/// **That a transfer cannot touch anything but cash.** The Journal screen can post
/// any balanced two-line entry, and one debiting "Office rent" against "Bank" is
/// mechanically valid while being a completely different event. This use case
/// exists so that mistake is **structurally impossible here** rather than merely
/// discouraged.
///
/// ## The figures
///
/// Moving Rs 50,000 from Bank to Cash posts `Dr Cash 50,000 / Cr Bank 50,000`:
/// **no income, no expense, nothing spent and nothing owed** — which is the whole
/// accounting consequence of moving money the business already owns.
void main() {
  const npr = 'NPR';
  final fiscalYear = const NepaliFiscalCalendar().forBsYear(2082);

  late AppDatabase db;
  late DriftJournalRepository journal;
  late TransferCash transfers;

  setUp(() async {
    db = openInMemoryDatabase();
    journal = DriftJournalRepository(db);
    await DriftAccountRepository(db).saveAll(const ChartOfAccounts().all);
    transfers = TransferCash(
      fiscalYear: fiscalYear,
      postEntry: PostJournalEntry(
        fiscalYear: fiscalYear,
        journal: journal,
        unitOfWork: DriftUnitOfWork(db),
      ),
    );
  });

  tearDown(() async => db.close());

  Money rs(int majorUnits) => Money.minor(majorUnits * 100, npr);

  Future<TransferOutcome> transfer({
    Account? from,
    Account? to,
    int amount = 50000,
    DateTime? date,
  }) =>
      transfers.transfer(
        from: from ?? ChartOfAccounts.bank,
        to: to ?? ChartOfAccounts.cash,
        amount: rs(amount),
        reason: 'Cash to bank',
        date: date ?? DateTime(2026, 3, 10),
      );

  group('a transfer between cash accounts', () {
    test('posts a balanced entry with no income or expense', () async {
      final outcome = await transfer();

      expect(outcome, isA<TransferCompleted>());
      final entry = (await journal.all()).single;

      expect(entry.lines, hasLength(2));
      // Dr where it landed, Cr where it came from.
      final debit = entry.lines.firstWhere((JournalLine l) => l.isDebit);
      final credit = entry.lines.firstWhere((JournalLine l) => l.isCredit);

      expect(debit.account.id, ChartOfAccounts.cash.id);
      expect(credit.account.id, ChartOfAccounts.bank.id);
      expect(debit.amount.minorUnits, credit.amount.minorUnits);
      expect(debit.amount.minorUnits, 5000000);
    });

    test('recognises neither expense nor income account', () async {
      // **The guarantee, stated as a test.** If a non-cash account ever became
      // transferable, this fails -- which is the point.
      expect(TransferCash.isCashAccount(ChartOfAccounts.bank), isTrue);
      expect(TransferCash.isCashAccount(ChartOfAccounts.cash), isTrue);
      expect(TransferCash.isCashAccount(ChartOfAccounts.officeRent), isFalse);
      expect(TransferCash.isCashAccount(ChartOfAccounts.salesRevenue), isFalse);
      expect(TransferCash.isCashAccount(ChartOfAccounts.payable), isFalse);
      expect(TransferCash.cashAccounts, hasLength(2));
    });
  });

  group('what it refuses', () {
    test('a destination that is not a cash account', () async {
      // **The mistake this use case exists to prevent.** Moving money to "Office
      // rent" is spending it, not transferring it, and on a two-box form the two
      // look identical.
      final outcome = await transfer(to: ChartOfAccounts.officeRent);

      expect(outcome, isA<TransferRefused>());
      expect(
        (outcome as TransferRefused).reason,
        TransferRefusal.notACashAccount,
      );
      // **Case-insensitive**, so this does not depend on how the account happens
      // to be capitalised -- a test that breaks on a rename tests nothing.
      expect(outcome.message.toLowerCase(), contains('office rent'));
      expect((await journal.all()), isEmpty,
          reason: 'a refused transfer must leave no trace at all');
    });

    test('a source that is not a cash account', () async {
      final outcome = await transfer(from: ChartOfAccounts.receivable);

      expect(outcome, isA<TransferRefused>());
      expect((await journal.all()), isEmpty);
    });

    test('the same account on both sides', () async {
      final outcome =
          await transfer(from: ChartOfAccounts.bank, to: ChartOfAccounts.bank);

      expect(
        (outcome as TransferRefused).reason,
        TransferRefusal.sameAccount,
      );
      expect((await journal.all()), isEmpty);
    });

    test('an amount of zero or less', () async {
      expect(
        ((await transfer(amount: 0)) as TransferRefused).reason,
        TransferRefusal.notPositive,
      );
      expect(
        ((await transfer(amount: -500)) as TransferRefused).reason,
        TransferRefusal.notPositive,
      );
      expect((await journal.all()), isEmpty);
    });

    test('a date outside the fiscal year, passed through from the engine',
        () async {
      // The engine owns the fiscal-year rule; this only checks the refusal is not
      // swallowed on the way through.
      final outcome = await transfer(date: DateTime(2024, 3, 10));

      expect(outcome, isA<TransferRefused>());
      expect(
        (outcome as TransferRefused).reason,
        TransferRefusal.rejected,
      );
      expect((await journal.all()), isEmpty);
    });
  });

  test('the default accounts are bank and cash', () {
    // The common case needs no choices made, and those choices are visible.
    expect(TransferCash.defaultFrom.id, ChartOfAccounts.bank.id);
    expect(TransferCash.defaultTo.id, ChartOfAccounts.cash.id);
  });
}
