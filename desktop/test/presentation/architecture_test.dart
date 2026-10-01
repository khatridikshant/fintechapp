import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the layer boundaries that `docs/AI_RULES.md` states as hard rules.
///
/// A screen that imports a repository compiles, runs, and quietly breaks the
/// architecture. Nothing else in the toolchain complains, so these tests exist to
/// complain instead.
///
/// ## What the rules actually are, stated precisely
///
/// An earlier version of this file forbade the presentation layer from importing
/// `src/domain/` at all. **That rule was not true of the code, and the test only
/// appeared to pass because it matched `package:` paths and the screens happen to
/// use relative ones.** The screens legitimately need domain *value types* to
/// display them: `Money`, `Account`, `BookBackup`.
///
/// The real rule, which is what `AI_RULES.md` means by "the UI never touches the
/// database", is:
///
/// - presentation must not reach **infrastructure**, a database driver, or a
///   **repository port**. Behaviour goes through a use case.
/// - presentation may read domain value types and read-only interfaces.
/// - domain must depend on nothing outside itself.
///
/// This test now says that, and matches relative paths as well as `package:`
/// ones, so it cannot be satisfied by accident.
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

  /// The targets of every import in [file], normalised to forward slashes.
  List<String> importsIn(File file) => file
      .readAsStringSync()
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.startsWith('import '))
      .map((line) => line.replaceAll('\\', '/'))
      .toList();

  group('The presentation layer does not reach past a use case', () {
    test('no screen imports infrastructure, a database driver, or a repository',
        () {
      // Matched as substrings so a relative `../../infrastructure/...` is caught
      // just as a `package:` path is.
      const forbidden = <String>[
        'infrastructure/',
        'package:drift/',
        'package:sqlite3/',
        '_repository.dart',
      ];

      final offenders = <String>[];
      for (final file in dartFilesIn('lib/src/presentation')) {
        for (final line in importsIn(file)) {
          for (final needle in forbidden) {
            if (line.contains(needle)) offenders.add('${file.path}: $line');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'A screen must go through a use case. Reaching into '
            'infrastructure or a repository breaks the rule that the UI never '
            'touches the database.\n${offenders.join('\n')}',
      );
    });

    test('the presentation layer imports domain value types and nothing more',
        () {
      // Not a prohibition: a record of what is actually imported from the
      // domain, so a new domain import in a screen is a deliberate act.
      //
      // These are value types and read-only interfaces a screen has to display
      // or call. Anything else from the domain belongs behind a use case.
      const allowed = <String>{
        'domain/shared/money.dart',
        'domain/shared/book_backup.dart',
        'domain/shared/book_backup_service.dart',
        // `BookYear`, `BackupRun`, and `BackupFailure`: the screen has to name
        // the fiscal years it found and report which ones it could not cover.
        'domain/shared/book_year.dart',
        // The Backup screen reports the outcome of an upload and when each
        // year's books were last on the server, so it needs the result and
        // record value types and the read-only upload interface. Sending is
        // behaviour and still goes through the port.
        'domain/shared/book_upload.dart',
        'domain/shared/book_upload_service.dart',
        // `SignInResult` and `SignInStatus`: the Settings screen has to say which
        // of the three outcomes happened -- refused, unreachable, or a bad
        // address -- because they ask different things of the user. Sending the
        // request is behaviour and still goes through `AuthActions`.
        'domain/shared/sign_in.dart',
        // `BusinessProfile`: the Settings screen builds one from what the user
        // typed, and shows the domain's own wording when it refuses. It is a value
        // type; loading and saving it goes through `BusinessDetails`.
        'domain/billing/business_profile.dart',
        'domain/accounting/account.dart',
        'domain/reporting/general_ledger.dart',
      };

      final offenders = <String>[];
      for (final file in dartFilesIn('lib/src/presentation')) {
        for (final line in importsIn(file)) {
          if (!line.contains('domain/')) continue;
          final allowedImport = allowed.any(line.contains);
          if (!allowedImport) offenders.add('${file.path}: $line');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'A screen just picked up a domain import that is not a value '
            'type or a read-only interface. Either it is legitimate and belongs '
            'in the allowed list above with a reason, or the behaviour belongs '
            'behind a use case.\n${offenders.join('\n')}',
      );
    });
  });

  group('The domain layer stays independent', () {
    test('no domain file imports Flutter, the application, or infrastructure',
        () {
      const forbidden = <String>[
        'package:flutter/',
        'application/',
        'infrastructure/',
        'presentation/',
      ];

      final offenders = <String>[];
      for (final file in dartFilesIn('lib/src/domain')) {
        for (final line in importsIn(file)) {
          for (final needle in forbidden) {
            if (line.contains(needle)) offenders.add('${file.path}: $line');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'The domain must depend on nothing. This is what makes the '
            'accounting rules testable in isolation and the UI replaceable.\n'
            '${offenders.join('\n')}',
      );
    });

    test('the calendar stays first-party', () {
      // Removed deliberately on supply-chain grounds. See ADR 009. This guards
      // against a well-meaning `flutter pub add bikram_sambat` later.
      final offenders = <String>[];
      for (final directory in <String>['lib', 'test']) {
        for (final file in dartFilesIn(directory)) {
          // This file is excluded, and has to be: it contains the import string
          // it is searching for, so scanning every file would match itself.
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
