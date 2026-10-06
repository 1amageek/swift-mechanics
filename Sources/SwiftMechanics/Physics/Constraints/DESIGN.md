# Constraints component

## Purpose and Scope
Parent: [responsibility owner](../DESIGN.md). Dispatch responsibility: IM12, owning CN-001..007; JT-005..006; KI-006..008 in [SPEC](../../../../SPEC.md). Scope: identified coordinate constraint equations, assembly/projection, rank and reaction ambiguity, limits/passive joint contributions and prescribed/query domains. Children: [CoordinateEquations](CoordinateEquations/DESIGN.md), [AssemblyProjection](AssemblyProjection/DESIGN.md), [ScalarJointPorts](ScalarJointPorts/DESIGN.md). The initial stateless domains are behaviorally qualified below. Full eventual requirement ownership remains.

## Responsibilities and Boundaries
The implementation owner owns child component directories under Sources/SwiftMechanics/Physics/Constraints and Tests/MechanicsConstraintsTests. Root alone owns this module index, package registration, global probes, PROGRESS.md and commits. The owner reads actual supplier paths before designing required protocol operations, values, units, ownership and failure. Numerical kernels do not infer missing mechanism dynamics or manufacture reactions.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Responsibility owner](../DESIGN.md) | parent | Dispatch/composition invariants | Sole graph/index authority | Full-target closure remains IM48 |
| [CoordinateEquations](CoordinateEquations/DESIGN.md) | child | Scaled polynomial g/J/time terms and knife-edge rows | Actual input/evaluation owner | Qualified selected domain |
| [AssemblyProjection](AssemblyProjection/DESIGN.md) | child | Local KKT assembly and weighted speed projection | Actual residual/rank owner | Qualified selected domain |
| [ScalarJointPorts](ScalarJointPorts/DESIGN.md) | child | Scalar passive/limit laws | Actual power/domain owner | Qualified selected domain |
| [JointStops](JointStops/DESIGN.md) | child | Source-bound scalar stop impulse evaluation | Selected Native and original ordinary/Embedded public paths qualified | Automatic Runtime enforcement and constrained simultaneous impact remain separate |
| [GeometricRelations](GeometricRelations/DESIGN.md) | child | Original frame/point/axis holonomic geometry | AF22 nonpolynomial relation owner | Selected AF22/AF23 behavior qualified; broader geometry domains remain open |
| [ManifoldProjection](ManifoldProjection/DESIGN.md) | child | Bounded tangent-metric local assembly and manifold retraction | AF22 configuration correction owner | Actual original geometry acceptance qualified for selected AF22/AF23 paths |
| [MechanicsNonlinear](../../Mathematics/Nonlinear/DESIGN.md) | depends on | original-residual nonlinear solves | Verified initial producer handoff | Consume only documented admitted domains; report missing producer contracts |
| [MechanicsComplementarity](../../Mathematics/Complementarity/DESIGN.md) | depends on | admitted orthant/cone numerical solves | Verified initial producer handoff | Consume only documented admitted domains; report missing producer contracts |
| [MechanicsJoints](../../Modeling/Joints/DESIGN.md) | depends on | actual q-v manifolds, framed tree motion and Jacobians | Verified initial producer handoff | Consume only documented admitted domains; report missing producer contracts |
| [MechanicsRuntime](../../Execution/Runtime/DESIGN.md) | depends on | accepted/trial contributor state and nonqueuing admission | Verified initial producer handoff | Consume only documented admitted domains; report missing producer contracts |

## Architecture
```text
verified identified supplier values / caller-owned equation or port domain
 -> component-owned bounded laws / residuals / state contribution
 -> independent physical acceptance and explicit output or typed failure
```

