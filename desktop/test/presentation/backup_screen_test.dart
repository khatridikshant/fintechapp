import 'package:financeapp/src/domain/shared/book_backup.dart';
import 'package:financeapp/src/domain/shared/book_backup_service.dart';
import 'package:financeapp/src/domain/shared/book_upload.dart';
import 'package:financeapp/src/domain/shared/book_upload_service.dart';
import 'package:financeapp/src/domain/shared/book_year.dart';
import 'package:financeapp/src/presentation/app_services.dart';
import 'package:financeapp/src/presentation/finance_app.dart';
import 'package:financeapp/src/presentation/screens/backup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for the Backup screen, with a stubbed service so no file is
/// touched.
///
/// The most important assertions here are about **coverage**: the screen must
/// name the fiscal years that have no backup, because a screen that looked
/// reassuring while older years were unprotected is the failure this feature
/// exists to prevent.
void main() {
  BookBackup backup(String year, {int bytes = 200000}) => BookBackup(
        fileName: 'accounting-${year.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}'
            '-20260930100000000.db',
        filePath: '/backups/$year.db',
        fiscalYearLabel: year,
        takenAt: DateTime(2026, 9, 30, 10),
        fileSizeBytes: bytes,
        checksum: 'a' * 64,
      );

  BookYear year(String label) =>
      BookYear(fiscalYearLabel: label, filePath: '/books/$label.db');

  Future<void> openBackup(
    WidgetTester tester,
    BackupActions service, {
    UploadActions? uploads,
  }) async {
    tester.view.physicalSize = const Size(1600, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      FinanceApp(services: AppServices(backup: service, upload: uploads)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backup'));
    await tester.pumpAndSettle();
  }

  group('The Backup screen', () {
    testWidgets('lists every fiscal year found', (tester) async {
      await openBackup(
        tester,
        _StubService(
          years: [year('FY 2083/84'), year('FY 2082/83')],
          existing: [backup('FY 2082/83'), backup('FY 2083/84')],
        ),
      );

      expect(find.byType(BackupScreen), findsOneWidget);
      expect(find.text('FY 2083/84'), findsOneWidget);
      expect(find.text('FY 2082/83'), findsOneWidget);
    });

    testWidgets('warns loudly about a year with no backup', (tester) async {
      // The warning that was missing from the first version, which backed up
      // only the current year while looking reassuring.
      await openBackup(
        tester,
        _StubService(
          years: [year('FY 2083/84'), year('FY 2082/83')],
          existing: [backup('FY 2083/84')],
        ),
      );

      expect(find.text('1 fiscal year has no backup'), findsOneWidget);
      expect(find.text('No backup for this year'), findsOneWidget);
      // The notice names the year in its body, so the user knows which one.
      expect(find.textContaining('FY 2082/83. These years'), findsOneWidget);
    });

    testWidgets('the warning counts the years when several are unprotected',
        (tester) async {
      await openBackup(
        tester,
        _StubService(
          years: [year('FY 2083/84'), year('FY 2082/83'), year('FY 2081/82')],
          existing: [backup('FY 2083/84')],
        ),
      );

      expect(find.text('2 fiscal years have no backup'), findsOneWidget);
      expect(find.text('No backup for this year'), findsNWidgets(2));
    });

    testWidgets('does not warn when every year has a backup', (tester) async {
      await openBackup(
        tester,
        _StubService(
          years: [year('FY 2083/84')],
          existing: [backup('FY 2083/84')],
        ),
      );

      expect(find.textContaining('no backup'), findsNothing);
    });

    testWidgets('shows when each year was last backed up', (tester) async {
      await openBackup(
        tester,
        _StubService(
          years: [year('FY 2083/84')],
          existing: [backup('FY 2083/84')],
        ),
      );

      expect(find.textContaining('Last backed up'), findsOneWidget);
      expect(find.textContaining('195 KB'), findsOneWidget);
    });

    testWidgets('says plainly that a local backup does not survive the machine',
        (tester) async {
      await openBackup(
        tester,
        _StubService(
          years: [year('FY 2083/84')],
          existing: [backup('FY 2083/84')],
        ),
      );

      expect(
        find.textContaining('does not survive losing this computer'),
        findsOneWidget,
      );
      expect(find.textContaining('USB drive'), findsOneWidget);
    });

    testWidgets('a successful run reports how many years were covered',
        (tester) async {
      await openBackup(
        tester,
        _StubService(
          years: [year('FY 2083/84'), year('FY 2082/83')],
          runBackups: [backup('FY 2083/84'), backup('FY 2082/83')],
        ),
      );

      await tester.tap(find.text('Back up all years now'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Backed up 2 fiscal years and verified them'),
        findsOneWidget,
      );
    });

    testWidgets('a partial run names the year it could not cover',
        (tester) async {
      // A run that covered one of two years must not read as a success.
      await openBackup(
        tester,
        _StubService(
          years: [year('FY 2083/84'), year('FY 2081/82')],
          runBackups: [backup('FY 2083/84')],
          runFailures: [
            const BackupFailure(
              fiscalYearLabel: 'FY 2081/82',
              reason: 'the file is unreadable',
            ),
          ],
        ),
      );

      await tester.tap(find.text('Back up all years now'));
      await tester.pumpAndSettle();

      expect(find.textContaining('could NOT be backed up'), findsOneWidget);
      expect(find.textContaining('FY 2081/82'), findsWidgets);
    });

    testWidgets('a failed run says so rather than looking successful',
        (tester) async {
      await openBackup(
        tester,
        _StubService(failWith: StateError('the disk is full')),
      );

      await tester.tap(find.text('Back up all years now'));
      await tester.pumpAndSettle();

      expect(find.textContaining('did not succeed'), findsOneWidget);
      expect(find.textContaining('the disk is full'), findsOneWidget);
    });

    testWidgets('says so when there are no books at all', (tester) async {
      await openBackup(tester, _StubService());

      expect(find.textContaining('No fiscal-year books were found'),
          findsOneWidget);
    });

    testWidgets('verifying a backup reports the result', (tester) async {
      await openBackup(
        tester,
        _StubService(
          years: [year('FY 2083/84')],
          existing: [backup('FY 2083/84')],
        ),
      );

      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(find.textContaining('intact'), findsOneWidget);
    });

    testWidgets('verifying a damaged backup reports the damage',
        (tester) async {
      await openBackup(
        tester,
        _StubService(
          years: [year('FY 2083/84')],
          existing: [backup('FY 2083/84')],
          verification: BackupVerification(
            backup: backup('FY 2083/84'),
            checksumMatches: false,
            integrityPassed: false,
            detail: 'Its contents have changed since it was taken.',
          ),
        ),
      );

      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(find.textContaining('changed since it was taken'), findsOneWidget);
    });

    testWidgets('a listing failure is shown rather than a blank panel',
        (tester) async {
      await openBackup(
        tester,
        _StubService(listError: StateError('the backup folder is unreadable')),
      );

      expect(
        find.textContaining('the backup folder is unreadable'),
        findsOneWidget,
      );
    });
  });

  group('The screen cannot restore', () {
    test('the interface the screen is given has no restore', () {
      final actions = _StubService();
      expect(actions, isA<BackupActions>());
      expect(actions, isNot(isA<BookBackupService>()),
          reason: 'restoring replaces the books and is deliberately not '
              'reachable from a button on a list');
    });
  });

  /// Sending a backup off the machine.
  ///
  /// The screen must never imply the books are safe off-machine when they are
  /// not, and the local backup must keep working whether or not a server is
  /// reachable. That is what these check.
  group('Sending backups to the server', () {
    testWidgets('offers nothing to send when there is no session',
        (tester) async {
      await openBackup(
        tester,
        _StubService(
          years: [year('FY 2082/83')],
          existing: [backup('FY 2082/83')],
        ),
      );

      // The button is absent rather than present-and-dead, and the reason is
      // stated rather than left to be guessed.
      expect(find.text('Send to the server'), findsNothing);
      expect(find.textContaining('needs a signed-in session'), findsOneWidget);
      // Taking a local backup is unaffected by the absence of a server.
      expect(find.text('Back up all years now'), findsOneWidget);
    });

    testWidgets('offers the button when a session is configured',
        (tester) async {
      await openBackup(
        tester,
        _StubService(
          years: [year('FY 2082/83')],
          existing: [backup('FY 2082/83')],
        ),
        uploads: _StubUploads(),
      );

      expect(find.text('Send to the server'), findsOneWidget);
      expect(find.textContaining('needs a signed-in session'), findsNothing);
    });

    testWidgets('sends the newest backup of every year', (tester) async {
      final uploads = _StubUploads();

      await openBackup(
        tester,
        _StubService(
          years: [year('FY 2083/84'), year('FY 2082/83')],
          existing: [backup('FY 2083/84'), backup('FY 2082/83')],
        ),
        uploads: uploads,
      );

      await tester.tap(find.text('Send to the server'));
      await tester.pumpAndSettle();

      expect(uploads.uploaded, ['FY 2083/84', 'FY 2082/83']);
      expect(find.textContaining('Sent 2 of 2'), findsOneWidget);
    });

    testWidgets('does not send a year that has never been backed up',
        (tester) async {
      final uploads = _StubUploads();

      await openBackup(
        tester,
        _StubService(
          years: [year('FY 2083/84'), year('FY 2082/83')],
          existing: [backup('FY 2083/84')],
        ),
        uploads: uploads,
      );

      await tester.tap(find.text('Send to the server'));
      await tester.pumpAndSettle();

      expect(uploads.uploaded, ['FY 2083/84']);
      // One of two years, not one of one: the skipped year has no backup and
      // must still be counted.
      expect(find.textContaining('Sent 1 of 2'), findsOneWidget);
    });

    testWidgets('never claims every year is stored when a year has no backup',
        (tester) async {
      // The message must not say the whole book is off-machine while a year has
      // no backup at all — that is the reassuring-but-false report this screen
      // exists to prevent.
      await openBackup(
        tester,
        _StubService(
          years: [year('FY 2083/84'), year('FY 2082/83')],
          existing: [backup('FY 2083/84')],
        ),
        uploads: _StubUploads(),
      );

      await tester.tap(find.text('Send to the server'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Every year is now stored off this computer'),
        findsNothing,
      );
      expect(find.textContaining('no backup at all'), findsOneWidget);
    });

    testWidgets('reports every year stored only when that is actually true',
        (tester) async {
      await openBackup(
        tester,
        _StubService(
          years: [year('FY 2083/84'), year('FY 2082/83')],
          existing: [backup('FY 2083/84'), backup('FY 2082/83')],
        ),
        uploads: _StubUploads(),
      );

      await tester.tap(find.text('Send to the server'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sent 2 of 2'), findsOneWidget);
      expect(
        find.textContaining('Every year is now stored off this computer'),
        findsOneWidget,
      );
    });

    testWidgets('reports a year that could not be sent rather than success',
        (tester) async {
      final uploads = _StubUploads(
        statusFor: {
          'FY 2082/83': UploadStatus.conflict,
        },
      );

      await openBackup(
        tester,
        _StubService(
          years: [year('FY 2083/84'), year('FY 2082/83')],
          existing: [backup('FY 2083/84'), backup('FY 2082/83')],
        ),
        uploads: uploads,
      );

      await tester.tap(find.text('Send to the server'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sent 1 of 2'), findsOneWidget);
      expect(find.textContaining('could NOT be sent'), findsOneWidget);
      expect(find.textContaining('FY 2082/83'), findsWidgets);
    });

    testWidgets('says plainly when a year has never been sent', (tester) async {
      await openBackup(
        tester,
        _StubService(
          years: [year('FY 2082/83')],
          existing: [backup('FY 2082/83')],
        ),
        uploads: _StubUploads(),
      );

      expect(find.text('Not sent to the server yet'), findsOneWidget);
    });

    testWidgets('shows when and as which revision a year was last sent',
        (tester) async {
      await openBackup(
        tester,
        _StubService(
          years: [year('FY 2082/83')],
          existing: [backup('FY 2082/83')],
        ),
        uploads: _StubUploads(
          history: {
            'FY 2082/83': [
              UploadRecord(
                fiscalYearLabel: 'FY 2082/83',
                fileName: 'accounting-FY-2082-83.db',
                uploadedAt: DateTime(2026, 9, 30, 11, 30),
                remoteRevision: 4,
                checksum: 'a' * 64,
              ),
            ],
          },
        ),
      );

      expect(find.textContaining('Sent to the server:'), findsOneWidget);
      expect(find.textContaining('revision 4'), findsOneWidget);
      expect(find.text('Not sent to the server yet'), findsNothing);
    });

    testWidgets('keeps the off-machine warning even when a session exists',
        (tester) async {
      // A server copy is only as good as the last successful upload, and the
      // older warning is still true for a year that has never been sent.
      await openBackup(
        tester,
        _StubService(
          years: [year('FY 2082/83')],
          existing: [backup('FY 2082/83')],
        ),
        uploads: _StubUploads(),
      );

      expect(
        find.textContaining('does not survive losing this computer'),
        findsOneWidget,
      );
    });
  });
}

/// A stubbed backup service. Implements only the narrow interface, so this also
/// proves a screen needs nothing more.
class _StubService implements BackupActions {
  _StubService({
    List<BookYear> years = const [],
    List<BookBackup> existing = const [],
    List<BookBackup>? runBackups,
    this.runFailures = const [],
    this.failWith,
    this.listError,
    BackupVerification? verification,
  })  : _years = years,
        _existing = existing,
        _runBackups = runBackups ?? existing,
        _verification = verification;

  final List<BookYear> _years;
  final List<BookBackup> _existing;
  final List<BookBackup> _runBackups;
  final List<BackupFailure> runFailures;
  final Object? failWith;
  final Object? listError;
  final BackupVerification? _verification;

  @override
  Future<List<BookYear>> knownYears() async => _years;

  @override
  Future<List<BookBackup>> listBackups() async {
    if (listError != null) throw listError!;
    return _existing;
  }

  @override
  Future<BackupRun> takeBackup() async {
    if (failWith != null) throw failWith!;
    return BackupRun(backups: _runBackups, failures: runFailures);
  }

  @override
  Future<BackupVerification> verify(BookBackup backup) async =>
      _verification ??
      BackupVerification(
        backup: backup,
        checksumMatches: true,
        integrityPassed: true,
      );
}

/// A stubbed upload service. No network, no files.
class _StubUploads implements UploadActions {
  _StubUploads({
    this.statusFor = const <String, UploadStatus>{},
    this.history = const <String, List<UploadRecord>>{},
  });

  /// The status to return per fiscal year. Defaults to a success.
  final Map<String, UploadStatus> statusFor;

  /// What has already been sent, per year.
  final Map<String, List<UploadRecord>> history;

  /// The fiscal years that were actually uploaded, in order, so a test can
  /// prove which years were sent and which were not.
  final List<String> uploaded = <String>[];

  @override
  BackendSession? get session => BackendSession(
        serverBaseUrl: Uri.parse('http://127.0.0.1:8123'),
        token: 'a-token',
        bookId: '1',
      );

  @override
  bool get canUpload => true;

  @override
  Future<UploadResult> upload(BookBackup backup) async {
    uploaded.add(backup.fiscalYearLabel);
    final status = statusFor[backup.fiscalYearLabel] ?? UploadStatus.uploaded;

    return UploadResult(
      backup: backup,
      status: status,
      remoteRevision: status == UploadStatus.uploaded ? 1 : null,
      message: switch (status) {
        UploadStatus.uploaded => 'Stored on the server as revision 1.',
        UploadStatus.unverified =>
          'This snapshot is no longer the one that was verified.',
        UploadStatus.rejected => 'The server refused this snapshot.',
        UploadStatus.conflict => 'The server already holds a newer revision.',
        UploadStatus.unreachable => 'The server could not be reached.',
      },
    );
  }

  @override
  Future<List<UploadRecord>> uploadsFor(String fiscalYearLabel) async =>
      history[fiscalYearLabel] ?? const [];
}
