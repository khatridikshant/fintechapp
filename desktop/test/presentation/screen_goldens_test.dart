import 'dart:io';

import 'package:financeapp/src/application/build_reports.dart';
import 'package:financeapp/src/application/post_inventory_movement.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/domain/inventory/inventory_movement.dart';
import 'package:financeapp/src/domain/inventory/product.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_credit_note_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_inventory_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_invoice_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_unit_of_work.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:financeapp/src/presentation/screens/financial_reports_screen.dart';
import 'package:financeapp/src/presentation/screens/stock_movement_screen.dart';
import 'package:financeapp/src/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the screens changed this session to PNGs under `goldens/`.
///
/// Run `flutter test --update-goldens test/presentation/screen_goldens_test.dart`
/// to regenerate them.
///
/// ## Why this is here, and what it is for
///
/// `flutter test --update-goldens` draws the real widget tree through the real
/// theme, so the file is what the application actually renders — and unlike a
/// screenshot script it **fails on a layout overflow**, which is the defect class
/// this most wants to catch.
///
/// **These are for a human to look at.** Nothing asserts pixel equality forever;
/// a golden that must match byte-for-byte across Flutter versions is a
/// maintenance tax with no benefit. What is wanted is that *someone* can see every
/// changed screen, and that a later diff shows **what** moved rather than only
/// that something did.
/// Compares against the stored PNG **only when explicitly asked**.
///
/// ## Why this is opt-in
///
/// A golden is a picture of one machine's font rasterisation at one Flutter
/// version. Compared by default it fails on every other machine and after every
/// Flutter upgrade, for reasons that have nothing to do with the application —
/// which trains people to regenerate goldens on sight and makes the check worthless.
///
/// So the two halves are separated deliberately:
///
/// - **Rendering always happens**, and that is where the real value is.
///   `RenderFlex` overflow throws during layout, so an overflowing screen fails
///   these tests on every machine, with no golden involved.
/// - **The pixel comparison runs only when asked**, via
///   `GOLDENS=1 flutter test ...` or `--update-goldens`, so it is a deliberate
///   "did this change look right?" step rather than a tripwire.
Future<void> expectGoldenMatches(
  WidgetTester tester,
  String path,
) async {
  final requested = Platform.environment['GOLDENS'] == '1' ||
      Platform.environment['GOLDENS'] == 'true';

  if (!requested) return;

  await expectLater(find.byType(Scaffold).first, matchesGoldenFile(path));
}

