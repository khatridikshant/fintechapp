import 'dart:io';
import 'dart:typed_data';

import 'package:financeapp/src/application/restore_backup.dart';
import 'package:financeapp/src/domain/shared/backup_download.dart';
import 'package:financeapp/src/domain/shared/book_backup_service.dart';
import 'package:financeapp/src/infrastructure/backup/file_book_backup_service.dart';
import 'package:financeapp/src/infrastructure/database/app_database.dart';
import 'package:financeapp/src/infrastructure/database/sqlite_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Restoring a snapshot from the server.
///
/// **A restore overwrites the live books**, so every test here is about what must
/// *not* happen: nothing written before verification, and nothing at all when the
/// download is refused.
void main() {
  late Directory booksDir;
  late Directory backupDir;
  late AppDatabase current;

  setUp(() {
    booksDir = Directory.systemTemp.createTempSync('restore');
    backupDir = Directory(p.join(booksDir.path, 'backups'))..createSync();
    current = openInMemoryDatabase();
  });

  tearDown(() async {
    await current.close();
    booksDir.deleteSync(recursive: true);
  });

  BookBackupService backups() => FileBookBackupService(
        currentDatabase: current,
        booksDirectory: booksDir,
        backupDirectory: backupDir,
        currentFiscalYearLabel: 'FY 2082/83',
      );

  RestoreBackup restoreWith(BackupDownloader downloads) => RestoreBackup(
        backups: backups(),
        downloads: downloads,
        booksDirectory: booksDir,
      );

  group('a refused download', () {
    test('writes nothing at all', () async {
      final restore = restoreWith(_Downloader(
        available: true,
        result: const DownloadFailed(DownloadRefusal.notAvailable),
      ));

      final result = await restore(
        remoteRevision: 1,
        fiscalYearLabel: 'FY 2082/83',
      );

      expect(result, isA<RestoreRefused>());
      expect(backupDir.listSync(), isEmpty,
          reason: 'a refused download must not leave a snapshot behind');
      expect(
        booksDir
            .listSync()
            .where((FileSystemEntity e) => e.path.contains('restore-')),
        isEmpty,
        reason: 'and must not leave a staged file beside the years',
      );
    });

    test('a checksum mismatch is refused with the server\'s own numbers',
        () async {
      final restore = restoreWith(_Downloader(
        available: true,
        result: const DownloadFailed(
          DownloadRefusal.checksumMismatch,
          'The server recorded aaa but sent bbb.',
        ),
      ));

      final result = await restore(
        remoteRevision: 1,
        fiscalYearLabel: 'FY 2082/83',
      );

      expect(result, isA<RestoreRefused>());
      expect((result as RestoreRefused).reason, contains('aaa'));
      expect(result.reason, contains('bbb'));
    });

    test('an unreachable server is refused before anything is fetched',
        () async {
      final downloads = _Downloader(available: false);
      final restore = restoreWith(downloads);

      final result = await restore(
        remoteRevision: 1,
        fiscalYearLabel: 'FY 2082/83',
      );

      expect(result, isA<RestoreRefused>());
      expect(downloads.calls, 0,
          reason:
              'an offline machine must not start a restore it cannot finish');
    });

    test('a file that is not a database is refused after download', () async {
      final restore = restoreWith(_Downloader(
        available: true,
        result: DownloadSucceeded(DownloadedBackup(
          bytes: Uint8List.fromList(
            'this is not a sqlite database'.codeUnits,
          ),
          declaredChecksum: 'a' * 64,
          fileSize: 28,
        )),
      ));

      final result = await restore(
        remoteRevision: 1,
        fiscalYearLabel: 'FY 2082/83',
      );

      expect(result, isA<RestoreRefused>(),
          reason:
              'a matching checksum is not enough: it must be a real database');
      expect(backupDir.listSync(), isEmpty);
    });
  });
}

/// A [BackupDownloader] that answers from a script.
class _Downloader implements BackupDownloader {
  _Downloader({required this.available, this.result});

  final bool available;
  final DownloadAttempt? result;

  int calls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<DownloadAttempt> download({
    required int revision,
    required String fiscalYearLabel,
  }) async {
    calls++;
    return result ?? const DownloadFailed(DownloadRefusal.refused);
  }
}
