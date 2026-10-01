import 'dart:io';

import 'package:path/path.dart' as p;

import 'business_database.dart';
import 'sqlite_native.dart';

/// The business database's file name.
///
/// **Deliberately not `accounting-FY-*.db`.** `FileBooksSession` discovers fiscal
/// years with `^accounting-FY-(\d{4})-(\d{2})\.db$`, so this name cannot be
/// mistaken for a year, cannot be opened read-only as a concluded year, and cannot
/// appear in the year list the user sees.
const String businessDatabaseName = 'business.db';

/// Opens the business database that sits beside the fiscal-year databases.
BusinessDatabase openBusinessDatabase(Directory booksDirectory) =>
    BusinessDatabase(
      openExecutor(File(p.join(booksDirectory.path, businessDatabaseName))),
    );
