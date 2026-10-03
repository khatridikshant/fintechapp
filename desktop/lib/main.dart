import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'src/application/account_session.dart';
import 'src/application/conclude_fiscal_year.dart';
import 'src/domain/accounting/chart_of_accounts.dart';
import 'src/domain/shared/book_backup.dart';
import 'src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'src/domain/shared/book_upload.dart';
import 'src/domain/shared/book_upload_service.dart';
import 'src/infrastructure/auth/http_auth_client.dart';
import 'src/infrastructure/auth/secure_credential_store.dart';
import 'src/infrastructure/backup/backup_service_fiscal_year_archive.dart';
import 'src/infrastructure/backup/http_fiscal_year_concluder.dart';
import 'src/infrastructure/database/drift_journal_repository.dart';
import 'src/infrastructure/database/drift_unit_of_work.dart';
import 'src/infrastructure/database/file_books_session.dart';
import 'src/infrastructure/database/local_fiscal_year_transition.dart';
import 'src/infrastructure/http/http_licence_authorisation_client.dart';
import 'src/infrastructure/http/http_transport.dart';
import 'src/infrastructure/licensing/licence_gate.dart';
import 'src/infrastructure/licensing/licence_store.dart';
import 'src/infrastructure/licensing/licence_verifier.dart';
import 'src/infrastructure/sync/http_backup_uploader.dart';
import 'src/presentation/app_services.dart';
import 'src/presentation/finance_app.dart';

/// financeapp Ã¢â‚¬â€ offline-first business software for small Nepali businesses.
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

    // Stable per machine, so a licence issued to this installation is recognised on
    // the next launch. Derived from the support directory, which the OS gives us
    // per user, and never regenerated.
    final installationId = _installationId(supportDirectory.path);

    final licenceClient = HttpLicenceAuthorisationClient(transport);

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

    // **The licence gate.** Sign-in is what starts the offline window: it obtains
    // the signed authorisation, and every launch after that verifies it locally,
    // with no network call. Built here because this is the only place that can name
    // the OS store and the compiled-in public key.
    final licenceStore = LicenceStore();
    final licenceVerifier = const LicenceVerifier(
      // **A placeholder, and deliberately so.** The real constant is produced by
      // `php artisan financeapp:licence-keypair` and pasted in at build time. It is
      // NOT read from the environment, because a public key the user can replace
      // would make the signature check meaningless.
      publicKey: licencePublicKey,
    );
    final licenceGate = LicenceGate(
      verifier: licenceVerifier,
      store: licenceStore,
      installationId: installationId,
    );

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
          // Concluding a year needs **both** the books and a signed-in uploader
          // to archive to, and the uploader belongs to the account session Ã¢â‚¬â€ so
          // this is built here, in the composition root, rather than on the
          // session.
          concludeYear: ConcludeFiscalYear(
            fiscalYear: session.openYear.fiscalYear,
            databaseFile: session.currentYearFile,
            journal: DriftJournalRepository(session.database),
            unitOfWork: DriftUnitOfWork(session.database),
            archive: BackupServiceFiscalYearArchive(
              backups: session.backup,
              // **No sign-in means no archive**, and therefore no close. Passing a
              // uploader that refuses is what makes that true.
              uploads: account.upload ?? const NoUploads(),
              // Tells the server to keep only one snapshot of the year just
              // closed. Read through a closure so the **current** session is used
              // rather than the one captured when this object was built, which
              // would be null after a later sign-in.
              concluder: HttpFiscalYearConcluder(
                transport: transport,
                session: () => account.session,
              ),
            ),
            transition: LocalFiscalYearTransition(
              booksDirectory: session.booksDirectory,
            ),
            accounts: const ChartOfAccounts().all,
          ),
        ).forSession(session).withLicenceGate(
          // **The gate is built here, in the composition root**, because it is the
          // only place that can name the OS store, the compiled-in public key, and
          // the transport. The presentation layer receives a closure and never
          // learns any of them.
          //
          // Sign-in is what **starts** the offline window: it obtains the signed
          // authorisation, which is then verified locally for as long as that
          // authorisation allows. No network call happens per launch.
          recheck: () async => licenceGate.evaluate(),
          signIn: ({
            required String serverUrl,
            required String email,
            required String password,
          }) async {
            final result = await account.signIn(
              serverBaseUrl: Uri.parse(serverUrl),
              email: email,
              password: password,
            );
            if (!result.isSuccess) throw StateError(result.message);

            // A token alone is not a licence. The signed authorisation is fetched
            // and verified **before** anything is stored, so a licence that does
            // not verify never becomes the thing the gate reads next launch.
            final session = account.session;
            if (session == null) throw StateError('Sign-in did not complete.');

            final fetched = await licenceClient.fetch(
              serverBaseUrl: Uri.parse(serverUrl),
              token: session.token,
              bookId: session.bookId,
              installationId: installationId,
              deviceName: _deviceName,
            );
            if (!fetched.isGranted) {
              // **The token is discarded.** A signed-in session with no licence
              // must not be left behind, or the user would appear signed in while
              // locked, which is the most confusing state available.
              await account.signOut();
              throw StateError(fetched.message ?? 'Could not obtain a licence.');
            }

            final authorisation = fetched.authorisation!;
            final verification = await licenceVerifier.verify(
              claimsPayload: authorisation.claims,
              signatureBase64: authorisation.signature,
              installationId: installationId,
            );
            if (!verification.mayOperate) {
              await account.signOut();
              throw StateError(verification.message);
            }

            await licenceStore.write(
              StoredLicence(
                claims: authorisation.claims,
                signature: authorisation.signature,
                // **The server's own clock**, read out of the signed payload rather
                // than taken from this machine, or clock-rollback detection would be
                // comparing the clock against itself.
                serverTime: DateTime.parse(
                  LicenceVerifier.parseClaims(
                    authorisation.claims,
                  )['issued_at']!,
                ).toUtc(),
              ),
            );
          },
          signOut: () async {
            await licenceStore.clear();
            await account.signOut();
          },
        ),
      ),
    );
  } catch (error) {
    runApp(StartupFailureApp(error: error));
  }
}

