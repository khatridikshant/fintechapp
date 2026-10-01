import 'package:financeapp/src/application/issue_invoice.dart';
import 'package:financeapp/src/domain/accounting/chart_of_accounts.dart';
import 'package:financeapp/src/domain/billing/business_profile.dart';
import 'package:financeapp/src/domain/billing/business_profile_repository.dart';
import 'package:financeapp/src/domain/billing/customer.dart';
import 'package:financeapp/src/domain/billing/invoice.dart';
import 'package:financeapp/src/domain/billing/invoice_line.dart';
import 'package:financeapp/src/domain/fiscal/fiscal_year.dart';
import 'package:financeapp/src/domain/shared/money.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/drift_account_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_customer_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_document_number_sequence.dart';
import 'package:financeapp/src/infrastructure/database/drift_invoice_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_journal_repository.dart';
import 'package:financeapp/src/infrastructure/database/drift_unit_of_work.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The seller details must be copied onto the invoice **by the use case**, and
/// before the document is recorded.
///
/// The printed invoice is the evidence in an audit. If the record held only a
/// reference to the business, then changing the address in Settings would make
/// last year's invoices disagree with the paper the customer was handed.
void main() {
  late AppDatabase db;
  late _FakeBusinessProfileRepository sellers;

  final fiscalYear = FiscalYear(
    label: 'FY 2082/83',
    start: DateTime(2026, 7), // 1 Shrawan 2083
    end: DateTime(2027, 7),
  );

  setUp(() {
    db = openInMemoryDatabase();
    sellers = _FakeBusinessProfileRepository();
  });

  tearDown(() async => db.close());

  Invoice anInvoice() => Invoice(
        id: 'inv-1',
        issueDate: DateTime(2026, 8, 15),
        customerId: 'cust-1',
        lines: [
          InvoiceLine(
            description: 'Keyboard',
            quantity: 1,
            unitPrice: Money.fromMajorUnits(100000, 'NPR'),
          ),
        ],
      );

  IssueInvoice useCase() => IssueInvoice(
        fiscalYear: fiscalYear,
        customers: DriftCustomerRepository(db),
        numbers: DriftDocumentNumberSequence(db),
        journal: DriftJournalRepository(db),
        invoices: DriftInvoiceRepository(db),
        unitOfWork: DriftUnitOfWork(db),
        sellers: sellers,
      );

  setUp(() async {
    await DriftCustomerRepository(db).save(
      Customer(
        id: 'cust-1',
        name: 'Himalayan Traders',
        panNumber: '301234567',
      ),
    );
    // The journal lines reference chart-of-accounts ids, so the accounts must
    // exist or the foreign key fails before anything under test runs.
    await DriftAccountRepository(db).saveAll(ChartOfAccounts().all);
  });

  test('the issued invoice carries the seller details as printed', () async {
    await sellers.save(BusinessProfile(
      name: 'Sharma Electronics Pvt. Ltd.',
      panNumber: '301234567',
      address: 'New Road, Kathmandu',
    ));

    final outcome = await useCase()(anInvoice());

    expect(outcome, isA<InvoiceIssued>());
    final issued = outcome as InvoiceIssued;
    expect(issued.invoice.sellerName, 'Sharma Electronics Pvt. Ltd.');
    expect(issued.invoice.sellerPan, '301234567');
  });

  test('the stored document carries them too, not just the returned value',
      () async {
    // The record is what a report or an audit reads back, so stamping only the
    // returned object would be a fix that does not survive.
    await sellers.save(BusinessProfile(
      name: 'Sharma Electronics Pvt. Ltd.',
      panNumber: '301234567',
    ));

    final outcome = await useCase()(anInvoice()) as InvoiceIssued;
    final stored = await DriftInvoiceRepository(db).byId('inv-1');

    expect(stored, isNotNull);
    expect(stored!.invoice.sellerName, 'Sharma Electronics Pvt. Ltd.');
    expect(stored.invoice.sellerPan, '301234567');
    // The same values that came back, so the two cannot disagree.
    expect(stored.invoice.sellerPan, outcome.invoice.sellerPan);
  });

  test('a profile with no PAN is stamped as absent, not invented', () async {
    // Never fabricate a number: a wrong PAN on a bill is worse than none, because
    // it looks compliant and is not.
    await sellers.save(BusinessProfile(name: 'Not Registered Yet'));

    final outcome = await useCase()(anInvoice()) as InvoiceIssued;

    expect(outcome.invoice.sellerName, 'Not Registered Yet');
    expect(outcome.invoice.sellerPan, isNull);
  });

  test('no business profile at all leaves the snapshot empty', () async {
    // A fresh installation has no profile. The invoice still issues, and
    // `InvoiceCompliance` reports the missing snapshot rather than this silently
    // producing an unevidenced document.
    final outcome = await useCase()(anInvoice()) as InvoiceIssued;

    expect(outcome.invoice.sellerName, isNull);
    expect(outcome.invoice.sellerPan, isNull);
  });
}

/// A seller store the test controls.
///
/// The real one is backed by `business.db` and is covered by
/// `business_profile_persistence_test.dart`; this is here to test the use case,
/// not the storage.
class _FakeBusinessProfileRepository implements BusinessProfileRepository {
  BusinessProfile? profile;

  @override
  Future<BusinessProfile?> load() async => profile;

  @override
  Future<void> save(BusinessProfile next) async => profile = next;
}
