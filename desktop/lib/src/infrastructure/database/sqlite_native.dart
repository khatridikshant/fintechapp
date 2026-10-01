import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'app_database.dart';

/// Native SQLite wiring that works in a plain Dart VM.
///
/// Deliberately free of Flutter plugin imports, so it can be used by tests.
/// The application-side opener lives in `connection.dart`, which adds the
/// platform directory lookup on top of this.

bool _configured = false;

/// Makes a native SQLite library available to the current process.
///
/// The application gets its SQLite from `sqlite3_flutter_libs`, but that is a
/// Flutter plugin and is not loaded by `flutter test`. On Windows the fallback
/// is `winsqlite3.dll`, which ships with the operating system. On macOS and
/// Linux the `sqlite3` package locates the system library itself.
void configureNativeSqlite() {
  if (_configured) return;
  _configured = true;
  if (Platform.isWindows) {
    open.overrideFor(
      OperatingSystem.windows,
      () => DynamicLibrary.open('winsqlite3.dll'),
    );
  }
}

/// Turns on foreign key enforcement for one underlying SQLite connection.
///
/// This is applied through drift's `setup` hook, which runs for **every**
/// connection the executor opens, rather than once in `MigrationStrategy`.
///
/// That distinction is load-bearing. `PRAGMA foreign_keys` is per-connection
/// state, not a property of the database file. When it was set in the migration
/// strategy it worked under drift 2.23, which used a single connection, and
/// silently stopped working under drift 2.31, where a connection may be opened
/// per operation. The database is the second line of defence, so foreign keys
/// must be enforced on the connection that is actually doing the writing.
void enforceForeignKeys(sqlite.Database database) {
  database.execute('PRAGMA foreign_keys = ON');
}

/// Forces the connection to refuse every write for its whole lifetime.
///
/// `PRAGMA query_only` is per-connection, like `foreign_keys`, so it is applied
/// through the `setup` hook to every connection the executor opens. A historical
/// fiscal year must be opened read-only (specification sections 21 and 26), and
/// "read-only" has to mean enforced rather than intended: a screen with no save
/// button is not the same as a database that cannot be written to.
///
/// A write on such a connection fails with *"attempt to write a readonly
/// database"*, which is testable, which is the point.
void forceReadOnly(sqlite.Database database) {
  database.execute('PRAGMA query_only = ON');
}

/// Applies both guards, for a writable connection.
void _writableSetup(sqlite.Database database) => enforceForeignKeys(database);

/// Applies both guards, for a read-only connection.
void _readOnlySetup(sqlite.Database database) {
  enforceForeignKeys(database);
  forceReadOnly(database);
}

/// A throwaway in-memory database. Used by tests and scratch work.
AppDatabase openInMemoryDatabase({bool readOnly = false}) {
  configureNativeSqlite();
  return AppDatabase(
    NativeDatabase.memory(setup: readOnly ? _readOnlySetup : _writableSetup),
  );
}

/// An on-disk database at an explicit path.
///
/// Used by tests that must prove data survives closing and reopening the file.
///
/// Set [readOnly] for a concluded fiscal year. The specification requires
/// historical years to be opened read-only, and this enforces that at the
/// database rather than trusting every caller to remember.
AppDatabase openFileDatabase(File file, {bool readOnly = false}) {
  configureNativeSqlite();
  return AppDatabase(
    NativeDatabase(file, setup: readOnly ? _readOnlySetup : _writableSetup),
  );
}

/// A configured **executor**, for a database other than [AppDatabase].
///
/// The business database is a second, smaller schema beside the year databases,
/// so it needs the same SQLite setup -- **`PRAGMA query_only` per connection**
/// included -- without being an `AppDatabase`. Reusing [openFileDatabase] would
/// build the wrong schema over it.
QueryExecutor openExecutor(File file) {
  configureNativeSqlite();
  return NativeDatabase(file, setup: _writableSetup);
}

/// A throwaway in-memory [QueryExecutor], for tests of the business database.
QueryExecutor openInMemoryExecutor() {
  configureNativeSqlite();
  return NativeDatabase.memory(setup: _writableSetup);
}