## Contracts and Invariants
Child designs precede declarations. Every operation identifies physical dimensions, coordinate/frame/revision meaning, supplied domain and exact output semantics. Missing models or providers fail explicitly. Original physical residuals and work/energy identities decide acceptance. Required Runtime contributors own persistent internal state; rejected transactions preserve physical, subsystem and random prefixes. Generic interfaces alone do not qualify unimplemented physics. Eventual full requirement ownership remains after an initial qualified subset.

## State, Ownership, and Lifecycle
Operation work is exclusive and bounded. Public services use required protocol witnesses; callbacks execute outside short metadata locks. Shared mutable state preserves identical storage, isolation and Sendable contracts on Native/WASM/Embedded. Immutable contributor values carry continuation across acceptance/checkpoint rather than hidden service caches.

## Failure, Concurrency, and Constraints
Invalid units/frames/domain, stale state, singular or inconsistent equations/ports, unsupported modes, nonfinite output, cancellation and resource exhaustion are typed. Budgets are caller-owned and checked before traversal/allocation; supplier ledgers remain separate and unknown failed work does not permit retry. OS API availability propagates from actual suppliers. No source backend or synchronization fallback is permitted.

## Verification and Change Impact
Tests/MechanicsConstraintsTests owns actual success/failure, analytic/independent residual and resource/cancellation tests. Constraint proof distinguishes consistent redundant rows from contradiction and nonunique reactions, actual closure/projection and explicit-time derivative terms. Root composes selected Native and exact matching WASM profiles after a stable source snapshot. Changed domain/state/port assumptions invalidate dependent consumers, not unrelated supplier evidence.

The initial implementation is stateless: its actual SwiftPM dependencies are Core, Numerics, Nonlinear, Joints and the internal [ScalarFunctions boundary](../../Mathematics/ScalarFunctions/DESIGN.md). Complementarity and Runtime are hard prerequisites for the full assigned scope, not unused imports in these current kernels. Dynamic reaction, time evolution, mixed quaternion charts and general prescribed/query domains remain future IM12 obligations. Test owner: [Constraints tests](../../../../Tests/MechanicsConstraintsTests/DESIGN.md).

### Initial handoff evidence (2026-10-04)
Native focused execution passed fourteen of fifteen cases; the sole failure was a bitwise comparison after SI normalization round-trip. The changed tolerance assertion passed its targeted recheck, establishing composite fifteen-case/four-suite evidence for the final snapshot. Source review followed actual evaluation, KKT/rank/full-original-row acceptance, projection and scalar energy paths. Root selected public-service probe separately compiled, linked and executed with exit 0 on Native, ordinary WASM and Embedded WASM using Swift 6.4.0 release and matching SDKs; EmbeddedUnicode and Node24.19.0 WASI Preview1 remain the existing profiles. It independently checked both circle branches, weighted projection and energy, redundant reaction ambiguity, contradictory original-row failure and scalar passive/sliding power. Whole-target IM48, general geometric queries, dynamic reactions and accepted mechanism evolution remain unqualified.

### Consolidation contract
This directory is a component inside the SwiftMechanics module, not a separate SwiftPM target. Its existing public behavior and exact-profile evidence remain its contract authority. Cross-component access uses the documented contracts; internal visibility alone does not grant admission or publication authority. Source relocation requires integrated behavioral requalification.

## AF22 General Geometry Dispatch

IM16.9 owns two independent lower children, GeometricRelations and ManifoldProjection. Their source is excluded until root registers the frozen contract and dedicated behavioral target. Existing quadratic evaluation/closest-point KKT and public Joints/Numerics contracts remain read-only. Actual public point Jacobian/motion, compiled model admission/evaluation and joint/root integration supply the lower primitive path. A geometric tangent sample must retain all original rows, normalized dimensions/time scales and actual centripetal/prescribed bias; it must not duplicate quaternion Ndot correction.

```text
immutable body/frame relation + bounded source/layout/domain identity
 -> actual compiled snapshot + public point/axis motion
 -> original g + tangent A/drift/bias
 -> bounded tangent-metric correction + manifold retraction
 -> all-row residual/rank and explicit local correction evidence
```

