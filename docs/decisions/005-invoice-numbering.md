# ADR 005 — Invoice numbering

**Status:** Accepted

## Context
Nepal-focused deployment. Finalised invoice numbers must be sequential,
unauditable, and never reused. The sequence must be reconstructable after the
fact.

## Decision
Finalised document numbers are sequential within the fiscal year and document
type, and start at 1 each fiscal year. The number is determined by fiscal year,
issue date, document type, and the configured numbering policy.

```
INV-2082-83-1042
```

## Consequences
- A draft does not consume a serial. The serial is consumed at the moment of
  issuance, so deleting a draft creates no gap and wastes no number.
- An issued invoice is never physically deleted. Corrections use credit notes,
  debit notes, sales returns, or payment reversals.
- Credit notes and debit notes have their own controlled sequences, must reference
  the original invoice, and preserve the audit trail.
- Invoice numbers are never reused, including after a fiscal-year reopen.
- Because each fiscal year has its own database, the sequence is naturally scoped
  per database, but the server must validate the fiscal year on archive.
