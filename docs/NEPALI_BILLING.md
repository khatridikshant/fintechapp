# Nepal billing requirements

What a Nepali business must put on an invoice, where each rule comes from, and
**which rules this application treats as settled and which it refuses to guess**.

## The point of this document

The architecture specification requires it, and it is the more important half of
the task:

> Nepal's applicable tax rules shall be verified against current authoritative
> requirements before production release and **shall not be treated as
> permanently fixed application constants**.

So this document records three things for every rule:

1. **What** the rule requires.
2. **Where it comes from**, so a claim can be checked rather than believed.
3. **How confident we are**, and specifically what would have to change in the
   code when the answer changes.

**Nothing here is a constant.** Every value that could change — the VAT rate, the
registration thresholds, the abbreviated-invoice ceiling — is carried by
`NepalTaxRules` with a version string, so a rule change is data, not a code
change.

---

## The two statutes

| Law | Governs |
| --- | --- |
| **Value Added Tax Act, 2052 (1996)** | VAT: registration, the invoice obligation, rates, records |
| **Value Added Tax Rules, 2053 (1997)** | Procedure. **Rule 17** prescribes the tax-invoice format. **Rule 17(Ka)** permits the abbreviated retail invoice. **Rule 23** covers records. |
| **Income Tax Act, 2058 (2002)** | Income tax records. **Section 81** is the retention rule. |
| **Finance Act, annual** | Sets the VAT rate for the year, thresholds, exemptions, penalties |
| **Electronic Billing Procedure, 2074 (2017)** | CBMS e-billing, for large taxpayers |

Sources: nepalLaws and actnepal for the statutory text; the IRD-adjacent
summaries listed at the end for commentary.

---

## Rule 17: what a tax invoice must contain

A full **tax invoice** (कर बीजक) requires all of these. The application calls
this `InvoiceKind.taxInvoice`.

| # | Field | Note |
| --- | --- | --- |
| 1 | Heading "Tax Invoice" / कर बीजक | Distinct from a retail cash memo |
| 2 | Supplier name, address, **PAN** | Exactly as registered with the IRD |
| 3 | Sequential invoice number | Per fiscal year, no reuse, no gaps |
| 4 | Invoice date | Bikram Sambat; Gregorian also recommended |
| 5 | Buyer name, address, **PAN** | See the PAN rule below |
| 6 | Description of goods/services | Item-wise |
| 7 | Quantity, unit, rate | Per line |
| 8 | Discount | A separate line, not netted silently |
| 9 | Taxable value | Subtotal before VAT |
| 10 | VAT rate | Stated explicitly (standard 13%) |
| 11 | VAT amount | Separate line |
| 12 | Grand total | **In figures and in words** |
| 13 | Authorised signature and seal | |
| 14 | **HS code** (first 4 digits) for goods | Added by the 46th amendment |

**Copies.** A full tax invoice is **triplicate**: original to the buyer, duplicate
retained for audit, triplicate retained in the invoice book. A computer-generated
system satisfies this by print control and retention rather than carbon paper —
which is what "single print with *Copy of Original* reprints" in the CBMS
requirements describes.

---

## Rule 17(Ka): the abbreviated retail invoice

A high-volume retailer — restaurant, supermarket, petrol pump, pharmacy — may
issue an **abbreviated** invoice for a transaction **up to NPR 10,000**:

- VAT shown **inclusive**; no separate tax line required
- Buyer PAN **optional**
- A **single** copy is sufficient

**Two conditions, and both matter:**

- The transaction must be within the ceiling.
- **If the buyer asks for a full tax invoice, one must be issued** (Section 14A).
  The customer's request is not optional.

An abbreviated invoice is therefore a *convenience for the seller*, never a way to
refuse a customer who asks properly. `InvoiceCompliance` reports this so a screen
can offer to upgrade the document rather than silently issuing the weaker one.

---

## Whose PAN is required on the bill

**There is a conflict in the sources, and it is recorded rather than resolved by
guessing.** Two thresholds appear:

| Source | Rule |
| --- | --- |
| Rule 17 commentary, several practitioner guides | Buyer PAN required if the buyer is **VAT-registered** or the transaction is **≥ NPR 10,000** |
| Other practitioner guides | Buyer PAN required if the buyer is a **firm**; optional for an **individual buying under NPR 1 lakh** |

They may be reconcilable — the 10,000 figure being the abbreviated-invoice
ceiling that applies to *all* transactions, the 1 lakh figure applying to
*individuals*. **This application does not choose between them.** It asks for the
buyer's PAN when either condition clearly applies:

- the buyer is recorded as **VAT-registered**, or
- the invoice is a **full tax invoice** (so the NPR 10,000 ceiling applies), or
- the total is **at or above NPR 100,000**, the stricter individual figure.

`NepalTaxRules.buyerPanRequiredFor` is one function, so reconciling this is a
one-line data change once the position is confirmed.

**Why the buyer's PAN matters beyond the form.** A purchase invoice lacking the
**vendor's** PAN may be **disallowed as input credit** in an audit. A bill missing
either party's PAN is not a valid tax bill. That is a cash cost, not a formality.

---

## VAT

