import 'package:drift/drift.dart';

import '../../domain/accounting/account_type.dart';

/// Storage rows.
///
/// These are deliberately dumb. They contain no accounting rules; the rules
/// live in `domain/accounting/`. The tables exist to persist what the domain
/// decided, and to refuse obviously corrupt rows as a second line of defence.
///
/// The generated data class names are overridden with `@DataClassName` so that
/// drift does not generate `Account`, `JournalEntry`, and `JournalLine`, which
/// would collide with the domain types of the same name.

@DataClassName('AccountRow')
class Accounts extends Table {
  TextColumn get id => text()();

  TextColumn get code => text().unique()();

  TextColumn get name => text()();

  TextColumn get type => textEnum<AccountType>()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('JournalEntryRow')
class JournalEntries extends Table {
  TextColumn get id => text()();

  DateTimeColumn get date => dateTime()();

  TextColumn get description => text()();

  TextColumn get reference => text().nullable()();

  /// Currency of the whole entry. V1 is single-currency per book, so this is
  /// recorded once on the header and repeated on lines for query convenience.
  TextColumn get currency => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('JournalLineRow')
class JournalLines extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Insertion order, used to reconstruct the entry's line order.
  TextColumn get journalEntryId => text()();

  TextColumn get accountId => text()();

  /// Amount in minor units, for example paisa. **Integer, never REAL.**
  ///
  /// A REAL column would reintroduce binary floating point at the storage
  /// boundary and silently corrupt amounts. This is the single most important
  /// column type in the schema.
  IntColumn get debitMinorUnits => integer().withDefault(const Constant(0))();

  IntColumn get creditMinorUnits => integer().withDefault(const Constant(0))();

  TextColumn get currency => text()();

  /// The database refuses rows the domain would never produce.
  ///
  /// The domain already guarantees a line is one side or the other, so these
  /// checks fire only if something writes to the database without going through
  /// the domain. That is exactly the case they exist to catch.
  ///
  /// The foreign keys are declared here rather than with drift's
  /// `.references()` helper. On drift 2.31 that helper silently produced no
  /// constraint at all: the generated columns carried no `defaultConstraints`,
  /// the `CREATE TABLE` had no `REFERENCES` clause, and every foreign key test
  /// quietly stopped failing. Declaring the keys explicitly is verifiable and
  /// does not depend on generator behaviour. A test asserts the declared keys
  /// exist, so this cannot regress unnoticed again.
  @override
  List<String> get customConstraints => [
        'CHECK (debit_minor_units >= 0 AND credit_minor_units >= 0)',
        'CHECK ((debit_minor_units > 0 AND credit_minor_units = 0) '
            'OR (credit_minor_units > 0 AND debit_minor_units = 0))',
        'FOREIGN KEY (journal_entry_id) REFERENCES journal_entries(id)',
        'FOREIGN KEY (account_id) REFERENCES accounts(id)',
      ];
}

/// The next serial to hand out, per document type and fiscal year.///
/// ADR 005 requires the sequence to be independent per document type and per
/// fiscal year, so the pair is the primary key. A row exists only once a
/// document of that type has actually been issued in that year, which is what
/// makes "a draft does not consume a serial" true at the storage level: creating
/// a draft does not create a row here.
@DataClassName('DocumentSequenceRow')
class DocumentSequences extends Table {
  /// The `DocumentType` name, for example `invoice`.
  TextColumn get documentType => text()();

  /// The fiscal year label, for example `FY 2082/83`.
  TextColumn get fiscalYearLabel => text()();

  /// Highest serial already allocated. Never negative.
  IntColumn get lastSequence => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {documentType, fiscalYearLabel};

  @override
  List<String> get customConstraints => [
        'CHECK (last_sequence >= 0)',
      ];
}

/// Customers the business invoices.
///
/// The id is supplied by the caller and is permanent. Optional fields are
/// nullable rather than defaulted to an empty string, so that "not provided" has
/// exactly one representation.
@DataClassName('CustomerRow')
class Customers extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get panNumber => text().nullable()();