The new assembly contract is local manifold correction under a caller tangent metric and path bound. It does not return existing quadratic KKT closest-point/stationarity evidence. Upper mechanism evolution starts only after actual lower behavior is verified. Multiple disconnected physical roots, mixed planar/spatial records and moving prescribed-frame Runtime continuation remain separate prerequisite gaps; successful articulated plus sixDOF/spherical branches do not close CN-004 wholesale. Root owns shared registration/probes/commit; nonlinear_mechanisms owns only the two new children and MechanicsGeometricConstraintTests.

AF22 selected lower qualification is owned by [FoundationVerification](../../../../Verification/FoundationVerification/DESIGN.md#af22-selected-general-geometry-qualification). The two children are now registered; this supersedes the dispatch-time exclusion above. Native evidence includes regular axis alignment and mixed manifolds; the exact public three-profile evidence covers the independently constructed four-bar path.

### AF24 original physical geometry handoff

[GeometricRelations](GeometricRelations/DESIGN.md#af24-planar-geometry-and-physical-row-authority) owns original planar point/distance admission and source-bound physical row covectors. This is independent of Dynamics' additive planar inertia source; neither owner consumes the other's evolving implementation. Root serializes shared registration and lower behavioral qualification before upper mechanism/reaction consumers.


## AF25 lower ownership frontier

[GeometricRelations](GeometricRelations/DESIGN.md) owns the additive distinction between original multiplier nullity and unique endpoint wrenches. [AssemblyProjection](AssemblyProjection/DESIGN.md) owns active-coordinate rank on the original full layout, including empty active coordinates and zero original rows. These are disjoint lower writers. Full prescribed-root geometry and [ManifoldProjection](ManifoldProjection/DESIGN.md) consume frozen, behaviorally checked contracts after IM16.27; GeometricRelations mutable ownership transfers explicitly at that boundary. [Implementation plan](../../../../IMPLEMENTATION_PLAN.md#af25-remaining-planar-reactions-and-full-prescribed-root-frontier) owns dispatch; child designs own detailed contracts.


AF25 selected prescribed-root geometry and D-only projection now compose the frozen lower contracts. GeometricRelations and ManifoldProjection own their original-row, source-binding and lifetime guarantees. Their changed contracts and inherited paths have [final integrated behavior evidence](../../../../Verification/FoundationVerification/DESIGN.md#af25-upper-integrated-qualification); broader domains remain child-declared refusals.


## AF26 trajectory consumer ownership

[GeometricRelations](GeometricRelations/DESIGN.md#af26-source-tagged-trajectory-binding-contract) and [ManifoldProjection](ManifoldProjection/DESIGN.md) consume the actually qualified lower trajectory ports and preserve original quadratic behavior. Child designs own new source-tagged frame/chart/law binding and D-only projection. [Upper parallel ownership](../../../../IMPLEMENTATION_PLAN.md#af26-upper-exclusive-implementation-and-independent-verification) assigns their exclusive writer and downstream nonlinear consumer; the frozen handoff is not upper behavioral evidence. Selected lower interaction is [qualified separately](../../../../Verification/FoundationVerification/DESIGN.md#af26-support-lifetime-correction-profile-evidence). Full constraint/trajectory domains remain open.

Selected AF26 trajectory geometry/manifold and nonlinear composition have [actual integrated evidence](../../../../Verification/FoundationVerification/DESIGN.md#af26-upper-integrated-selected-qualification). That selected qualification retains child-declared unsupported seams/domains and does not close the full constraint/trajectory requirement set.

## Selected Rolling Row Composition

[RollingRelations](RollingRelations/DESIGN.md) owns source-bound rolling disk/plane contact geometry, physical velocity covectors and transported acceleration bias. Its child links Native row/rank/work/failure evidence. This row-construction contract does not provide a rolling constraint solver, projection or coupled evolution; original portable qualification remains independent.
