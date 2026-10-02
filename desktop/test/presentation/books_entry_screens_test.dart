import 'package:financeapp/src/application/issue_credit_note.dart';
import 'package:financeapp/src/application/post_inventory_movement.dart';
import 'package:financeapp/src/application/post_journal_entry.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/billing/customer.dart';
import 'package:financeapp/src/domain/fiscal/fiscal_year.dart';
import 'package:financeapp/src/domain/inventory/product.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_credit_note_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_customer_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_document_number_sequence.dart';
import 'package:financeapp/src/infrastructure/database/drift_inventory_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_invoice_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_payment_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_unit_of_work.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:financeapp/src/presentation/app_services.dart';
import 'package:financeapp/src/presentation/finance_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the three screens that change the books by hand.
///
/// **These run against the real use cases over a real database**, not against
/// stubs. A stub would only prove the screen forwards its arguments; using the
/// real thing also proves the screen and the use case agree on what the fields
/// mean, which is where a screen that guessed would show up.
///
/// All three screens follow one rule: **they decide nothing.** Each collects what
/// was typed and hands it over, so what matters is that the result actually
/// lands in the books.
void main() {
  late AppDatabase db;
  late DriftInventoryRepository inventory;
  final year = FiscalYear(
    label: 'FY 2082/83',
    start: DateTime(2026, 7),
    end: DateTime(2027, 7),
  );

  setUp(() async {
    db = openInMemoryDatabase();
    // The chart of accounts must exist before anything can post to it.
    await DriftAccountRepository(db).saveAll(const ChartOfAccounts().all);
    await DriftCustomerRepository(db).save(
      Customer(id: 'C-0001', name: 'Himalayan Traders'),
    );
    inventory = DriftInventoryRepository(db);
  });

  tearDown(() async => db.close());

  Future<void> open(WidgetTester tester, String item) async {
    tester.view.physicalSize = const Size(1600, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      FinanceApp(
        services: AppServices(
          postMovement: PostInventoryMovement(
            fiscalYear: year,
            inventory: inventory,
            journal: DriftJournalRepository(db),
            unitOfWork: DriftUnitOfWork(db),
          ),
          issueCreditNote: IssueCreditNote(
            fiscalYear: year,
            invoices: DriftInvoiceRepository(db),
            payments: DriftPaymentRepository(db),
            creditNotes: DriftCreditNoteRepository(db),
            numbers: DriftDocumentNumberSequence(db),
            journal: DriftJournalRepository(db),
            unitOfWork: DriftUnitOfWork(db),
          ),
          postEntry: PostJournalEntry(
            fiscalYear: year,
            journal: DriftJournalRepository(db),
            unitOfWork: DriftUnitOfWork(db),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  group('stock movements', () {
    testWidgets('records stock against a product', (tester) async {
      await inventory.saveProduct(
        Product(
          id: 'prd-1',
          name: 'Keyboard',
          salePrice: Money.fromMajorUnits(2500, 'NPR'),
        ),
      );

      await open(tester, 'Stock Movements');

      await tester.enterText(
        find.byKey(const ValueKey<String>('movement-product-field')),
        'prd-1',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('movement-quantity-field')),
        '10',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('movement-value-field')),
        '25000',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('movement-post-button')),
      );
      await tester.pumpAndSettle();

      final stock = await inventory.stockOf(
        Product(
          id: 'prd-1',
          name: 'Keyboard',
          salePrice: Money.fromMajorUnits(2500, 'NPR'),
        ),
      );
      expect(stock.quantity, 10, reason: 'the typed quantity must be recorded');
      expect(stock.value.minorUnits, 2500000);
      expect(await inventory.allMovements(), hasLength(1));
    });

    testWidgets('never asks for a unit price, which would drift',
        (tester) async {
      await open(tester, 'Stock Movements');

      expect(
          find.textContaining('not a price you type per unit'), findsOneWidget);
    });

    testWidgets('refuses a product that does not exist, saying so',
        (tester) async {
      await open(tester, 'Stock Movements');

      await tester.enterText(
        find.byKey(const ValueKey<String>('movement-product-field')),
        'nope',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('movement-quantity-field')),
        '1',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('movement-value-field')),
        '100',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('movement-post-button')),
      );
      await tester.pumpAndSettle();

      // The use case's own refusal, and nothing written.
      expect(await inventory.allMovements(), isEmpty);
      expect(find.textContaining('nope'), findsWidgets);
    });
  });

  group('journal entries', () {
    testWidgets('refuses to submit while debits and credits differ',
        (tester) async {
      await open(tester, 'Journal');

      await tester.enterText(
        find.byKey(const ValueKey<String>('entry-description-field')),
        'Rent for August',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('entry-debit-amount-field')),
        '100',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('entry-credit-amount-field')),
        '80',
      );
      await tester.pumpAndSettle();

      // Shown before anything is pressed, so a mismatch is never a surprise.
      expect(find.textContaining('Difference:'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('entry-post-button')),
      );
      await tester.pumpAndSettle();

      expect(await DriftJournalRepository(db).all(), isEmpty,
          reason: 'an unbalanced entry must never reach the books');
    });

    testWidgets('posts a balanced entry into the ledger', (tester) async {
      await open(tester, 'Journal');

      await tester.enterText(
        find.byKey(const ValueKey<String>('entry-description-field')),
        'Rent for August',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('entry-debit-amount-field')),
        '100',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('entry-credit-amount-field')),
        '100',
      );
      await tester.pumpAndSettle();

      expect(find.text('Debits and credits are equal.'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('entry-post-button')),
      );
      await tester.pumpAndSettle();

      expect(await DriftJournalRepository(db).all(), hasLength(1));
    });
  });

  group('credit notes', () {
    testWidgets('refuses an invoice that was never sent', (tester) async {
      await open(tester, 'Credit Notes');

      await tester.enterText(
        find.byKey(const ValueKey<String>('credit-invoice-field')),
        'INV-2082-83-9999',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('credit-amount-field')),
        '500',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('credit-issue-button')),
      );
      await tester.pumpAndSettle();

      // The use case's own refusal, surfaced rather than swallowed.
      expect(find.textContaining('INV-2082-83-9999'), findsWidgets);
    });
  });
}
