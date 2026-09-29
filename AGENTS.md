# AGENTS.md

Instructions for any AI coding agent working in this repository.

## Read these before touching code

1. `PROGRESS.md` — current state, the next bounded task, open questions.
2. `docs/AI_RULES.md` — the development contract. Hard prohibitions.
3. `docs/ARCHITECTURE.md` — structure and technology rationale.
4. The relevant ADR in `docs/decisions/` for the subsystem you are changing.
5. The three specifications at the repository root, when the task touches
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
