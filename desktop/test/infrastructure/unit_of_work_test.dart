import 'package:financeapp/src/domain/accounting/account.dart';
import 'package:financeapp/src/domain/accounting/account_type.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_unit_of_work.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';

const npr = 'NPR';

Money rs(int majorUnits) => Money.minor(majorUnits * 100, npr);

DateTime day(int d) => DateTime(2026, 9, d);

const bank = Account(
    id: 'acct-bank', code: '1010', name: 'Bank', type: AccountType.asset);
const receivable = Account(
    id: 'acct-ar',
    code: '1030',
    name: 'Accounts Receivable',
    type: AccountType.asset);
const inventory = Account(
    id: 'acct-inv', code: '1040', name: 'Inventory', type: AccountType.asset);
const sales = Account(
    id: 'acct-sales',
    code: '4010',
    name: 'Sales Revenue',
    type: AccountType.income);
const cogs = Account(
    id: 'acct-cogs',
    code: '5020',
    name: 'Cost of Goods Sold',
    type: AccountType.expense);
const rent = Account(
    id: 'acct-rent',
    code: '5010',
    name: 'Office Rent',
    type: AccountType.expense);

/// Never persisted, so any line referencing it violates a foreign key.
const ghost = Account(
    id: 'acct-ghost',
    code: '9999',
    name: 'Nonexistent Account',
    type: AccountType.expense);

JournalEntry revenueEntry({String id = 'JE-REV'}) => JournalEntry(
      id: id,
      date: day(29),
      description: 'Invoice INV-1042',
      reference: 'INV-1042',
      lines: [
        JournalLine.debit(account: receivable, amount: rs(3000)),
        JournalLine.credit(account: sales, amount: rs(3000)),
      ],
    );

JournalEntry cogsEntry({String id = 'JE-COGS', Account credit = inventory}) =>
    JournalEntry(
      id: id,
      date: day(29),
      description: 'Cost of goods sold for INV-1042',
      reference: 'INV-1042',
      lines: [
        JournalLine.debit(account: cogs, amount: rs(2000)),
        JournalLine.credit(account: credit, amount: rs(2000)),
      ],
    );

