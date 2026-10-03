# ConnectedSleep

## Purpose and Scope
Bounded connected-component sleep and wake decisions. Parent: [MechanicsMechanisms](../DESIGN.md). No children. Full IM16 requirements remain owned beyond this initial admitted subset.

## Responsibilities and Boundaries
Declared kinetic energy and coordinate velocity criteria over actual coupled coordinate graph; connected wake from explicit caller seed identities. Command/topology/impact consumers must supply those seeds through their own accepted event authority. Decisions alone do not qualify resting contact stacks or dynamic sleep omission.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Parent](../DESIGN.md) | parent | IM16 ownership | Module composition | Root registers and qualifies actual paths |
| [Dynamics](../../MechanicsDynamics/DESIGN.md) | depends on | Rigid equations and solve | Real compiled physical mass | No diagonal proxy |
| [Constraints](../../MechanicsConstraints/DESIGN.md) | depends on | Required rank and evaluation | Original identified rows | Rank does not imply force or feasibility |
| [Runtime](../../MechanicsRuntime/DESIGN.md) | coordinates with | Accepted physical transactions | Immutable accepted prefix | Model replacement has separate admission authority |
| [Integration](../../MechanicsIntegration/DESIGN.md) | coordinates with | Equation and continuation witnesses | Actual stage/time acceptance | Exact chart readback |

## Architecture
```text
accepted physical energy/velocity + graph + wake seeds -> connected groups -> immutable decision
```
Actual dependencies used: ConstraintCoordinateLayout identities/scales, actual RigidDynamicsSystem mass/velocity and caller NumericalWork. No Runtime sleep publication occurs.

## Contracts and Invariants
Graph and criteria are caller bounded, coordinate IDs unique and edges valid. Wake propagates over every connected edge. No mutable hidden cache; accepted contributor integration is required before execution can omit dynamics.
All values and public witnesses are Sendable on every target. Frames, model/layout revision, temporal force versus impulse interpretation and physical units stay explicit. Output is published only after original physical acceptance.

## State, Ownership, and Lifecycle
Source records are immutable; workspace and authoritative NumericalWork are caller-exclusive values. Required suppliers execute outside locks. No global cache or mutable shared producer state is introduced. Rich operation contexts may be immutable final Sendable owners to bound debug stack overlap. Structural scalar-slot budgets do not claim allocator or physical-copy measurements.

## Failure, Concurrency, and Constraints
Typed failures distinguish stale binding, shape/domain/physical residual, cancellation, overflow, capacity and supplier error. Caller maxima are checked before allocation; checked integer products bound workspaces. Supplier work is separate from orchestration work; unknown partial supplier failure stops without retry. Ledger replacement/reset is rejected. Unavailable callable paths carry FIXME(INCOMPLETE_IMPLEMENTATION) and typed failure.

## Verification and Change Impact
[Test owner](../../../Tests/MechanicsMechanismsTests/DESIGN.md). Planned actual evidence: Independent connected wake, threshold failure, graph/capacity/cancel, unchanged source. Root owns Native and exact original WASM/Embedded qualification after source freeze; declarations alone grant no qualification. Changed mass/row/scaling/chart or lifecycle supplier contracts require affected composition requalification.

### Selected AF17 execution evidence

Native connected energy/speed/wake-decision and invalid/cancel cases passed. Sources compile in the public WASM products; no WASM sleep-decision execution or accepted dynamics omission is certified. Exact profile identity and root logs are indexed by the [parent design](../DESIGN.md); the corresponding test owner retains the independent physical oracles. Private stack diagnostics are not qualification.
