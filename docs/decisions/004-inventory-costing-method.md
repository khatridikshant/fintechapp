# ADR 004 — Inventory costing method and negative stock

**Status:** **Accepted.** Supersedes the open question this file previously held.
**Decided by:** the product owner, 2026-09-29.

## The two decisions

1. **Costing method: moving weighted average.**
2. **Negative stock: blocked.** A sale that would take stock below zero is
   refused, and nothing is written.

## Why this had to be decided by the owner

Specification section 29 is explicit:

> The exact inventory valuation method shall be explicitly selected and
> documented before implementation. The application shall not silently choose
> FIFO, weighted average, moving average, or another costing method.

> Negative inventory behavior shall also be explicitly defined before
> implementation.

Neither is a technical detail. The costing method determines cost of goods sold,
which determines gross profit, which determines the balance sheet and the tax
position. Choosing it by accident, or changing it later, silently restates
historical profit.

## Decision 1 — moving weighted average

`docs/INVENTORY_EXPLAINED.md` explains all four methods in plain language with
worked numbers. This section records why this one was chosen.

**It matches the data model the specification already has.** Section 13 gives a
product a single `cost` field. Moving weighted average maintains exactly one
current cost per product. FIFO would need a *layer* per receipt, which the
specification does not model.

**It is permitted.** Weighted average cost is one of the two methods allowed by
IAS 2 *Inventories* and by NAS 2, the Nepali standard that mirrors it. See
`docs/INVENTORY_EXPLAINED.md` for the caveat about verifying this.

**It is the least machinery for the most correctness.** FIFO requires cost layers,
partial-layer consumption on every sale, and layer logic for purchase returns —
which the specification's own end-to-end test includes (line 1770). Moving
weighted average collapses all of that into one number per product.

**It makes year-end carry-forward trivial.** Section 29 requires that inventory
carry forward its opening quantity *and valuation*. With a running valuation, the
opening value is simply the closing value.

**The accepted cost.** Moving average reports the average cost, not the cost of
the specific units sold. Gross profit is therefore slightly different from what a
FIFO system would report for the same transactions. This is a known, disclosed
property of the method, not a defect.

### The implementation rule that makes it work

**Store the running inventory value as authoritative, and derive cost per unit
from it.** Do not store a rounded average cost.

If the average cost is stored as, say, `Rs 3.33` and multiplied by quantity, the
inventory account stops reconciling with reality within weeks, and the error is
silent. Instead:

```
inventory_value_minor_units   <- authoritative, integer paisa
quantity_on_hand              <- authoritative, integer units
cost_per_unit                 <- derived, for display only: value / quantity
```

A sale posts COGS from the value movement, so the inventory account always
reconciles to the sum of the movements by construction, whatever the rounding of
the displayed unit cost.

## Decision 2 — negative stock is blocked

**With moving weighted average, selling stock that does not exist has no defined
cost.** Allowing it forces a guess — zero, or the last known cost — and a guessed
COGS is a wrong gross profit in two fiscal years at once. Blocking is the only
option that keeps every number defined.

Specification section 34's invariant assumes stock is known before the sale:

> Given: Stock = 10. When: Sell = 3. Then: Stock = 7. And: COGS is correct. And:
> Journal balances.

### How the check is made

Stock is the **sum of all recorded movements** for the product, regardless of the
movement's date. Not "stock as of the transaction date".

That choice is deliberate. An as-of-date check would reject a sale whenever the
matching purchase happens to have a later date, punishing a user purely for the
order they entered data in. Summing all movements still prevents selling goods
that were never recorded at all, which is the case that actually matters.

### Accepted costs of blocking

- **Data-entry order becomes load-bearing.** A purchase must be recorded before
  the sale, or the sale is refused.
- **Onboarding must handle opening stock.** A business that starts using the
  application with goods already on the shelf, and records no opening stock, has
  every sale blocked. `OPENING_STOCK` is already a movement reason (section 14),
  so the mechanism exists, but the UI must make entering opening stock an obvious
  first step and the refusal must say *why* it was blocked rather than issuing a
  bare refusal.
- **It does not protect against backdated transactions.** Stock can be recorded
  today and a sale inserted with a date three months earlier; the totals still
  look correct, but the COGS uses a cost that did not exist at that date. This is
  accepted for V1. Correcting it would mean replaying movements in date order,
  which is a separate design.
- **It does not make the cost correct, only defined.** See Decision 1.

## Follow-on decisions

1. **Stock reductions that are not sales.** Damage, theft, stock-count
   corrections, and disposal need adjustment movements. Disposal and the
   write-down are now modelled; whether a *general* adjustment may take stock
   negative is a separate question, and the answer may differ from the sales
   answer. Still open.
2. ~~**Valuation at the lower of cost and net realisable value.**~~ **DONE.** The
   write-down is implemented: a value-only movement that reduces the carrying
   amount without changing quantity, posting
   `Dr 5070 Inventory Adjustments / Cr 1040 Inventory`. It refuses a value at or
   above the carrying amount, because IAS 2 does not permit inventory to be
   revalued upwards. Recording it as a movement rather than a side entry is what
   keeps the inventory account equal to the sum of the movements. See
   `PROGRESS.md` section 4.19.
3. **Purchase returns.** Section 29's end-to-end test includes one, and it
   interacts with the running valuation. Not built.
4. **Rounding residue across a period.** Value-first accounting keeps the ledger
   reconciled at all times, but the sum of COGS across many sales will not
   necessarily equal the total value that left inventory unless each posting is
   taken from the value movement.
