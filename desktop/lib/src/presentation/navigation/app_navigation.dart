import 'package:flutter/material.dart';

import '../app_services.dart';
import '../finance_app_shell.dart';
import '../screens/backup_screen.dart';
import '../screens/credit_note_screen.dart';
import '../screens/conclude_fiscal_year_screen.dart';
import '../screens/customer_screen.dart';
import '../screens/journal_entry_screen.dart';
import '../screens/stock_movement_screen.dart';
import '../screens/invoice_screen.dart';
import '../screens/payment_screen.dart';
import '../screens/profit_and_loss_screen.dart';
import '../screens/receivables_screen.dart';
import '../screens/product_screen.dart';
import '../screens/financial_reports_screen.dart';
import '../screens/chart_of_accounts_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/general_ledger_screen.dart';
import '../screens/licenses_screen.dart';
import '../screens/placeholder_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/transfer_screen.dart';
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
          title: 'Dashboard',
          icon: Icons.space_dashboard_outlined,
          // **Every loader present, or no route.** A dashboard missing one figure
          // would render a partial landing screen, and a partial landing screen is
          // worse than none — it looks like the state of the business.
          route: services.dashboardTrialBalance == null ||
                  services.profitAndLoss == null ||
                  services.balanceSheet == null
              ? null
              : (context) => DashboardScreen(
                    trialBalance: services.dashboardTrialBalance!,
                    profitAndLoss: services.profitAndLoss!,
                    balanceSheet: services.balanceSheet!,
                    fiscalYearLabel:
                        services.session?.openYear.fiscalYear.label,
                  ),
        ),
      ],
    ),
    NavigationGroup(
      title: 'Accounting',
      sections: <NavigationItem>[
        NavigationItem(
          title: 'Journal',
          icon: Icons.menu_book_outlined,
          route: services.postEntry == null
              ? null
              : (context) => JournalEntryScreen(postEntry: services.postEntry!),
        ),
        NavigationItem(
          title: 'Chart of Accounts',
          icon: Icons.account_tree_outlined,
          route: services.chartOfAccounts == null
              ? null
              : (context) => ChartOfAccountsScreen(
                    chartOfAccounts: services.chartOfAccounts!,
                    fiscalYearLabel:
                        services.session?.openYear.fiscalYear.label,
                  ),
        ),
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
        // Credit notes reduce an invoice already sent. Not in ui.txt's navigation
        // list, but `IssueCreditNote` exists and a business with no way to issue
        // one cannot correct a mistake it has already billed.
        NavigationItem(
          title: 'Credit Notes',
          icon: Icons.receipt_long_outlined,
          route: services.issueCreditNote == null
              ? null
              : (context) => CreditNoteScreen(
                    issueCreditNote: services.issueCreditNote!,
                  ),
        ),
        NavigationItem(
          title: 'Customers',
          icon: Icons.people_outline,
          route: services.createCustomer == null
              ? null
              : (context) =>
                  CustomerScreen(createCustomer: services.createCustomer!),
        ),
        NavigationItem(
          title: 'Receivables',
          icon: Icons.account_balance_wallet_outlined,
          route: services.receivables == null
              ? null
              : (context) => ReceivablesScreen(
                    receivables: services.receivables!,
                  ),
        ),
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
        NavigationItem(
          title: 'Products',
          icon: Icons.inventory_2_outlined,
          route: services.createProduct == null
              ? null
              : (context) =>
                  ProductScreen(createProduct: services.createProduct!),
        ),
        NavigationItem(title: 'Stock', icon: Icons.warehouse_outlined),
        NavigationItem(
            title: 'Stock Movements',
            icon: Icons.swap_vert_outlined,
            route: services.postMovement == null
                ? null
                : (context) => StockMovementScreen(
                      postMovement: services.postMovement!,
                    )),
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
        NavigationItem(
          title: 'Transfers',
          icon: Icons.compare_arrows_outlined,
          route: services.transferCash == null
              ? null
              : (context) => TransferScreen(
                    transferCash: services.transferCash!,
                    fiscalYearLabel:
                        services.session?.openYear.fiscalYear.label,
                  ),
        ),
      ],
    ),
    NavigationGroup(
      title: 'Reports',
      sections: <NavigationItem>[
        NavigationItem(
          title: 'Profit & Loss',
          icon: Icons.show_chart_outlined,
          route: services.profitAndLoss == null
              ? null
              : (context) => ProfitAndLossScreen(
                    profitAndLoss: services.profitAndLoss!,
                    fiscalYearLabel:
                        services.session?.openYear.fiscalYear.label,
                  ),
        ),
        NavigationItem(
          title: 'Balance Sheet',
          icon: Icons.assignment_outlined,
          route: services.balanceSheet == null
              ? null
              : (context) => BalanceSheetScreen(
                    balanceSheet: services.balanceSheet!,
                    fiscalYearLabel:
                        services.session?.openYear.fiscalYear.label,
                  ),
        ),
        // The four reports below are built. They share one screen, and each entry
        // opens it on its own report, so the navigation reads the way `ui.txt`
        // describes while only one widget exists.
        NavigationItem(
          title: 'Cash Flow',
          icon: Icons.waterfall_chart_outlined,
          route: _reportsRoute(services, FinancialReport.cashFlow),
        ),
        NavigationItem(
          title: 'Sales Reports',
          icon: Icons.bar_chart_outlined,
          route: _reportsRoute(services, FinancialReport.sales),
        ),
        NavigationItem(
          title: 'Inventory Reports',
          icon: Icons.donut_small_outlined,
          route: _reportsRoute(services, FinancialReport.inventory),
        ),
        NavigationItem(
          title: 'Category Reports',
          icon: Icons.category_outlined,
          route: _reportsRoute(services, FinancialReport.byCategory),
        ),
        NavigationItem(
          title: 'Tax Reports',
          icon: Icons.receipt_outlined,
          route: _reportsRoute(services, FinancialReport.tax),
        ),
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
                    // **Through the gate when there is one.** Falling back to
                    // `account.signOut()` alone would clear the token and leave
                    // the stored licence, so the application would stay unlocked
                    // after a sign-out. A build with no gate has no licence to
                    // forget, so the bare sign-out is correct there.
                    onSignOut: services.signOutForLicence ??
                        (services.account?.signOut ?? () async {}),
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
        NavigationItem(
          title: 'Fiscal Year',
          icon: Icons.event_outlined,
          route: services.concludeYear == null
              ? null
              : (context) => ConcludeFiscalYearScreen(
                    concludeYear: services.concludeYear!,
                  ),
        ),
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

/// Opens the shared reports screen on one report, or null when the books expose
/// none of them.
///
/// Null rather than a disabled-looking-but-live route, so the entry says
/// "unavailable" instead of opening an error.
WidgetBuilder? _reportsRoute(AppServices services, FinancialReport report) {
  if (services.cashFlow == null ||
      services.sales == null ||
      services.inventoryReport == null ||
      services.categoryReport == null ||
      services.tax == null) {
    return null;
  }
  return (context) => FinancialReportsScreen(
        cashFlow: services.cashFlow!,
        sales: services.sales!,
        inventory: services.inventoryReport!,
        categoryReport: services.categoryReport!,
        tax: services.tax!,
        fiscalYearLabel: services.session?.openYear.fiscalYear.label,
        initialReport: report,
      );
}

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
