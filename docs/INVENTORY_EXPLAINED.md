# Inventory costing, explained

Written for someone who is not an accountant. It explains what the choice was,
what the options mean with real numbers, what Nepali rules allow as far as I have
been able to establish, and what this application actually does.

If you read one section, read **"What this application does"**.

---

## Why this is a decision at all

When you buy goods, you know exactly what you paid. When you *sell* goods, you
need to know what they **cost you**, because that cost has to be subtracted from
the sale price to work out your profit. That subtracted figure is called **COGS**
— cost of goods sold.

If every unit cost the same, this would be trivial. The problem is that you buy
the same product at different prices over time:

- January: buy 10 keyboards at Rs 100 each
- February: buy 10 more at Rs 120 each (prices went up)

You now have 20 keyboards. You paid Rs 2,200 in total. In March you sell 10 of
them for Rs 200 each.

**Which 10 did you sell, and what did they cost you?** There is no fact of the
matter — the keyboards are identical and nobody tracked which physical box went
out. So you have to *choose a rule*. That rule is the "costing method".

Every method gives a different profit from the exact same transactions. This is
why the choice has to be made deliberately and written down: it is not a
technicality, it is a real accounting policy.

---

## The four methods, with numbers

Using the example above: 10 @ Rs 100, then 10 @ Rs 120. Sell 10 for Rs 200 each.
Revenue is Rs 2,000.

| Method | What it assumes | COGS | Closing stock | Gross profit |
| --- | --- | --- | --- | --- |
| **Weighted average** | All units cost the same average | **Rs 1,100** | Rs 1,100 | **Rs 900** |
| **FIFO** | Oldest units sold first | **Rs 1,000** | Rs 1,200 | **Rs 1,000** |
| **LIFO** | Newest units sold first | **Rs 1,200** | Rs 1,000 | **Rs 800** |
| **Specific identification** | You track each physical unit | depends | depends | depends |

Weighted average works like this: total value Rs 2,200 ÷ 20 units = **Rs 110 per
unit**. Selling 10 costs 10 × 110 = Rs 1,100.

Notice that **the same sale produces three different profits** — Rs 800, Rs 900,
or Rs 1,000 — purely depending on the rule chosen. That is the whole reason this
decision is significant.

### FIFO — First In, First Out

Assumes you sell the oldest stock first. You paid Rs 100 for the first 10, so
those are the ones that went out.

- Good: matches how most physical businesses actually operate (old stock moves
  first, especially with perishables).
- Cost: the software must remember every purchase as a separate "layer", and when
  a sale spans two layers, track how much is left in each. Returns have to unpick
  layers too. This is a lot more machinery and a lot more places to go wrong.

### LIFO — Last In, First Out

Assumes you sell the newest stock first. **Not permitted under IAS 2 and, as far
as I can establish, not permitted in Nepal.** Listed only so you know what it is
if you see the term. LIFO lets a business flatter its profit in a rising market,
which is why many jurisdictions disallow it.

### Weighted average

Recomputes one average cost each time you buy, and uses that average for every
sale until the next purchase.

- Two variants:
  - **Moving (perpetual) average** — the average updates on every purchase. This
    is what this application uses.
  - **Periodic average** — the average is only worked out once, at the end of the
    period. Simpler, but during the year your inventory account on the balance
    sheet does not match what is physically on the shelf, which makes COGS
    misleading all year.
- Good: one number per product. Simple to explain, simple to audit, and it never
  leaves a pile of unresolved cost layers.
- Cost: the reported cost is an *average*, not the cost of the specific units
  sold. Profit will therefore differ slightly from what FIFO would report. That
  is a disclosed property of the method, not a bug.

### Specific identification

You label every unit and record exactly which one was sold. Most accurate, and
used for cars, jewellery, and antiques. Impractical for a shop selling hundreds of
cheap identical items.

---

## What Nepali rules say

**Read this section with the caveat at the end.**

Nepal's accounting standards are issued by **ICAN** (the Institute of Chartered
Accountants of Nepal). There are broadly two frameworks:

- **NFRS** — Nepal Financial Reporting Standards, based on IFRS. Used by larger
  and public-interest entities.
- **NFRS for SMEs** — a reduced version for smaller entities.
- **NAS** — Nepal Accounting Standards, for entities outside the above.

Inventory is covered by a standard that mirrors **IAS 2 *Inventories***. What that
means in practice:

1. **Costing method.** FIFO and weighted average cost are permitted. **LIFO is
   prohibited.** So all three of the useful methods above are compliant, and the
   one method excluded happens to be the one most open to manipulation.
2. **Consistency.** The method must be applied **consistently** from period to
   period, and it must be **disclosed** in the financial statements. You cannot
   switch methods when it suits the reported profit.
3. **Measurement.** Inventory must be carried at the **lower of cost and net
   realisable value**. In plain terms: if stock you paid Rs 100 for can now only
   be sold for Rs 80, you must write it down to Rs 80 and recognise the Rs 20 loss
   *now*, not when you eventually sell it.
