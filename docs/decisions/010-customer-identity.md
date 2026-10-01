# ADR 010 — Customer identity: a random id and a separate business code

**Status:** Accepted, and **partially implemented**. The domain carries the
decision; the database columns are blocked, and section "What is not yet built"
below says exactly why.

## The decision

A customer has **two identifiers**, because they answer two different questions:

| | |
| --- | --- |
| **id** | The **internal identity**. Random, permanent, never changed, never reused. |
| **code** | The **business reference** — `C-0001` — printed on invoices and quoted on the phone. |

The owner chose this after being offered a single sequential identifier.

## Why they are separate

Invoice records and journal entries reference a customer by `id`, so **an `id` that
changed would repoint historical sales at a different person**. It is therefore
random and never derived from anything a person can type.

The `code` is the part people see, and because it is **not** identity it may be
re-sequenced or corrected without touching a single historical sale.

A single sequential identifier would have been simpler and wrong: it ties the
internal identity to business numbering, so the two can never be separated
afterwards.

## Why the id is random

Ids must not collide **if two installations ever sync** — an open question in
`PROGRESS.md` 7.16. A random id cannot collide, which closes that problem now at
no cost, whereas fixing it after data exists means a migration. It also means any
caller can generate one without coordinating with anybody.

## Why the name is not a key

Nepali names repeat — two customers called "Ram Bahadur" are not a mistake — and
a name is **mutable**: misspelled, transliterated differently
(`Krishna Shrestha` / `krishna shrestha`), or changed on marriage. An identity that
moves repoints history, so a unique index on a name would either reject legitimate
customers or turn a routine correction into a lost record.

## Where duplicate detection comes from instead

The instinct to catch duplicates is right; name-as-key is the wrong mechanism.

- **A unique index on `pan_number`**, partial over rows where it is present. A PAN
  is a genuine unique key: two different businesses cannot share one, so this index
  **cannot produce a false collision** — the property a name cannot offer. Many
  customers are individuals with no PAN at all, hence the partial index.
- **A unique index on `code`**, so two customers cannot be quotable as the same
  reference.
- **An advisory name-and-phone similarity warning** when creating a customer. A
  *warning*, not a constraint: the user decides, because sometimes two people with
  the same name really are different people.

---

## What is not yet built

**This section is historical.** The fields were blocked when this ADR was first
written; they are now stored, in a separate `customer_details` table at schema
v10. The reasoning for that table is below, because it is the part worth keeping.

### Why the columns could not simply go on `customers`

Adding them to `customers` turned out to be substantially harder than it looks:

1. **`createTable` writes the table's *current* definition.** A database migrated
   from before v3 has no `customers` table, and the step that creates it produces
   the **v10** shape. The migration must therefore *not* add the columns on that
   path, while *must* add them on every other path — a guard on both `from` and
   `to`, because `onUpgrade` is called with both ends and a test that deliberately
   migrates only to v9 must not acquire v10 columns.

2. **The generated data class always targets the newest schema.** Every migration
   test that stops at an intermediate version and then *reads* a customer crashed
   with a null-check failure, because the row has no `is_vat_registered` key. 21
   tests depended on the assumption that `customers` never changes after v3.

3. **The per-version schema helpers would not regenerate.** Updating
   `drift_schemas/drift_schema_v3..v9.json` did not propagate to
   `test/generated/schema_v3.dart`, across repeated `drift_dev schema generate`
   runs.

### What was done instead

**A separate `customer_details` table** created at v10, keyed to `customers.id`,
holding `code`, `isVatRegistered`, and `businessName`. **No existing table is
touched**, so every v1–v9 snapshot stays valid and all 32 migration tests pass
unchanged. Reads go through a **left outer join**, because a customer recorded
before v10 has no detail row and an inner join would silently drop them from the
customer list — and a customer who cannot be found cannot be invoiced.

Adding another tax attribute later is then a new table rather than a risky change
to a table the books depend on.

### A bug worth remembering

The PAN unique index was initially created only in `onUpgrade`, so a **fresh**
database never had it, and two customers with the same PAN were accepted. An index
added only to the upgrade path leaves every new database without the guarantee —
which is exactly where a duplicate would slip in. It is now created on **both**
paths, and `test/infrastructure/customer_details_persistence_test.dart` covers it.

## Consequences worth remembering

- **`Customer.displayReference` never returns the `id`.** It is meaningless to
  anyone outside the system.
- A customer created before this decision has no `code`. That is truthful — inventing
  `C-0001` for a customer nobody ever quoted that way would fabricate a business
  reference — so the field is nullable and must stay so.