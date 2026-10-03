# ADR 012 — Purchases and input credit

**Status:** Accepted

## Context

The sales side exists and is complete: invoice, credit note, payment, and the
receivable they settle. The purchase side does not. Stock can be received through
a manual inventory movement, so `1040 Inventory` is debited and `2010 Accounts
Payable` is credited — but with **no document behind either**, and three consequences
follow from that gap:

1. **Input VAT is always zero.** The VAT return reads the figures the purchase
   documents carry, and there are none, so the return reports output VAT and no
   input credit. That is half a return, and the half that is missing is the one the
   business paid for.
2. **`2010 Accounts Payable` is a hand-credited balance.** Nothing records *what*
   was bought, *from whom*, or *at what price*, so a payable cannot be aged,
   settled against a document, or defended in an audit.
3. **Input VAT claim depends on the vendor's PAN**, which `NEPALI_BILLING.md`
   records may be disallowed in an audit if the bill lacks it. An application that
   cannot store the bill cannot surface the risk.

The specification requires this: `purchases`, `purchase_lines`, and `suppliers` are
named in the schema (section 22), and gate 4's VAT return cannot be completed
without them.

## Decision

### A supplier mirrors ADR 010's identity decision, unchanged

`Supplier` (`domain/billing/supplier.dart`) adopts the customer pattern exactly:

- **`id` random and permanent.** Purchases reference a supplier by id, so an id
  that moved would repoint historical payables at a different business.
- **`code` is the business reference** — `S-0001` — printed on the bill.
- **`name` is not a key.** Nepali names repeat and change on marriage.
- **PAN is the genuine unique key**, under a partial index over present values.
  Two businesses cannot share a PAN, so this index cannot produce a false
  collision.

The PAN carries a **real accounting consequence here that it does not have for a
customer.** On the sales side a missing buyer PAN is a form problem. On the
purchase side it is a **cash cost**: the VAT the business paid may be disallowed as
input credit. `Supplier.canSupportInputCredit` reports this, and it is a
**prediction shown to the user, not a rule the application enforces** — refusing to
record the purchase would leave the stock unrecorded, which is worse than recording
it with a warning.

### Purchases get their own document type and their own sequence

`DocumentType.purchase`, prefix `PUR`, with an **independent sequence** per fiscal
year, exactly as ADR 005 requires for every other document type. A purchase must
never share a counter with an invoice or a credit note.

**Numbering stays gap-free**, and this is the CBMS requirement from
`NEPALI_BILLING.md`: numbers are allocated inside the issuing transaction and never
reserved, skipped, or consumed by a draft. A gap in purchase numbering is the same
defect as a gap in invoice numbering.

### The entry

A purchase with VAT:

```
Dr  1040 Inventory              subtotal — the net cost of the goods
Dr  1150 Input VAT Recoverable  VAT charged on the purchase
Cr  2010 Accounts Payable       total, including VAT
```

Three points that are decisions rather than arithmetic:

- **Input VAT is an asset, not a reduction of expense.** `1150` is a recoverable
  tax, and the goods' cost in `1040` is the **net** figure. Capitalising the gross
  and expensing it later would put a recoverable tax into cost of sales.
- **A purchase from a supplier without a PAN still posts input VAT**, and is
  flagged. Refusing would mean the goods never enter stock.
- **A zero-rated purchase omits the VAT line** rather than posting a zero,
  mirroring the sales side so there is one rule, not two.

### Purchase returns are a debit-note style reversal, not a deletion

A purchase is never edited or deleted once posted. A return is recorded as a
**negative purchase document with its own sequence** that reverses the entry:
`Cr 1040 / Cr 1150 / Dr 2010`, and issues the stock back out. This mirrors credit
notes on the sales side and is the only correction path ADR 005 permits.

### A purchase that moves stock records the movement in the same transaction

Purchasing stock must do two things atomically: record the bill, and record the
inventory movement. Without the second, `1040` and the physical stock diverge. The
movement value is the **net** amount (subtotal), because inventory carries at cost
and the VAT is never part of it — `1150` is where VAT sits.

### The payable is derived, never stored

`PurchaseBalance` computes outstanding from the bill total and the payments and
credits recorded against it, exactly as `InvoiceBalance` does on the sales side. A
running balance on the purchase would be a second source of truth that could
disagree silently with the documents that produced it.

## Consequences

- **The VAT return becomes complete.** `BuildTaxSummary` sums input VAT from
  purchase documents rather than reporting zero, and the figure it reports is the
  figure the ledger carries.
- **`2010 Accounts Payable` acquires a document behind every posting to it.** The
  account can be aged and settled against a bill.
- **Payables and receivables become separate aggregates** with separate reports.
  `ui.txt` already lists Payables, Suppliers and Purchases as navigation entries;
  this is what makes them real.
- **Input VAT creates a reconciling account.** `2020 VAT Payable` and
  `1150 Input VAT Recoverable` are both VAT accounts, and a return is the
  difference. A business whose `1150` grows without a matching output VAT has a
  problem the report will now show.
- **Adding `1150` is a new account, not a change to an existing one.** Existing
  `2020` postings are untouched, and no historical entry is repointed.