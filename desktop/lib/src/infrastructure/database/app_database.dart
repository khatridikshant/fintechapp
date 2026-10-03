import 'package:drift/drift.dart';

// Required by the generated part file, which references AccountType. Imports
// are not transitive through `tables.dart`, so the type must be in scope here.
import '../../domain/accounting/account_type.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The schema version this application writes.
///
/// A top-level constant rather than a literal inside the getter, because more
/// than one place has to know it: the database declares it to drift, and the
/// backup upload declares it to the server. Two copies of the number would drift
/// apart, and the server uses it to decide how to read the snapshot.
const int currentSchemaVersion = 16;

/// The local SQLite database for one fiscal year.
///
/// The architecture requires one database per fiscal year, so this class models
/// a single year's book and never spans years.
@DriftDatabase(
  tables: [
    Accounts,
    JournalEntries,
    JournalLines,
    DocumentSequences,
    Customers,
    // ADR 012: suppliers, the other side of a purchase.
    Suppliers,
    SupplierDetails,
    Invoices,
    InvoiceLines,
    Payments,
    CreditNotes,
    CreditNoteLines,
    Products,
    InventoryMovements,
    ProductCategories,
    ProductCategoryAssignments,
    Purchases,
    PurchaseLines,
    SupplierPayments,
    CustomerDetails,
    InvoiceSellers,
    CustomerCodeSequences,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Bump this whenever the schema changes, and add a migration step in
  /// [migration]. A schema change without a migration is prohibited.
  ///
  /// Version history:
  ///   1  accounts, journal_entries, journal_lines
  ///   2  document_sequences
  ///   3  customers
  ///   4  invoices, invoice_lines
  ///   5  payments
  ///   6  credit_notes, credit_note_lines
  ///   7  products, inventory_movements
  ///   8  inventory_movements.journal_entry_id
  ///   9  inventory_movements allows a value-only write-down
  ///   10 customer_details
  ///   11 invoice_sellers
  ///   12 customer_code_sequences
  ///   13 suppliers, supplier_details
  ///   14 product_categories, product_category_assignments
  ///   15 purchases, purchase_lines
  ///   16 supplier_payments
  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Stepwise, additive migrations only. Never drop and recreate: an
          // existing database holds the user's books, and recreating a table
          // would silently discard them.
          //
          // Each step is guarded by its own version, so a database that is
          // several versions behind runs every step it needs rather than only
          // the last.
          if (from < 2) {
            await m.createTable(documentSequences);
          }
          if (from < 3) {
            await m.createTable(customers);
          }
          if (from < 4) {
            // Invoices reference customers and journal entries, so both of
            // those tables must already exist. The ordering above guarantees it.
            await m.createTable(invoices);
            await m.createTable(invoiceLines);
          }
          if (from < 5) {
            // Payments reference invoices and accounts, both of which exist by
            // this point.
            await m.createTable(payments);
          }
          if (from < 6) {
            // Credit notes reference invoices and journal entries.
            await m.createTable(creditNotes);
            await m.createTable(creditNoteLines);
          }
          if (from < 7) {
            // Products first, because movements reference them.
            //
            // Note: `createTable` writes the table's **current** definition, so
            // the movement table is created already carrying the v8 column. That
            // is why the v8 step below must not run on this path.
            await m.createTable(products);
            await m.createTable(inventoryMovements);
          } else if (from < 8) {
            // The movement table already exists at its v7 shape and needs the
            // journal entry link added.
            //
            // This is a table **rebuild**, not `addColumn`, because SQLite cannot
            // add a foreign key with `ALTER TABLE ADD COLUMN` — it would silently
            // produce a table missing the constraint, and the link between a
            // movement and its entry would then be enforced only by luck.
            // `TableMigration` recreates the table with the new definition and
            // copies the existing rows across, so no movement is lost.
            //
            // The transformer supplies `null` for the new column: rows written
            // before posting existed genuinely have no entry, and inventing one
            // would put a fabricated figure in the books.
            //
            // TableMigration is marked experimental by drift, and is used
            // deliberately: it is the supported way to change a table's
            // constraints on SQLite.
            await m.alterTable(
              // ignore: experimental_member_use
              TableMigration(
                inventoryMovements,
                columnTransformer: {
                  inventoryMovements.journalEntryId:
                      const Constant<Object>(null),
                },
              ),
            );
          } else if (from < 9) {
            // Relaxing a CHECK to allow a value-only write-down. A CHECK cannot
            // be altered in place on SQLite either, so this is another table
            // rebuild. No row can violate the new constraint that did not already
            // satisfy the old one, because the new one only permits more.
            await m.alterTable(
              // ignore: experimental_member_use
              TableMigration(inventoryMovements),
            );
          }
          if (from < 10) {
            // Customer identity and tax details, in their own table.
            //
            // **Deliberately additive and self-contained.** No existing table is
            // touched, which is what keeps every v1-v9 migration test valid: a
            // database older than v10 simply has no `customer_details` table, and
            // a database that already has `customers` is unaffected. Adding these
            // as columns on `customers` instead would have changed the shape that
            // `createTable` produces for every pre-v3 database.
            //
            // `customers` exists by v3 and v10 is later, so the foreign key's
            // target always exists by the time this runs.
            await m.createTable(customerDetails);
          }
          if (from < 11) {
            // The seller details printed on each invoice.
            //
            // **A new table, so nothing existing is touched** and every v1-v10
            // migration test stays valid -- the same reasoning as
            // `customer_details`. `invoices` exists by v4, so the foreign key's
            // target always exists by the time this runs.
            await m.createTable(invoiceSellers);
          }
          if (from < 12) {
            // The lifetime customer-code counter.
            //
            // A new table, so nothing existing is touched and every earlier
            // migration test stays valid.
            await m.createTable(customerCodeSequences);
          }
          if (from < 13) {
            // Suppliers, and their display and tax details. See ADR 012.
            //
            // **New tables only**, so nothing existing is touched and every earlier
            // migration test stays valid.
            await m.createTable(suppliers);
            await m.createTable(supplierDetails);
          }
          if (from < 14) {
            // Product categories, and the assignment of a product to one.
            //
            // **New tables only.** A `category_id` column on `products` was
            // rejected for the reason ADR 010 records: `createTable` writes the
            // current definition, so a v1-to-v16 database would create `products`
            // already carrying the column while a v7-to-v16 one would not, and
            // every older schema snapshot would disagree about the shape of the
            // same table. A table absent from every earlier snapshot keeps
            // `products` frozen at its v7 shape and leaves all existing migration
            // tests valid.
            //
            // Order matters: the assignment references both, so both must exist
            // first.
            await m.createTable(productCategories);
            await m.createTable(productCategoryAssignments);
          }
          if (from < 15) {
            // Purchases and their lines. See ADR 012.
            //
            // **New tables only**, for the same reason as above. Purchases
            // reference suppliers (v13) and journal entries (v1); lines reference
            // purchases and products (v7). All three exist by this point.
            await m.createTable(purchases);
            await m.createTable(purchaseLines);
          }
          if (from < 16) {
            // Payments made to suppliers, settling part or all of a purchase.
            //
            // A new table, so nothing existing is touched. References `purchases`
            // (v15) and `accounts` (v1), both of which exist by now.
            await m.createTable(supplierPayments);
          }
        },
        beforeOpen: (OpeningDetails details) async {
          // Note: `PRAGMA foreign_keys` is per-connection state, so it is NOT
          // set here. It is applied through the `setup` hook in
          // `sqlite_native.dart`, which runs for every connection the executor
          // opens. Setting it here only configures one connection and silently
          // stops enforcing foreign keys once the executor pools connections.
        },
      );
}
