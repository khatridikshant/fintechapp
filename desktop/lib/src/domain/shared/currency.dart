/// The currency of the book.
///
/// V1 is single-currency per the specification, so this is a constant rather
/// than configuration. It is declared once here so the amount of code, the
/// database, and the screens cannot disagree about what currency the books are
/// kept in.
///
/// Money amounts are always integer **minor units** of this currency: paisa for
/// rupees. See `Money`.
const String bookCurrency = 'NPR';