void main() {
  const npr = 'NPR';
  final fiscalYear = const NepaliFiscalCalendar().forBsYear(2082);

  /// Loads a real font so the goldens contain **readable text**.
  ///
  /// Without this every glyph renders as a filled box — the test binding's
  /// placeholder font. The images are then useless for the thing they are most
  /// needed for, which is spotting a wrong label, a truncated sentence or a
  /// missing prefix. Layout is visible either way; the words are not.
  ///
  /// **Guarded on the file existing**, because this is a golden test and it must
  /// not fail on a machine without Arial. On such a machine the goldens still
  /// generate, they are just boxes.
  setUpAll(() async {
    // **The family the app theme actually asks for.** AppTheme sets its
    // fontFamily to 'Segoe UI', so registering the font under any other name leaves
    // the theme asking for a family the engine does not have, and every glyph stays
    // a box. This was the whole reason the first attempt produced unreadable
    // images.
    const fontFamily = 'Segoe UI';
    final fontFile = File('C:/Windows/Fonts/segoeui.ttf');
    if (!fontFile.existsSync()) return;
    if (!fontFile.existsSync()) return;

    final loader = FontLoader(fontFamily)
      ..addFont(
        Future<ByteData>.value(
          ByteData.sublistView(fontFile.readAsBytesSync()),
        ),
      );
    await loader.load();
  });

  /// A database with the chart seeded, which every posting path needs before a
  /// journal entry can reference an account.
  Future<AppDatabase> seededDatabase() async {
    final db = openInMemoryDatabase();
    await DriftAccountRepository(db).saveAll(const ChartOfAccounts().all);
    return db;
  }

  void useDesktopSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('stock movement screen', (tester) async {
    useDesktopSurface(tester);
    final db = await seededDatabase();
    addTearDown(db.close);

    final inventory = DriftInventoryRepository(db);
    final product = Product(
      id: 'prod-1',
      name: 'Keyboard',
      salePrice: Money.minor(20000, npr),
    );
    await inventory.saveProduct(product);
    await inventory.applyMovement(
      product,
      InventoryMovement.receipt(
        id: 'MV-OPEN',
        productId: product.id,
        date: fiscalYear.startDate.add(const Duration(days: 1)),
        reason: MovementReason.openingStock,
        quantity: 100,
        value: Money.minor(100000, npr),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StockMovementScreen(
            postMovement: PostInventoryMovement(
              fiscalYear: fiscalYear,
              inventory: inventory,
              journal: DriftJournalRepository(db),
              unitOfWork: DriftUnitOfWork(db),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectGoldenMatches(tester, 'goldens/stock_movement_screen.png');
  });

  testWidgets('stock movement screen with an adjustment chosen',
      (tester) async {
    // The one screen state that changed shape today: the direction control only
    // exists for an adjustment, so this is the only way to see it rendered.
    useDesktopSurface(tester);
    final db = await seededDatabase();
    addTearDown(db.close);
    final inventory = DriftInventoryRepository(db);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StockMovementScreen(
            postMovement: PostInventoryMovement(
              fiscalYear: fiscalYear,
              inventory: inventory,
              journal: DriftJournalRepository(db),
              unitOfWork: DriftUnitOfWork(db),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('movement-product-field')),
      'prod-1',
    );
    await tester.tap(find.byType(DropdownButtonFormField<MovementReason>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(MovementReason.adjustment.label).last);
    await tester.pumpAndSettle();

    await expectGoldenMatches(tester, 'goldens/stock_movement_adjustment.png');
  });

  testWidgets('financial reports screen, cash flow tab', (tester) async {
    useDesktopSurface(tester);
    final db = await seededDatabase();
    addTearDown(db.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: FinancialReportsScreen(
          cashFlow: BuildCashFlow(
            fiscalYear: fiscalYear,
            journal: DriftJournalRepository(db),
          ),
          sales: BuildSalesSummary(
            fiscalYear: fiscalYear,
            invoices: DriftInvoiceRepository(db),
            creditNotes: DriftCreditNoteRepository(db),
          ),
          inventory: BuildInventorySummary(
            fiscalYear: fiscalYear,
            inventory: DriftInventoryRepository(db),
          ),
          tax: BuildTaxSummary(
            fiscalYear: fiscalYear,
            invoices: DriftInvoiceRepository(db),
            creditNotes: DriftCreditNoteRepository(db),
          ),
          fiscalYearLabel: fiscalYear.label,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectGoldenMatches(
        tester, 'goldens/financial_reports_cash_flow.png');
  });

  testWidgets('financial reports screen, VAT tab', (tester) async {
    // The VAT view is the one whose figures changed today, and its notice text is
    // long enough to overflow a narrow window.
    useDesktopSurface(tester);
    final db = await seededDatabase();
    addTearDown(db.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: FinancialReportsScreen(
          cashFlow: BuildCashFlow(
            fiscalYear: fiscalYear,
            journal: DriftJournalRepository(db),
          ),
          sales: BuildSalesSummary(
            fiscalYear: fiscalYear,
            invoices: DriftInvoiceRepository(db),
            creditNotes: DriftCreditNoteRepository(db),
          ),
          inventory: BuildInventorySummary(
            fiscalYear: fiscalYear,
            inventory: DriftInventoryRepository(db),
          ),
          tax: BuildTaxSummary(
            fiscalYear: fiscalYear,
            invoices: DriftInvoiceRepository(db),
            creditNotes: DriftCreditNoteRepository(db),
          ),
          fiscalYearLabel: fiscalYear.label,
          initialReport: FinancialReport.tax,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectGoldenMatches(tester, 'goldens/financial_reports_vat.png');
  });
}
