import 'package:flutter/material.dart';

import '../app_services.dart';
import '../finance_app_shell.dart';
import '../screens/backup_screen.dart';
import '../screens/customer_screen.dart';
import '../screens/invoice_screen.dart';
import '../screens/payment_screen.dart';
import '../screens/general_ledger_screen.dart';
import '../screens/licenses_screen.dart';
import '../screens/placeholder_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/trial_balance_screen.dart';

/// A group of related screens, as `ui.txt` section 13 lays out the navigation.
@immutable
class NavigationGroup {
  const NavigationGroup({required this.title, required this.sections});

  /// The group heading, shown as a large label above its items.
  final String title;

  final List<NavigationItem> sections;
}

/// One destination in the primary navigation.
@immutable
class NavigationItem {
  const NavigationItem({required this.title, required this.icon, this.route});

  /// Builds the screen this opens, or `null` when it has not been built yet.
  final WidgetBuilder? route;

  final String title;

  /// A simple outline icon, per `ui.txt` section 4: "simple icons".
  final IconData icon;
}

/// The primary navigation, in the order `ui.txt` section 13 suggests.
///
/// A section has a screen only when the corresponding use case has been wired in
/// [services]. Everything else shows a placeholder that says plainly that it has
/// not been built, rather than a blank panel or a crash.
///
/// [onAccountChanged] reaches the Settings screen, which needs it because signing
/// in changes which token a backup is sent with, and the shell has to rebuild its
/// services for that to take effect. Optional, so a test or a bare screen does not
/// have to supply one.
List<NavigationGroup> buildNavigation(
  AppServices services, {
  Future<void> Function()? onAccountChanged,
}) {
  final trialBalance = services.trialBalance;

  return <NavigationGroup>[
    NavigationGroup(
      title: 'Overview',
      sections: <NavigationItem>[
        NavigationItem(
            title: 'Dashboard', icon: Icons.space_dashboard_outlined),
      ],
    ),
    NavigationGroup(
      title: 'Accounting',
      sections: <NavigationItem>[
        NavigationItem(title: 'Journal', icon: Icons.menu_book_outlined),
        NavigationItem(
            title: 'Chart of Accounts', icon: Icons.account_tree_outlined),
        NavigationItem(
          title: 'General Ledger',
          icon: Icons.vertical_split_outlined,
          route: services.generalLedger == null
              ? null
              : (context) =>
                  GeneralLedgerScreen(loader: services.generalLedger!),
        ),
        NavigationItem(
          title: 'Trial Balance',
          icon: Icons.balance_outlined,
          route: trialBalance == null
              ? null
              : (context) => TrialBalanceScreen(
                    loader: trialBalance,
                    // Tapping an account opens that account's ledger, so the two
                    // reports drill into each other without a router.
                    onAccountSelected: services.generalLedger == null
                        ? null
                        : (_) => _shellOf(context).select(
                              _ledgerItemFor(services)!,
                            ),
                  ),
        ),
      ],
    ),
    NavigationGroup(
      title: 'Sales',
      sections: <NavigationItem>[
        NavigationItem(
          title: 'Invoices',
          icon: Icons.description_outlined,
          route: services.issueInvoice == null
              ? null
              : (context) =>
                  InvoiceScreen(issueInvoice: services.issueInvoice!),
        ),
        NavigationItem(title: 'Sales', icon: Icons.trending_up_outlined),
        NavigationItem(
          title: 'Customers',
          icon: Icons.people_outline,
          route: services.createCustomer == null
              ? null
              : (context) =>
                  CustomerScreen(createCustomer: services.createCustomer!),
        ),
        NavigationItem(
            title: 'Receivables', icon: Icons.account_balance_wallet_outlined),
      ],
    ),
    NavigationGroup(
      title: 'Purchases',
      sections: <NavigationItem>[
        NavigationItem(title: 'Purchases', icon: Icons.shopping_cart_outlined),
        NavigationItem(title: 'Suppliers', icon: Icons.local_shipping_outlined),
        NavigationItem(title: 'Payables', icon: Icons.payments_outlined),
      ],
    ),
    NavigationGroup(
      title: 'Inventory',
      sections: <NavigationItem>[
        NavigationItem(title: 'Products', icon: Icons.inventory_2_outlined),
        NavigationItem(title: 'Stock', icon: Icons.warehouse_outlined),
        NavigationItem(
            title: 'Stock Movements', icon: Icons.swap_vert_outlined),
      ],
    ),
    NavigationGroup(
      title: 'Payments',
      sections: <NavigationItem>[
        NavigationItem(
          title: 'Receipts',
          icon: Icons.receipt_long_outlined,
          route: services.recordPayment == null
              ? null
              : (context) =>
                  PaymentScreen(recordPayment: services.recordPayment!),
        ),
        NavigationItem(title: 'Payments', icon: Icons.paid_outlined),
        NavigationItem(title: 'Transfers', icon: Icons.compare_arrows_outlined),
      ],
    ),
    NavigationGroup(
      title: 'Reports',
      sections: <NavigationItem>[
        NavigationItem(title: 'Profit & Loss', icon: Icons.show_chart_outlined),
        NavigationItem(title: 'Balance Sheet', icon: Icons.assignment_outlined),
        NavigationItem(
            title: 'Cash Flow', icon: Icons.waterfall_chart_outlined),
        NavigationItem(title: 'Sales Reports', icon: Icons.bar_chart_outlined),
        NavigationItem(
            title: 'Inventory Reports', icon: Icons.donut_small_outlined),
        NavigationItem(title: 'Tax Reports', icon: Icons.receipt_outlined),
      ],
    ),
    NavigationGroup(
      title: 'System',
      sections: <NavigationItem>[
        NavigationItem(
          title: 'Settings',
          icon: Icons.settings_outlined,
          route: services.account == null && services.businessDetails == null
              ? null
              : (context) => SettingsScreen(
                    account: services.account,
                    onAccountChanged: onAccountChanged ?? () async {},
                    businessDetails: services.businessDetails,
                    onBusinessSaved: (profile) async {
                      await services.businessDetails?.save(profile);
                      // Rebuild so anything reading the profile sees the new one.
                      await onAccountChanged?.call();
                    },
                  ),
        ),
        NavigationItem(
          title: 'Backup',
          icon: Icons.backup_outlined,
          route: services.backup == null
              ? null
              : (context) => BackupScreen(
                    service: services.backup!,
                    // Null when the desktop is not signed in. The screen still
                    // works; it just cannot send anything off the machine.
                    uploads: services.upload,
                  ),
        ),
        NavigationItem(title: 'Sync', icon: Icons.sync_outlined),
        NavigationItem(title: 'Fiscal Year', icon: Icons.event_outlined),
        // Required by the MIT and BSD-3 licences of every dependency.
        NavigationItem(
          title: 'Licences',
          icon: Icons.gavel_outlined,
          route: LicensesScreen.route,
        ),
      ],
    ),
  ];
}

/// Every navigation item, flattened. Used for searching and for tests.
List<NavigationItem> allNavigationItemsFor(AppServices services) =>
    buildNavigation(services)
        .expand((group) => group.sections)
        .toList(growable: false);

/// The General Ledger navigation item, or null when it has no screen.
NavigationItem? _ledgerItemFor(AppServices services) {
  for (final group in buildNavigation(services)) {
    for (final section in group.sections) {
      if (section.title == 'General Ledger') return section;
    }
  }
  return null;
}

/// The shell's own state, reached from a descendant so a navigation item can
/// change the selected section without the shell exposing a global registry.
FinanceAppShellState _shellOf(BuildContext context) =>
    context.findAncestorStateOfType<FinanceAppShellState>()!;

/// The screen shown for a section that exists in the design but has not been
/// built yet.
Widget placeholderFor(String title) => PlaceholderScreen(title: title);