void main() {
  group('UnitOfWork', () {
    test('commits every part of a successful business operation', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final accounts = DriftAccountRepository(db);
      final journal = DriftJournalRepository(db);
      final unitOfWork = DriftUnitOfWork(db);

      await accounts.saveAll([receivable, sales, inventory, cogs]);

      await unitOfWork.run(() async {
        await journal.append(revenueEntry());
        await journal.append(cogsEntry());
      });

      final loaded = await journal.all();
      // Ordering is by date then id, and both entries share a date, so this
      // asserts membership rather than an order it does not care about.
      expect(loaded.map((e) => e.id),
          unorderedEquals(<String>['JE-REV', 'JE-COGS']));
      expect(loaded.every((e) => e.isBalanced), isTrue);
    });

    test('rolls back every repository when the operation fails partway',
        () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final accounts = DriftAccountRepository(db);
      final journal = DriftJournalRepository(db);
      final unitOfWork = DriftUnitOfWork(db);

      await accounts.saveAll([receivable, sales, inventory, cogs]);

      // The revenue entry is written first and succeeds on its own. The COGS
      // entry then fails. Without a shared transaction the revenue entry and
      // its lines would survive, leaving an invoice recorded with revenue but
      // no cost of sale, and the profit for the period would be overstated.
      await expectLater(
        unitOfWork.run(() async {
          await journal.append(revenueEntry());
          await journal.append(cogsEntry(credit: ghost));
        }),
        throwsA(anything),
      );

      expect(await journal.byId('JE-REV'), isNull,
          reason: 'the revenue entry must roll back with the failed operation');
      expect(await journal.byId('JE-COGS'), isNull);
      expect(await db.select(db.journalEntries).get(), isEmpty,
          reason: 'no entry header may survive');
      expect(await db.select(db.journalLines).get(), isEmpty,
          reason: 'no journal line may survive a rolled-back operation');
    });

    test('rolls back account writes as well as journal writes', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final accounts = DriftAccountRepository(db);
      final journal = DriftJournalRepository(db);
      final unitOfWork = DriftUnitOfWork(db);

      await accounts.saveAll([receivable, sales, inventory, cogs]);

      await expectLater(
        unitOfWork.run(() async {
          // A new account is created as part of the same operation.
          await accounts.save(rent);
          await journal.append(revenueEntry());
          await journal.append(cogsEntry(credit: ghost));
        }),
        throwsA(anything),
      );

      expect(await accounts.byId('acct-rent'), isNull,
          reason: 'an account created inside the failed operation must not '
              'survive either');
      expect((await accounts.all()).length, 4);
    });

    test('a repository opening its own transaction joins the outer one',
        () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final accounts = DriftAccountRepository(db);
      final journal = DriftJournalRepository(db);
      final unitOfWork = DriftUnitOfWork(db);

      await accounts.saveAll([receivable, sales, inventory, cogs]);

      // JournalRepository.append wraps itself in a transaction. Inside a unit
      // of work that inner transaction must compose with the outer one rather
      // than committing independently, otherwise rollback would be incomplete.
      await expectLater(
        unitOfWork.run(() async {
          await journal.append(revenueEntry());
          throw StateError(
              'the operation failed after the journal was written');
        }),
        throwsStateError,
      );

      expect(await journal.byId('JE-REV'), isNull,
          reason: "the repository's own transaction must not have committed");
    });

    test('nested units of work join the outer transaction', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final accounts = DriftAccountRepository(db);
      final journal = DriftJournalRepository(db);
      final unitOfWork = DriftUnitOfWork(db);

      await accounts.saveAll([receivable, sales, inventory, cogs]);

      // A use case calling another use case that also opens a unit of work must
      // still be all-or-nothing at the outer boundary.
      await expectLater(
        unitOfWork.run(() async {
          await unitOfWork.run(() async {
            await journal.append(revenueEntry());
          });
          throw StateError('the outer operation failed');
        }),
        throwsStateError,
      );

      expect(await journal.byId('JE-REV'), isNull,
          reason: 'the inner unit of work must not have committed on its own');
    });

    test('a successful nested unit of work commits with its parent', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final accounts = DriftAccountRepository(db);
      final journal = DriftJournalRepository(db);
      final unitOfWork = DriftUnitOfWork(db);

      await accounts.saveAll([receivable, sales, inventory, cogs]);

      await unitOfWork.run(() async {
        await journal.append(revenueEntry());
        await unitOfWork.run(() async {
          await journal.append(cogsEntry());
        });
      });

      expect((await journal.all()).length, 2);
    });

    test('the error from a failed operation reaches the caller', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final unitOfWork = DriftUnitOfWork(db);

      await expectLater(
        unitOfWork.run<void>(() async => throw const FormatException('boom')),
        throwsA(isA<FormatException>()),
        reason: 'a unit of work must not swallow the reason it failed',
      );
    });

    test('a failure the domain refuses still rolls back cleanly', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final accounts = DriftAccountRepository(db);
      final journal = DriftJournalRepository(db);
      final unitOfWork = DriftUnitOfWork(db);

      await accounts.saveAll([receivable, sales]);

      // The second entry is unbalanced, so it cannot even be constructed. The
      // first entry must not survive the attempt.
      await expectLater(
        unitOfWork.run(() async {
          await journal.append(revenueEntry(id: 'JE-OK'));
          throw UnbalancedJournalException(rs(500), rs(400));
        }),
        throwsA(isA<UnbalancedJournalException>()),
      );

      expect(await journal.byId('JE-OK'), isNull);
    });

    test('a committed operation is visible after reopening the database',
        () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final accounts = DriftAccountRepository(db);
      final journal = DriftJournalRepository(db);
      final unitOfWork = DriftUnitOfWork(db);

      await accounts.saveAll([receivable, sales]);

      await unitOfWork.run(() async {
        await journal.append(revenueEntry());
      });

      // Reading through a fresh repository instance sees the committed data.
      expect(await DriftJournalRepository(db).byId('JE-REV'), isNotNull);
    });
  });
}