4. **Genuine goods only.** Only goods held for sale enter inventory. Once stock is
   known to be unsaleable, it is written off, not carried.

### ⚠️ Verify this before relying on it

The general shape above — FIFO and weighted average allowed, LIFO not, consistency
required, lower of cost and net realisable value — is well established
internationally and is what IAS 2 says. I am **reasonably** confident Nepal's
standard mirrors it, because Nepal's standards are IFRS-derived.

However:

- I have **not verified this against the current published text** of the Nepali
  standard, and standards change.
- **Which framework applies to your business depends on its size and status**, and
  I do not know which one you fall under.
- **The Income Tax Act 2058 governs what the tax office will accept** for
  deducting COGS, and I have **not verified** whether it prescribes or restricts a
  method separately from the accounting standards.
- Property, plant, and equipment depreciation aside, tax and accounting rules in
  Nepal can diverge.

**If the reported figures will be used for tax, a filing, an audit, or a loan
application, confirm the method with a Nepali chartered accountant.** This
document is an engineering and design record, not accounting or tax advice.

---

## What this application does

Recorded in `docs/decisions/004-inventory-costing-method.md`.

### 1. Costing method: moving weighted average

**Why:** it is permitted under the standard, it matches the product model the
specification already defines (one `cost` field per product, not cost layers), and
it is by far the least machinery for the same compliance. FIFO's extra accuracy
was judged not worth the extra moving parts for a small-business tool.

### 2. Negative stock is blocked

If a sale would take stock below zero, it is **refused** and nothing is written.

**Why:** with weighted average, selling stock you do not have has **no defined
cost**. The software would have to guess — zero, or the last known price — and a
guessed cost means a wrong profit figure in two years at once. Refusing is the
only option that keeps every number meaningful.

**What "stock" means here:** the total of all recorded movements for that product,
whatever date each movement carries. Not "how much did I have on the day of the
sale". This is deliberate: a date-based check would reject a perfectly good sale
simply because the purchase behind it happened to be recorded with a later date,
punishing you for the order you typed things in.

### 3. The cost is tracked as a *value*, not a rounded price

This one matters and is easy to miss. The system stores:

- **the total value of the stock** (Rs 2,200), in paisa, as a whole number, and
- **how many units** (20),

and works out the cost per unit (Rs 110) only for display.

**Why:** if it stored the price as Rs 110 and multiplied, tiny rounding errors
creep in with every transaction and the inventory account slowly stops matching
reality — silently. Tracking the total value instead means the inventory account
always reconciles, whatever the displayed unit price rounds to.

---

## What this application does *not* do yet

Being explicit so nobody assumes these are handled:

1. **Writing down stock that will not sell.** The "lower of cost and net
   realisable value" rule above is **not implemented**. If stock becomes
   unsaleable, there is currently no supported way to write it down. This must be
   built before inventory can be called complete.
2. **Stock reductions that are not sales.** Damage, theft, and stock-count
   corrections need their own adjustment entries. The rule for whether an
   adjustment may bring stock to zero or below is a separate decision, still open.
3. **Purchase returns.** Returning goods to a supplier, and what it does to the
   running value, is not modelled yet.
4. **Backdated transactions.** Stock recorded today plus a sale dated months
   earlier will still be accepted, and the cost used is today's average rather
   than the average that existed then. Accepted for now; noted as a limitation.
5. **Onboarding.** A business starting with goods already on the shelf must record
   opening stock first, or every sale is blocked. The mechanism exists
   (`OPENING_STOCK`); making it easy is a UI task.

---

## Glossary

| Term | Meaning |
| --- | --- |
| **COGS** | Cost of goods sold. What the goods you sold cost *you*. Subtracted from revenue to get gross profit. |
| **Gross profit** | Revenue minus COGS. Profit before rent, salaries, and other running costs. |
| **Costing method** | The rule for deciding what sold goods cost you when you bought them at different prices. |
| **FIFO** | First In, First Out. Oldest stock is assumed sold first. |
| **LIFO** | Last In, First Out. Newest stock assumed sold first. Not permitted. |
| **Weighted average** | All units assumed to cost the same average. Recomputed on each purchase (moving) or once a period (periodic). |
| **Cost layer** | A record of one purchase at one price. FIFO needs these; weighted average does not. |
| **Net realisable value** | What you could actually sell the stock for, less the cost of selling it. |
| **Lower of cost and NRV** | Carry inventory at whichever is *lower*: what you paid, or what you can now get. Write down the difference. |
| **Perpetual / moving** | Updated continuously, on every transaction. |
| **Periodic** | Updated only at the end of a period. |

---

## See also

- `docs/decisions/004-inventory-costing-method.md` — the formal decision record.
- `docs/decisions/002-fiscal-year-per-database.md` — why inventory value carries
  forward at year end.
- `Rewritten_Business_Application_Architecture.txt` sections 13, 14, 29, and 34 —
  the specification's inventory model, movement reasons, and invariants.
