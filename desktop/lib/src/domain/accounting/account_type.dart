/// The side of a ledger that increases an account.
enum NormalBalance { debit, credit }

/// The five account types of the double-entry model.
///
/// The type is not cosmetic. It determines which side of the ledger increases
/// the account, whether the account belongs on the balance sheet or in the
/// profit and loss statement, and how [normalBalance] is interpreted.
enum AccountType {
  asset,
  liability,
  equity,
  income,
  expense;

  /// The side that increases this account.
  ///
  /// Assets and expenses increase on the debit side. Liabilities, equity, and
  /// income increase on the credit side. This is the rule that makes a ledger
  /// balance readable: a positive balance always means the account grew in the
  /// direction it is supposed to grow.
  NormalBalance get normalBalance => switch (this) {
        AccountType.asset || AccountType.expense => NormalBalance.debit,
        AccountType.liability ||
        AccountType.equity ||
        AccountType.income =>
          NormalBalance.credit,
      };

  /// True for accounts that appear on the balance sheet and carry forward into
  /// the next fiscal year.
  bool get isBalanceSheet =>
      this == AccountType.asset ||
      this == AccountType.liability ||
      this == AccountType.equity;

  /// True for accounts that are closed at fiscal-year end. Their result is
  /// transferred to equity rather than carried forward as activity.
  bool get isProfitAndLoss =>
      this == AccountType.income || this == AccountType.expense;
}
