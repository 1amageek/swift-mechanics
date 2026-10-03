# MechanicsDeformingContact

## Purpose and Scope
Parent: [system/package](../../DESIGN.md). IM23 owns deforming geometry and self-contact under [SPEC](../../SPEC.md). Children: [MaterialGeometry](MaterialGeometry/DESIGN.md), [WitnessForces](WitnessForces/DESIGN.md), [ContactTransactions](ContactTransactions/DESIGN.md). Registered selected source has behavioral/profile evidence below; full FX-009 remains incomplete.

## Responsibilities and Boundaries
Root owns frozen source qualification and assigned publication/admission corrections after model_records transfers to IM16. Root exclusively owns this module index, Package.swift, shared probes/scripts, PROGRESS and commits. Direct dependencies are Core, Model, Numerics, Flexible, Collision and ContactLaws. Rigid ContactResponse does not supply the nodal representation. Producer changes require root coordination and an explicit reassignment before editing.

## Related Designs
[Canonical implementation plan](../../IMPLEMENTATION_PLAN.md) owns prerequisite IDs; [root](../../DESIGN.md) owns composition. Only verified public producer contracts may be consumed. Child designs own exact selected operations, assumptions and evidence, without duplicating supplier internals.

## Architecture
```text
Flexible nodal state -> MaterialGeometry -> WitnessForces <- Collision / ContactLaws
 -> ContactTransactions -> explicit value-history acceptance or unchanged rejection
```

## Contracts and Invariants
Current nodal geometry and material-coordinate binding, invalidation, actual deforming contact forces and friction/self-contact. Existing Tet4 and analytic contact qualifications do not certify cloth/cable or flexible evolution.
Units, frames, revision, chart, fidelity, parameter provenance and temporal meaning must remain explicit. Numerical status alone cannot establish physical acceptance. The full assigned requirements persist where an initial admitted domain does not cover them. Callable incomplete branches have markers and explicit failure; no silent substitute qualifies a requirement.

## State, Ownership, and Lifecycle
Child designs establish operation state, persistent contributor state, source/borrow lifetime and accepted/rejected publication before declarations. Shared state has identical Mutex/actor storage, isolation and Sendable contracts on Native/WASM/Embedded. Callbacks and resource release occur outside control locks.

## Failure, Concurrency, and Constraints
Public typed errors expose stale binding, unsupported domain, nonfinite inputs, cancellation, capacity and known/unknown supplier work. Each child declares caller-owned budgets before allocation. There is no build/profile qualification during source dispatch.

## Verification and Change Impact
The assigned owner traces producer implementations and fixes each required physical oracle before source. Native tests exercise actual physics and failed paths, not declarations. Root registers stable production targets and qualifies selected public operations on exact profiles after source freeze. Direct/transitive consumers must recheck changed assumptions. Full IM48 remains incomplete.

Initial selected handoff: eighteen Native cases passed actual geometry, current policy/owner admission, normal/friction nodal transport, independent moment/virtual power, stale/supplier work, value-history continuation and late initial-history cancellation. All 346 registered Native cases pass. Original Native/WASM/Embedded execution exercises real same-body Tet4 witness, actual law and nodal force/power, rejection/acceptance of immutable history and direct point current-cell rejection. Exact Swift6.4.0 release, matching WASM SDKs, EmbeddedUnicode, Node24.19.0 WASI Preview1. Value-history acceptance is not physical nodal evolution. Full surface coverage, cloth/cable, moving obstacles, angular/cohesive/hard-impact response, CCD, coupled integration and checkpoint codec/migration remain unqualified; child boundaries are authoritative.
