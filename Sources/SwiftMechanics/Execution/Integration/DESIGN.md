# Integration component

## Purpose and Scope
Parent: [responsibility owner](../DESIGN.md). Own IM09 smooth ODE integration, adaptive error control and real accepted/trial transaction use. [SPEC](../../../../SPEC.md) owns TI-001..003, TI-007, TI-009..010; [plan](../../../../IMPLEMENTATION_PLAN.md) owns prerequisites. Children: [Equations](Equations/DESIGN.md), [Continuation](Continuation/DESIGN.md), [Stepping](Stepping/DESIGN.md). Full eventual methods/domains remain IM09 responsibility after a qualified initial handoff.

## Responsibilities and Boundaries
Integrator owns stage equations, error/order/acceptance, retry and accepted-time semantics. Runtime owns state, contributors, checkpoint and publication lifetime; Nonlinear owns actual numerical iteration and original-residual acceptance. A provider owns its equation and coordinate/manifold domain. No gears/contact world dependency is needed to prove manufactured smooth ODEs. Worker owns only child components and Tests/MechanicsIntegrationTests; root owns this index, Package/global probes/PROGRESS/commits.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Equations](Equations/DESIGN.md) | child | Pure identified coordinate/equation/chart methods | Owned responsibility | See the qualified handoff below |
| [Continuation](Continuation/DESIGN.md) | child | Required integrator history and association | Owned responsibility | See the qualified handoff below |
| [Stepping](Stepping/DESIGN.md) | child | Actual explicit stages, error control and trial acceptance | Owned responsibility | See the qualified handoff below |
| [NonlinearEvolution](../../Physics/Mechanisms/NonlinearEvolution/DESIGN.md) | used by | Public validated endpoint record proposal | The projected owner computes physical consistency before using Continuation | Does not expose internal Integration reporting/capture or Runtime authority |
| [Responsibility owner](../DESIGN.md) | parent | Composition/global invariants | Sole registration authority | Full closure remains IM48 |
| [Runtime](../Runtime/DESIGN.md) | depends on | Required session/trial methods, explicit contributor continuation, bounded work and acceptance | Verified initial handoff 6ae2742 | Fixed-anchor kinematic domain, API availability and nonqueuing busy; no hidden integrator state |
| [Nonlinear](../../Mathematics/Nonlinear/DESIGN.md) | depends on | Generic equation providers and original-residual acceptance | Verified admitted numerical kernel | Embedded fixed compiler requires exercised generic scalar provider; failure work not invented |

## Architecture
```text
real Runtime accepted snapshot + identified equation/method policy
 -> bounded stages / implicit numerical equations in exclusive Runtime trial
 -> original equation and local-error/time acceptance
 -> accepted publication or rejected trial with bounded retry / typed terminal failure
```

## Contracts and Invariants
Define provider domain, layout, units, derivative meaning and purity before source. q-v/manifold convention cannot be inferred from array length. Actual supported charts/methods, tolerances, error norm, step-selection policy and resource accounting are explicit. Rejected stages leave accepted physical/contributor/random state unchanged. Continuation-dependent adaptive/implicit history belongs an explicit required Runtime contributor. No unsupported method, stiffness domain or missing history returns successful default output.

## State, Ownership, and Lifecycle
Operation workspace is exclusive and bounded; accepted values are immutable. Runtime is authority for concurrent admission, cancellation and commit. Same Sendable/storage/isolation contracts apply to every target; OS API availability propagates honestly. Provider callbacks and numerical work occur outside short Runtime metadata locks.

## Failure, Concurrency, and Constraints
Invalid provider/layout/time/chart, nonfinite derivatives, method/domain mismatch, failure to solve/accept, capacity/iteration/work limits and cancellation are typed. Supplier work remains distinct from outer stage work; unavailable failure ledgers do not authorize retry. Steps cannot silently advance accepted time or switch equation/method/backend.

## Verification and Change Impact
Independent manufactured ODE solutions must prove actual method order/error control, rejected-trial restoration, exact accepted terminal-time semantics and checkpoint continuation; implicit methods exercise actual Nonlinear required witnesses. Invalid derivative, cancellation, busy/closed session and exhausted retry/work fail with last accepted prefix. Tests/MechanicsIntegrationTests owns local evidence; root owns exact-profile selected public execution. Changes to provider/manifold/stage/continuation assumptions invalidate dependent mechanism and fluid evolution evidence.

## Qualified Initial Handoff (2026-10-04)
Actual local proof: nine Native behavioral tests/three suites. Supported scope: classical RK4 and adaptive Heun-Euler on explicitly identified Float64 Euclidean charts, independent observed order, accepted terminal time, rejected contributor/random rollback, exact continuation restart and malformed/cancel/resource/ledger failure. Root's selected public-protocol composition separately compiled/linked and actually exited 0 on Native and both exact Swift 6.4.0 release SDK IDs swift-6.4.0-RELEASE_wasm and swift-6.4.0-RELEASE_wasm-embedded. Embedded retained the existing EmbeddedUnicode trait; Node.js 24.19.0 WASI Preview1 ran both artifacts. Commands used project timeout guards. Root composite probe records its actual analytic/failure path in [FoundationVerification](../../../../Verification/FoundationVerification/DESIGN.md); Native host is macOS27, not minimum macOS13 qualification. No parallel WASI/browser/iOS/Linux proof follows.

Remaining eventual owner scope: implicit/stiff/manifold/dense-output methods, arbitrary chart migration and complete TI domains. The initial handoff permits documented consumer composition and preserves full SPEC requirement ownership; it does not close whole-target IM48.

A supplier cannot replace/reset its authoritative numerical ledger: the real prepare/derivative witness regression proves typed invalidOwnerAccess, unavailable failed work, no retry and full accepted-prefix preservation. The exact Embedded debug stack failure was isolated by a private instruction-preserving relocation, then fixed through same-target trial phase/source fixture decomposition. Final shipped artifacts use the original memory/stack profile and actually pass; no relocation is included.

### Consolidation contract
This directory is a component inside the SwiftMechanics module, not a separate SwiftPM target. Its existing public behavior and exact-profile evidence remain its contract authority. Cross-component access uses the documented contracts; internal visibility alone does not grant admission or publication authority. Source relocation requires integrated behavioral requalification.
