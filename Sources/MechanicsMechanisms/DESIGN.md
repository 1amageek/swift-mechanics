# MechanicsMechanisms

## Purpose and Scope
Parent: [system/package](../../DESIGN.md). IM16 owns constrained mechanism execution under [SPEC](../../SPEC.md). The frozen AF16 source is registered for root behavioral qualification. The complete IM16 requirement domain remains open; actual child designs own admitted contracts and selected evidence.

## Responsibilities and Boundaries
model_records exclusively owns new child production directories and Tests/MechanicsMechanismsTests after the IM23 source/test freeze. Root exclusively owns this module index, Package.swift, shared probes/scripts, PROGRESS and commits. Dependencies are read-only: Runtime, Integration, Constraints, Transmissions, Actuation, Dynamics. Root owns an additive public Constraints rank operation; source availability is not qualification. Producer changes require root coordination and an explicit reassignment before editing.

## Related Designs
[Canonical implementation plan](../../IMPLEMENTATION_PLAN.md) owns prerequisite IDs; [root](../../DESIGN.md) owns composition. Only verified public producer contracts may be consumed. Child designs own exact selected operations, assumptions and evidence, without duplicating supplier internals.

## Architecture
```text
identified producer inputs -> bounded owned computation -> original acceptance evidence
 -> immutable qualified result or typed failure with preserved accepted prefix
```

## Contracts and Invariants
Actual constrained acceleration, original reactions, declared DAE/chart stepping and accepted engagement/break/wake state. General loop geometry, topology replacement and chart reconciliation require explicit contracts before source.
Units, frames, revision, chart, fidelity, parameter provenance and temporal meaning must remain explicit. Numerical status alone cannot establish physical acceptance. The full assigned requirements persist where an initial admitted domain does not cover them. Callable incomplete branches have markers and explicit failure; no silent substitute qualifies a requirement.

## State, Ownership, and Lifecycle
Child designs establish operation state, persistent contributor state, source/borrow lifetime and accepted/rejected publication before declarations. Shared state has identical Mutex/actor storage, isolation and Sendable contracts on Native/WASM/Embedded. Callbacks and resource release occur outside control locks.

## Failure, Concurrency, and Constraints
Public typed errors expose stale binding, unsupported domain, nonfinite inputs, cancellation, capacity and known/unknown supplier work. Each child declares caller-owned budgets before allocation. There is no build/profile qualification during source dispatch.

## Verification and Change Impact
The assigned owner traces producer implementations and fixes each required physical oracle before source. Native tests exercise actual physics and failed paths, not declarations. Root registers stable production targets and qualifies selected public operations on exact profiles after source freeze. Direct/transitive consumers must recheck changed assumptions. Full IM48 remains incomplete.

## Frozen Source Children

The child source/test snapshot is frozen for root registration and actual behavioral qualification. Source availability is not execution evidence. The [implementation plan](../../IMPLEMENTATION_PLAN.md#frozen-af16-source-handoff-and-actual-build-edges) owns the current dependency/ownership handoff.

| Child design | Relationship | Contract used | Cautions |
|---|---|---|---|
| [ConstrainedDynamics](ConstrainedDynamics/DESIGN.md) | child | Selected public operations defined by the child | Exact admitted domain and behavioral qualification belong to that child |
| [AffineEvolution](AffineEvolution/DESIGN.md) | child | Selected public operations defined by the child | Exact admitted domain and behavioral qualification belong to that child |
| [AcceptedTransitions](AcceptedTransitions/DESIGN.md) | child | Selected public operations defined by the child | Exact admitted domain and behavioral qualification belong to that child |
| [ConnectedSleep](ConnectedSleep/DESIGN.md) | child | Selected public operations defined by the child | Exact admitted domain and behavioral qualification belong to that child |

## Selected AF17 Qualification

Root registered the fixed source graph after lower review and exercised actual implementations. All 436 Native behavioral tests in 30 registered modules passed in `.build/af17-integrated-native.log`. Selected public compositions compiled/linked and exited 0 on original Native arm64 macOS27, swift-6.4.0-RELEASE_wasm and its matching Embedded SDK with EmbeddedUnicode, Node24.19.0 WASI Preview1; `.build/af17-{native,wasm,embedded}-run.log` owns execution output. Original stack reservation and unmodified produced artifacts were used. This is selected-path evidence, not all Native test paths on WASM, target-wide performance, actual WASI parallelism or full requirement closure.

Native: sixteen constrained/redundant/momentum/gear/accepted-lock/leaf-break/connected-decision/failed-work cases. Public profiles: actual required constrained gear dynamics/integration/replay, leaf detachment and Runtime break/checkpoint replay. Root preserved typed Dynamics total-force failure, added required Embedded direct Constraints visibility, and phased the oversized probe caller; production physics/isolation is unchanged. General loop/manifold/subtree/multievent/sleep evolution remains open.
