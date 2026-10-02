import 'dart:io';

import 'package:financeapp/src/application/conclude_fiscal_year.dart';
import 'package:financeapp/src/domain/accounting/account.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/fiscal/fiscal_year.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_unit_of_work.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:financeapp/src/presentation/app_services.dart';
import 'package:financeapp/src/presentation/finance_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the Conclude Fiscal Year screen.
///
/// This is the one screen that can lose a year, so the tests are about what it
/// **tells the user and refuses to do** — not about how it looks.
void main() {
  final year = FiscalYear(
    label: 'FY 2082/83',
    start: DateTime(2026, 7),
    end: DateTime(2027, 7),
  );

  late AppDatabase db;
  late DriftJournalRepository journal;
  late Directory tempDir;
  late File dbFile;
  late _Archive archive;
  late _Transition transition;

  setUp(() async {
    db = openInMemoryDatabase();
    await DriftAccountRepository(db).saveAll(const ChartOfAccounts().all);
    journal = DriftJournalRepository(db);
    tempDir = Directory.systemTemp.createTempSync('closesc');
    dbFile = File('${tempDir.path}/books.db')..writeAsBytesSync(<int>[0]);
    archive = _Archive();
    transition = _Transition();
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      FinanceApp(
        services: AppServices(
          concludeYear: ConcludeFiscalYear(
            fiscalYear: year,
            databaseFile: dbFile,
            journal: journal,
            unitOfWork: DriftUnitOfWork(db),
            archive: archive,
            transition: transition,
            accounts: const ChartOfAccounts().all,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fiscal Year'));
    await tester.pumpAndSettle();
  }

  testWidgets('states the archive requirement before anything is pressed',
      (tester) async {
    await open(tester);

    // A user who does not read the page must still not close a year believing
    // it was archived.
    expect(find.textContaining('archived to the server first'), findsOneWidget);
    expect(find.textContaining('stays open'), findsOneWidget);
    expect(find.textContaining('unbalanced'), findsOneWidget);
  });

  testWidgets('closes the year and reports what carried forward',
      (tester) async {
    await open(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('conclude-year-button')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('FY 2082/83 is closed'), findsOneWidget);
    expect(find.textContaining('FY 2083/84 is now open'), findsOneWidget);
    expect(transition.calls, 1);
  });

  testWidgets('an unreachable archive leaves the year open and says why',
      (tester) async {
    archive.available = false;

    await open(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('conclude-year-button')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('cannot be reached'), findsOneWidget);
    expect(transition.calls, 0,
        reason: 'the screen must not create a next year it was told not to');
  });

  testWidgets('a failed archive reports it and does not claim success',
      (tester) async {
    archive.failWith = 'the server refused';

    await open(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('conclude-year-button')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('was not closed'), findsOneWidget);
    expect(find.textContaining('is closed with a'), findsNothing);
    expect(transition.calls, 0);
  });

  testWidgets('the button is disabled once the year is closed', (tester) async {
    await open(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('conclude-year-button')),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('conclude-year-button')),
    );
    expect(button.onPressed, isNull,
        reason: 'a year must not be concluded twice');
  });
}

/// A [FiscalYearArchive] that can be made unavailable or made to fail.
class _Archive implements FiscalYearArchive {
  bool available = true;
  String? failWith;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> archive(FiscalYear fiscalYear, File databaseFile) async {
    final failure = failWith;
    if (failure != null) throw StateError(failure);
  }
}

/// A [FiscalYearTransition] that only counts.
class _Transition implements FiscalYearTransition {
  int calls = 0;

  @override
  Future<void> beginNextYear({
    required FiscalYear fiscalYear,
    required Map<Account, Money> openingBalances,
  }) async {
    calls++;
  }
}
