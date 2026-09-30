import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'src/domain/fiscal/nepali_fiscal_calendar.dart';
import 'src/presentation/app_services.dart';
import 'src/infrastructure/database/file_books_session.dart';
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

    runApp(
      FinanceApp(services: AppServices().forSession(session)),
    );
  } catch (error) {
    runApp(StartupFailureApp(error: error));
  }
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
