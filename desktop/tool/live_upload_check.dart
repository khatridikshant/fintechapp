// A live check of the real HTTP transport, against a running backend.
//
// NOT part of the test suite: it is not named `*_test.dart`, so `flutter test`
// does not pick it up. It needs a running server, which the unit tests
// deliberately do not.
//
//   cd backend && php artisan serve --port=8124
//   cd desktop && FINANCEAPP_SERVER=http://127.0.0.1:8124 \
//     flutter test test/live_upload_check.dart
//
// It exists because the unit tests replace the transport with a fake. That
// leaves `IoHttpTransport` — the actual socket, the actual multipart encoding as
// it goes on the wire — unverified by them, and this closes that gap.
//
// **It registers a fresh account each run**, so it starts from a book with no
// stored revisions and asserts absolute revision numbers. Pointing it at a book
// that already has revisions would make those assertions meaningless, which is
// the mistake an earlier version of this file made.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:financeapp/src/domain/shared/book_backup.dart';
import 'package:financeapp/src/domain/shared/book_upload.dart';
import 'package:financeapp/src/infrastructure/http/http_transport.dart';
import 'package:financeapp/src/infrastructure/sync/http_backup_uploader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A unique stamp for this run, shared by the username, email and PAN.
///
/// Declared once: rebuilding it inline in each expression lets two of them
/// disagree by a microsecond, which registers two companies on one PAN and looks
/// exactly like a working uniqueness constraint.
final int stamp = DateTime.now().microsecondsSinceEpoch + 1;

/// Nine digits from [seed], always exactly nine.
///
/// `pan` is `size:9` and unique, so this has to be nine characters and has to
/// differ per run. **Padding rather than slicing is what guarantees the length:**
/// an earlier version built eight digits and threw a `RangeError` from
/// `'000'.substring(0, 8)`, which looked like a server rejection and was not.
String _panFrom(int seed) =>
    (800000000 + (seed % 100000000)).toString().padLeft(9, '0');

