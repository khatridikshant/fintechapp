import 'dart:io';

import 'package:financeapp/src/application/post_inventory_movement.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/inventory/inventory_movement.dart';
import 'package:financeapp/src/domain/inventory/product.dart';
import 'package:financeapp/src/domain/inventory/product_stock.dart';
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

PostInventoryMovement useCaseFor(AppDatabase db) => PostInventoryMovement(
      fiscalYear: fiscalYear,
      inventory: DriftInventoryRepository(db),
      journal: DriftJournalRepository(db),
      unitOfWork: DriftUnitOfWork(db),
    );

InventoryMovement purchase(
  int quantity,
  int valueRupees, {
  String id = 'MV-1',
  DateTime? date,
}) =>
    InventoryMovement.receipt(
      id: id,
      productId: keyboard.id,
      date: date ?? DateTime(2026, 1, 10),
      reason: MovementReason.purchase,
      quantity: quantity,
      value: rs(valueRupees),
    );

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('financeapp_invpost_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('Posting a receipt', () {
    test('a purchase debits inventory and credits payables', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      final outcome = await useCaseFor(db)(purchase(10, 1000));

      expect(outcome, isA<InventoryMovementPosted>());
      final posted = outcome as InventoryMovementPosted;
      final lines = posted.journalEntry.lines;

      expect(lines, hasLength(2));
      expect(lines[0].account.code, '1040');
      expect(lines[0].isDebit, isTrue);
      expect(lines[0].debit.minorUnits, 100000);
      expect(lines[1].account.code, '2010');
      expect(lines[1].isCredit, isTrue);
      expect(lines[1].credit.minorUnits, 100000);
      expect(posted.journalEntry.isBalanced, isTrue);
    });

    test('opening stock credits owner equity', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      final outcome = await useCaseFor(db)(
        InventoryMovement.receipt(
          id: 'MV-OPEN',
          productId: keyboard.id,
          date: DateTime(2026, 1, 5),
          reason: MovementReason.openingStock,
          quantity: 10,
          value: rs(1000),
        ),
      ) as InventoryMovementPosted;

      final lines = outcome.journalEntry.lines;
      expect(lines[0].account.code, '1040');
      expect(lines[1].account.code, '3010');
    });

    test('the movement records the entry that posted it', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      final posted =
          await useCaseFor(db)(purchase(10, 1000)) as InventoryMovementPosted;

      final row = (await db.select(db.inventoryMovements).get()).single;
      expect(row.journalEntryId, 'JE-MV-MV-1');
      expect(row.journalEntryId, posted.journalEntry.id);
    });

    test('stock is updated by the posting', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      final posted =
          await useCaseFor(db)(purchase(10, 1000)) as InventoryMovementPosted;

      expect(posted.stock.quantity, 10);
      expect(posted.stock.value.minorUnits, 100000);
      expect(posted.stock.costPerUnit.minorUnits, 10000);
    });
  });

  group('The ledger and the stock agree', () {
    /// The inventory account balance from the trial balance.
    Future<Money> inventoryInLedger(AppDatabase db) async {
      final report = TrialBalance.from(
        entries: await DriftJournalRepository(db).all(),
        currency: npr,
      );
      final row = report.rows.firstWhere((r) => r.account.code == '1040');
      return row.balance;
    }

    test('after a purchase the two agree', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      final inventory = DriftInventoryRepository(db);

      await useCaseFor(db)(purchase(10, 1000));

      final stock = await inventory.stockOf(keyboard);
      expect(stock.value.minorUnits, 100000);
      expect((await inventoryInLedger(db)).minorUnits, 100000,
          reason: 'the inventory account must equal the stock on the shelf');
    });

    test('after the worked example and an issue, the two still agree',
        () async {
      // Buy 10 at Rs 100, then 10 at Rs 120, then issue 10.
      // Stock: 20 units worth Rs 2,200, then Rs 1,100 after issuing half.
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      final inventory = DriftInventoryRepository(db);
      final useCase = useCaseFor(db);

      await useCase(purchase(10, 1000, id: 'MV-1'));
      await useCase(
        purchase(10, 1200, id: 'MV-2', date: DateTime(2026, 1, 12)),
      );

      final before = await inventory.stockOf(keyboard);
      expect(before.value.minorUnits, 220000);
      expect(before.costPerUnit.minorUnits, 11000);

      final issueValue = before.valueOfIssue(10);
      await useCase(
        InventoryMovement.issue(
          id: 'MV-3',
          productId: keyboard.id,
          date: DateTime(2026, 1, 15),
          reason: MovementReason.sale,
          quantity: 10,
          value: issueValue.negated(),
        ),
      );

      final stock = await inventory.stockOf(keyboard);
      expect(stock.quantity, 10);
      expect(stock.value.minorUnits, 110000, reason: 'exactly Rs 1,100');
      expect((await inventoryInLedger(db)).minorUnits, 110000,
          reason: 'the inventory account must hold exactly what the stock is '
              'worth, which is the whole point of value-first tracking');
    });

    test('a sale debits cost of goods sold and credits inventory', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      final inventory = DriftInventoryRepository(db);
      final useCase = useCaseFor(db);

      await useCase(purchase(10, 1000, id: 'MV-1'));
      final current = await inventory.stockOf(keyboard);

      final issued = await useCase(
        InventoryMovement.issue(
          id: 'MV-2',
          productId: keyboard.id,
          date: DateTime(2026, 1, 15),
          reason: MovementReason.sale,
          quantity: 4,
          value: current.valueOfIssue(4).negated(),
        ),
      ) as InventoryMovementPosted;

      final lines = issued.journalEntry.lines;
      expect(lines[0].account.code, '5020',
          reason: 'cost of goods sold is debited on a sale');
      expect(lines[0].debit.minorUnits, 40000);
      expect(lines[1].account.code, '1040');
      expect(lines[1].credit.minorUnits, 40000);
    });

    test('the trial balance balances after every scenario', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      final inventory = DriftInventoryRepository(db);
      final useCase = useCaseFor(db);

      await useCase(purchase(10, 1000, id: 'MV-1'));
      final current = await inventory.stockOf(keyboard);
      await useCase(
        InventoryMovement.issue(
          id: 'MV-2',
          productId: keyboard.id,
          date: DateTime(2026, 1, 15),
          reason: MovementReason.sale,
          quantity: 3,
          value: current.valueOfIssue(3).negated(),
        ),
      );

      final report = TrialBalance.from(
        entries: await DriftJournalRepository(db).all(),
        currency: npr,
      );
      expect(report.isBalanced, isTrue);
      expect(report.assertBalanced, returnsNormally);
    });
  });

  group('Non-sale reasons map to documented accounts', () {
    test('a purchase return reverses the payable', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      final useCase = useCaseFor(db);

      await useCase(purchase(10, 1000, id: 'MV-1'));

      final returned = await useCase(
        InventoryMovement.issue(
          id: 'MV-2',
          productId: keyboard.id,
          date: DateTime(2026, 1, 20),
          reason: MovementReason.purchaseReturn,
          quantity: 2,
          value: rs(200),
        ),
      ) as InventoryMovementPosted;

      expect(returned.journalEntry.lines[0].account.code, '2010');
      expect(returned.journalEntry.lines[0].isDebit, isTrue);
      expect(returned.journalEntry.lines[1].account.code, '1040');
      expect(returned.stock.quantity, 8);
      expect(returned.stock.value.minorUnits, 80000);
    });

    test('a sale return puts cost of goods sold back', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      final inventory = DriftInventoryRepository(db);
      final useCase = useCaseFor(db);

      await useCase(purchase(10, 1000, id: 'MV-1'));
      final current = await inventory.stockOf(keyboard);
      await useCase(
        InventoryMovement.issue(
          id: 'MV-2',
          productId: keyboard.id,
          date: DateTime(2026, 1, 15),
          reason: MovementReason.sale,
          quantity: 4,
          value: current.valueOfIssue(4).negated(),
        ),
      );

      final returned = await useCase(
        InventoryMovement.receipt(
          id: 'MV-3',
          productId: keyboard.id,
          date: DateTime(2026, 1, 20),
          reason: MovementReason.saleReturn,
          quantity: 4,
          value: rs(400),
        ),
      ) as InventoryMovementPosted;

      expect(returned.journalEntry.lines[0].account.code, '1040');
      expect(returned.journalEntry.lines[0].isDebit, isTrue);
      expect(returned.journalEntry.lines[1].account.code, '5020');
      expect(returned.journalEntry.lines[1].isCredit, isTrue);
    });

    test('a stock loss debits the adjustment account', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      final useCase = useCaseFor(db);

      await useCase(purchase(10, 1000, id: 'MV-1'));

      final lost = await useCase(
        InventoryMovement.issue(
          id: 'MV-2',
          productId: keyboard.id,
          date: DateTime(2026, 1, 25),
          reason: MovementReason.adjustment,
          quantity: 1,
          value: rs(100),
        ),
      ) as InventoryMovementPosted;

      expect(lost.journalEntry.lines[0].account.code, '5070');
      expect(lost.journalEntry.lines[1].account.code, '1040');
    });

    test('a stock gain credits the adjustment account', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      final useCase = useCaseFor(db);

      await useCase(purchase(10, 1000, id: 'MV-1'));

      final found = await useCase(
        InventoryMovement.receipt(
          id: 'MV-2',
          productId: keyboard.id,
          date: DateTime(2026, 1, 25),
          reason: MovementReason.adjustment,
          quantity: 1,
          value: rs(100),
        ),
      ) as InventoryMovementPosted;

      expect(found.journalEntry.lines[0].account.code, '1040');
      expect(found.journalEntry.lines[1].account.code, '5070');
      expect(found.stock.quantity, 11);
    });

    test('a transfer is refused rather than given a guessed entry', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      final outcome = await useCaseFor(db)(
        InventoryMovement.issue(
          id: 'MV-XFER',
          productId: keyboard.id,
          date: DateTime(2026, 1, 25),
          reason: MovementReason.transfer,
          quantity: 1,
          value: rs(100),
        ),
      );

      expect(outcome, isA<InventoryMovementRejected>());
      final rejected = outcome as InventoryMovementRejected;
      expect(
        rejected.reason,
        PostInventoryMovementRejectionReason.unsupportedReason,
      );
      expect(rejected.message, contains('transfer'));

      expect(await db.select(db.inventoryMovements).get(), isEmpty);
      expect(await DriftJournalRepository(db).all(), isEmpty);
    });
  });

  group('Refusals write nothing', () {
    test('an out-of-stock issue is refused, and no entry survives', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      final useCase = useCaseFor(db);

      await useCase(purchase(10, 1000, id: 'MV-1'));

      await expectLater(
        useCase(
          InventoryMovement.issue(
            id: 'MV-TOOMANY',
            productId: keyboard.id,
            date: DateTime(2026, 1, 20),
            reason: MovementReason.sale,
            quantity: 11,
            value: rs(1100),
          ),
        ),
        throwsA(isA<NegativeStockException>()),
      );

      expect(await db.select(db.inventoryMovements).get(), hasLength(1),
          reason: 'the refused movement must not be written');
      expect(await DriftJournalRepository(db).all(), hasLength(1),
          reason: 'the entry written before the refusal must have rolled back');
      final stock = await DriftInventoryRepository(db).stockOf(keyboard);
      expect(stock.quantity, 10);
    });

    test('a movement for an unknown product is refused', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      final outcome = await useCaseFor(db)(
        InventoryMovement.receipt(
          id: 'MV-GHOST',
          productId: 'prod-nobody',
          date: DateTime(2026, 1, 10),
          reason: MovementReason.purchase,
          quantity: 1,
          value: rs(100),
        ),
      );

      expect(outcome, isA<InventoryMovementRejected>());
      expect(
        (outcome as InventoryMovementRejected).reason,
        PostInventoryMovementRejectionReason.unknownProduct,
      );
      expect(await db.select(db.inventoryMovements).get(), isEmpty);
      expect(await DriftJournalRepository(db).all(), isEmpty);
    });

    test('a movement outside the fiscal year is refused', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);

      for (final date in [
        fiscalYear.startDate.subtract(const Duration(days: 1)),
        fiscalYear.endDate.add(const Duration(days: 1)),
      ]) {
        final outcome = await useCaseFor(db)(purchase(1, 100, date: date));

        expect(outcome, isA<InventoryMovementRejected>());
        expect(
          (outcome as InventoryMovementRejected).reason,
          PostInventoryMovementRejectionReason.outsideFiscalYear,
        );
      }

      expect(await db.select(db.inventoryMovements).get(), isEmpty);
      expect(await DriftJournalRepository(db).all(), isEmpty);
    });

    test('posting the same movement twice is refused', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await seed(db);
      final useCase = useCaseFor(db);

      await useCase(purchase(10, 1000, id: 'MV-1'));

      await expectLater(
        useCase(purchase(10, 1000, id: 'MV-1')),
        throwsA(anything),
      );

      expect(await db.select(db.inventoryMovements).get(), hasLength(1),
          reason: 'the movement must not be counted twice');
      final stock = await DriftInventoryRepository(db).stockOf(keyboard);
      expect(stock.quantity, 10);
      expect(stock.value.minorUnits, 100000);
    });
  });

  group('Durability', () {
    test('a posted movement survives closing and reopening', () async {
      final file = File(p.join(tempDir.path, 'accounting-FY-2082-83.db'));

      final db = openFileDatabase(file);
      await seed(db);
      await useCaseFor(db)(purchase(10, 1000, id: 'MV-1'));
      await db.close();

      final reopened = openFileDatabase(file);
      final rows = await reopened.select(reopened.inventoryMovements).get();
      final stock = await DriftInventoryRepository(reopened).stockOf(keyboard);
      final entries = await DriftJournalRepository(reopened).all();
      await reopened.close();

      expect(rows, hasLength(1));
      expect(rows.single.journalEntryId, 'JE-MV-MV-1',
          reason: 'the link between the movement and its entry must survive');
      expect(stock.value.minorUnits, 100000);
      expect(entries, hasLength(1));
      expect(entries.single.isBalanced, isTrue);
    });
  });
}
