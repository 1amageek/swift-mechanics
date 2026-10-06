# StructuralAnalysis component

## Purpose and Scope
Parent: [responsibility owner](../DESIGN.md). IM28 owns modes and structural stability under [SPEC](../../../../SPEC.md). Children: [PhysicalModels](PhysicalModels/DESIGN.md), [Pencils](Pencils/DESIGN.md), [HarmonicResponse](HarmonicResponse/DESIGN.md), [Buckling](Buckling/DESIGN.md), [GeneralDampedSpectrum](GeneralDampedSpectrum/DESIGN.md), [NonlinearStability](NonlinearStability/DESIGN.md). Registered source has actual behavioral/profile evidence for the required ST-005..007 acceptance scenarios in the admitted domains indexed below. Unsupported optional element/material domains remain explicit.

## Responsibilities and Boundaries
Root owns frozen source qualification after material_kernels transfers to IM44. Root exclusively owns this module index, Package.swift, shared probes/scripts, PROGRESS and commits. Direct dependencies are Core, Model, Materials, Numerics, Compiler, Equilibrium, Flexible and the internal [ScalarFunctions boundary](../../Mathematics/ScalarFunctions/DESIGN.md). Beams is qualified before upper analysis composition. Producer changes require root coordination and an explicit reassignment before editing.

## Related Designs
[Canonical implementation plan](../../../../IMPLEMENTATION_PLAN.md) owns prerequisite IDs; [root](../../../../DESIGN.md) owns composition. Only verified public producer contracts may be consumed. Child designs own exact selected operations, assumptions and evidence, without duplicating supplier internals.

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [GeneralDampedSpectrum](GeneralDampedSpectrum/DESIGN.md) | child | Original nonproportional quadratic modes | Composes admitted physical pencils with the complex numerical solver | Qualification and domain belong to the child; old Pencils behavior remains unchanged |
| [NonlinearStability](NonlinearStability/DESIGN.md) | child | Original augmented equilibrium continuation and local constrained stability | Calibrated nonlinear force and actual compiled inertia | Exact source/policy owners; explicit branch ambiguity and bounded work |

## Architecture
```text
Flexible Beams / Tet4 / Equilibrium -> PhysicalModels
 -> Pencils / HarmonicResponse / Buckling / GeneralDampedSpectrum / NonlinearStability
 -> original equation acceptance
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

Initial selected handoff: fifteen Native cases pass after four lower Beam cases, including actual Tet4 rigid modes and compiled equilibrium pencils, cantilever/Euler refinement, Rayleigh poles, complex response, truss gradient/tangent/limit point and original-residual/resource/cancel/supplier failures. All 346 registered Native cases pass. Original Native/WASM/Embedded public execution calls actual Hermite assembly, cantilever modes, pinned buckling, harmonic response, truss critical point and typed nonlinear-beam rejection. Exact Swift6.4.0 release/matching SDKs, EmbeddedUnicode, Node24.19.0 WASI Preview1; no target isolation branches. This historical initial proof did not qualify general nonsymmetric/nonproportional spectra, nonlinear continuum beams or general structural evolution. AF28 subsequently qualified the stated complex/nonproportional spectra and AF29 qualified original multidimensional nonlinear stability; children own exact physical domains.

### Consolidation contract
This directory is a component inside the SwiftMechanics module, not a separate SwiftPM target. Its existing public behavior and exact-profile evidence remain its contract authority. Cross-component access uses the documented contracts; internal visibility alone does not grant admission or publication authority. Source relocation requires integrated behavioral requalification.

## AF28 nonproportional-spectrum dispatch

scalar_boundary exclusively owns the new GeneralDampedSpectrum child and dedicated tests, with the new Numerics/ComplexSpectrum prerequisite under the same owner. Existing Pencils/PhysicalModels/HarmonicResponse/Buckling and all suppliers stay read-only. Actual general spectral and original quadratic-pencil contracts precede declarations; no existing unsupported branch is silently redirected. Root alone owns this index, registration/public evidence/progress and commits. See [dispatch](../../../../IMPLEMENTATION_PLAN.md#af28-independent-frontier-dispatch).

Selected AF28 Native/ordinary-WASM/Embedded-WASM public behavior is qualified through the unchanged core profile. Exact integrated execution and remaining domain limits belong to [FoundationVerification](../../../../Verification/FoundationVerification/DESIGN.md#af28-integrated-selected-qualification); child contracts remain the API authority.

## AF29 nonlinear-stability dispatch

scalar_boundary exclusively owns NonlinearStability and its dedicated tests. Its documented original multidimensional KKT continuation and physically derived constrained spectrum are authorized for implementation. Existing suppliers remain read-only. Root owns shared registration and exact-profile public qualification after owner source freeze. The selected calibrated-source contract does not certify missing nonlinear continuum or material-history producers.

## AF30 requirement and evidence reconciliation

No production or verification premise changes in this reconciliation. The exact SPEC acceptance scenarios are met by the already executed admitted physical paths; qualified child contracts remain the sole authority for domain, unsupported material/element policy and operation semantics.

| Requirement | Actual physical path and independent acceptance evidence | Canonical evidence |
|---|---|---|
| ST-005 | Hermite cantilever frequency refinement, free-beam zero modes and real Tet4 six rigid zero modes; original generalized eigen-equation, normalization and invalid-mass/source failures | [Structural tests](../../../../Tests/MechanicsStructuralAnalysisTests/DESIGN.md), [modal contract](Pencils/DESIGN.md) |
| ST-006 | Analytic oscillator complex response/phase, excitation/output units and admitted linearization envelope; nonproportional original quadratic modes and failures | [Harmonic contract](HarmonicResponse/DESIGN.md), [general damping](GeneralDampedSpectrum/DESIGN.md), [AF28 qualification](../../../../Verification/FoundationVerification/DESIGN.md#af28-integrated-selected-qualification) |
| ST-007 | Actual Hermite Euler load refinement and physical nonlinear guided-bar model; original multidimensional constrained equilibrium, bifurcation, both secondary load folds and failed continuation | [Buckling contract](Buckling/DESIGN.md), [nonlinear contract](NonlinearStability/DESIGN.md), [AF29 qualification](../../../../Verification/FoundationVerification/DESIGN.md#af29-integrated-selected-qualification) |

The callable nonlinearBeam refusal remains honest: the current BeamAssembly supplies linear Hermite operators, not a finite-rotation nonlinear beam energy/history model. SPEC ST-007 requires a independently validated nonlinear buckling case, supplied by the actual nonlinear models above; it does not require that optional continuum beam domain. Finite-rotation elements and constitutive consistency remain the separately owned FX-002/006 breadth. No unsupported branch or numerical success is reclassified as physical success, and no unchanged build is repeated for a documentation reconciliation.
