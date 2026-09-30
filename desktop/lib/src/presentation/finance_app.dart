import 'package:flutter/material.dart';

import 'app_services.dart';
import 'finance_app_shell.dart';
import 'theme/app_theme.dart';

/// The application root.
///
/// The [MaterialApp] lives here rather than inside the shell, because the theme
/// it provides has to be an **ancestor** of every screen. A widget that reads the
/// theme from its own build method must sit below the `MaterialApp`; a shell that
/// built its own `MaterialApp` would be reading a theme that does not exist yet.
class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key, this.services = const AppServices()});

  /// The use cases the screens may call. A widget test supplies its own, so no
  /// screen ever needs a database to be exercised.
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppTheme.applicationName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: FinanceAppShell(services: services),
    );
  }
}
