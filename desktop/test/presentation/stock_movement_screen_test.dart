import 'package:financeapp/src/application/post_inventory_movement.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/accounting/journal_entry.dart';
import 'package:financeapp/src/domain/accounting/journal_line.dart';
import 'package:financeapp/src/domain/accounting/journal_repository.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/inventory/inventory_movement.dart';
import 'package:financeapp/src/domain/inventory/product.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_inventory_repository.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_unit_of_work.dart';
import 'package:financeapp/src/presentation/screens/stock_movement_screen.dart';
import 'package:financeapp/src/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The direction of a stock movement is decided by **the reason**, not by the
/// screen.
///
/// ## What this pins
///
/// The screen hardcoded `InventoryMovement.receipt(...)` for every reason, so
/// choosing "Sale" produced a receipt: stock went **up** by the quantity, cost of
/// goods sold was **credited** instead of debited, profit went **up** by the value
/// and no revenue was recognised. Every internal check passed — the entry
/// balanced, the trial balance balanced, the balance sheet balanced — because the
/// entry was well formed and simply meant the opposite of what was asked for.
///
/// There was also **no way to record an issue at all**, so `sale` — the only reason
/// that posts COGS — was unreachable from the application.
///
/// ## Why the journal is asserted, not the sign
///
/// Asserting `movement.quantity` would catch a positive/negative slip but not the
/// consequence. What matters is which account is debited, so these tests read the
/// posted entry back out of the database and check where the value landed. A
/// movement that was negative but still credited COGS would pass a weaker test and
/// still misstate the profit and loss.
/// Sizes the window so the whole navigation, including Stock Movements, is on
/// screen. Without this the entry is laid out off-view and cannot be tapped.
void useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  const npr = 'NPR';
  // The fiscal year that **contains today**, because the screen stamps each
  // movement with DateTime.now() and PostInventoryMovement refuses a date
  // outside the open year. A hard-coded year would make every test here fail for
  // a reason that has nothing to do with movement direction.
  final fiscalYear = const NepaliFiscalCalendar().containing(DateTime.now());

  late AppDatabase db;
  late DriftInventoryRepository inventory;
  late JournalRepository journal;

  setUp(() async {
    db = openInMemoryDatabase();
    inventory = DriftInventoryRepository(db);
    journal = DriftJournalRepository(db);

    // The chart must exist before any movement can post: the journal entry names
    // the inventory and cost-of-goods-sold accounts, and SQLite refuses a
    // reference to a row that is not there.
    await DriftAccountRepository(db).saveAll(const ChartOfAccounts().all);
  });

  tearDown(() async => db.close());

  /// Counter so the opening movement's id is unique when the reason-loop test
  /// seeds several times in one database. A fixed id collides on the second call
  /// and fails on the primary key rather than on anything about the test.
  var openingCount = 0;

  Future<void> openStock({int units = 100}) async {
    final product = Product(
      id: 'prod-1',
      name: 'Keyboard',
      salePrice: Money.minor(20000, npr),
    );
    await inventory.saveProduct(product);
    await inventory.applyMovement(
      product,
      InventoryMovement.receipt(
        id: 'MV-OPEN-${++openingCount}',
        productId: product.id,
        date: DateTime(2026, 3, 1),
        reason: MovementReason.openingStock,
        quantity: units,
        value: Money.minor(units * 1000, npr),
      ),
    );
  }

  /// Fills the screen and posts with [reason] selected.
  ///
  /// Goes through the real form and the real reason picker, because the defect
  /// was in how the screen interpreted the choice.
  Future<List<JournalEntry>> postWith(
    WidgetTester tester,
    MovementReason reason, {
    String quantity = '5',
    String value = '5000',
  }) async {
    final before = (await journal.all()).length;

    // **The screen directly, under the real theme.** The defect is in how `_post`
    // interprets the chosen reason, which has nothing to do with the shell's
    // navigation, and going through the shell made this test fail on whether a nav
    // entry was on screen rather than on whether the entry was posted.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StockMovementScreen(
            postMovement: PostInventoryMovement(
              fiscalYear: fiscalYear,
              inventory: inventory,
              journal: journal,
              unitOfWork: DriftUnitOfWork(db),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // **By the keys the screen declares**, not by label text or by position. The
    // labels are drawn by `InputDecorator` and are not reliably findable, and
    // positional finders would silently retarget if a field were inserted.
    await tester.enterText(
        find.byKey(const ValueKey<String>('movement-product-field')), 'prod-1');
    await tester.enterText(
        find.byKey(const ValueKey<String>('movement-quantity-field')),
        quantity);
    await tester.enterText(
        find.byKey(const ValueKey<String>('movement-value-field')), value);

    await tester.tap(find.byType(DropdownButtonFormField<MovementReason>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(reason.label).last);
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const ValueKey<String>('movement-post-button')));
    await tester.pumpAndSettle();

    final after = await journal.all();
    expect(after.length, before + 1,
        reason: 'recording a movement must add exactly one journal entry');
    return after;
  }

  /// The lines of the movement just recorded.
  ///
  /// **The newest entry**, because [postWith] has already asserted that exactly
  /// one was added. Taking the last rather than demanding a total of one is what
  /// lets the reason-loop test seed several movements into a single database.
  List<JournalLine> linesFor(List<JournalEntry> entries) {
    expect(entries, isNotEmpty);
    return entries.last.lines;
  }

  group('a reason that sends stock out', () {
    testWidgets('a sale debits cost of goods sold and credits inventory',
        (tester) async {
      // The spec is explicit: Dr Cost of Goods Sold / Cr Inventory.
      await openStock();
      final lines = linesFor(await postWith(tester, MovementReason.sale));

      final cogs = lines.singleWhere(
        (JournalLine l) => l.account.code == costOfGoodsSoldCode,
      );
      final stock = lines.singleWhere(
        (JournalLine l) => l.account.code == inventoryCode,
      );

      expect(cogs.isDebit, isTrue,
          reason: 'cost of goods sold is an expense, so it is debited');
      expect(cogs.amount.minorUnits, 500000, reason: 'Rs 5,000.00');
      expect(stock.isCredit, isTrue,
          reason: 'stock leaving the shelf is credited out of inventory');
    });

    testWidgets('a sale reduces the quantity in stock', (tester) async {
      await openStock(units: 100);
      await postWith(tester, MovementReason.sale, quantity: '5');

      final product = await inventory.productById('prod-1');
      final stock = await inventory.stockOf(product!);

      expect(stock.quantity, 95, reason: '100 received less 5 sold');
    });

    testWidgets('a return out is also an issue', (tester) async {
      await openStock();
      final lines = linesFor(await postWith(tester, MovementReason.returnOut));

      final stock =
          lines.singleWhere((JournalLine l) => l.account.code == inventoryCode);
      expect(stock.isCredit, isTrue);
    });

    testWidgets('a purchase return is an issue, not a receipt', (tester) async {
      await openStock();
      final lines =
          linesFor(await postWith(tester, MovementReason.purchaseReturn));

      final stock =
          lines.singleWhere((JournalLine l) => l.account.code == inventoryCode);
      expect(stock.isCredit, isTrue,
          reason: 'goods going back to a supplier leave the business');
    });
  });

  group('a reason that brings stock in', () {
    testWidgets('a purchase debits inventory and credits payable, not COGS',
        (tester) async {
      // Buying stock does not consume anything: it creates a liability to the
      // supplier. **Cost of goods sold is recognised on the sale, not the
      // purchase.** Getting this wrong would debit COGS on every delivery and
      // understate profit all year.
      await openStock();
      final lines = linesFor(await postWith(tester, MovementReason.purchase));

      final stock = lines.singleWhere(
        (JournalLine l) => l.account.code == inventoryCode,
      );
      final payable = lines.singleWhere(
        (JournalLine l) => l.account.code == payableCode,
      );

      expect(stock.isDebit, isTrue);
      expect(payable.isCredit, isTrue,
          reason: 'Rs 5,000.00 owed to the supplier');
      expect(
        lines.any((JournalLine l) => l.account.code == costOfGoodsSoldCode),
        isFalse,
        reason: 'nothing has been consumed yet, so COGS must not move',
      );
    });

    testWidgets('a purchase increases the quantity in stock', (tester) async {
      await openStock(units: 100);
      await postWith(tester, MovementReason.purchase, quantity: '20');

      final product = await inventory.productById('prod-1');
      final stock = await inventory.stockOf(product!);

      expect(stock.quantity, 120);
    });

    testWidgets('a sale return is a receipt', (tester) async {
      await openStock();
      final lines = linesFor(await postWith(tester, MovementReason.saleReturn));

      final stock =
          lines.singleWhere((JournalLine l) => l.account.code == inventoryCode);
      expect(stock.isDebit, isTrue,
          reason: 'goods coming back from a customer return to the shelf');
    });
  });

  testWidgets('every reason posts a direction matching its own meaning',
      (tester) async {
    // The whole defect in one test: for each reason the inventory account must
    // move the way that reason implies. A screen that decides direction itself
    // will fail this for every issue-side reason at once.
    const issuesStock = <MovementReason>[
      MovementReason.sale,
      MovementReason.purchaseReturn,
      MovementReason.returnOut,
    ];
    const bringsStock = <MovementReason>[
      MovementReason.purchase,
      MovementReason.saleReturn,
      MovementReason.returnIn,
    ];

    for (final reason in issuesStock) {
      await openStock();
      final lines = linesFor(await postWith(tester, reason));
      final stock =
          lines.singleWhere((JournalLine l) => l.account.code == inventoryCode);
      expect(stock.isCredit, isTrue, reason: '$reason must send stock out');
    }

    for (final reason in bringsStock) {
      await openStock();
      final lines = linesFor(await postWith(tester, reason));
      final stock =
          lines.singleWhere((JournalLine l) => l.account.code == inventoryCode);
      expect(stock.isDebit, isTrue, reason: '$reason must bring stock in');
    }
  });
}

/// The inventory and cost-of-goods-sold account codes, taken from the chart
/// rather than hardcoded here, so this test fails if the chart is renumbered
/// rather than silently asserting against an account that no longer exists.
final String inventoryCode = ChartOfAccounts.inventory.code;
final String costOfGoodsSoldCode = ChartOfAccounts.costOfGoodsSold.code;
final String payableCode = ChartOfAccounts.payable.code;
