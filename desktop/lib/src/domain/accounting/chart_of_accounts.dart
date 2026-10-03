import 'account.dart';
import 'account_type.dart';

/// The chart of accounts for the business.
///
/// This is the fixed set of accounts a small Nepali business posts to. It is
/// defined once, here, so that no feature invents its own account.
///
/// **Ids are permanent.** Every `id` is a hand-written literal. Journal lines
/// reference accounts by id, so an id that changed would silently repoint every
/// historical posting at a different account, and the books would still balance
/// while being wrong. Never generate an id, never derive one from a position in
/// a list, and never reuse an id for a different account.
///
/// **Codes are the human-facing label and may be renumbered.** Because the id is
/// what the journal stores, changing a code is a display change and cannot
/// corrupt history. That is the whole reason the two are separate.
///
/// Code ranges are conventional: `1xxx` assets, `2xxx` liabilities, `3xxx`
/// equity, `4xxx` income, `5xxx` expenses.
class ChartOfAccounts {
  const ChartOfAccounts();

  // --- Assets (1xxx) ---

  /// Money held at the bank.
  static const Account bank = Account(
    id: 'acct-bank',
    code: '1010',
    name: 'Bank',
    type: AccountType.asset,
  );

  /// Cash held in hand.
  static const Account cash = Account(
    id: 'acct-cash',
    code: '1020',
    name: 'Cash',
    type: AccountType.asset,
  );

  /// Money owed to the business by customers.
  static const Account receivable = Account(
    id: 'acct-receivable',
    code: '1030',
    name: 'Accounts Receivable',
    type: AccountType.asset,
  );

  /// Goods held for sale, at cost.
  static const Account inventory = Account(
    id: 'acct-inventory',
    code: '1040',
    name: 'Inventory',
    type: AccountType.asset,
  );

  /// Long-lived equipment used in the business.
  static const Account officeEquipment = Account(
    id: 'acct-office-equipment',
    code: '1050',
    name: 'Office Equipment',
    type: AccountType.asset,
  );

  /// VAT the business **paid** on purchases and may recover.
  ///
  /// ## Why this is an asset and not a reduction of the purchase
  ///
  /// This is the mirror of [vatPayable], and the two are the reason a VAT return
  /// exists: output VAT minus input VAT is what is owed to (or reclaimable from)
  /// the authority.
  ///
  /// It is an **asset** because the business has already paid it and holds a
  /// claim on it. The consequence that matters is on the purchase side: goods
  /// enter `1040 Inventory` at the **net** figure, and the VAT lands here. Putting
  /// the gross into inventory would carry a recoverable tax as part of the cost of
  /// goods, and it would silently become an expense the day that stock was sold.
  ///
  /// **Added in ADR 012.** A new account rather than a change to an existing one,
  /// so no historical posting is repointed.
  static const Account inputVatRecoverable = Account(
    id: 'acct-input-vat',
    code: '1150',
    name: 'Input VAT Recoverable',
    type: AccountType.asset,
  );

  // --- Liabilities (2xxx) ---

  /// Money the business owes to suppliers.
  static const Account payable = Account(
    id: 'acct-payable',
    code: '2010',
    name: 'Accounts Payable',
    type: AccountType.liability,
  );

  /// Value added tax collected on sales, owed to the tax authority.
  static const Account vatPayable = Account(
    id: 'acct-vat-payable',
    code: '2020',
    name: 'VAT Payable',
    type: AccountType.liability,
  );

  /// Borrowed money.
  static const Account loansPayable = Account(
    id: 'acct-loans-payable',
    code: '2030',
    name: 'Loans Payable',
    type: AccountType.liability,
  );

  // --- Equity (3xxx) ---

  /// The owner's stake in the business.
  static const Account ownersEquity = Account(
    id: 'acct-owners-equity',
    code: '3010',
    name: "Owner's Equity",
    type: AccountType.equity,
  );

