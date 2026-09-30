import '../shared/money.dart';
import 'journal_line.dart';

/// A posted double-entry journal entry.
///
/// The single invariant that defines the accounting engine is enforced in the
/// constructor: total debits must equal total credits. An unbalanced entry
/// cannot be constructed, so it cannot be persisted or reported. There is no
/// "create then fix" path.
///
/// An entry is immutable once constructed. It is never edited or deleted.
/// A correction is a new entry created by [reverse], which preserves the
/// original and leaves a complete audit trail.
class JournalEntry {
  JournalEntry({
    required this.id,
    required this.date,
    required this.description,
    this.reference,
    required List<JournalLine> lines,
  }) : lines = List.unmodifiable(lines) {
    if (this.lines.length < 2) {
      throw ArgumentError(
        'A journal entry needs at least two lines to record a double entry, '
        'got ${this.lines.length}.',
      );
    }
    _assertBalanced(this.lines);
  }

  final String id;

  /// The transaction date. Callers must confirm that this date falls inside the
  /// active fiscal year before posting; that check needs the fiscal calendar
  /// and does not belong in the journal itself.
  final DateTime date;

  final String description;

  /// Source document, for example an invoice number. This is what links a
  /// journal entry back to the business event that caused it.
  final String? reference;

  /// The lines, unmodifiable.
  final List<JournalLine> lines;

  /// Currency of the entry, taken from the first line.
  ///
  /// All lines share one currency. V1 is single-currency per book, so a mixed
  /// entry is a defect, and [Money] rejects it during the balance check.
  String get currency => lines.first.currency;

  Money get totalDebits => Money.sum(lines.map((line) => line.debit), currency);

  Money get totalCredits =>
      Money.sum(lines.map((line) => line.credit), currency);

  bool get isBalanced => totalDebits == totalCredits;

  /// Creates the entry that cancels this one.
  ///
  /// Every debit becomes a credit of the same amount on the same account, so
  /// the pair nets to zero. The original entry is not modified. The reversal
  /// references [id] of the original, so both remain traceable to the business
  /// event that caused them.
  JournalEntry reverse({
    required String id,
    required DateTime date,
    String? reason,
  }) =>
      JournalEntry(
        id: id,
        date: date,
        description: reason ?? 'Reversal of $this.id',
        reference: this.id,
        lines: lines.map((line) => line.opposite).toList(),
      );

  static void _assertBalanced(List<JournalLine> lines) {
    final currency = lines.first.currency;
    final debits = Money.sum(lines.map((line) => line.debit), currency);
    final credits = Money.sum(lines.map((line) => line.credit), currency);
    if (debits.minorUnits != credits.minorUnits) {
      throw UnbalancedJournalException(debits, credits);
    }
  }

  @override
  String toString() => 'JournalEntry($id, ${lines.length} lines, $totalDebits)';
}

/// Raised when a journal entry's debits and credits do not agree.
///
/// This is the most important exception in the application. It means the
/// accounting model has been violated, and it must never be caught and
/// suppressed in order to make an operation succeed.
class UnbalancedJournalException implements Exception {
  UnbalancedJournalException(this.totalDebits, this.totalCredits);

  final Money totalDebits;
  final Money totalCredits;

  /// The difference, useful for diagnostics.
  Money get difference => totalDebits.subtract(totalCredits);

  @override
  String toString() =>
      'UnbalancedJournalException: the journal is unbalanced. Total debits '
      '${totalDebits.format()} must equal total credits '
      '${totalCredits.format()}.';
}
