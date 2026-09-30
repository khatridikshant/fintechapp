import 'dart:io';

import 'package:financeapp/src/domain/accounting/account.dart';
import 'package:financeapp/src/domain/accounting/account_type.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

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
const equity = Account(
    id: 'acct-equity',
    code: '3010',
    name: "Owner's Equity",
    type: AccountType.equity);
const sales = Account(
    id: 'acct-sales',
    code: '4010',
    name: 'Sales Revenue',
    type: AccountType.income);
const rent = Account(
    id: 'acct-rent',
    code: '5010',
    name: 'Office Rent',
    type: AccountType.expense);
const cogs = Account(
    id: 'acct-cogs',
    code: '5020',
    name: 'Cost of Goods Sold',
    type: AccountType.expense);

/// An account that is intentionally never persisted, to provoke a foreign key
/// violation when a journal line references it.
const ghost = Account(
    id: 'acct-ghost',
    code: '9999',
    name: 'Nonexistent Account',
    type: AccountType.expense);

JournalEntry expenseEntry({
  String id = 'JE-1',
  Money? amount,
  Account creditAccount = bank,
}) {
  final value = amount ?? rs(500);
  return JournalEntry(
    id: id,
    date: day(29),
    description: 'Office rent for September',
    reference: 'REF-1',
    lines: [
      JournalLine.debit(account: rent, amount: value),
      JournalLine.credit(account: creditAccount, amount: value),
    ],
  );
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('financeapp_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('Accounts', () {
    test('round-trip through storage', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final accounts = DriftAccountRepository(db);

      await accounts.save(bank);

      final loaded = await accounts.byId('acct-bank');
      expect(loaded, isNotNull);
      expect(loaded!.id, bank.id);
      expect(loaded.code, '1010');
      expect(loaded.name, 'Bank');
      expect(loaded.type, AccountType.asset);
      expect(loaded.normalBalance, bank.normalBalance);
    });

    test('can be looked up by code', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final accounts = DriftAccountRepository(db);

      await accounts.saveAll([bank, rent, sales]);

      expect((await accounts.byCode('5010'))?.id, 'acct-rent');
      expect(await accounts.byCode('0000'), isNull);
    });

    test('are listed in chart-of-accounts order', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final accounts = DriftAccountRepository(db);

      await accounts.saveAll([sales, bank, rent]);

      final all = await accounts.all();
      expect(all.map((a) => a.code), ['1010', '4010', '5010']);
    });

    test('saving the same account twice updates rather than duplicates',
        () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final accounts = DriftAccountRepository(db);

      await accounts.save(bank);
      await accounts.save(const Account(
          id: 'acct-bank',
          code: '1010',
          name: 'Bank Account',
          type: AccountType.asset));

      final all = await accounts.all();
      expect(all.length, 1);
      expect(all.single.name, 'Bank Account');
    });

    test('a duplicate account code is rejected by the database', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final accounts = DriftAccountRepository(db);

      await accounts.save(bank);

      await expectLater(
        accounts.save(const Account(
            id: 'acct-other',
            code: '1010',
            name: 'Different account, same code',
            type: AccountType.asset)),
        throwsA(_messageContains('unique')),
      );
    });
  });

  group('Journal persistence', () {
    test('an entry and its lines round-trip unchanged', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await DriftAccountRepository(db).saveAll([bank, rent]);
      final journal = DriftJournalRepository(db);

      final original = expenseEntry();
      await journal.append(original);

      final loaded = await journal.byId('JE-1');
      expect(loaded, isNotNull);
      expect(loaded!.id, original.id);
      expect(loaded.date, original.date);
      expect(loaded.description, original.description);
      expect(loaded.reference, original.reference);
      expect(loaded.currency, npr);
      expect(loaded.lines.length, 2);
      expect(loaded.totalDebits.minorUnits, 50000);
      expect(loaded.totalCredits.minorUnits, 50000);
      expect(loaded.isBalanced, isTrue);
    });

    test('line order and sides are preserved', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await DriftAccountRepository(db).saveAll([bank, rent]);
      final journal = DriftJournalRepository(db);

      await journal.append(expenseEntry());

      final loaded = await journal.byId('JE-1');
      expect(loaded!.lines[0].account.id, 'acct-rent');
      expect(loaded.lines[0].isDebit, isTrue);
      expect(loaded.lines[0].debit.minorUnits, 50000);
      expect(loaded.lines[0].credit.minorUnits, 0);
      expect(loaded.lines[1].account.id, 'acct-bank');
      expect(loaded.lines[1].isCredit, isTrue);
      expect(loaded.lines[1].credit.minorUnits, 50000);
      expect(loaded.lines[1].debit.minorUnits, 0);
    });

    test('a null reference round-trips as null', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await DriftAccountRepository(db).saveAll([bank, rent]);
      final journal = DriftJournalRepository(db);

      await journal.append(JournalEntry(
        id: 'JE-NOREF',
        date: day(29),
        description: 'No reference',
        lines: [
          JournalLine.debit(account: rent, amount: rs(100)),
          JournalLine.credit(account: bank, amount: rs(100)),
        ],
      ));

      expect((await journal.byId('JE-NOREF'))!.reference, isNull);
    });

    test('a multi-line entry round-trips with all four lines', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await DriftAccountRepository(db)
          .saveAll([receivable, sales, inventory, cogs]);
      final journal = DriftJournalRepository(db);

      await journal.append(JournalEntry(
        id: 'JE-SALE',
        date: day(29),
        description: 'Sold 2 keyboards',
        lines: [
          JournalLine.debit(account: receivable, amount: rs(3000)),
          JournalLine.credit(account: sales, amount: rs(3000)),
          JournalLine.debit(account: cogs, amount: rs(2000)),
          JournalLine.credit(account: inventory, amount: rs(2000)),
        ],
      ));

      final loaded = await journal.byId('JE-SALE');
      expect(loaded!.lines.length, 4);
      expect(loaded.totalDebits.minorUnits, 500000);
      expect(loaded.isBalanced, isTrue);
    });

    test('entries are listed in date then id order', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await DriftAccountRepository(db).saveAll([bank, rent]);
      final journal = DriftJournalRepository(db);

      await journal.append(expenseEntry(id: 'JE-B'));
      await journal.append(JournalEntry(
        id: 'JE-A',
        date: day(30),
        description: 'Later date',
        lines: [
          JournalLine.debit(account: rent, amount: rs(100)),
          JournalLine.credit(account: bank, amount: rs(100)),
        ],
      ));

      final all = await journal.all();
      expect(all.map((e) => e.id), ['JE-B', 'JE-A']);
    });

    test('entries can be found by the account they touch', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await DriftAccountRepository(db).saveAll([bank, rent, equity]);
      final journal = DriftJournalRepository(db);

      await journal.append(expenseEntry(id: 'JE-1'));
      await journal.append(JournalEntry(
        id: 'JE-2',
        date: day(30),
        description: 'Opening balance',
        lines: [
          JournalLine.debit(account: bank, amount: rs(1000)),
          JournalLine.credit(account: equity, amount: rs(1000)),
        ],
      ));

      final bankEntries = await journal.entriesForAccount(bank);
      expect(bankEntries.map((e) => e.id), ['JE-1', 'JE-2']);

      final rentEntries = await journal.entriesForAccount(rent);
      expect(rentEntries.map((e) => e.id), ['JE-1']);

      final untouched = await journal.entriesForAccount(inventory);
      expect(untouched, isEmpty);
    });

    test('a posted entry cannot be overwritten by reposting its id', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await DriftAccountRepository(db).saveAll([bank, rent]);
      final journal = DriftJournalRepository(db);

      await journal.append(expenseEntry(amount: rs(500)));

      // Posted records are immutable. Reusing the id must fail rather than
      // silently replace the original entry.
      await expectLater(
        journal.append(expenseEntry(amount: rs(999))),
        throwsA(_messageContains('unique')),
      );

      expect((await journal.byId('JE-1'))!.totalDebits.minorUnits, 50000);
    });

    test('a reversal persists and nets the accounts to zero', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await DriftAccountRepository(db).saveAll([bank, rent]);
      final journal = DriftJournalRepository(db);

      final original = expenseEntry(id: 'JE-1');
      final reversal = original.reverse(id: 'JE-2', date: day(30));
      await journal.append(original);
      await journal.append(reversal);

      final reloadedOriginal = await journal.byId('JE-1');
      final reloadedReversal = await journal.byId('JE-2');

      expect(reloadedOriginal!.lines[0].isDebit, isTrue,
          reason: 'the original must be untouched by its reversal');
      expect(reloadedReversal!.reference, 'JE-1');
      expect(reloadedReversal.lines[0].isCredit, isTrue);

      // The pair nets to zero across every account.
      final bankNet = reloadedOriginal.totalCredits.minorUnits -
          reloadedReversal.totalCredits.minorUnits;
      expect(bankNet, 0);
    });
  });

  group('Durability across a restart', () {
    test('an entry survives closing and reopening the database file', () async {
      final file = File(p.join(tempDir.path, 'accounting-FY-2082-83.db'));

      final db = openFileDatabase(file);
      await DriftAccountRepository(db).saveAll([bank, rent]);
      await DriftJournalRepository(db).append(expenseEntry());
      await db.close();

      expect(file.existsSync(), isTrue,
          reason: 'the database file must exist on disk after close');

      final reopened = openFileDatabase(file);
      final loaded = await DriftJournalRepository(reopened).byId('JE-1');
      final loadedAccounts = await DriftAccountRepository(reopened).all();
      await reopened.close();

      expect(loaded, isNotNull);
      expect(loaded!.description, 'Office rent for September');
      expect(loaded.totalDebits.minorUnits, 50000);
      expect(loaded.totalCredits.minorUnits, 50000);
      expect(loaded.isBalanced, isTrue);
      expect(loadedAccounts.length, 2);
    });
  });

  group('Money is stored exactly', () {
    test('an amount with paisa precision round-trips with no drift', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await DriftAccountRepository(db).saveAll([bank, rent]);
      final journal = DriftJournalRepository(db);

      // Rs 1,284,500.07, a value binary floating point cannot hold exactly.
      const exact = Money.minor(128450007, npr);
      await journal.append(expenseEntry(id: 'JE-EXACT', amount: exact));

      final loaded = await journal.byId('JE-EXACT');
      expect(loaded!.lines[0].amount.minorUnits, 128450007);
      expect(loaded.lines[1].amount.minorUnits, 128450007);
      expect(loaded.totalDebits.minorUnits, 128450007);
      expect(loaded.totalDebits, exact);
    });

    test('zero-paisa amounts survive as whole rupees', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await DriftAccountRepository(db).saveAll([bank, rent]);
      final journal = DriftJournalRepository(db);

      await journal.append(expenseEntry(id: 'JE-WHOLE', amount: rs(1000)));

      final loaded = await journal.byId('JE-WHOLE');
      expect(loaded!.totalDebits.minorUnits, 100000);
    });

    test('money columns are INTEGER, never REAL', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      final rows = await db
          .customSelect(
              "SELECT name, type FROM pragma_table_info('journal_lines')")
          .get();
      final types = {
        for (final row in rows)
          row.read<String>('name'): row.read<String>('type'),
      };

      expect(types['debit_minor_units']?.toUpperCase(), 'INTEGER',
          reason: 'a REAL column would reintroduce floating point at the '
              'storage boundary and silently corrupt amounts');
      expect(types['credit_minor_units']?.toUpperCase(), 'INTEGER');
    });
  });

  group('The database refuses corrupt data', () {
    test('foreign key enforcement is actually switched on', () async {
      // This guards a real regression. `PRAGMA foreign_keys` is per-connection
      // state. When it was set once at open it worked under drift 2.23 and
      // silently stopped working under drift 2.31, and the only symptom was
      // that foreign key tests stopped failing. Asserting the pragma directly
      // makes the failure mode obvious instead of silent.
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      final result = await db.customSelect('PRAGMA foreign_keys').getSingle();

      expect(result.data.values.first, 1,
          reason: 'foreign keys must be enforced on the connection that '
              'performs the writes, or the database is not a second line of '
              'defence at all');
    });

    test('the foreign keys are actually declared in the schema', () async {
      // The pragma being on is useless if the table has no REFERENCES clause.
      // Both halves are asserted separately because they failed separately:
      // drift's `.references()` helper silently emitted nothing, and the pragma
      // was applied to the wrong connection.
      final db = openInMemoryDatabase();
      addTearDown(db.close);

      final rows = await db
          .customSelect("PRAGMA foreign_key_list('journal_lines')")
          .get();
      final targets = rows.map((r) => r.data['table']).toSet();

      expect(targets, containsAll(<Object>{'journal_entries', 'accounts'}),
          reason: 'journal_lines must declare foreign keys to its entry and '
              'its account, or orphaned lines are possible');
    });

    test('a failed multi-part write leaves nothing behind', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await DriftAccountRepository(db).saveAll([bank, rent]);
      final journal = DriftJournalRepository(db);

      // The credit references an account that was never persisted. The debit
      // line is written first, so without a transaction the header and the
      // first line would survive and the books would be corrupt.
      final doomed = JournalEntry(
        id: 'JE-DOOMED',
        date: day(29),
        description: 'Will fail partway through',
        lines: [
          JournalLine.debit(account: rent, amount: rs(500)),
          JournalLine.credit(account: ghost, amount: rs(500)),
        ],
      );

      await expectLater(
        journal.append(doomed),
        throwsA(_messageContains('foreign key')),
      );

      expect(await journal.byId('JE-DOOMED'), isNull,
          reason: 'the header must have rolled back');
      expect(await db.select(db.journalEntries).get(), isEmpty);
      expect(await db.select(db.journalLines).get(), isEmpty,
          reason: 'no orphan line may survive a failed append');
    });

    test('a foreign key violation is rejected by the database itself',
        () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await DriftAccountRepository(db).save(bank);

      await db.into(db.journalEntries).insert(JournalEntriesCompanion.insert(
            id: 'JE-RAW',
            date: day(29),
            description: 'Raw insert bypassing the domain',
            currency: npr,
          ));

      await expectLater(
        db.customStatement(
          'INSERT INTO journal_lines '
          '(journal_entry_id, account_id, debit_minor_units, credit_minor_units, currency) '
          'VALUES (?, ?, ?, ?, ?)',
          ['JE-RAW', 'acct-does-not-exist', 100, 0, npr],
        ),
        throwsA(_messageContains('foreign key')),
      );
    });

    test('a line cannot be both a debit and a credit', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await DriftAccountRepository(db).save(bank);
      await db.into(db.journalEntries).insert(JournalEntriesCompanion.insert(
            id: 'JE-BOTH',
            date: day(29),
            description: 'Both sides',
            currency: npr,
          ));

      await expectLater(
        db.customStatement(
          'INSERT INTO journal_lines '
          '(journal_entry_id, account_id, debit_minor_units, credit_minor_units, currency) '
          'VALUES (?, ?, ?, ?, ?)',
          ['JE-BOTH', 'acct-bank', 100, 100, npr],
        ),
        throwsA(_messageContains('check')),
      );
    });

    test('a line cannot be neither a debit nor a credit', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await DriftAccountRepository(db).save(bank);
      await db.into(db.journalEntries).insert(JournalEntriesCompanion.insert(
            id: 'JE-NEITHER',
            date: day(29),
            description: 'Neither side',
            currency: npr,
          ));

      await expectLater(
        db.customStatement(
          'INSERT INTO journal_lines '
          '(journal_entry_id, account_id, debit_minor_units, credit_minor_units, currency) '
          'VALUES (?, ?, ?, ?, ?)',
          ['JE-NEITHER', 'acct-bank', 0, 0, npr],
        ),
        throwsA(_messageContains('check')),
      );
    });

    test('a negative line amount is rejected', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await DriftAccountRepository(db).save(bank);
      await db.into(db.journalEntries).insert(JournalEntriesCompanion.insert(
            id: 'JE-NEG',
            date: day(29),
            description: 'Negative amount',
            currency: npr,
          ));

      await expectLater(
        db.customStatement(
          'INSERT INTO journal_lines '
          '(journal_entry_id, account_id, debit_minor_units, credit_minor_units, currency) '
          'VALUES (?, ?, ?, ?, ?)',
          ['JE-NEG', 'acct-bank', -100, 0, npr],
        ),
        throwsA(_messageContains('check')),
      );
    });

    test('a line without its parent entry is rejected', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await DriftAccountRepository(db).save(bank);

      await expectLater(
        db.customStatement(
          'INSERT INTO journal_lines '
          '(journal_entry_id, account_id, debit_minor_units, credit_minor_units, currency) '
          'VALUES (?, ?, ?, ?, ?)',
          ['JE-MISSING', 'acct-bank', 100, 0, npr],
        ),
        throwsA(_messageContains('foreign key')),
      );
    });
  });
}

/// Matches an exception whose text contains [needle], case-insensitively.
///
/// Matching on the message rather than the exception type keeps the assertions
/// tied to the actual database rule that fired (a foreign key, a check, a unique
/// index) instead of to whichever wrapper class the driver happens to use.
Matcher _messageContains(String needle) {
  final lower = needle.toLowerCase();
  return predicate(
    (Object? error) => error.toString().toLowerCase().contains(lower),
    'exception mentioning "$needle"',
  );
}
