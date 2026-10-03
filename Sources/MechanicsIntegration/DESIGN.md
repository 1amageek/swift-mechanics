# MechanicsIntegration

## Purpose and Scope
Parent: [system/package](../../DESIGN.md). Own IM09 smooth ODE integration, adaptive error control and real accepted/trial transaction use. [SPEC](../../SPEC.md) owns TI-001..003, TI-007, TI-009..010; [plan](../../IMPLEMENTATION_PLAN.md) owns prerequisites. Root indexes actual child contracts after their responsibility is fixed. Full eventual methods/domains remain IM09 responsibility after a qualified initial handoff.

## Responsibilities and Boundaries
Integrator owns stage equations, error/order/acceptance, retry and accepted-time semantics. Runtime owns state, contributors, checkpoint and publication lifetime; Nonlinear owns actual numerical iteration and original-residual acceptance. A provider owns its equation and coordinate/manifold domain. No gears/contact world dependency is needed to prove manufactured smooth ODEs. Worker owns only child components and Tests/MechanicsIntegrationTests; root owns this index, Package/global probes/PROGRESS/commits.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Root](../../DESIGN.md) | parent | Composition/global invariants | Sole registration authority | Full closure remains IM48 |
| [Runtime](../MechanicsRuntime/DESIGN.md) | depends on | Required session/trial methods, explicit contributor continuation, bounded work and acceptance | Verified initial handoff 6ae2742 | Fixed-anchor kinematic domain, API availability and nonqueuing busy; no hidden integrator state |
| [Nonlinear](../MechanicsNonlinear/DESIGN.md) | depends on | Generic equation providers and original-residual acceptance | Verified admitted numerical kernel | Embedded fixed compiler requires exercised generic scalar provider; failure work not invented |

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
