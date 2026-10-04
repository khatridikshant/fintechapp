import '../domain/accounting/account.dart';
import '../domain/accounting/account_repository.dart';
import '../domain/accounting/account_type.dart';

/// The chart of accounts, grouped for reading.
///
/// ## Why grouping happens here and not in the screen
///
/// The order a reader expects is **assets, liabilities, equity, income,
/// expenses** — which is the order the balance sheet and the profit and loss use.
/// If the screen chose the grouping, the chart would be one place that disagrees
/// with the two statements built from it, and a user comparing them would be
/// looking at two different arrangements of the same accounts.
///
/// ## Why the *stored* accounts, not the built-in chart
///
/// The chart is seeded when a year is created, and a business may legitimately
/// add accounts of its own. Reading the repository rather than
/// `ChartOfAccounts.all` means an account the user added **appears here** instead
/// of being invisible while still being usable in a journal entry.
///
/// That matters: an account you can post to but cannot see is how a chart stops
/// being trustworthy.
abstract interface class ChartOfAccountsLoader {
  Future<ChartOfAccountsView> load();
}

/// One group of accounts, in display order.
class AccountGroup {
  const AccountGroup({required this.type, required this.accounts});

  final AccountType type;
  final List<Account> accounts;

  /// The heading a reader sees.
  ///
  /// **Defined here rather than on `AccountType`** so the wording is a decision of
  /// this report rather than a property of the enum. The enum is accounting
  /// vocabulary; what to call it on screen is presentation.
  String get title => switch (type) {
        AccountType.asset => 'Assets',
        AccountType.liability => 'Liabilities',
        AccountType.equity => 'Equity',
        AccountType.income => 'Income',
        AccountType.expense => 'Expenses',
      };

  /// Which side increases the accounts in this group, in the short form a book
  /// keeper uses: `Dr` or `Cr`.
  ///
  /// **A group property, not an account one, because every account in a group
  /// shares a type and therefore a normal side.** The alternative -- a screen
  /// reading [AccountType.normalBalance] for each row -- would make the *wording*
  /// a property of the domain enum, which is exactly what [title] refuses to do,
  /// and it would ask every account the same question to produce one answer.
  String get normalSideLabel =>
      type.normalBalance == NormalBalance.debit ? 'Dr' : 'Cr';

  /// Which statement these accounts appear on.
  ///
  /// Reads [AccountType.isBalanceSheet] rather than switching on the type again,
  /// so the chart and the two statements cannot disagree about where an account
  /// belongs -- that question is answered in one place, the domain, and this is
  /// only its wording.
  String get statementLabel =>
      type.isBalanceSheet ? 'Balance sheet' : 'Profit and loss';

  @override
  String toString() =>
      'AccountGroup(${type.name}, ${accounts.length} accounts)';
}

/// The whole chart, grouped.
class ChartOfAccountsView {
  const ChartOfAccountsView({required this.groups, required this.total});

  final List<AccountGroup> groups;

  /// How many accounts in total, for the heading.
  final int total;

  @override
  String toString() =>
      'ChartOfAccountsView(${groups.length} groups, $total accounts)';
}

class LoadChartOfAccounts implements ChartOfAccountsLoader {
  const LoadChartOfAccounts({required this.accounts});

  final AccountRepository accounts;

  /// The order accounts appear in, and the order the groups appear in.
  ///
  /// **The same order the two statements use**, so the chart and the statements
  /// read alike.
  static const List<AccountType> _order = <AccountType>[
    AccountType.asset,
    AccountType.liability,
    AccountType.equity,
    AccountType.income,
    AccountType.expense,
  ];

  @override
  Future<ChartOfAccountsView> load() async {
    final stored = await accounts.all();

    // Grouped by type, in the declared order, then sorted by code **within** each
    // group. An account whose type is not in [_order] would be invisible, so the
    // list is built from the stored accounts rather than from [_order] -- a type
    // added later is then shown, at the end, instead of silently dropped.
    final grouped = <AccountType, List<Account>>{};
    for (final account in stored) {
      grouped.putIfAbsent(account.type, () => <Account>[]).add(account);
    }

    final groups = <AccountGroup>[
      for (final type in _order)
        if (grouped.remove(type) case final List<Account> in_)
          AccountGroup(
            type: type,
            accounts: List<Account>.unmodifiable(
              in_
                ..sort(
                  (Account a, Account b) => a.code.compareTo(b.code),
                ),
            ),
          ),
      // Anything left has a type the order above does not name. Kept rather than
      // dropped, because an account that exists but is not shown is worse than one
      // shown out of order.
      for (final entry in grouped.entries)
        AccountGroup(
          type: entry.key,
          accounts: List<Account>.unmodifiable(
            entry.value
              ..sort((Account a, Account b) => a.code.compareTo(b.code)),
          ),
        ),
    ];

    return ChartOfAccountsView(
      groups: List<AccountGroup>.unmodifiable(groups),
      total: stored.length,
    );
  }
}
