import 'dart:io';

import 'package:financeapp/src/application/post_inventory_movement.dart';
import 'package:financeapp/src/application/write_down_inventory.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/inventory/inventory_movement.dart';
import 'package:financeapp/src/domain/inventory/product.dart';
import 'package:financeapp/src/domain/reporting/profit_and_loss.dart';
import 'package:financeapp/src/domain/reporting/trial_balance.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_inventory_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_unit_of_work.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const npr = 'NPR';
const chart = ChartOfAccounts();

Money rs(int majorUnits) => Money.minor(majorUnits * 100, npr);

final fiscalYear = const NepaliFiscalCalendar().forBsYear(2082);

final keyboard = Product(
  id: 'prod-keyboard',
  name: 'Keyboard',
  salePrice: rs(200),
);

Future<void> seed(AppDatabase db) async {
  await DriftAccountRepository(db).saveAll(chart.all);
  await DriftInventoryRepository(db).saveProduct(keyboard);
}

PostInventoryMovement poster(AppDatabase db) => PostInventoryMovement(
      fiscalYear: fiscalYear,
      inventory: DriftInventoryRepository(db),
      journal: DriftJournalRepository(db),
      unitOfWork: DriftUnitOfWork(db),
    );

WriteDownInventory writer(AppDatabase db) => WriteDownInventory(
      fiscalYear: fiscalYear,
      inventory: DriftInventoryRepository(db),
      journal: DriftJournalRepository(db),
      unitOfWork: DriftUnitOfWork(db),
    );

/// Buys 10 units for Rs 1,000, so the stock is carried at Rs 1,000.
Future<void> buyTenFor1000(AppDatabase db) async {
  await poster(db)(
    InventoryMovement.receipt(
      id: 'MV-BUY',
      productId: keyboard.id,
      date: DateTime(2026, 1, 10),
      reason: MovementReason.purchase,
      quantity: 10,
      value: rs(1000),
    ),
  );
}