/// The public key that verifies a licence authorisation.
///
/// **A placeholder that fails closed.** This must be replaced with the base64
/// public key printed by `php artisan financeapp:licence-keypair` **before any
/// real licence will verify** Ã¢â‚¬â€ which is the intended behaviour here, because a
/// build that silently accepted an unverifiable licence would be worse than one
/// that refuses.
///
/// Deliberately a compile-time constant rather than an environment variable: a
/// public key the user can swap out at runtime would make the signature check
/// meaningless, since anything the machine can replace is something the machine
/// controls.
///
/// Replacing it needs a **new desktop build**. That is the accepted cost of having
/// no network call between "I have a licence" and "this licence is genuine"; see
/// ADR 014.
const String licencePublicKey =
    'hNJ0abFa9Z/kTmL8bfQCCFAwG5hUFgp37/oxG3TAKB0=';

/// A stable id for this installation.
///
/// Derived from the OS-provided per-user support directory, so it **survives
/// restarts** Ã¢â‚¬â€ a licence is bound to an installation, so an id that changed per
/// launch would lock the user out every time they started the application.
///
/// Never regenerated, and never taken from the network: the server is told what it
/// is, rather than being allowed to choose it.
String _installationId(String supportDirectoryPath) {
  final digest = sha256.convert(utf8.encode(supportDirectoryPath));
  return 'inst-${digest.toString().substring(0, 32)}';
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
/// With none of those set Ã¢â‚¬â€ which is the normal case Ã¢â‚¬â€ uploading stays absent and
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

/// A uploader that can do nothing, used when nobody is signed in.
///
/// **A fiscal year must not be concluded without an archive**, so this exists to
/// make that true rather than to allow a close with nowhere to put the result:
/// [isAvailable] reports false and the close stops before writing anything.
class NoUploads implements UploadActions {
  const NoUploads();

  @override
  bool get canUpload => false;

  @override
  BackendSession? get session => null;

  @override
  Future<UploadResult> upload(BookBackup backup) async => UploadResult(
        backup: backup,
        status: UploadStatus.unreachable,
        message: 'Nobody is signed in, so there is nowhere to archive to.',
      );

  @override
  Future<List<UploadRecord>> uploadsFor(String fiscalYearLabel) async =>
      const <UploadRecord>[];
}
