# ADR 008 — Desktop framework: Flutter

**Status:** Accepted. Supersedes the "TBD" desktop framework in the architecture
specification section 3.

## Context
The architecture requires a cross-platform desktop framework for Windows,
macOS, and Linux, with a replaceable presentation layer and a mature testing
story. The project is commercial and must carry no licensing cost.

## Decision
Flutter, with the Dart application runtime.

## Rationale
1. **Zero licensing cost, no vendor dependency.** Flutter is BSD-3. No paid
   tier exists and none is planned, so no licence can be repriced or revoked
   later. This was the decisive criterion.
2. **Fastest AI-assisted iteration loop.** The project will be built largely by
   AI agents in bounded tasks. Dart's fast compile-feedback keeps failed
   iterations cheap. The project's real defence against wrong accounting is its
   test suite, not its type system, so a stronger type system was judged less
   valuable than a faster edit-compile-test cycle.
3. **The UI is predominantly forms and data entry**, Flutter's strongest
   category, which maps directly onto the Windows 7/8 desktop design system in
   `ui.txt`.

## Accepted trade-off
Dart has no built-in fixed-precision decimal and no immutable primitive types.
The mitigation is the `Money` value object backed by integer minor units, in
`lib/src/domain/shared/money.dart`. State-machine rules that would be enforced by
a type system are instead enforced by tests. This is a conscious decision, not an
oversight.

## Alternatives rejected
| Option | Reason |
| --- | --- |
| Tauri v2 | Also zero cost, stronger guarantees. Rejected for slower AI iteration and a thinner ecosystem for data-dense business UI. Worth revisiting if AI iteration proves painful. |
| Electron | MIT, but 100-200 MB bundles and high memory, and weaker numeric discipline. |
| Qt 6 | LGPL obligations or a commercial licence. Avoided. |
| .NET MAUI | MIT, but no Linux desktop target, which the architecture requires. |
| Avalonia | The MIT core is free for commercial use, but since April 2026 Avalonia gates its IDE tooling and premium components behind per-seat commercial licences (Plus EUR 299/seat/yr, Pro EUR 899/seat/yr). The framework is MIT forever, so a purely commercial MIT-core build would also be acceptable, but the tooling dependency is an ongoing commercial relationship. |
| Uno Platform | Apache 2.0 core, but nventive sells adjacent commercial products. |

## Consequence
The presentation layer must remain replaceable. Nothing in `domain/`,
`application/`, or `infrastructure/` may import `package:flutter/*` except
where strictly necessary for platform services, and never for business logic.
