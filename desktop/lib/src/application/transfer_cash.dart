import '../domain/accounting/account.dart';
import '../domain/accounting/chart_of_accounts.dart';
import '../domain/accounting/journal_entry.dart';
import '../domain/accounting/journal_line.dart';
import '../domain/fiscal/fiscal_year.dart';
import '../domain/shared/money.dart';
import 'post_journal_entry.dart';

/// Moving money between the business's own cash accounts.
///
/// ## Why this is not a journal entry
///
/// The Journal screen can already post any entry, including one that moves money
/// between bank and cash. What it cannot do is **stop you** from posting something
/// that only looks like a transfer. A two-line entry debiting "Office rent" and
/// crediting "Bank" is mechanically valid, balances, and is a completely different
/// event from moving money between two tills — but on the Journal screen it is the
/// same two boxes.
///
/// So this use case exists to make one rule structural rather than advisory: **both
/// sides must be a cash account.** A "transfer" that lands on an expense or a
/// liability is a miscategorisation, and it should not be possible to record one
/// here and have it look like housekeeping.
///
/// ## The entry it produces
///
/// `Dr <to> / Cr <from>` for the amount moved. That is the whole accounting
/// consequence of moving money between two accounts the business already owns:
/// nothing is spent, nothing is owed, and no income or expense is recognised.
class TransferCash {
  const TransferCash({
    required this.fiscalYear,
    required this.postEntry,
  });

  final FiscalYear fiscalYear;
  final PostJournalEntry postEntry;

  /// Fixed default, so the common case needs no choices made.
  static final Account defaultFrom = ChartOfAccounts.bank;

  /// Fixed default, so the common case needs no choices made.
  static final Account defaultTo = ChartOfAccounts.cash;

  /// The accounts a transfer may move money between.
  ///
  /// **Both sides, and nothing else.** An account absent from this list cannot
  /// appear in a transfer, which is what makes "both sides are cash" a rule rather
  /// than a suggestion.
  static List<Account> get cashAccounts => const <Account>[
        ChartOfAccounts.bank,
        ChartOfAccounts.cash,
      ];

  /// Whether [account] may take part in a transfer.
  static bool isCashAccount(Account account) => cashAccounts.any(
        (Account candidate) => candidate.id == account.id,
      );

  Future<TransferOutcome> transfer({
    required Account from,
    required Account to,
    required Money amount,
    required String reason,
    DateTime? date,
  }) async {
    if (from.id == to.id) {
      return const TransferRefused(
        TransferRefusal.sameAccount,
        'Choose two different accounts. Moving money from an account to itself '
        'does nothing.',
      );
    }

    // **Checked in this order, and before anything is written.** A transfer to an
    // expense account is the mistake this whole use case exists to prevent, so it
    // is refused rather than recorded.
    if (!isCashAccount(from)) {
      return TransferRefused(
        TransferRefusal.notACashAccount,
        '${from.name} is not a cash account. A transfer moves money the business '
        'already owns, between its bank and cash. To record something else, '
        'use the Journal screen.',
      );
    }
    if (!isCashAccount(to)) {
      return TransferRefused(
        TransferRefusal.notACashAccount,
        '${to.name} is not a cash account. A transfer moves money the business '
        'already owns, between its bank and cash. To record something else, '
        'use the Journal screen.',
      );
    }

    if (amount.minorUnits <= 0) {
      return const TransferRefused(
        TransferRefusal.notPositive,
        'The amount must be more than zero.',
      );
    }

    final DateTime when = date ?? DateTime.now();

    // Posted through the ordinary engine, so the entry is validated, balanced,
    // range-checked against the fiscal year and written in a transaction exactly
    // as any other entry would be. A transfer gets no special treatment that
    // could make it behave differently from the ledger it lands in.
    final outcome = await postEntry(
      JournalEntry(
        id: 'TRN-${when.microsecondsSinceEpoch}',
        date: when,
        description: reason.trim().isEmpty
            ? 'Transfer from ${from.name} to ${to.name}'
            : 'Transfer: ${reason.trim()}',
        reference: 'TRANSFER-${when.microsecondsSinceEpoch}',
        lines: <JournalLine>[
          JournalLine.debit(account: to, amount: amount),
          JournalLine.credit(account: from, amount: amount),
        ],
      ),
    );

    return switch (outcome) {
      JournalEntryPosted(:final entry) =>
        TransferCompleted(entry: entry, from: from, to: to, amount: amount),
      // A refusal from the engine -- a date outside the fiscal year, most likely.
      // Passed through rather than swallowed, because it carries its own reason.
      JournalEntryRejected(:final reason) =>
        TransferRefused(TransferRefusal.rejected, '$reason'),
    };
  }
}

/// Why a transfer was refused.
enum TransferRefusal {
  /// The same account on both sides.
  sameAccount,

  /// One side is not a cash account.
  notACashAccount,

  /// Zero, or a negative amount.
  notPositive,

  /// The accounting engine refused it, most often a date outside the year.
  rejected,
}

/// What happened.
sealed class TransferOutcome {
  const TransferOutcome();
}

class TransferCompleted extends TransferOutcome {
  const TransferCompleted({
    required this.entry,
    required this.from,
    required this.to,
    required this.amount,
  });

  final JournalEntry entry;
  final Account from;
  final Account to;
  final Money amount;
}

class TransferRefused extends TransferOutcome {
  const TransferRefused(this.reason, this.message);

  final TransferRefusal reason;

  /// Says what to do instead, not only what went wrong.
  final String message;

  @override
  String toString() => 'TransferRefused(${reason.name}: $message)';
}
