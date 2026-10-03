import 'package:financeapp/src/application/post_journal_entry.dart';
import 'package:financeapp/src/application/transfer_cash.dart';
import 'package:financeapp/src/domain/accounting/account.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_unit_of_work.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:financeapp/src/presentation/screens/transfer_screen.dart';
import 'package:financeapp/src/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The transfer screen.
///
/// ## What it pins
///
/// **That a non-cash account is not even selectable.** The domain test proves the
/// rule is *enforced*; this proves it is also **unreachable through the form**, so
/// the mistake cannot be made by someone who never triggers a refusal.
///
/// The Journal screen will happily post `Dr Office Rent / Cr Bank`. That is a valid
/// balanced entry and a completely different event, and on a two-box form it looks
/// identical to moving money between tills.
void main() {
  // The year **containing today**, because the screen stamps the transfer with
  // DateTime.now() and the engine refuses a date outside the open year. A
  // hard-coded year would make every test here fail for a reason that has nothing
  // to do with the transfer.
  final fiscalYear = const NepaliFiscalCalendar().containing(DateTime.now());

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

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: TransferScreen(transferCash: transfers),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> fillAndPost(WidgetTester tester, String amount) async {
    await tester.enterText(
      find.byKey(const ValueKey<String>('transfer-amount-field')),
      amount,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('transfer-post-button')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('offers only the cash accounts', (tester) async {
    await pump(tester);

    await tester.tap(find.byType(DropdownButtonFormField<Account>).first);
    await tester.pumpAndSettle();

    // Both cash accounts are offered...
    expect(find.textContaining('Bank'), findsWidgets);
    expect(find.textContaining('Cash'), findsWidgets);
    // ...and no expense account is reachable at all.
    expect(find.textContaining('Office Rent'), findsNothing);
    expect(find.textContaining('Sales Revenue'), findsNothing);
    expect(find.textContaining('Accounts Receivable'), findsNothing);
  });

  testWidgets('a valid transfer posts and says so', (tester) async {
    await pump(tester);

    await fillAndPost(tester, '50000');

    expect(find.textContaining('Moved Rs 50,000.00'), findsOneWidget,
        reason: 'the confirmation names the accounts and the amount');
    expect((await journal.all()).single, isNotNull);
  });

  testWidgets('the same account on both sides is refused, with advice',
      (tester) async {
    await pump(tester);

    // Choose Bank for both sides.
    await tester.tap(find.byType(DropdownButtonFormField<Account>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Bank').last);
    await tester.pumpAndSettle();

    await fillAndPost(tester, '1000');

    expect(find.textContaining('two different accounts'), findsOneWidget);
    expect(await journal.all(), isEmpty,
        reason: 'a refused transfer must leave no trace');
  });

  testWidgets('an amount of zero is refused and nothing is posted',
      (tester) async {
    await pump(tester);

    await fillAndPost(tester, '0');

    expect(find.textContaining('more than zero'), findsOneWidget);
    expect(await journal.all(), isEmpty);
  });

  testWidgets('the amount field is marked so it can be found by key',
      (tester) async {
    // A guard on the test's own wiring: if these keys stop matching, the tests
    // above would silently stop filling the form.
    await pump(tester);

    expect(find.byKey(const ValueKey<String>('transfer-amount-field')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('transfer-post-button')),
        findsOneWidget);
  });
}
