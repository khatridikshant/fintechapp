import 'package:drift/drift.dart';

import '../../domain/accounting/account.dart';
import '../../domain/accounting/journal_entry.dart';
import '../../domain/accounting/journal_line.dart';
import '../../domain/accounting/journal_repository.dart';
import '../../domain/shared/money.dart';
import 'app_database.dart';
import 'mappers.dart';

class DriftJournalRepository implements JournalRepository {
  DriftJournalRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> append(JournalEntry entry) {
    // One transaction. If any line fails, for example because it references an
    // account that does not exist, the header and every line already written
    // are rolled back. An entry without its lines must never be observable.
    return _db.transaction(() async {
      await _db.into(_db.journalEntries).insert(
            JournalEntriesCompanion.insert(
              id: entry.id,
              date: entry.date,
              description: entry.description,
              reference: Value(entry.reference),
              currency: entry.currency,
            ),
          );

      for (final line in entry.lines) {
        await _db.into(_db.journalLines).insert(
              JournalLinesCompanion.insert(
                journalEntryId: entry.id,
                accountId: line.account.id,
                debitMinorUnits: Value(line.debit.minorUnits),
                creditMinorUnits: Value(line.credit.minorUnits),
                currency: line.currency,
              ),
            );
      }
    });
  }

  @override
  Future<JournalEntry?> byId(String id) async {
    final header = await (_db.select(_db.journalEntries)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (header == null) return null;
    return _rebuild(header, await _linesFor(id));
  }

  @override
  Future<List<JournalEntry>> all() async {
    final headers = await (_db.select(_db.journalEntries)
          ..orderBy([
            (t) => OrderingTerm(expression: t.date),
            (t) => OrderingTerm(expression: t.id),
          ]))
        .get();

    final entries = <JournalEntry>[];
    for (final header in headers) {
      entries.add(await _rebuild(header, await _linesFor(header.id)));
    }
    return entries;
  }

  @override
  Future<List<JournalEntry>> entriesForAccount(Account account) async {
    final ids = await (_db.selectOnly(_db.journalLines, distinct: true)
          ..addColumns([_db.journalLines.journalEntryId])
          ..where(_db.journalLines.accountId.equals(account.id)))
        .map((row) => row.read(_db.journalLines.journalEntryId)!)
        .get();

    final entries = <JournalEntry>[];
    for (final id in ids) {
      final entry = await byId(id);
      if (entry != null) entries.add(entry);
    }
    return entries;
  }

  Future<List<JournalLineRow>> _linesFor(String entryId) {
    return (_db.select(_db.journalLines)
          ..where((t) => t.journalEntryId.equals(entryId))
          // Insertion order preserves the order the lines were posted in, which
          // is what makes a reloaded entry identical to the original.
          ..orderBy([(t) => OrderingTerm(expression: t.id)]))
        .get();
  }

  /// Reconstructs a domain entry from its rows.
  ///
  /// The `JournalEntry` constructor re-checks the balance, so a corrupt row set
  /// is caught here rather than silently returned as a plausible-looking entry.
  Future<JournalEntry> _rebuild(
    JournalEntryRow header,
    List<JournalLineRow> lineRows,
  ) async {
    final accountRows = await _db.select(_db.accounts).get();
    final accounts = {
      for (final row in accountRows) row.id: accountFromRow(row),
    };

    final lines = lineRows.map((row) {
      final account = accounts[row.accountId];
      if (account == null) {
        throw StateError(
          'Journal line ${row.id} references unknown account ${row.accountId}.',
        );
      }
      final debit = Money.minor(row.debitMinorUnits, row.currency);
      final credit = Money.minor(row.creditMinorUnits, row.currency);
      return debit.isPositive
          ? JournalLine.debit(account: account, amount: debit)
          : JournalLine.credit(account: account, amount: credit);
    }).toList();

    return JournalEntry(
      id: header.id,
      date: header.date,
      description: header.description,
      reference: header.reference,
      lines: lines,
    );
  }
}