  /// Money the owner has taken out of the business.
  static const Account drawings = Account(
    id: 'acct-drawings',
    code: '3020',
    name: "Owner's Drawings",
    type: AccountType.equity,
  );

  /// Accumulated profit carried forward from concluded fiscal years.
  static const Account retainedEarnings = Account(
    id: 'acct-retained-earnings',
    code: '3030',
    name: 'Retained Earnings',
    type: AccountType.equity,
  );

  // --- Income (4xxx) ---

  /// Revenue from selling goods or services.
  static const Account salesRevenue = Account(
    id: 'acct-sales-revenue',
    code: '4010',
    name: 'Sales Revenue',
    type: AccountType.income,
  );

  /// Income from anything other than the main trading activity.
  static const Account otherIncome = Account(
    id: 'acct-other-income',
    code: '4020',
    name: 'Other Income',
    type: AccountType.income,
  );

  // --- Expenses (5xxx) ---

  /// Rent for business premises.
  static const Account officeRent = Account(
    id: 'acct-office-rent',
    code: '5010',
    name: 'Office Rent',
    type: AccountType.expense,
  );

  /// The cost of the goods that were sold.
  static const Account costOfGoodsSold = Account(
    id: 'acct-cost-of-goods-sold',
    code: '5020',
    name: 'Cost of Goods Sold',
    type: AccountType.expense,
  );

  /// Payroll.
  static const Account salariesAndWages = Account(
    id: 'acct-salaries-and-wages',
    code: '5030',
    name: 'Salaries and Wages',
    type: AccountType.expense,
  );

  /// Electricity, water, internet, and telephone.
  static const Account utilities = Account(
    id: 'acct-utilities',
    code: '5040',
    name: 'Utilities',
    type: AccountType.expense,
  );

  /// Consumable supplies used in the office.
  static const Account officeSupplies = Account(
    id: 'acct-office-supplies',
    code: '5050',
    name: 'Office Supplies',
    type: AccountType.expense,
  );

  /// Fees charged by the bank.
  static const Account bankCharges = Account(
    id: 'acct-bank-charges',
    code: '5060',
    name: 'Bank Charges',
    type: AccountType.expense,
  );

  /// Stock gains and losses that are not a sale or a purchase: stock-count
  /// corrections, damage, theft, and the generic return reasons.
  ///
  /// An expense account used in **both** directions, which is the conventional
  /// treatment for a shrinkage account. A stock loss debits it; a stock gain
  /// credits it, which reduces expenses and so increases profit by the value
  /// found. Two accounts would be more pure and one is what a small business
  /// actually reconciles against.
  static const Account inventoryAdjustments = Account(
    id: 'acct-inventory-adjustments',
    code: '5070',
    name: 'Inventory Adjustments',
    type: AccountType.expense,
  );

  /// Every account, ordered by code.
  List<Account> get all => const [
        bank,
        cash,
        receivable,
        inventory,
        officeEquipment,
        inputVatRecoverable,
        payable,
        vatPayable,
        loansPayable,
        ownersEquity,
        drawings,
        retainedEarnings,
        salesRevenue,
        otherIncome,
        officeRent,
        costOfGoodsSold,
        salariesAndWages,
        utilities,
        officeSupplies,
        bankCharges,
        inventoryAdjustments,
      ];

  /// Looks up an account by its code, for example `1010`.
  ///
  /// Returns `null` rather than throwing so that form validation can report an
  /// unknown code to the user.
  Account? byCode(String code) {
    for (final account in all) {
      if (account.code == code) return account;
    }
    return null;
  }

  /// Looks up an account by its permanent id.
  Account? byId(String id) {
    for (final account in all) {
      if (account.id == id) return account;
    }
    return null;
  }

  /// Every account of one type, for example every expense.
  List<Account> ofType(AccountType type) =>
      all.where((account) => account.type == type).toList();
}
