import 'dart:io';

import 'package:financeapp/src/domain/accounting/account_type.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/reporting/trial_balance.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const npr = 'NPR';
const chart = ChartOfAccounts();

Money rs(int majorUnits) => Money.minor(majorUnits * 100, npr);

DateTime day(int d) => DateTime(2026, 9, d);

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('financeapp_chart_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('Chart persistence', () {
    test('the whole chart round-trips with ids, codes, and types intact',
        () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final accounts = DriftAccountRepository(db);

      await accounts.saveAll(chart.all);
      final reloaded = await accounts.all();

      expect(reloaded.length, chart.all.length);

      final original = {for (final a in chart.all) a.id: a};
      for (final account in reloaded) {
        final source = original[account.id];
        expect(source, isNotNull,
            reason: 'reloaded account ${account.id} was not in the chart');
        expect(account.code, source!.code);
        expect(account.name, source.name);
        expect(account.type, source.type,
            reason: 'account type was corrupted in storage, which would make '
                'the account report the wrong normal balance');
      }
    });

    test('reloading preserves the code order of the chart', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final accounts = DriftAccountRepository(db);

      await accounts.saveAll(chart.all);
      final reloaded = await accounts.all();

      expect(
        reloaded.map((a) => a.code),
        chart.all.map((a) => a.code),
      );
    });

    test('every reloaded account still resolves by code and by id', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final accounts = DriftAccountRepository(db);

      await accounts.saveAll(chart.all);

      expect((await accounts.byCode('1010'))?.id, 'acct-bank');
      expect((await accounts.byId('acct-cost-of-goods-sold'))?.code, '5020');
    });
  });

  group('Posting against persisted accounts', () {
    test('a complete cycle posts against reloaded accounts', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final accounts = DriftAccountRepository(db);
      final journal = DriftJournalRepository(db);

      await accounts.saveAll(chart.all);
      final reloaded = await accounts.all();
      final byCode = {for (final a in reloaded) a.code: a};

      // The accounts used here came out of the database, not from the constant
      // chart. This is what proves the permanent ids and the foreign keys line
      // up: a posting to an id that did not round-trip would be rejected.
      await journal.append(JournalEntry(
        id: 'OB-1',
        date: day(1),
        description: 'Opening balance',
        lines: [
          JournalLine.debit(account: byCode['1010']!, amount: rs(100000)),
          JournalLine.credit(account: byCode['3010']!, amount: rs(100000)),
        ],
      ));
      await journal.append(JournalEntry(
        id: 'SA-1',
        date: day(3),
        description: 'Sale with cost of goods sold',
        lines: [
          JournalLine.debit(account: byCode['1010']!, amount: rs(20000)),
          JournalLine.credit(account: byCode['4010']!, amount: rs(20000)),
          JournalLine.debit(account: byCode['5020']!, amount: rs(12000)),
          JournalLine.credit(account: byCode['1040']!, amount: rs(12000)),
        ],
      ));

      final report = TrialBalance.from(
        entries: await journal.all(),
        currency: npr,
      );
      final balances = {for (final row in report.rows) row.account.code: row};

      expect(report.isBalanced, isTrue);
      expect(balances['1010']!.balance.minorUnits, 12000000);
      expect(balances['1040']!.balance.minorUnits, -1200000,
          reason: 'the sale credited inventory that had never been purchased');
      expect(balances['4010']!.balance.minorUnits, 2000000);
      expect(balances['5020']!.balance.minorUnits, 1200000);
    });

    test('the chart survives closing and reopening the database', () async {
      final file = File(p.join(tempDir.path, 'accounting-FY-2082-83.db'));

      final db = openFileDatabase(file);
      await DriftAccountRepository(db).saveAll(chart.all);
      await db.close();

      final reopened = openFileDatabase(file);
      final reloaded = await DriftAccountRepository(reopened).all();
      await reopened.close();

      expect(reloaded.length, chart.all.length);
      expect(reloaded.map((a) => a.id).toSet(),
          chart.all.map((a) => a.id).toSet());
    });

    test('saving the chart twice does not duplicate it', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final accounts = DriftAccountRepository(db);

      await accounts.saveAll(chart.all);
      await accounts.saveAll(chart.all);

      final reloaded = await accounts.all();
      expect(reloaded.length, chart.all.length,
          reason: 'seeding must be idempotent, or a second run would fail on '
              'the unique account code');
    });
  });

  group('Chart types survive storage', () {
    test('normal balances are unchanged after a round trip', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final accounts = DriftAccountRepository(db);

      await accounts.saveAll(chart.all);
      final reloaded = {for (final a in await accounts.all()) a.id: a};

      for (final account in chart.all) {
        expect(reloaded[account.id]!.normalBalance, account.normalBalance,
            reason: '${account.name} changed normal balance in storage');
      }
      expect(
        reloaded['acct-bank']!.type,
        AccountType.asset,
      );
      expect(
        reloaded['acct-sales-revenue']!.type,
        AccountType.income,
      );
    });
  });
}
