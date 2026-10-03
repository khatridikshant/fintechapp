import 'dart:io';

import 'package:path/path.dart' as p;

import '../../application/conclude_fiscal_year.dart';
import '../../domain/accounting/account.dart';
import '../../domain/accounting/account_type.dart';
import '../../domain/accounting/chart_of_accounts.dart';
import '../../domain/accounting/journal_entry.dart';
import '../../domain/accounting/journal_line.dart';
import '../../domain/fiscal/fiscal_year.dart';
import '../../domain/shared/money.dart';
import 'drift_account_repository.dart';
import 'drift_journal_repository.dart';
import 'sqlite_native.dart';

/// Creates the next fiscal year's database and carries the opening balances into
/// it.
///
/// ## Opening balances are one entry, not a series
///
/// Everything that carries forward is posted as a single dated entry at the start
/// of the new year, debiting assets and crediting liabilities and equity. Doing it
/// as one entry means the balance sheet of the new year balances from its first
/// moment, rather than being assembled over several edits.
class LocalFiscalYearTransition implements FiscalYearTransition {
  LocalFiscalYearTransition({required this.booksDirectory});

  final Directory booksDirectory;

  @override
  Future<void> beginNextYear({
    required FiscalYear nextYear,
    required Map<Account, Money> openingBalances,
  }) async {
    await booksDirectory.create(recursive: true);

    // **The file is named from [nextYear], which is why the parameter is not
    // called `fiscalYear`.** It was, and passing the year being concluded then
    // created that year's database instead — reopening a concluded year and
    // appending an opening entry to it.
    final database = openFileDatabase(_fileFor(nextYear));

    try {
      // The chart first: the opening entry references these accounts, and a
      // foreign key to an account that does not exist would be refused.
      await DriftAccountRepository(database)
          .saveAll(const ChartOfAccounts().all);

      final lines = _openingLines(openingBalances);

      if (lines.isNotEmpty) {
        await DriftJournalRepository(database).append(
          JournalEntry(
            id: 'OPEN-${nextYear.label}',
            date: nextYear.startDate,
            description: 'Opening balances carried from ${nextYear.label}',
            reference: 'OPENING-${nextYear.label}',
            lines: lines,
          ),
        );
      }
    } finally {
      await database.close();
    }
  }

  /// The opening entry's lines, debiting assets and crediting the rest.
  ///
  /// **Every account is placed on the side that matches its normal balance**, so a
  /// carried-forward liability becomes a credit. Getting that backwards would show
  /// next year's balance sheet with liabilities on the asset side, and the trial
  /// balance would still agree.
  List<JournalLine> _openingLines(Map<Account, Money> balances) {
    final lines = <JournalLine>[];

    balances.forEach((Account account, Money balance) {
      if (balance.isZero) return;
      final isDebitNormal = account.normalBalance == NormalBalance.debit;
      lines.add(
        isDebitNormal
            ? JournalLine.debit(account: account, amount: balance.abs())
            : JournalLine.credit(account: account, amount: balance.abs()),
      );
    });

    // Sorted by code so the entry is deterministic: the same books carried
    // forward twice must produce identical postings.
    lines.sort((JournalLine a, JournalLine b) =>
        a.account.code.compareTo(b.account.code));
    return List<JournalLine>.unmodifiable(lines);
  }

  /// The next year's file, named the way every other year's file is named.
  File _fileFor(FiscalYear fiscalYear) {
    final safe = fiscalYear.label.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');
    return File(p.join(booksDirectory.path, 'accounting-$safe.db'));
  }
}
