import 'dart:io';

import 'package:financeapp/src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'package:financeapp/src/infrastructure/database/file_books_session.dart';
import 'package:financeapp/src/presentation/app_services.dart';
import 'package:flutter_test/flutter_test.dart';

/// `AppServices` copies itself in two places, and a forgotten field there is
/// invisible: nothing crashes, a screen just quietly stops working.
///
/// These tests exist because that is exactly what had happened. `forSession` and
/// `forAccount` dropped `createProduct`, `postMovement`, `issueCreditNote`,
/// `postEntry` and `concludeYear`, so switching fiscal year or signing in silently
/// removed the catalogue, the stock, the credit-note, the manual-journal and the
/// year-end screens. Each of those fields is now asserted explicitly below.
void main() {
  final fiscalYear = const NepaliFiscalCalendar().forBsYear(2082);

  /// A real session on a real directory, because the fields under test are
  /// produced by a real session. A fake would only prove the fake.
  Future<FileBooksSession> sessionIn(Directory directory) =>
      FileBooksSession.openOn(
        booksDirectory: directory,
        startYear: fiscalYear,
      );

  test('switching year carries every use case across', () async {
    final directory = Directory.systemTemp.createTempSync('services-year');
    addTearDown(() => directory.deleteSync(recursive: true));
    final session = await sessionIn(directory);

    // The services as they stand before any switch, with the session's use cases
    // in place -- the state the application assembles at startup.
    final before = AppServices(
      trialBalance: session.trialBalance,
      generalLedger: session.generalLedger,
      createCustomer: session.createCustomer,
      issueInvoice: session.issueInvoice,
      recordPayment: session.recordPayment,
      createProduct: session.createProduct,
      postMovement: session.postMovement,
      issueCreditNote: session.issueCreditNote,
      postEntry: session.postEntry,
      cashFlow: session.cashFlow,
      sales: session.sales,
      inventoryReport: session.inventoryReport,
      categoryReport: session.categoryReport,
      tax: session.tax,
    );

    final after = before.forSession(session);

    // Each field named, so a future omission is a named failure rather than a
    // mystery.
    expect(after.trialBalance, isNotNull, reason: 'trial balance');
    expect(after.generalLedger, isNotNull, reason: 'general ledger');
    expect(after.createCustomer, isNotNull, reason: 'customer');
    expect(after.issueInvoice, isNotNull, reason: 'invoice');
    expect(after.recordPayment, isNotNull, reason: 'payment');
    expect(after.createProduct, isNotNull, reason: 'product');
    expect(after.postMovement, isNotNull, reason: 'stock movement');
    expect(after.issueCreditNote, isNotNull, reason: 'credit note');
    expect(after.postEntry, isNotNull, reason: 'journal entry');
    expect(after.cashFlow, isNotNull, reason: 'cash flow');
    expect(after.sales, isNotNull, reason: 'sales');
    expect(after.inventoryReport, isNotNull, reason: 'inventory');
    expect(after.categoryReport, isNotNull, reason: 'category report');
    expect(after.tax, isNotNull, reason: 'VAT');
  });

  test('signing in and out carries every use case across', () async {
    final directory = Directory.systemTemp.createTempSync('services-account');
    addTearDown(() => directory.deleteSync(recursive: true));
    final session = await sessionIn(directory);

    final services = AppServices(
      trialBalance: session.trialBalance,
      createCustomer: session.createCustomer,
      createProduct: session.createProduct,
      postMovement: session.postMovement,
      issueCreditNote: session.issueCreditNote,
      postEntry: session.postEntry,
      cashFlow: session.cashFlow,
      sales: session.sales,
      inventoryReport: session.inventoryReport,
      categoryReport: session.categoryReport,
      tax: session.tax,
    );

    // `forAccount` is what runs on sign-in and on sign-out. With no account it
    // simply rebuilds the bundle, and nothing may be lost.
    final after = services.forAccount();

    expect(after.trialBalance, isNotNull, reason: 'trial balance');
    expect(after.createCustomer, isNotNull, reason: 'customer');
    expect(after.createProduct, isNotNull, reason: 'product');
    expect(after.postMovement, isNotNull, reason: 'stock movement');
    expect(after.issueCreditNote, isNotNull, reason: 'credit note');
    expect(after.postEntry, isNotNull, reason: 'journal entry');
    expect(after.cashFlow, isNotNull, reason: 'cash flow');
    expect(after.sales, isNotNull, reason: 'sales');
    expect(after.inventoryReport, isNotNull, reason: 'inventory');
    expect(after.categoryReport, isNotNull, reason: 'category report');
    expect(after.tax, isNotNull, reason: 'VAT');
  });

  test('a year switcher produces a session whose reports read that year',
      () async {
    // The reports must belong to the open year, not to whatever year happened to
    // be open when the use case was first built.
    final directory = Directory.systemTemp.createTempSync('services-open');
    addTearDown(() => directory.deleteSync(recursive: true));
    final session = await sessionIn(directory);

    await session.open(fiscalYear);

    expect(session.cashFlow.fiscalYear.label, fiscalYear.label);
    expect(session.sales.fiscalYear.label, fiscalYear.label);
    expect(session.inventoryReport.fiscalYear.label, fiscalYear.label);
    expect(session.categoryReport.fiscalYear.label, fiscalYear.label);
    expect(session.tax.fiscalYear.label, fiscalYear.label);
  });
}
