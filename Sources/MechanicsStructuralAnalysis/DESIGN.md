# MechanicsStructuralAnalysis

## Purpose and Scope
Parent: [system/package](../../DESIGN.md). IM28 owns modes and structural stability under [SPEC](../../SPEC.md). This is an AF14 dispatch boundary, not a registered target or implementation qualification. Actual child design links are added after their contracts exist.

## Responsibilities and Boundaries
/root/material_kernels exclusively owns child production directories and Tests/MechanicsStructuralAnalysisTests. Root exclusively owns this module index, Package.swift, shared probes/scripts, PROGRESS and commits. Dependencies are read-only: Equilibrium, Flexible, Numerics, Materials. Producer changes require root coordination and an explicit reassignment before editing.

## Related Designs
[Canonical implementation plan](../../IMPLEMENTATION_PLAN.md) owns prerequisite IDs; [root](../../DESIGN.md) owns composition. Only verified public producer contracts may be consumed. Child designs own exact selected operations, assumptions and evidence, without duplicating supplier internals.

## Architecture
```text
identified producer inputs -> bounded owned computation -> original acceptance evidence
 -> immutable qualified result or typed failure with preserved accepted prefix
```

## Contracts and Invariants
Actual mass/tangent modal problems, normalization/classification, damped frequency response and explicit buckling assumptions. Initial Tet4 qualification does not certify beam, nonlinear buckling or structural evolution.
Units, frames, revision, chart, fidelity, parameter provenance and temporal meaning must remain explicit. Numerical status alone cannot establish physical acceptance. The full assigned requirements persist where an initial admitted domain does not cover them. Callable incomplete branches have markers and explicit failure; no silent substitute qualifies a requirement.

## State, Ownership, and Lifecycle
Child designs establish operation state, persistent contributor state, source/borrow lifetime and accepted/rejected publication before declarations. Shared state has identical Mutex/actor storage, isolation and Sendable contracts on Native/WASM/Embedded. Callbacks and resource release occur outside control locks.

## Failure, Concurrency, and Constraints
Public typed errors expose stale binding, unsupported domain, nonfinite inputs, cancellation, capacity and known/unknown supplier work. Each child declares caller-owned budgets before allocation. There is no build/profile qualification during source dispatch.

## Verification and Change Impact
The assigned owner traces producer implementations and fixes each required physical oracle before source. Native tests exercise actual physics and failed paths, not declarations. Root registers stable production targets and qualifies selected public operations on exact profiles after source freeze. Direct/transitive consumers must recheck changed assumptions. Full IM48 remains incomplete.
