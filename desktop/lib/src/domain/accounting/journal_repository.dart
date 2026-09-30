import 'account.dart';
import 'journal_entry.dart';

/// Port for storing and retrieving posted journal entries.
///
/// This is an interface owned by the domain. The implementation lives in
/// `infrastructure/`.
abstract interface class JournalRepository {
  /// Appends an entry and all of its lines as a single atomic operation.
  ///
  /// Either the entry and every line are written, or nothing is. A partially
  /// written entry, or a debit without its matching credit, would be an
  /// unrepairable corruption of the books, so this must never be observable.
  ///
  /// [entry] is guaranteed balanced by [JournalEntry] itself, so an unbalanced
  /// entry cannot reach storage.
  Future<void> append(JournalEntry entry);

  Future<JournalEntry?> byId(String id);

  /// All entries, ordered by date then id.
  Future<List<JournalEntry>> all();

  /// Entries that touch [account], in the order they were posted.
  Future<List<JournalEntry>> entriesForAccount(Account account);
}