  TextColumn get phone => text().nullable()();

  TextColumn get address => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  /// The database refuses a customer with no name.
  ///
  /// The domain already guarantees this, so the check fires only if something
  /// writes to the database without going through the domain. That is exactly
  /// the case it exists to catch.
  @override
  List<String> get customConstraints => [
        "CHECK (trim(name) <> '')",
      ];
}

/// Identity and tax details that do not belong on `customers` itself.
///
/// **Why a separate table rather than more columns on `customers`.** Adding
/// columns to `customers` turned out to be far harder than it looks: `createTable`
/// writes the table's *current* definition, so every older-version migration test
/// acquired the new columns and many broke. A table that did not exist before v10
/// is simply absent from every v1-v9 snapshot, so `customers` stays frozen at its
/// v3 shape and those tests are untouched. See ADR 010.
///
/// ## Why these are not on `customers`
///
/// `id` and `name` identify a customer; these are *attributes of its tax status*
/// that were added later. Keeping them apart means adding another such attribute
/// later is a new table rather than a risky change to a table the books depend on.
@DataClassName('CustomerDetailRow')
class CustomerDetails extends Table {
  /// The customer this describes. One row per customer at most.
  TextColumn get customerId =>
      text().references(Customers, #id, onDelete: KeyAction.cascade)();

  /// The business reference, such as `C-0001`. Not the identity.
  TextColumn get code => text().nullable()();

  /// Whether VAT registration is active. Stated, never inferred -- see
  /// `Customer.isVatRegistered` for why.
  BoolColumn get isVatRegistered =>
      boolean().withDefault(const Constant(false))();

  /// The registered business name, where it differs from the contact name.
  TextColumn get businessName => text().nullable()();

  @override
  Set<Column> get primaryKey => {customerId};

  /// Two customers must not end up quotable as the same reference.
  @override
  List<Set<Column>> get uniqueKeys => [
        {code},
      ];
}

/// Issued invoices.
///
/// An invoice is a record, not merely the journal entry it produced. Without
/// this table an invoice cannot be listed, reprinted, or marked as paid, and the
/// receivable it created cannot be broken down by customer.
///
/// The totals are a denormalisation for listing and printing. They are derived
/// from the lines in the domain, and **recomputation stays authoritative**; a
/// test asserts the stored values equal the recomputed ones so the two cannot
/// silently diverge.
@DataClassName('InvoiceRow')
class Invoices extends Table {
  TextColumn get id => text()();

  /// The printed document number. Unique, because reissuing one is prohibited.
  TextColumn get number => text().unique()();

  /// The sequence part of [number], kept separately so it can be ordered and
  /// audited without parsing the formatted string.
  IntColumn get sequence => integer()();

  TextColumn get fiscalYearLabel => text()();

  TextColumn get customerId => text()();

  DateTimeColumn get issueDate => dateTime()();

  TextColumn get currency => text()();

  /// The VAT rate applied, in basis points.
  ///
  /// Stored rather than inferred. Without it a reloaded invoice could not
  /// reproduce its own VAT, and deriving the rate back out of the stored
  /// subtotal and VAT amount would be lossy and would break for a zero-rated
  /// invoice.
  IntColumn get vatRateBasisPoints => integer()();

  /// All amounts are **INTEGER minor units**, never REAL.
  IntColumn get subtotalMinorUnits => integer()();

  IntColumn get vatMinorUnits => integer()();

  IntColumn get totalMinorUnits => integer()();

  /// The journal entry that records the sale. A foreign key, so an invoice
  /// cannot exist without the accounting behind it.
  TextColumn get journalEntryId => text()();

  @override
  Set<Column> get primaryKey => {id};

  /// Foreign keys are declared explicitly rather than with drift's
  /// `.references()`, which silently produced nothing on drift 2.31. See the
  /// note on `JournalLines`.
  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (customer_id) REFERENCES customers(id)',
        'FOREIGN KEY (journal_entry_id) REFERENCES journal_entries(id)',
        'CHECK (sequence >= 1)',
        'CHECK (vat_rate_basis_points >= 0)',
        'CHECK (subtotal_minor_units >= 0)',
        'CHECK (vat_minor_units >= 0)',
        'CHECK (total_minor_units >= 0)',
        "CHECK (trim(id) <> '')",
      ];
}

