import 'dart:ffi';
import 'dart:io';

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

/// A throwaway in-memory database. Used by tests and scratch work.
AppDatabase openInMemoryDatabase() {
  configureNativeSqlite();
  return AppDatabase(NativeDatabase.memory(setup: enforceForeignKeys));
}

/// An on-disk database at an explicit path.
///
/// Used by tests that must prove data survives closing and reopening the file.
AppDatabase openFileDatabase(File file) {
  configureNativeSqlite();
  return AppDatabase(NativeDatabase(file, setup: enforceForeignKeys));
}
