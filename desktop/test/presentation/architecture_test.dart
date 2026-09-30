import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the layer boundaries that `docs/AI_RULES.md` states as hard rules.
///
/// A screen that imports a repository compiles, runs, and quietly breaks the
/// architecture. Nothing else in the toolchain complains, so these tests exist to
/// complain instead.
void main() {
  /// Every Dart file under a directory, recursively.
  List<File> dartFilesIn(String relativeDirectory) {
    final directory = Directory(relativeDirectory);
    if (!directory.existsSync()) {
      fail('expected $relativeDirectory to exist');
    }
    return directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        // Generated code is not ours to police.
        .where((file) => !file.path.endsWith('.g.dart'))
        .toList();
  }

  group('The presentation layer does not reach past the application layer', () {
    test('no screen imports a repository or a drift type', () {
      final offenders = <String>[];

      for (final file in dartFilesIn('lib/src/presentation')) {
        final source = file.readAsStringSync();
        for (final line in source.split('\n')) {
          if (!line.trimLeft().startsWith('import ')) continue;
          if (line.contains('src/infrastructure/') ||
              line.contains('package:drift/') ||
              line.contains('package:sqlite3/')) {
            offenders.add('${file.path}: $line');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'A screen must go through a use case. Reaching into '
            'infrastructure breaks the rule that the UI never touches the '
            'database.\n${offenders.join('\n')}',
      );
    });

    test('no screen imports the domain layer directly', () {
      final offenders = <String>[];

      for (final file in dartFilesIn('lib/src/presentation')) {
        final source = file.readAsStringSync();
        for (final line in source.split('\n')) {
          if (!line.trimLeft().startsWith('import ')) continue;
          if (line.contains('src/domain/')) {
            offenders.add('${file.path}: $line');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Screens call use cases in the application layer, not domain '
            'internals.\n${offenders.join('\n')}',
      );
    });
  });

  group('The domain layer stays independent', () {
    test('no domain file imports Flutter, the application, or infrastructure',
        () {
      final offenders = <String>[];

      for (final file in dartFilesIn('lib/src/domain')) {
        final source = file.readAsStringSync();
        for (final line in source.split('\n')) {
          if (!line.trimLeft().startsWith('import ')) continue;
          if (line.contains('package:flutter/') ||
              line.contains('src/application/') ||
              line.contains('src/infrastructure/') ||
              line.contains('src/presentation/')) {
            offenders.add('${file.path}: $line');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'The domain must depend on nothing. This is what makes the '
            'accounting rules testable and the UI replaceable.\n'
            '${offenders.join('\n')}',
      );
    });
  });

  group('The calendar stays in-tree', () {
    test('no file imports the third-party Bikram Sambat package', () {
      // Removed deliberately on supply-chain grounds. See ADR 009. This guards
      // against a well-meaning `flutter pub add bikram_sambat` later.
      final offenders = <String>[];

      for (final directory in <String>[
        'lib',
        'test',
      ]) {
        for (final file in dartFilesIn(directory)) {
          // This file is excluded, and has to be. It contains the import string
          // it is searching for, so a test that scans every file would match
          // itself and fail for ever. Excluding the checker is the honest fix;
          // loosening the pattern would let a real import slip through.
          if (file.path.endsWith('architecture_test.dart')) continue;

          final source = file.readAsStringSync();
          if (source.contains("import 'package:bikram_sambat/") ||
              source.contains('import "package:bikram_sambat/')) {
            offenders.add(file.path);
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'The BS calendar data is first-party in '
            'lib/src/domain/fiscal/bs_calendar_data.dart. Do not reintroduce '
            'the package.\n${offenders.join('\n')}',
      );
    });
  });
}