/// The seller details **as printed on** a given invoice.
///
/// ## Why a separate table rather than two more columns on `invoices`
///
/// Adding a column to `invoices` would change the shape `createTable` produces for
/// every database older than the new version, and that broke the migration tests
/// when this was tried on `customers` (ADR 010). A table that did not exist before
/// v11 is simply absent from every earlier snapshot, so the existing tests are
/// untouched.
///
/// The alternative — regenerating the older snapshots to match — was tried and is
/// the reason the pattern exists: it does not reliably propagate to
/// `test/generated/`, and it rewrites the historical record of what each version
/// contained.
@DataClassName('InvoiceSellerRow')
class InvoiceSellers extends Table {
  /// The invoice this was printed on.
  TextColumn get invoiceId => text().references(Invoices, #id)();

  /// The registered business name as printed.
  TextColumn get sellerName => text()();

  /// The PAN as printed, as nine digits.
  TextColumn get sellerPan => text()();

  @override
  Set<Column> get primaryKey => {invoiceId};
}

/// The lines of an issued invoice.
///
/// Stored because an invoice must be reprintable. A journal line records an
/// account and an amount, not what was sold, so the description, quantity, and
/// unit price have nowhere else to live.
@DataClassName('InvoiceLineRow')
class InvoiceLines extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get invoiceId => text()();

  /// Position on the invoice, starting at 1. Preserves the order the lines were
  /// entered in, which is the order they print in.
  IntColumn get lineNumber => integer()();

  TextColumn get description => text()();

  IntColumn get quantity => integer()();

  IntColumn get unitPriceMinorUnits => integer()();

  TextColumn get currency => text()();

  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (invoice_id) REFERENCES invoices(id)',
        'CHECK (line_number >= 1)',
        'CHECK (quantity >= 1)',
        'CHECK (unit_price_minor_units > 0)',
        "CHECK (trim(description) <> '')",
      ];
}

/// Payments received from customers, each settling part or all of an invoice.
///
/// The outstanding balance of an invoice is never stored. It is derived from the
/// invoice total and these rows, so it cannot drift from the payments that
/// produced it.
@DataClassName('PaymentRow')
class Payments extends Table {
  TextColumn get id => text()();

  TextColumn get invoiceId => text()();

  DateTimeColumn get date => dateTime()();

  /// Amount in minor units, for example paisa. **Integer, never REAL.**
  IntColumn get amountMinorUnits => integer()();

  TextColumn get currency => text()();

  /// The account the money arrived in, for example Bank or Cash.
  TextColumn get accountId => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (invoice_id) REFERENCES invoices(id)',
        'FOREIGN KEY (account_id) REFERENCES accounts(id)',
        'CHECK (amount_minor_units > 0)',
        "CHECK (trim(id) <> '')",
      ];
}

/// Credit notes, which are how a posted invoice is corrected.
///
/// ADR 005 prohibits editing or deleting an issued invoice, so a customer
/// returning goods, a pricing error, or an after-the-fact discount is recorded
/// here instead and posted as a reversal.
///
/// Like an invoice, the totals are a denormalisation for listing and printing.
/// They are derived from the lines in the domain and **recomputation stays
/// authoritative**.
@DataClassName('CreditNoteRow')
class CreditNotes extends Table {
  TextColumn get id => text()();

  /// The printed document number, from its own `CRN` sequence.
  TextColumn get number => text().unique()();

  IntColumn get sequence => integer()();

  TextColumn get fiscalYearLabel => text()();

  /// The invoice being credited. Required, so every correction is traceable.
  TextColumn get invoiceId => text()();

  DateTimeColumn get date => dateTime()();

  TextColumn get currency => text()();

  IntColumn get vatRateBasisPoints => integer()();

  /// All amounts are **INTEGER minor units**, never REAL.
  IntColumn get subtotalMinorUnits => integer()();

