import 'credit_note.dart';
import 'document_number.dart';

/// A credit note that has been numbered and posted.
///
/// The counterpart of `IssuedInvoice`: a draft has no number and no accounting
/// behind it, and this does. The two are created together or not at all.
///
/// The journal entry id is derived from the credit note id, so re-issuing a
/// credit note id that has already been posted is refused by the journal's
/// primary key rather than double-posted.
class IssuedCreditNote {
  const IssuedCreditNote._({
    required this.creditNote,
    required this.number,
    required this.journalEntryId,
  });

  factory IssuedCreditNote({
    required CreditNote creditNote,
    required DocumentNumber number,
  }) =>
      IssuedCreditNote._(
        creditNote: creditNote,
        number: number,
        journalEntryId: journalEntryIdFor(creditNote),
      );

  /// The journal entry id for a credit note.
  static String journalEntryIdFor(CreditNote creditNote) =>
      'JE-CRN-${creditNote.id}';

  final CreditNote creditNote;

  /// The serial allocated at issuance, from the credit note's own sequence.
  final DocumentNumber number;

  /// The journal entry that reverses the sale.
  final String journalEntryId;

  String get id => creditNote.id;

  @override
  bool operator ==(Object other) =>
      other is IssuedCreditNote &&
      other.creditNote == creditNote &&
      other.number == number;

  @override
  int get hashCode => Object.hash(creditNote, number);

  @override
  String toString() =>
      'IssuedCreditNote(${number.value}, ${creditNote.total.format()})';
}