void main() {
  final server = Platform.environment['FINANCEAPP_SERVER'];

  if (server == null || server.isEmpty) {
    test('live upload check', () {}, skip: 'set FINANCEAPP_SERVER to run');
    return;
  }

  final base = Uri.parse(server);
  final transport = IoHttpTransport(timeout: const Duration(seconds: 10));
  final temp = Directory.systemTemp.createTempSync('financeapp_live');
  final log = File(p.join(temp.path, 'uploads.json'));

  late HttpBackupUploader uploader;

  tearDownAll(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// Registers a throwaway account and returns the session it produced.
  Future<BackendSession> registerFreshAccount() async {
    final response = await transport.send(
      method: 'POST',
      url: Uri.parse('$base/api/auth/register'),
      headers: const <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: <List<int>>[
        utf8.encode(
          jsonEncode(<String, Object?>{
            // Required since ADR 011. See `live_signin_check.dart` for why these
            // are supplied, and why the stamp is declared once rather than being
            // rebuilt in each expression.
            'username': 'live-upload-$stamp',
            'company_name': 'Live Check Traders',
            'company_pan': _panFrom(stamp),
            'vat_registered': false,
            'name': 'Live Check',
            'email': 'live-$stamp@example.com',
            'password': 'a-long-enough-passphrase',
            'password_confirmation': 'a-long-enough-passphrase',
            'device_name': 'live-check',
          }),
        ),
      ],
    );

    expect(response.statusCode, 201, reason: response.body);
    final decoded = jsonDecode(response.body) as Map<String, Object?>;

    return BackendSession(
      serverBaseUrl: base,
      token: decoded['token']! as String,
      bookId: '${(decoded['book']! as Map)['id']}',
      accountLabel: 'live check',
    );
  }

  setUpAll(() async {
    uploader = HttpBackupUploader(
      transport: transport,
      session: await registerFreshAccount(),
      uploadLogFile: log,
    );
  });

  /// A genuine SQLite file, as the backup service would produce.
  File realDatabase(String name) {
    final file = File(p.join(temp.path, name));
    final process = Process.runSync('php', <String>[
      '-r',
      "\$p = new PDO('sqlite:${file.path}'); "
          "\$p->exec('CREATE TABLE journal_entries (id INTEGER PRIMARY KEY, note TEXT)'); "
          "\$p->exec(\"INSERT INTO journal_entries (note) VALUES ('live')\"); ",
    ]);
    if (process.exitCode != 0 || !file.existsSync()) {
      throw StateError('could not build a probe database: ${process.stderr}');
    }
    return file;
  }

  BookBackup describe(File file, String label) => BookBackup(
        fileName: p.basename(file.path),
        filePath: file.path,
        fiscalYearLabel: label,
        takenAt: DateTime.now(),
        fileSizeBytes: file.lengthSync(),
        checksum: sha256.convert(file.readAsBytesSync()).toString(),
      );

  test('the real transport uploads a snapshot and the server confirms it',
      () async {
    final file = realDatabase('accounting-FY-2082-83.db');
    final result = await uploader.upload(describe(file, 'FY 2082/83'));

    expect(result.status, UploadStatus.uploaded, reason: result.message);
    expect(
      result.remoteRevision,
      1,
      reason: 'a fresh book has no revisions, so the first is 1',
    );
    expect(result.isSuccess, isTrue);
    expect(file.existsSync(), isTrue, reason: 'the local copy is untouched');
    // ignore: avoid_print
    print('  uploaded: ${result.message}');
  });

  test('re-uploading advances the revision, because the sequence is re-read',
      () async {
    // **A conflict is not expected here, and that is correct.** The uploader
    // reads the server's stored revisions before it sends, so a second upload
    // from this installation legitimately becomes the next revision. A 409 is
    // for the different case where *another* installation stored a revision
    // between the read and the write. The mapping of 409 to
    // `UploadStatus.conflict` is covered by the unit tests, where the race can
    // be staged deterministically, and the backend tests cover the server
    // emitting it. Reproducing that race live would be a timing test.
    final file = realDatabase('accounting-FY-2081-82.db');
    final first = await uploader.upload(describe(file, 'FY 2081/82'));
    expect(first.status, UploadStatus.uploaded, reason: first.message);

    final second = await uploader.upload(describe(file, 'FY 2081/82'));
    expect(second.status, UploadStatus.uploaded, reason: second.message);
    expect(
      second.remoteRevision,
      first.remoteRevision! + 1,
      reason: 'the sequence must advance, or a second upload would silently '
          'overwrite the first',
    );
    // ignore: avoid_print
    print('  revision advanced ${first.remoteRevision} -> '
        '${second.remoteRevision}');
  });

  test('two fiscal years keep independent revision sequences', () async {
    // The bug this guards: counting every year's revisions together would make
    // the second year start at 3 instead of 1.
    final file = realDatabase('accounting-FY-2083-84.db');
    final result = await uploader.upload(describe(file, 'FY 2083/84'));

    expect(result.status, UploadStatus.uploaded, reason: result.message);
    expect(result.remoteRevision, 1);
    // ignore: avoid_print
    print('  new year starts at revision ${result.remoteRevision}');
  });

  test('a file that is not a database is refused by the server', () async {
    final file = File(p.join(temp.path, 'accounting-FY-2080-81.db'))
      ..writeAsBytesSync(List<int>.generate(4096, (i) => (i * 7) % 256));
    final result = await uploader.upload(describe(file, 'FY 2080/81'));

    expect(result.status, UploadStatus.rejected, reason: result.message);
    expect(result.isSuccess, isFalse);
    // ignore: avoid_print
    print('  rejected: ${result.message}');
  });

  test('an unreachable server is reported and the backup is intact', () async {
    final offline = HttpBackupUploader(
      transport: IoHttpTransport(timeout: const Duration(milliseconds: 500)),
      session: BackendSession(
        // A port nothing is listening on.
        serverBaseUrl: Uri.parse('http://127.0.0.1:9'),
        token: uploader.session!.token,
        bookId: uploader.session!.bookId,
      ),
      uploadLogFile: log,
    );

    final file = realDatabase('accounting-FY-2079-80.db');
    final result = await offline.upload(describe(file, 'FY 2079/80'));

    expect(result.status, UploadStatus.unreachable, reason: result.message);
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(0));
    // ignore: avoid_print
    print('  offline: ${result.message}');
  });

  test('a refused upload is not recorded as a success', () async {
    // Only the two years that uploaded should have a record.
    expect(await uploader.uploadsFor('FY 2082/83'), hasLength(1));
    expect(await uploader.uploadsFor('FY 2081/82'), hasLength(2));
    expect(await uploader.uploadsFor('FY 2083/84'), hasLength(1));
    expect(await uploader.uploadsFor('FY 2080/81'), isEmpty);
    expect(await uploader.uploadsFor('FY 2079/80'), isEmpty);
    // ignore: avoid_print
    print('  local upload log: '
        '${await uploader.uploadsFor('FY 2081/82')}');
  });
}