  IntColumn get vatMinorUnits => integer()();

  IntColumn get totalMinorUnits => integer()();

  TextColumn get journalEntryId => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (invoice_id) REFERENCES invoices(id)',
        'FOREIGN KEY (journal_entry_id) REFERENCES journal_entries(id)',
        'CHECK (sequence >= 1)',
        'CHECK (vat_rate_basis_points >= 0)',
        'CHECK (subtotal_minor_units >= 0)',
        'CHECK (vat_minor_units >= 0)',
        'CHECK (total_minor_units >= 0)',
        "CHECK (trim(id) <> '')",
      ];
}

/// The lines of a credit note, so it can be reprinted like an invoice.
@DataClassName('CreditNoteLineRow')
class CreditNoteLines extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get creditNoteId => text()();

  IntColumn get lineNumber => integer()();

  TextColumn get description => text()();

  IntColumn get quantity => integer()();

  IntColumn get unitPriceMinorUnits => integer()();

  TextColumn get currency => text()();

  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (credit_note_id) REFERENCES credit_notes(id)',
        'CHECK (line_number >= 1)',
        'CHECK (quantity >= 1)',
        'CHECK (unit_price_minor_units > 0)',
        "CHECK (trim(description) <> '')",
      ];
}

/// Products the business sells.
///
/// **There is no cost column, deliberately.** ADR 004 chose moving weighted
/// average with the running inventory *value* authoritative, and the cost per
/// unit is derived from that value. A stored cost would be a second source of
/// truth that drifts. See `docs/INVENTORY_EXPLAINED.md`.
@DataClassName('ProductRow')
class Products extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  /// Sale price in **INTEGER minor units**, never REAL.
  IntColumn get salePriceMinorUnits => integer()();

  TextColumn get currency => text()();

  BoolColumn get stockTrackingEnabled => boolean()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (sale_price_minor_units >= 0)',
        "CHECK (trim(name) <> '')",
        "CHECK (trim(id) <> '')",
      ];
}

/// Every change in a product's stock, with a reason.
///
/// Specification section 14 requires every stock change to have a reason, and
/// section 33 requires that movements are never deleted — corrections use
/// compensating movements.
///
/// `quantity` and `value_minor_units` are **both signed and always point the same
/// way**, enforced by a CHECK. That is what lets the quantity on hand and the
/// value on hand each be a plain sum of the rows.
@DataClassName('InventoryMovementRow')
class InventoryMovements extends Table {
  TextColumn get id => text()();

  TextColumn get productId => text()();

  DateTimeColumn get date => dateTime()();

  /// The `MovementReason` name, for example `purchase`.
  TextColumn get reason => text()();

  /// Signed units. Positive is stock coming in.
  IntColumn get quantity => integer()();

  /// Signed value in minor units. Same sign as `quantity`.
  IntColumn get valueMinorUnits => integer()();

  TextColumn get currency => text()();

  /// The journal entry this movement posted, once it has been posted.
  ///
  /// **Nullable only for rows written before v8, and for a non-stock-tracked
  /// product where a movement may carry no accounting.** Every movement written
  /// by the posting use case sets it. It is not made non-nullable because
  /// backfilling a value that does not exist would be a lie, and because a
  /// movement is a physical fact that must be recordable even when its accounting
  /// is still pending.
  TextColumn get journalEntryId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (product_id) REFERENCES products(id)',
        'FOREIGN KEY (journal_entry_id) REFERENCES journal_entries(id)',
        // A movement changes the quantity, the value, or both.
        'CHECK (quantity <> 0 OR value_minor_units <> 0)',
        // When both change they point the same way. A **value-only** movement is
        // allowed, and is how a write-down is recorded: the goods are still held,
        // so only the carrying value falls.
        'CHECK ((quantity > 0 AND value_minor_units > 0) '
            'OR (quantity < 0 AND value_minor_units < 0) '
            'OR (quantity = 0 AND value_minor_units <> 0))',
        "CHECK (trim(id) <> '')",
      ];
}
