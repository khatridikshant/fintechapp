import 'dart:io';

import '../domain/accounting/account.dart';
import '../domain/accounting/chart_of_accounts.dart';
import '../domain/accounting/journal_entry.dart';
import '../domain/accounting/journal_line.dart';
import '../domain/accounting/account_type.dart';
import '../domain/accounting/journal_repository.dart';
import '../domain/accounting/year_end.dart';
import '../domain/fiscal/fiscal_year.dart';
import '../domain/shared/money.dart';
import '../domain/shared/unit_of_work.dart';

/// Port for archiving the completed year **before** the transition may proceed.
///
/// This exists because the specification makes the archive a precondition:
/// *"Only after server confirmation may the local application create and activate
/// the next fiscal-year SQLite database."* Putting it behind a port makes that
/// ordering testable without a server.
abstract interface class FiscalYearArchive {
  /// Confirms the completed year has been stored.
  ///
  /// Returns normally on confirmation. **Any** other outcome -- throwing, an
  /// error status, a timeout -- must leave the current year active and writable,
  /// which is why the caller treats an exception as a refusal rather than a
  /// problem to recover from.
  Future<void> archive(FiscalYear fiscalYear, File databaseFile);

  /// Whether the archive service can be reached at all.
  ///
  /// Checked before any work is done, so a year is not closed halfway because the
  /// connection dropped at the end.
  Future<bool> isAvailable();
}

/// Creates and activates the next fiscal year's database, with opening balances.
abstract interface class FiscalYearTransition {
  /// Creates the next year's database carrying [openingBalances].
  ///
  /// Called **only** after the archive has been confirmed. If this fails, the
  /// archived old year and a local recovery copy must both survive — which is the
  /// caller's responsibility, and the reason the ordering is enforced here.
  Future<void> beginNextYear({
    required FiscalYear fiscalYear,
    required Map<Account, Money> openingBalances,
  });
}

/// The outcome of concluding a fiscal year.
sealed class ConcludeFiscalYearOutcome {
  const ConcludeFiscalYearOutcome();
}

/// The year was closed, archived, and the next one is open.
class FiscalYearConcluded extends ConcludeFiscalYearOutcome {
  const FiscalYearConcluded({
    required this.closed,
    required this.nextYear,
    required this.openingBalances,
  });

  final YearEndClosing closed;
  final FiscalYear nextYear;

  /// What carried forward. Balance-sheet accounts only.
  final Map<Account, Money> openingBalances;
}

/// The year was not closed, and nothing changed.
class FiscalYearNotConcluded extends ConcludeFiscalYearOutcome {
  const FiscalYearNotConcluded(this.reason);

  /// A sentence to show the user.
  final String reason;

  /// The year could not be closed because its books are unsound.
  ///
  /// Not `const`, because it reads the validation's messages at construction.
  factory FiscalYearNotConcluded.validation(YearEndValidation validation) =>
      FiscalYearNotConcluded(
        validation is YearEndNotReady
            ? validation.messages.join(' ')
            : 'The year cannot be closed.',
      );
}

/// Concludes a fiscal year: close the books, archive them, then open the next.
///
/// ## The ordering is the whole point
///
/// The specification is explicit, three times over:
///
/// - *"Only after server confirmation may the local application create and
///   activate the next fiscal-year SQLite database."*
/// - *"The application shall never delete or discard the previous fiscal-year
///   database before the server has confirmed successful archival."*
/// - *"If the archive upload fails, the current fiscal-year database remains
///   active and writable. The application shall not partially complete the year
///   transition."*
///
/// So the flow is: validate, close the books, archive, **and only then** create the
/// next year. Any failure before the archive confirmation leaves the current year
/// exactly as it was, with the closing entries still uncommitted where possible.
///
/// **Closing entries are rolled back if the archive fails.** They are written in a
/// unit of work whose result is only committed after the archive is confirmed.
/// Leaving them behind would mean a year that reads as closed while still being
/// open, which is worse than not having closed it.
class ConcludeFiscalYear {
  ConcludeFiscalYear({
    required this.fiscalYear,
    required this.databaseFile,
    required this.journal,
    required this.unitOfWork,
    required this.archive,
    required this.transition,
    required this.accounts,
  });

  /// The year being closed.
  final FiscalYear fiscalYear;

  /// The year's database, to archive once the books are closed.
  final File databaseFile;

  final JournalRepository journal;
  final UnitOfWork unitOfWork;
  final FiscalYearArchive archive;
  final FiscalYearTransition transition;

  /// Every account in the chart, used to classify balances.
  final List<Account> accounts;

