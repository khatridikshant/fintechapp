# ADR 013 — Product categories

**Status:** Accepted

## Context

The specification names `product_categories` in the schema (section 22). Today a
product is a name, a sale price, and a stock-tracking flag, and nothing else. For a
business with a hundred products that is workable; for one selling hardware, spices
and mobile accessories it is not, because every report is a flat list and the
operator retypes the same category name a hundred times.

## Decision

### A category is a name and a code, and is optional on a product

`ProductCategory`: random permanent `id`, a `code` such as `ELEC-01`, and a `name`
such as "Mobile Accessories". A product **may** carry a category. A product with no
category is an ordinary product, not an incomplete one.

**Category is not required, deliberately.** Making it mandatory would force the
operator to create category records before they can sell anything, and would block
every existing book — a migration backfilling a placeholder category would put a
category on every historical product that never had one, which is a fabrication.

### A category has a parent, and the tree is one level deep for V1

`parentId` is nullable and exists so the schema can express a hierarchy. **V1
resolves at most one level of nesting** and reports a cycle or a depth violation as
a refusal rather than flattening it silently. A tree that is walked correctly but
looped on would hang a report; refusing is honest.

This is deliberately less than the schema allows. `ui.txt` shows a flat category
list, and building a full tree now would be building for a requirement that does not
exist yet.

### Name is not a key, for the same reason as ADR 010 and 012

A category name is mutable and repeats. A unique index on the name would reject two
legitimate categories and turn a spelling correction into a lost record. Duplicate
detection comes from the **code**, under a unique index, because a code is the
business reference and two categories sharing one reference would be genuinely
ambiguous.

### Deleting a category that is in use is refused, not cascaded

A product referencing a category means the category cannot go. The alternative —
deleting it and clearing the reference — would silently reclassify historical stock
and rewrite what a stock report said last quarter. The refusal names the products.

### A category is reference data, not a journal dimension

Categories appear in **inventory and sales reports only**. They have no account and
post nothing. A category that could be posted to would be an account with a
parent, and that is a different feature.

## Consequences

- **Inventory and sales reports can group.** A stock report by category is now
  answerable, which is the reason this exists.
- **The product form gains one optional dropdown** and nothing else changes. A
  product with no category behaves exactly as it did before.
- **Categories are per fiscal year**, like every other record, because one SQLite
  database per year means a category created this year does not exist in last
  year's book. A report spanning years cannot assume the same categories. This is
  ADR 002 applied honestly rather than worked around.