| | |
| --- | --- |
| Standard rate | **13%** (raised from 10% in 2005) |
| Set by | The **Finance Act** annually, under Section 7 — **so it is not fixed** |
| Zero-rated | Applies to specific supplies (e.g. export) |
| Exempt | Specific supplies listed in the Act |

The application already models this correctly in substance: `Invoice.vat` is
computed on the **combined** subtotal rather than line by line, because per-line
rounding would drift from the return filed with the authority. A zero-rated invoice
**omits the VAT line entirely** rather than posting a zero, which is what a return
expects.

**Rates are held in basis points**, so no floating-point value ever enters a tax
calculation.

---

## Registration thresholds — unverified, and deliberately not implemented

Whether a business *must* register is a threshold question, and **the sources
disagree**:

| Business | Reported threshold |
| --- | --- |
| Goods / trading | NPR 5,000,000 (50 lakh) |
| Services | NPR 2,000,000 or NPR 3,000,000 (Finance Act 2081) — sources conflict |

**No threshold is implemented in the application.** The VAT-registered flag on
`BusinessProfile` is entered by the user, not inferred from a turnover the
application does not reliably hold. Guessing a threshold would produce confidently
wrong compliance advice, which is worse than none.

---

## E-billing (CBMS) — out of scope for V1, recorded so it is not forgotten

- Applies to VAT/PAN-registered businesses above a turnover threshold, **reported as
  NPR 200 million (20 crore)** by an IRD notice of 4 Baishakh 2083 (≈ April 2026),
  reduced from NPR 25 crore. The threshold has moved repeatedly and is described in
  the literature as a **"moving threshold" and an open risk**.
- Requires IRD-certified billing software, transmitting at issuance, with immutable
  timestamped sequential invoices and single-print control.
- Certified software must use a **relational database** and be able to produce
  **Annex 5** (transaction records) and **Annex 13** (high-value transactions)
  reports.

**Not implemented, and deliberately so**: this is a certification and integration
programme, not a feature. Two design consequences are recorded now rather than
discovered later:

1. The local database **is already relational and per-fiscal-year**, which is the
   prerequisite. Nothing about that needs undoing.
2. Invoice numbers are **sequential, gap-free, and allocated inside the issuing
   transaction** — which is the property CBMS certification actually checks. The
   existing `DocumentNumber` design satisfies it; **do not add gaps** (for
   "nice" numbering, or to reserve numbers) or certification becomes impossible.

---

## Record retention

| Law | Period | From what point |
| --- | --- | --- |
| **Income Tax Act §81(2)** | **5 years** | **Expiry of the concerned income year** |
| VAT | **6 years** | Commonly stated as 6 years from creation/transaction |

The two differ, and the difference matters:

- §81 runs from **the end of the income year**, not from the transaction date. An
  invoice dated 2081/04/01 is in an income year ending 2081/07/16, so its clock
  starts from that date, not from the invoice.
- The binding constraint is therefore **VAT's 6 years**, and it is longer than the
  income-tax period in almost every case.

**This corrects a previous claim in `docs/BACKUP_AND_RETENTION.md`,** which said
"Nepali law requires businesses to retain records for at least 6 years" as a single
undifferentiated rule. The accurate statement is two rules with different periods and
different start points, of which 6 years binds. `RetentionPolicy` now computes the
earliest safe deletion date per year and takes the longer of the two.

---

## What the implementation deliberately does not do

| Not done | Why |
| --- | --- |
| Registration thresholds | Sources conflict; the flag is user-entered |
| Choosing between the 10,000 and 1 lakh PAN rules | Unresolved conflict, surfaced as one function |
| E-invoicing / CBMS integration | A certification programme, not a feature |
| Annex 5 / Annex 13 reports | Follows CBMS, which is not in V1 |
| Nepali-language rendering | ui.txt sets English as the default; a transliteration layer is a separate task |
| Frozen VAT rate | Carried by `NepalTaxRules` with a version, per the spec's instruction |

---

## Sources

Statutory text:

- [Section 81, Income Tax Act 2058 — records](https://nepallaws.com/Laws/income-tax-act-2058-2002/chapter-15-records-and-information-collection/section-81-to-maintain-records-or-documents/)
- [Section 81, Income Tax Act 2058 (Nepali text)](https://actnepal.com/en/section/269/0/section-81-to-maintain-records-or-documents-of-income-tax-act-2058-2002)

Commentary and practitioner summaries — **secondary, and where they conflict this
document says so**:

- VAT invoice format, Rule 17: <https://hamroinvoice.com/blog/vat-bill-format-nepal-rule17-guide>
- HS code and IRD format: <https://hamroinvoice.com/blog/nepal-ird-bill-format-hs-code-guide>
- Registration thresholds and penalties: <https://www.attorneynepal.com/blog/vat-registration-nepal-turnover-threshold-process>
- Rates, thresholds and returns: <https://lawalpine.com/blog/vat-in-nepal-rates-and-thresholds-2082-83>
- E-billing and CBMS, with the threshold history: <https://www.vatupdate.com/2026/09/20/nepal-e-invoicing-e-reporting-country-booklet/>
- Customer-credit PAN and input-credit risk: <https://udyot.com/docs/nepal-vat-overview/>

**Before production, confirm against ird.gov.np and a chartered accountant.**
Thresholds and the VAT rate change with the Finance Act every year, and this
document is a starting point, not an authority.
