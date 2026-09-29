# ADR 004 — Inventory costing method: UNRESOLVED, BLOCKING

**Status:** Open. Must be decided before any inventory implementation.

## Context
The architecture specification, section 29, states:

> The exact inventory valuation method shall be explicitly selected and
> documented before implementation. The application shall not silently choose
> FIFO, weighted average, moving average, or another costing method.

Inventory valuation determines COGS, which determines gross profit, which
determines the balance sheet. It is not a detail that can be deferred, because
changing it later would silently restate historical profit.

## Candidates

| Method | Behaviour | Cost |
| --- | --- | --- |
| Moving weighted average | Recompute average cost after every purchase. Sale uses the current average. | Simple. Diverges from actual purchase cost. Requires recalculation on every movement, so it must be computed transactionally. |
| Periodic weighted average | Average recomputed once at period end. | Simplest, but the inventory account on the balance sheet disagrees with physical reality during the year. |
| FIFO | Oldest stock issued first. | Matches physical flow closely. Requires cost layers, so each sale may create several journal lines. |
| Specific identification | Manual. | Accurate but impractical for a small-business tool. |

## Also unresolved

**Negative inventory behaviour.** May a sale be posted when the stock on hand is
insufficient? Options: block the sale, allow it and let stock go negative, or
warn and allow. This interacts directly with the costing method, because selling
stock that does not exist has no defined cost.

## What is required

A written decision on both questions, from the product owner, before Gate 6
begins. An AI agent must not choose. If this ADR is still Open when inventory
work is requested, stop and ask.
