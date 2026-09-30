import '../domain/accounting/journal_entry.dart';
import '../domain/accounting/journal_repository.dart';
import '../domain/fiscal/fiscal_year.dart';
import '../domain/shared/unit_of_work.dart';

/// The outcome of attempting to post a journal entry.
///
/// A refusal is not an exception. Posting a transaction dated outside the active
/// fiscal year is a normal, expected thing for a user to try, and the caller is
/// expected to show them a message about it. Only a genuine malfunction throws.
sealed class PostJournalEntryOutcome {
  const PostJournalEntryOutcome();
}

/// The entry was posted.
final class JournalEntryPosted extends PostJournalEntryOutcome {
  const JournalEntryPosted(this.entry);

  final JournalEntry entry;
}

/// The entry was refused and nothing was written.
final class JournalEntryRejected extends PostJournalEntryOutcome {
  const JournalEntryRejected({
    required this.entry,
    required this.reason,
    required this.fiscalYear,
  });

  final JournalEntry entry;
  final PostRejectionReason reason;

  /// The fiscal year the posting was tested against, so a message can name it.
  final FiscalYear fiscalYear;

  /// A message suitable for showing to a user.
  String get message => switch (reason) {
        PostRejectionReason.outsideFiscalYear =>
          'This transaction is dated outside ${fiscalYear.label} '
              '(${_short(fiscalYear.startDate)} to ${_short(fiscalYear.endDate)}) '
              'and cannot be posted into it.',
      };

  static String _short(DateTime d) => '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

enum PostRejectionReason {
  /// The entry is dated outside the active fiscal year.
  outsideFiscalYear,
}

/// Posts a journal entry into an active fiscal year.
///
/// This is the first use case in the application layer, and it exists to hold a
/// rule that belongs to no single layer below it:
///
/// Specification section 27 requires that a transaction be rejected when its
/// date falls outside the active fiscal year. That check needs the fiscal
/// calendar, and the calendar must not leak into [JournalEntry], which would
/// break the domain's independence. It must also not live in the repository,
/// where it could be bypassed by any other caller. So it lives here, at the
/// boundary where a business operation is actually performed.
///
/// The guard runs **before** anything is written. Nothing is opened, nothing is
/// rolled back, and no partial state is ever created for a refused posting.
///
/// The write itself runs inside [UnitOfWork], so when this use case grows to
/// also post cost of goods sold, a stock movement, or a receivable, all of those
/// become part of the same atomic operation.
class PostJournalEntry {
  const PostJournalEntry({
    required this.fiscalYear,
    required this.journal,
    required this.unitOfWork,
  });

  /// The fiscal year currently open for writing.
  final FiscalYear fiscalYear;

  final JournalRepository journal;

  final UnitOfWork unitOfWork;

  /// Validates and posts [entry].
  ///
  /// Returns [JournalEntryPosted] or [JournalEntryRejected]. Throws only if the
  /// write itself fails, for example because the entry id has already been
  /// posted, in which case the transaction is rolled back and nothing is
  /// written.
  Future<PostJournalEntryOutcome> call(JournalEntry entry) async {
    if (!fiscalYear.contains(entry.date)) {
      return JournalEntryRejected(
        entry: entry,
        reason: PostRejectionReason.outsideFiscalYear,
        fiscalYear: fiscalYear,
      );
    }

    await unitOfWork.run(() => journal.append(entry));

    return JournalEntryPosted(entry);
  }
}
