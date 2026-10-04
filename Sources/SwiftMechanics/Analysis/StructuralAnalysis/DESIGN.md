# StructuralAnalysis component

## Purpose and Scope
Parent: [responsibility owner](../DESIGN.md). IM28 owns modes and structural stability under [SPEC](../../../../SPEC.md). Children: [PhysicalModels](PhysicalModels/DESIGN.md), [Pencils](Pencils/DESIGN.md), [HarmonicResponse](HarmonicResponse/DESIGN.md), [Buckling](Buckling/DESIGN.md). Registered selected source has behavioral/profile evidence below; full ST-005..007 remains incomplete.

## Responsibilities and Boundaries
Root owns frozen source qualification after material_kernels transfers to IM44. Root exclusively owns this module index, Package.swift, shared probes/scripts, PROGRESS and commits. Direct dependencies are Core, Model, Materials, Numerics, Compiler, Equilibrium, Flexible and the internal [ScalarFunctions boundary](../../Mathematics/ScalarFunctions/DESIGN.md). Beams is qualified before upper analysis composition. Producer changes require root coordination and an explicit reassignment before editing.

## Related Designs
[Canonical implementation plan](../../../../IMPLEMENTATION_PLAN.md) owns prerequisite IDs; [root](../../../../DESIGN.md) owns composition. Only verified public producer contracts may be consumed. Child designs own exact selected operations, assumptions and evidence, without duplicating supplier internals.

## Architecture
```text
Flexible Beams / Tet4 / Equilibrium -> PhysicalModels
 -> Pencils / HarmonicResponse / Buckling -> original equation acceptance
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

Initial selected handoff: fifteen Native cases pass after four lower Beam cases, including actual Tet4 rigid modes and compiled equilibrium pencils, cantilever/Euler refinement, Rayleigh poles, complex response, truss gradient/tangent/limit point and original-residual/resource/cancel/supplier failures. All 346 registered Native cases pass. Original Native/WASM/Embedded public execution calls actual Hermite assembly, cantilever modes, pinned buckling, harmonic response, truss critical point and typed nonlinear-beam rejection. Exact Swift6.4.0 release/matching SDKs, EmbeddedUnicode, Node24.19.0 WASI Preview1; no target isolation branches. General nonsymmetric/nonproportional spectra, nonlinear continuum beams and general structural evolution remain unqualified; children own exact physical domains.

### Consolidation contract
This directory is a component inside the SwiftMechanics module, not a separate SwiftPM target. Its existing public behavior and exact-profile evidence remain its contract authority. Cross-component access uses the documented contracts; internal visibility alone does not grant admission or publication authority. Source relocation requires integrated behavioral requalification.
