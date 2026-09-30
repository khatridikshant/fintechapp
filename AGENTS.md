# AGENTS.md

Instructions for any AI coding agent working in this repository.

## Read these before touching code

1. `PROGRESS.md` — current state, the next bounded task, open questions.
   **Read section 7 in full.** It accumulates the discoveries, the resolved gaps,
   the still-open questions, and the drift mechanics that cost time to work out
   the first time. It is the cheapest part of this repository to read and the most
   expensive part to rediscover.
2. `docs/AI_RULES.md` — the development contract. Hard prohibitions.
3. `docs/ARCHITECTURE.md` — structure and technology rationale.
4. `docs/INVENTORY_EXPLAINED.md` — plain-language accounting explainer, when the
   task touches inventory, costing, COGS, or stock. Written for a non-accountant,
   so use it to check that a change still makes accounting sense rather than only
   passing tests.
5. `docs/NEPALI_CALENDAR.md` — plain-language explainer for the Bikram Sambat
   calendar, when the task touches fiscal years, dates, or anything that decides
   which year a transaction belongs to. **It records what has and has not been
   verified about the calendar data.** Read it before changing that data.
6. The relevant ADR in `docs/decisions/` for the subsystem you are changing.
7. The three specifications at the repository root, when the task touches
   accounting, fiscal years, sync, or UI. They override any summary, including
   this file and `PROGRESS.md`.

## The short version

- Domain first. Define and test the business operation, then build its screen.
- The UI never touches the database. It calls a use case.
- Every journal must balance. There is no exception.
- Write the failing test first. Then implement. Then verify the accounting result
  by hand, independently of the code.
- Never change a test to make it pass. If a test fails, decide deliberately
  whether the code or the expectation is wrong, and resolve it from the
  documented accounting rules.
- Money is always the `Money` type, never a `double` or `num`.
- Posted financial records are immutable. Corrections use credit notes, debit
  notes, reversals, or compensating inventory movements.
- **Never change the Bikram Sambat calendar data without reading
  `docs/NEPALI_CALENDAR.md` first.** A wrong month length misfiles transactions
  into the wrong fiscal year while every internal check still passes.
- Schema changes require a migration.
- All normal operations work offline. Only authentication, sync, backup, and
  fiscal-year conclusion require the network.
- Keep tasks bounded. One capability, one layer set, full test suite, then stop.
- If a requirement is ambiguous, stop and ask. Do not invent an accounting rule.

## Layer boundaries

```
presentation  ->  application  ->  domain
                                   ^
                                   |
                             infrastructure
```

`domain/` imports nothing from the other layers. `presentation/` never imports
`domain/` internals directly; it goes through use cases.

## Update PROGRESS.md

When you finish a task, update `PROGRESS.md`: move the completed work into
"done", correct the gate status, and replace "Next task" with the following
bounded task. The next agent depends on this.

**Also record anything you learned the hard way** in section 7. A discovery that
only lives in a chat transcript is lost, and the next agent will pay for it again.
Record resolved gaps as RESOLVED with what closed them rather than deleting them,
and keep the reasoning, not just the outcome.
