import 'dart:io';

import '../domain/accounting/account.dart';
import '../domain/accounting/chart_of_accounts.dart';
import '../domain/accounting/journal_entry.dart';
import '../domain/accounting/journal_line.dart';
import '../domain/accounting/account_type.dart';
import '../domain/accounting/journal_repository.dart';
import '../domain/accounting/year_end.dart';
import '../domain/fiscal/fiscal_year.dart';
import '../domain/fiscal/nepali_fiscal_calendar.dart';
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

  /// Tells the server the year is concluded, and lets it drop the duplicate
  /// snapshots it holds of it.
  ///
  /// ## Why this is separate from [archive], and why it runs later
  ///
  /// **A concluded year is immutable**, so every snapshot of it the server holds
  /// is byte-identical, and only the newest is worth keeping. But the server can
  /// only be told this **after** the next year's books exist locally.
  ///
  /// Doing it during [archive] would leave the two sides disagreeing if the
  /// transition then failed: the server would record the year as concluded while
  /// this computer still had it open and writable, and the year could then be
  /// edited after being declared final.
  ///
  /// ## Failure is not fatal
  ///
  /// Returns normally whether or not the server accepted, and reports what
  /// happened. **The extra copies cost disk and nothing else** -- the archive
  /// itself is already confirmed by then -- so a refusal here must not fail a
  /// close that has otherwise succeeded. It is housekeeping, not correctness.
  Future<ConcludeOutcome> conclude(FiscalYear fiscalYear);
}

/// Tells a server that a fiscal year is concluded, so it can keep only one
/// snapshot of it.
///
/// Separate from [FiscalYearArchive] because the two happen at different times:
/// the archive must be confirmed **before** the transition, and this **after** it.
/// Splitting them keeps that ordering visible in the types rather than implied by
/// the order of two calls inside one method.
abstract interface class FiscalYearConcluder {
  /// Reports the server concluding [fiscalYear].
  ///
  /// Returns rather than throwing for every outcome, because **none of them can
  /// fail a close**: by the time this runs the archive is already confirmed and
  /// the next year's books already exist, so the record is safe. The duplicates
  /// that may remain cost disk and nothing else.
  Future<ConcludeOutcome> conclude(FiscalYear fiscalYear);
}

/// What the server said when it was told the year was concluded.
enum ConcludeOutcome {
  /// The year was concluded and the duplicates dropped.
  concluded,

  /// The server could not be reached. The local close stands and the copies
  /// remain; the next attempt can pick this up.
  unreachable,

  /// The server refused, with a reason. Nothing was deleted.
  refused,
}

/// Creates and activates the next fiscal year's database, with opening balances.
abstract interface class FiscalYearTransition {
  /// Creates the database of [nextYear], carrying [openingBalances] into it.
  ///
  /// Called **only** after the archive has been confirmed. If this fails, the
  /// archived old year and a local recovery copy must both survive — which is the
  /// caller's responsibility, and the reason the ordering is enforced here.
  ///
  /// ## The parameter is the NEW year, and it is named that way on purpose
  ///
  /// It was called `fiscalYear`, which read as "the year being closed" and was
  /// in fact called that way. The implementation names the file from this value,
  /// so passing the wrong year did not fail — it reopened a concluded year and
  /// corrupted it. **A parameter whose meaning is ambiguous will eventually be
  /// supplied wrongly**, so the name now states which year it must be.
  Future<void> beginNextYear({
    required FiscalYear nextYear,
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
    this.serverOutcome = ConcludeOutcome.unreachable,
  });

  final YearEndClosing closed;
  final FiscalYear nextYear;

  /// What the server said when told the year was concluded.
  ///
  /// **The close succeeded regardless.** This reports only whether the duplicate
  /// snapshots on the server were dropped, so a screen can mention it without
  /// implying the year failed to close.
  final ConcludeOutcome serverOutcome;

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
    this.calendar,
  });

  /// The calendar the successor year is derived from.
  ///
  /// Optional so a caller need not supply one, and injectable so a test can prove
  /// the successor comes from the calendar rather than from date arithmetic.
  final NepaliFiscalCalendar? calendar;

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
    //
    // **`_nextYear`, not `fiscalYear`.** This method creates the database named by
    // the year it is handed, so handing it the year being *closed* reopens that
    // concluded year's file read-write and appends the next year's opening entry
    // into it. The archived year would then hold both the closing entries and an
    // opening entry, assets would be posted twice, and every later read of that
    // year would fail `assertBalanced`. The next year would also never exist.
    await transition.beginNextYear(
      nextYear: _nextYear,
      openingBalances: opening,
    );

    // **Last, and deliberately.** The server is told the year is concluded only
    // once the next year's books exist here. Doing it earlier would let a
    // failure in between leave the two sides disagreeing: the server holding a
    // year as final while this computer still had it open and writable.
    //
    // Best-effort by design. The archive is already confirmed, so the record is
    // safe; the duplicates that remain cost disk and nothing else, and failing a
    // close over housekeeping would be the worse outcome.
    final outcome = await archive.conclude(fiscalYear);

    return FiscalYearConcluded(
      closed: closing,
      nextYear: _nextYear,
      openingBalances: opening,
      serverOutcome: outcome,
    );
  }

  /// The year that follows, derived from the calendar rather than by arithmetic.
  ///
  /// ## Why not `endDate + one day`
  ///
  /// It was, and it was wrong twice. It started the new year on the day the old
  /// one **ends** rather than the day after, and it gave the new year two days of
  /// life. Every document after Shrawan would then be filed by a rule nobody
  /// wrote down, and the year boundaries would no longer be the ones the calendar
  /// data describes.
  ///
  /// ## Why the calendar and not the clock
  ///
  /// A close must not depend on what day it happens to be run. The start Bikram
  /// Sambat year comes from [fiscalYear]'s own label, so the same books always
  /// close into the same successor.
  late final FiscalYear _nextYear = _calendar.forBsYear(_startBsYear + 1);

  /// The Bikram Sambat year [fiscalYear] starts in, read from its label.
  ///
  /// `FY 2082/83` is `2082`. Parsed once and cached, because it is needed to
  /// derive the successor.
  late final int _startBsYear = () {
    final match = RegExp(r'^FY (\d{4})/\d{2}$').firstMatch(fiscalYear.label);
    if (match == null) {
      // **Cannot happen through the UI**, which only ever offers years the
      // calendar produced. Throwing beats guessing: a wrong successor here would
      // create the wrong file, and a silently-created file is far worse than a
      // close that refuses and says why.
      throw ArgumentError(
        'The fiscal year label "${fiscalYear.label}" is not in the form '
        '"FY 2082/83", so the year that follows it cannot be derived. Close the '
        'year through the application rather than naming it by hand.',
      );
    }
    return int.parse(match.group(1)!);
  }();

  /// The calendar, injected so the successor is derived from the same data the
  /// rest of the application uses.
  late final NepaliFiscalCalendar _calendar =
      calendar ?? const NepaliFiscalCalendar();

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
}
