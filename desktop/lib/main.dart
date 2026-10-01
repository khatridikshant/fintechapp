import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'src/application/account_session.dart';
import 'src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'src/domain/shared/book_upload.dart';
import 'src/domain/shared/book_upload_service.dart';
import 'src/infrastructure/auth/http_auth_client.dart';
import 'src/infrastructure/auth/secure_credential_store.dart';
import 'src/infrastructure/database/file_books_session.dart';
import 'src/infrastructure/http/http_transport.dart';
import 'src/infrastructure/sync/http_backup_uploader.dart';
import 'src/presentation/app_services.dart';
import 'src/presentation/finance_app.dart';

/// financeapp — offline-first business software for small Nepali businesses.
///
/// The generated counter application that `flutter create` produced has been
/// replaced. The shell and the design system live under
/// `lib/src/presentation/`, and the design contract is `ui.txt`.
///
/// ## Wiring
///
/// This is the **composition root**: the one place that knows about the database,
/// the repositories, and the use cases together. Nothing below it does. A screen
/// receives a use case through [AppServices] and never learns where the data
/// came from, which is what keeps the layers honest.
///
/// Opening the database can fail, and a user staring at a blank window learns
/// nothing from that. So the failure is reported on screen, and the application
/// name still appears, so it is clear which program failed.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // The fiscal year today falls in. ADR 002 gives each year its own database,
    // and this is the one the business is trading in, so it is the writable one.
    final fiscalYear = const NepaliFiscalCalendar().containing(DateTime.now());

    // The books folder holds one database per fiscal year. The session finds
    // them all, opens the trading year, and opens every concluded year
    // read-only, as the specification requires.
    final supportDirectory = await getApplicationSupportDirectory();
    final session = await FileBooksSession.openOn(
      booksDirectory: supportDirectory,
      startYear: fiscalYear,
    );

    // One transport for the life of the application, so signing in and sending
    // backups reuse the same connection pool.
    final transport = IoHttpTransport();
    final uploadLogFile =
        File(p.join(supportDirectory.path, 'backups', 'uploads.json'));

    final account = AccountSession(
      auth: HttpAuthClient(transport),
      store: SecureCredentialStore(),
      deviceName: _deviceName,
      uploadBuilder: (session) => HttpBackupUploader(
        transport: transport,
        session: session,
        uploadLogFile: uploadLogFile,
      ),
    );

    // A returning user stays signed in. A store that cannot be read leaves the
    // session null, which is the same as never having signed in.
    await account.restore();

    runApp(
      FinanceApp(
        services: AppServices(
          account: account,
          // From `business.db`, which is **not** a fiscal-year database, so the
          // business is not asked to re-enter its details every Ashadh.
          businessDetails: session.businessDetails,
          // The developer stopgap still wins when it is configured, because the
          // live check and the manual workflow depend on it. With nothing set --
          // the normal case -- this is null and the account session's uploader is
          // used instead.
          upload: _uploadsFrom(Platform.environment, supportDirectory),
        ).forSession(session),
      ),
    );
  } catch (error) {
    runApp(StartupFailureApp(error: error));
  }
}

/// A name for this installation, so the server can identify it.
///
/// ADR 003 allows one active desktop installation per account, which means the
/// server has to be able to say *which* one is signing in. A name derived from
/// the platform is more use than a constant, because a user with two machines can
/// then tell them apart in the account's device list.
String get _deviceName => 'desktop-${Platform.operatingSystem}';

/// Builds the upload capability from the environment, or returns null.
///
/// **This is a stopgap, and it is deliberately obvious about that.** The
/// specification requires the account session to be established by signing in
/// and the token to be kept in protected operating-system storage
/// (`flutter_secure_storage`). Neither exists yet, so until the sign-in screen
/// does, a session can be supplied through the environment:
///
/// ```
/// FINANCEAPP_SERVER=http://127.0.0.1:8123
/// FINANCEAPP_TOKEN=<the token /api/auth/login returned>
/// FINANCEAPP_BOOK=<the book id /api/auth/register returned>
/// ```
///
/// With none of those set — which is the normal case — uploading stays absent and
/// the application is exactly as it was: entirely local, needing no network. That
/// matters, because a desktop application that cannot reach the internet must
/// still work.
/// The uploader, or null when no session is configured.
UploadActions? _uploadsFrom(
  Map<String, String> environment,
  Directory supportDirectory,
) {
  final server = environment['FINANCEAPP_SERVER']?.trim();
  final token = environment['FINANCEAPP_TOKEN']?.trim();
  final bookId = environment['FINANCEAPP_BOOK']?.trim();

  if (server == null ||
      server.isEmpty ||
      token == null ||
      token.isEmpty ||
      bookId == null ||
      bookId.isEmpty) {
    return null;
  }

  final base = Uri.tryParse(server);
  if (base == null || !base.hasScheme) return null;

  // **Refuse to send the books in clear text to another machine.** An upload
  // carries the bearer token and the entire accounting database, so a plain
  // `http://` URL pointing anywhere other than this machine would put both on the
  // network in the clear. Loopback is allowed because it never leaves the
  // machine and is how the server is run in development.
  if (!_isSafeServer(base)) return null;

  return HttpBackupUploader(
    transport: IoHttpTransport(),
    session: BackendSession(
      serverBaseUrl: base,
      token: token,
      bookId: bookId,
    ),
    // Beside the local backups, so the record of what was sent travels with the
    // snapshots it describes.
    uploadLogFile: File(
      p.join(supportDirectory.path, 'backups', 'uploads.json'),
    ),
  );
}

/// Whether a configured server may be sent the books.
///
/// HTTPS always, or plain `http` only when the host is this machine. Anything
/// else would put the token and the whole database on the network readable.
bool _isSafeServer(Uri server) {
  if (server.scheme == 'https') return true;
  if (server.scheme != 'http') return false;

  const loopback = <String>{'localhost', '127.0.0.1', '::1', '[::1]'};
  return loopback.contains(server.host);
}

/// Shown when the application cannot open its books.
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'financeapp',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'financeapp could not open its books',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your data has not been changed. Try opening the '
                    'application again, and if it keeps failing, check that the '
                    'folder holding your books is readable and not in use by '
                    'another copy of the program.',
                    style: const TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$error',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