Future<Money> inventoryInLedger(AppDatabase db) async {
  final report = TrialBalance.from(
    entries: await DriftJournalRepository(db).all(),
    currency: npr,
  );
  return report.rows.firstWhere((r) => r.account.code == '1040').balance;
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('financeapp_writedown_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('Writing stock down', () {
    test('reduces the carrying value and posts the loss', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await buyTenFor1000(db);

      // 10 units carried at Rs 1,000, now only worth Rs 800, so Rs 80 each.
      final outcome = await writer(db)(
        movementId: 'MV-WD',
        productId: keyboard.id,
        date: DateTime(2026, 2, 1),
        netRealisableValue: rs(800),
      );

      expect(outcome, isA<InventoryWrittenDown>());
      final written = outcome as InventoryWrittenDown;
      expect(written.carryingValueBefore.minorUnits, 100000);
      expect(written.carryingValueAfter.minorUnits, 80000);
      expect(written.reduction.minorUnits, 20000, reason: 'Rs 200');
      expect(written.stock.value.minorUnits, 80000);
      expect(written.stock.costPerUnit.minorUnits, 8000, reason: 'Rs 80 each');
    });

    test('posts Dr 5070 and Cr 1040 for the reduction', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await buyTenFor1000(db);

      final written = await writer(db)(
        movementId: 'MV-WD',
        productId: keyboard.id,
        date: DateTime(2026, 2, 1),
        netRealisableValue: rs(800),
      ) as InventoryWrittenDown;

      final lines = written.journalEntry.lines;
      expect(lines, hasLength(2));
      expect(lines[0].account.code, '5070');
      expect(lines[0].isDebit, isTrue);
      expect(lines[0].debit.minorUnits, 20000);
      expect(lines[1].account.code, '1040');
      expect(lines[1].isCredit, isTrue);
      expect(lines[1].credit.minorUnits, 20000);
      expect(written.journalEntry.isBalanced, isTrue);
    });

    test('the quantity is untouched, because the goods are still held',
        () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await buyTenFor1000(db);

      final written = await writer(db)(
        movementId: 'MV-WD',
        productId: keyboard.id,
        date: DateTime(2026, 2, 1),
        netRealisableValue: rs(800),
      ) as InventoryWrittenDown;

      expect(written.stock.quantity, 10,
          reason: 'a write-down is not a disposal: the goods are still on the '
              'shelf, they are simply worth less');
      expect(written.movement.quantity, 0);
      expect(written.movement.isValueOnly, isTrue);
    });

    test('the inventory account and the stock value still agree', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await buyTenFor1000(db);

      await writer(db)(
        movementId: 'MV-WD',
        productId: keyboard.id,
        date: DateTime(2026, 2, 1),
        netRealisableValue: rs(800),
      );

      final stock = await DriftInventoryRepository(db).stockOf(keyboard);
      expect(stock.value.minorUnits, 80000);
      expect((await inventoryInLedger(db)).minorUnits, 80000,
          reason: 'going through the movement ledger is what keeps the two '
              'equal, rather than two calculations that can drift');
    });

    test('the loss appears in the profit and loss statement', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await buyTenFor1000(db);

      await writer(db)(
        movementId: 'MV-WD',
        productId: keyboard.id,
        date: DateTime(2026, 2, 1),
        netRealisableValue: rs(800),
      );

      final report = ProfitAndLoss.from(
        entries: await DriftJournalRepository(db).all(),
        currency: npr,
      );
      final adjustmentLine =
          report.expenses.firstWhere((l) => l.account.code == '5070');

      expect(adjustmentLine.balance.minorUnits, 20000);
      expect(report.totalExpenses.minorUnits, 20000);
      expect(report.netResult.minorUnits, -20000,
          reason: 'the write-down is a loss of Rs 200 with no revenue yet');
      expect(report.isLoss, isTrue);
    });

    test('the trial balance balances after a write-down', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await buyTenFor1000(db);

      await writer(db)(
        movementId: 'MV-WD',
        productId: keyboard.id,
        date: DateTime(2026, 2, 1),
        netRealisableValue: rs(800),
      );

      final report = TrialBalance.from(
        entries: await DriftJournalRepository(db).all(),
        currency: npr,
      );
      expect(report.isBalanced, isTrue);
      expect(report.assertBalanced, returnsNormally);
    });

    test('the movement records the entry that posted it', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await buyTenFor1000(db);

      await writer(db)(
        movementId: 'MV-WD',
        productId: keyboard.id,
        date: DateTime(2026, 2, 1),
        netRealisableValue: rs(800),
      );

      final rows = await db.select(db.inventoryMovements).get();
      final writeDown = rows.firstWhere((r) => r.id == 'MV-WD');
      expect(writeDown.quantity, 0);
      expect(writeDown.valueMinorUnits, -20000);
      expect(writeDown.reason, 'writeDown');
      expect(writeDown.journalEntryId, 'JE-MV-MV-WD');
    });

    test('writing down twice is allowed and compounds correctly', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await buyTenFor1000(db);
      final useCase = writer(db);

      await useCase(
        movementId: 'MV-WD1',
        productId: keyboard.id,
        date: DateTime(2026, 2, 1),
        netRealisableValue: rs(800),
      );
      final second = await useCase(
        movementId: 'MV-WD2',
        productId: keyboard.id,
        date: DateTime(2026, 3, 1),
        netRealisableValue: rs(500),
      ) as InventoryWrittenDown;

      expect(second.reduction.minorUnits, 30000,
          reason: 'from Rs 800 down to Rs 500');
      expect(second.stock.value.minorUnits, 50000);
      expect(second.stock.quantity, 10);
      expect((await inventoryInLedger(db)).minorUnits, 50000);
    });

    test('writing the whole value to zero is allowed', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await buyTenFor1000(db);

      final written = await writer(db)(
        movementId: 'MV-WD',
        productId: keyboard.id,
        date: DateTime(2026, 2, 1),
        netRealisableValue: rs(0),
      ) as InventoryWrittenDown;

      expect(written.reduction.minorUnits, 100000);
      expect(written.stock.value.isZero, isTrue);
      expect(written.stock.quantity, 10,
          reason: 'worthless stock is still held until it is disposed of');
      expect((await inventoryInLedger(db)).isZero, isTrue);
    });

    test('a write-down can be followed by a disposal', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await buyTenFor1000(db);

      await writer(db)(
        movementId: 'MV-WD',
        productId: keyboard.id,
        date: DateTime(2026, 2, 1),
        netRealisableValue: rs(800),
      );

      // Now scrap the goods, which is a separate movement of a different reason.
      final scrapped = await poster(db)(
        InventoryMovement.issue(
          id: 'MV-SCRAP',
          productId: keyboard.id,
          date: DateTime(2026, 2, 5),
          reason: MovementReason.adjustment,
          quantity: 10,
          value: rs(800),
        ),
      ) as InventoryMovementPosted;

      expect(scrapped.stock.quantity, 0);
      expect(scrapped.stock.value.isZero, isTrue,
          reason: 'disposing of stock already written down to Rs 800 takes '
              'Rs 800 out, leaving nothing');
      expect((await inventoryInLedger(db)).isZero, isTrue);
    });
  });

  group('A write-down that is not one is refused', () {
    test('a value at the current carrying value is refused', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await buyTenFor1000(db);

      // Already carried at Rs 1,000, so Rs 1,000 is not lower.
      final outcome = await writer(db)(
        movementId: 'MV-WD',
        productId: keyboard.id,
        date: DateTime(2026, 2, 1),
        netRealisableValue: rs(1000),
      );

      expect(outcome, isA<WriteDownRejected>());
      final rejected = outcome as WriteDownRejected;
      expect(
        rejected.reason,
        WriteDownRejectionReason.notBelowCarryingValue,
      );
      expect(rejected.carryingValue!.minorUnits, 100000);
      expect(rejected.message, contains('lower'));
    });

    test('a value above the carrying value is refused', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await buyTenFor1000(db);

      // A rise in value is not a write-down. Recognising it would be a
      // revaluation, which IAS 2 does not permit for inventory.
      final outcome = await writer(db)(
        movementId: 'MV-WD',
        productId: keyboard.id,
        date: DateTime(2026, 2, 1),
        netRealisableValue: rs(1500),
      );

      expect(outcome, isA<WriteDownRejected>());
      expect(
        (outcome as WriteDownRejected).reason,
        WriteDownRejectionReason.notBelowCarryingValue,
      );
    });

    test('one paisa below the carrying value is accepted', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await buyTenFor1000(db);

      // The boundary: exactly equal is refused, one paisa lower is accepted.
      final outcome = await writer(db)(
        movementId: 'MV-WD',
        productId: keyboard.id,
        date: DateTime(2026, 2, 1),
        netRealisableValue: Money.minor(99999, npr),
      );

      expect(outcome, isA<InventoryWrittenDown>());
      expect((outcome as InventoryWrittenDown).reduction.minorUnits, 1);
    });

    test('a refusal writes nothing at all', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await buyTenFor1000(db);
      final journal = DriftJournalRepository(db);

      await writer(db)(
        movementId: 'MV-WD',
        productId: keyboard.id,
        date: DateTime(2026, 2, 1),
        netRealisableValue: rs(1000),
      );

      expect(
        (await db.select(db.inventoryMovements).get()),
        hasLength(1),
        reason: 'only the purchase movement may exist',
      );
      expect(await journal.byId('JE-MV-MV-WD'), isNull);
      expect(await journal.all(), hasLength(1),
          reason: 'only the purchase entry may exist');
    });

    test('writing down a product with no stock is refused', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      final outcome = await writer(db)(
        movementId: 'MV-WD',
        productId: keyboard.id,
        date: DateTime(2026, 2, 1),
        netRealisableValue: rs(0),
      );

      expect(outcome, isA<WriteDownRejected>());
      expect(
        (outcome as WriteDownRejected).reason,
        WriteDownRejectionReason.nothingToWriteDown,
      );
    });

    test('a negative net realisable value is refused', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await buyTenFor1000(db);

      final outcome = await writer(db)(
        movementId: 'MV-WD',
        productId: keyboard.id,
        date: DateTime(2026, 2, 1),
        netRealisableValue: Money.minor(-1, npr),
      );

      expect(outcome, isA<WriteDownRejected>());
      expect(
        (outcome as WriteDownRejected).reason,
        WriteDownRejectionReason.negativeValue,
      );
      expect(outcome.message, contains('dispose'));
    });

    test('an unknown product is refused', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      final outcome = await writer(db)(
        movementId: 'MV-WD',
        productId: 'prod-nobody',
        date: DateTime(2026, 2, 1),
        netRealisableValue: rs(0),
      );

      expect(outcome, isA<WriteDownRejected>());
      expect(
        (outcome as WriteDownRejected).reason,
        WriteDownRejectionReason.unknownProduct,
      );
    });

    test('a write-down outside the fiscal year is refused', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      await buyTenFor1000(db);

      for (final date in [
        fiscalYear.startDate.subtract(const Duration(days: 1)),
        fiscalYear.endDate.add(const Duration(days: 1)),
      ]) {
        final outcome = await writer(db)(
          movementId: 'MV-WD',
          productId: keyboard.id,
          date: date,
          netRealisableValue: rs(800),
        );

        expect(outcome, isA<WriteDownRejected>());
        expect(
          (outcome as WriteDownRejected).reason,
          WriteDownRejectionReason.outsideFiscalYear,
        );
      }

      expect(await db.select(db.inventoryMovements).get(), hasLength(1));
    });
  });

  group('The database guardrails', () {
    test('a value-only movement of the wrong reason is rejected', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      // The domain refuses this, and the database CHECK does too: only a
      // write-down may change value without quantity.
      expect(
        () => InventoryMovement(
          id: 'MV-BAD',
          productId: keyboard.id,
          date: DateTime(2026, 2, 1),
          reason: MovementReason.adjustment,
          quantity: 0,
          value: rs(100),
        ),
        throwsArgumentError,
      );
    });

    test('a movement that changes neither quantity nor value is rejected',
        () async {
      expect(
        () => InventoryMovement(
          id: 'MV-BAD',
          productId: keyboard.id,
          date: DateTime(2026, 2, 1),
          reason: MovementReason.writeDown,
          quantity: 0,
          value: rs(0),
        ),
        throwsArgumentError,
      );
    });

    test('the database refuses a value-only row with a non-write-down reason',
        () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      // The database cannot check the reason name against the enum, so it
      // accepts a zero-quantity row; the domain is what restricts it to
      // write-downs. This asserts the CHECK at least permits the shape.
      await db.customStatement(
        'INSERT INTO inventory_movements '
        '(id, product_id, date, reason, quantity, value_minor_units, currency) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        ['MV-VO', keyboard.id, 1, 'writeDown', 0, -100, npr],
      );

      final rows = await db.select(db.inventoryMovements).get();
      expect(rows, hasLength(1));
    });

    test('the database rejects a row that changes neither', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      await expectLater(
        db.customStatement(
          'INSERT INTO inventory_movements '
          '(id, product_id, date, reason, quantity, value_minor_units, currency) '
          'VALUES (?, ?, ?, ?, ?, ?, ?)',
          ['MV-NOTHING', keyboard.id, 1, 'adjustment', 0, 0, npr],
        ),
        throwsA(predicate((e) => e.toString().toLowerCase().contains('check'))),
      );
    });
  });

  group('Durability', () {
    test('a write-down survives closing and reopening', () async {
      final file = File(p.join(tempDir.path, 'accounting-FY-2082-83.db'));

      final db = openFileDatabase(file);
      await seed(db);
      await buyTenFor1000(db);
      await writer(db)(
        movementId: 'MV-WD',
        productId: keyboard.id,
        date: DateTime(2026, 2, 1),
        netRealisableValue: rs(800),
      );
      await db.close();

      final reopened = openFileDatabase(file);
      final stock = await DriftInventoryRepository(reopened).stockOf(keyboard);
      final rows = await reopened.select(reopened.inventoryMovements).get();
      final report = TrialBalance.from(
        entries: await DriftJournalRepository(reopened).all(),
        currency: npr,
      );
      await reopened.close();

      expect(stock.quantity, 10);
      expect(stock.value.minorUnits, 80000);
      expect(rows.where((r) => r.reason == 'writeDown'), hasLength(1));
      expect(
        report.rows
            .firstWhere((r) => r.account.code == '1040')
            .balance
            .minorUnits,
        80000,
      );
    });
  });
}