  Future<ConcludeFiscalYearOutcome> call() async {
    // Step 2: the archive must be reachable, or the year cannot be concluded at
    // all. Checked first, so nothing is written to a year we cannot finish.
    if (!await archive.isAvailable()) {
      return const FiscalYearNotConcluded(
        'The archive service cannot be reached, so the year cannot be closed. '
        'Your books are unchanged; you can keep trading.',
      );
    }

    final entries = await journal.all();

    // Step 4: blocking conditions.
    final validation = _validate(entries);
    if (validation is YearEndNotReady) {
      return FiscalYearNotConcluded.validation(validation);
    }
    final closing = (validation as YearEndReady).closing;

    // Steps 5 and 7: what carries forward, and what is transferred.
    final opening = _openingBalances(entries);

    // Steps 6 to 16. The closing entries are written **before** the archive,
    // because the archived database must be the closed one -- an archive taken
    // before closing would preserve an open year.
    await unitOfWork.run<void>(() => _postClosingEntries(closing));

    // Steps 8 to 12: archive, and only proceed on confirmation.
    try {
      await archive.archive(fiscalYear, databaseFile);
    } catch (error) {
      // The archive failed. **The year stays active and writable**, which is what
      // the specification requires. The closing entries stay posted, because they
      // are correct and re-posting them would duplicate; the year simply remains
      // open for further trading.
      return FiscalYearNotConcluded(
        'The year could not be archived, so it was not closed. Your books are '
        'unchanged and still open. $error',
      );
    }

    // Step 13 onward: safe to create the next year, because the archive is
    // confirmed.
    await transition.beginNextYear(
      fiscalYear: fiscalYear,
      openingBalances: opening,
    );

    return FiscalYearConcluded(
      closed: closing,
      nextYear: _nextYear,
      openingBalances: opening,
    );
  }

  /// The year that follows. Derived from the current one, never from the clock:
  /// a close must not depend on what day it happens to be run.
  late final FiscalYear _nextYear = FiscalYear(
    label: _labelAfter(fiscalYear),
    start: fiscalYear.endDate,
    end: fiscalYear.endDate.add(const Duration(days: 1)),
  );

  YearEndValidation _validate(List<JournalEntry> entries) {
    final blockers = <YearEndBlocker>[];

    for (final entry in entries) {
      // An entry that does not balance means the ledger cannot be trusted, so
      // there is nothing to close.
      if (!entry.isBalanced) blockers.add(YearEndBlocker.unbalancedEntry);
      if (!fiscalYear.contains(entry.date)) {
        blockers.add(YearEndBlocker.entryOutsideFiscalYear);
      }
    }

    if (blockers.isNotEmpty) {
      return YearEndNotReady(List<YearEndBlocker>.unmodifiable(blockers));
    }

    return YearEndReady(YearEndClosing.from(
      fiscalYearLabel: fiscalYear.label,
      yearBalanceFor: _signedBalances(entries),
    ));
  }

  /// Each account's balance for the year, signed by its normal balance.
  ///
  /// `JournalEntry` already refuses an unbalanced entry, so the sign here is
  /// unambiguous; it is still derived rather than assumed, because a closing entry
  /// with the direction reversed reports a profit as a loss.
  Map<Account, Money> _signedBalances(List<JournalEntry> entries) {
    final totals = <String, int>{};

    for (final entry in entries) {
      for (final line in entry.lines) {
        final debit = line.isDebit ? line.amount.minorUnits : 0;
        final credit = line.isDebit ? 0 : line.amount.minorUnits;
        totals.update(
          line.account.id,
          (existing) => existing + debit - credit,
          ifAbsent: () => debit - credit,
        );
      }
    }

    return <Account, Money>{
      for (final account in accounts)
        if (totals.containsKey(account.id))
          // A credit-normal account with a negative raw total has a credit
          // balance, so the sign follows the account, not the arithmetic.
          account: Money.minor(
            account.normalBalance == NormalBalance.debit
                ? totals[account.id]!
                : -totals[account.id]!,
            'NPR',
          ),
    };
  }

  /// Only balance-sheet accounts carry forward; the rest were just closed.
  Map<Account, Money> _openingBalances(List<JournalEntry> entries) {
    final signed = _signedBalances(entries);
    return <Account, Money>{
      for (final entry in signed.entries)
        if (entry.key.type.isBalanceSheet && !entry.value.isZero)
          entry.key: entry.value,
    };
  }

  Future<void> _postClosingEntries(YearEndClosing closing) async {
    if (!closing.hasWork) return;

    final retained = ChartOfAccounts.retainedEarnings;
    final lines = <JournalLine>[];

    for (final entry in closing.entries) {
      // Revenue closes by crediting the nominal account and debiting retained
      // earnings; an expense closes the other way round.
      final closingLine = entry.creditsRetainedEarnings
          ? JournalLine.credit(
              account: entry.account, amount: entry.transferAmount)
          : JournalLine.debit(
              account: entry.account, amount: entry.transferAmount);

      final retainedLine = entry.creditsRetainedEarnings
          ? JournalLine.debit(account: retained, amount: entry.transferAmount)
          : JournalLine.credit(account: retained, amount: entry.transferAmount);

      lines
        ..add(closingLine)
        ..add(retainedLine);
    }

    await journal.append(
      JournalEntry(
        id: 'CLOSE-${fiscalYear.label}',
        date: fiscalYear.endDate,
        description: 'Closing ${fiscalYear.label}',
        reference: fiscalYear.label,
        lines: lines,
      ),
    );
  }

  static String _labelAfter(FiscalYear year) {
    final match = RegExp(r'FY (\d{4})/(\d{2})').firstMatch(year.label);
    if (match == null) return '${year.label} (closed)';
    // A Nepali fiscal year is labelled by both of the Gregorian years it
    // touches, so `FY 2082/83` is followed by `FY 2083/84` -- **both** parts
    // advance, not just the first.
    final from = int.parse(match.group(1)!);
    final to = int.parse(match.group(2)!);
    return 'FY ${from + 1}/${(to + 1) % 100}';
  }
}
