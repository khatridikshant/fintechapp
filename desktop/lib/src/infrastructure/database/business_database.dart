import 'package:drift/drift.dart';

part 'business_database.g.dart';

/// The schema version of [BusinessDatabase].
///
/// Separate from the year databases' version, because this database is upgraded
/// in place forever while a year database is archived and must never be rewritten.
const int businessSchemaVersion = 1;

/// Business-level data: who this business is.
///
/// ## Why it is not in a fiscal year's database
///
/// Every fiscal year has its own database file, so anything put in one belongs to
/// *that year*. **The business profile does not belong to a year.** It is the
/// name, address, PAN, and VAT status of the same business, and it changes rarely
/// if at all. Keeping it in the trading year's file meant a new fiscal year
/// started with no business details, so the owner had to retype them every
/// Ashadh — and an invoice risked printing without a PAN, which makes it invalid.
///
/// It lives here instead, in one small database beside the year files, under a name
/// that **deliberately does not match `accounting-FY-*.db`**, the pattern
/// `FileBooksSession` uses to discover years.
///
/// ## An invoice does not yet record what it used
///
/// The intent was for each invoice to carry its own copy of the seller details,
/// so a profile change would leave historical invoices exactly as issued.
/// **`Invoice` has no seller fields yet**, so a historical invoice shows the
/// business details as they are now. Recorded as a gap rather than a claim.
@DriftDatabase(tables: [BusinessProfiles])
class BusinessDatabase extends _$BusinessDatabase {
  /// Opens, creating it on first run.
  BusinessDatabase(super.e);

  @override
  int get schemaVersion => businessSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Only version 1 exists. Future tables get guarded steps here, exactly as
          // the year databases do -- and they can be added without touching a
          // single archived year.
        },
      );
}

/// The business profile, stored in its own file beside the year databases.
///
/// A **singleton** table. ADR 003 allows one book per account in V1, so there is
/// one business and a fixed key says so, which is honest about the current scope
/// rather than pretending to be general.
@DataClassName('BusinessProfileRow')
class BusinessProfiles extends Table {
  /// Always `primary` for V1: one row, by design.
  TextColumn get id => text()();

  /// The registered name, printed as the supplier on every invoice.
  TextColumn get name => text()();

  /// The tax identity, as nine digits, or null.
  TextColumn get pan => text().nullable()();

  /// Whether VAT registration is active. Stated by the owner, never inferred:
  /// whether registration is *compulsory* depends on a turnover threshold the
  /// Finance Act resets every year. See `PROGRESS.md` section 5.1.
  BoolColumn get isVatRegistered =>
      boolean().withDefault(const Constant(false))();

  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get bankDetails => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  /// The database refuses a nameless business.
  ///
  /// The domain guarantees it, so this only fires if something writes here without
  /// going through the domain -- which is exactly the case it exists to catch.
  @override
  List<String> get customConstraints => [
        "CHECK (trim(name) <> '')",
      ];
}
