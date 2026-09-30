import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';
import 'sqlite_native.dart';

/// Opens the on-disk database for the running application.
///
/// The architecture requires one SQLite database per fiscal year, so the caller
/// passes the fiscal-year file name, for example `accounting-FY-2082-83.db`.
/// This function never guesses the year.
///
/// Lives in its own file because it depends on a Flutter plugin
/// (`path_provider`), which must not be pulled into plain VM tests.
Future<AppDatabase> openApplicationDatabase(String fiscalYearFileName) async {
  configureNativeSqlite();
  final directory = await getApplicationSupportDirectory();
  final file = File(p.join(directory.path, fiscalYearFileName));
  await file.parent.create(recursive: true);
  return AppDatabase(
    NativeDatabase(file, setup: enforceForeignKeys),
  );
}
