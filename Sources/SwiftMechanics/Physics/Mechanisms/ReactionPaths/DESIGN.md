# ReactionPaths

## AF26 additive prescribed planar root contract

This additive contract is implemented in the files below; its runtime qualification is owned by root and is not inferred from source presence. The selected domain is a complete reduced planar tree whose root is genuinely prescribed through the original compiled model and `PrescribedRootBinding.program`. Existing spatial/planar tree and closed-loop operations remain unchanged. This port adds net prescribed-root support and tree cuts; it does not claim a bearing split, actuator/bearing decomposition, spatial support, or prescribed-root loop allocation.

### Confirmed prerequisite and responsibility boundary

`PrescribedRootBinding` validates compiled `.prescribedMotion` root authority and original law-bound q/v/a. `PrescribedRootConstraint` retains the full original physical system, root identity rows, layout and root sample. `MassWeightedMechanismSolver` fixes known-root acceleration before acceptance, computes root effort from original full inertial force, and accepts every original P/D force equation. `PhysicalConstrainedMotion` seals that system/motion association. These frozen producers establish coordinate effort; they do not supply a physical support allocation. Existing tree recovery requires zero residual in every generalized coordinate and no net wrench for a floating root, so it cannot be reused by pretending the prescribed root is fixed or by changing the original snapshot.

| Design | Relationship | Contract used | Caution |
|---|---|---|---|
| [GeometricRelations](../../Constraints/GeometricRelations/DESIGN.md) | depends on | Original compiled source, prescribedRoot binding, evaluator/original acceptance | Root program and original state remain authoritative; metadata alone is insufficient |
| [PrescribedMotions](../../../Modeling/Joints/PrescribedMotions/DESIGN.md) | depends on | OriginalPrescribedBaseMotionAcceptance, sealed base sample | Consume the current frozen program contract; new trajectory laws are a separate owner |
| [ConstrainedDynamics](../ConstrainedDynamics/DESIGN.md) | depends on | PrescribedRootConstraint, PhysicalConstrainedMotion, original rank/rows/force | Synthetic root rows represent effort, not physical endpoint covectors |
| [RigidEquations](../../Dynamics/RigidEquations/DESIGN.md) | depends on | PhysicalRigidEquationComputing.originalInertialForce/inertialWrench | Original MassProperties2D and bias; no copied Newton/Euler implementation |
| [Tests](../../../../../Tests/MechanicsReactionPathTests/DESIGN.md#af26-prescribed-planar-root-proof-contract) | used by | New public prescribed-root port | Independent scalar physical and refusal oracles; root owns execution |

```text
compiled root authority + original program/state + constraint + sealed motion
 -> builtin source/law/rows/rank acceptance
 -> builtin full original force + supplied/canonical per-body inertia and known loads
 -> original P effort and D residual acceptance
 -> original world-origin subtree/cut/body balance
 -> root-origin wrench projected through actual root columns equals P effort
 -> frame/reference conversion -> immutable continuous reduced report
```

### Public port and construction authority

The following signatures are fixed for the additive implementation. Input construction only retains immutable declarations; it cannot manufacture acceptance. The recovery operation alone constructs the report. Each primary type has its own file.

```swift
public struct PlanarPrescribedRootReactionInput: Sendable {
    public init(motion: PhysicalConstrainedMotion, geometry: GeometricConstraintSystem,
                state: KinematicState, constraint: PrescribedRootConstraint,
                originalDrive: [Double], topology: TreeReactionTopology)
}
public struct PlanarPrescribedRootReactionPolicy: Sendable {
    public init(geometry: ConstraintEvaluationPolicy, mechanism: MechanismSolvePolicy,
                tree: TreeReactionPolicy) throws(PlanarPrescribedRootReactionError)
}
public protocol PlanarPrescribedRootReactionRecovering: Sendable {
    func recover(_ input: PlanarPrescribedRootReactionInput, outputFrame: EntityID,
                 policy: PlanarPrescribedRootReactionPolicy,
                 loadWork: inout LoadWork, work: inout NumericalWork)
        throws(PlanarPrescribedRootReactionError) -> PlanarPrescribedRootReactionReport
}
public struct PlanarPrescribedRootReactionRecovery: PlanarPrescribedRootReactionRecovering {
    public init(equations: any PhysicalRigidEquationComputing = RigidEquationKernel(),
                gravity: any GravityEvaluating = GravityEvaluator())
}
```

Input exposes its six initializer fields and `dynamics: PhysicalRigidDynamicsSystem` derived from `constraint.system`. Policy exposes `geometry`, `mechanism`, and `tree`; it composes existing bounds, scales, tolerances and cancellation rather than inventing a numerical accuracy constant. Recovery validates coordinate scales/time/energy/revision and compatible dimensions under these policies. Report exposes `source: PlanarPrescribedRootReactionInput`, `joints: [PlanarJointReactionWrench]`, nonoptional `support: PlanarRootSupportWrench`, `rootActuationEffort: [Double]` in original known-coordinate order, `originalRank: ConstraintRankEvidence`, `maximumScaledOriginalGeneralizedResidual: Double`, `maximumScaledRootEffortResidual: Double`, `numericalWork: NumericalWork` and `loadWork: LoadWork`. Its nested `Fidelity` enum has `.reducedPlanarPrescribedRootBalance`, exposed by `fidelity`; no old report fidelity changes.

New files are `PlanarPrescribedRootReactionInput.swift`, `PlanarPrescribedRootReactionPolicy.swift`, `PlanarPrescribedRootReactionRecovering.swift`, `PlanarPrescribedRootReactionRecovery.swift`, `PlanarPrescribedRootReactionReport.swift`, `PlanarPrescribedRootReactionError.swift`, `PlanarPrescribedRootReactionContext.swift` and `PlanarPrescribedRootReactionArithmetic.swift`. The last two are internal phase/work owners, not alternative physical algorithms. Existing wrench/sign/temporal types are reused. The new error owns additive failures without editing shared `ReactionPathError`. Existing `PlanarTreeReactionRecovery.originalBody`, `originalGravity` and `originalLoad` have component-internal visibility for reuse; their implementations and existing public behavior are unchanged. `TreeReactionTopology.completeTree` documents the root support admitted by the selected port, preserving the old fixed/free domains and the explicit caller assumption.

### Admission, original acceptance and physical meaning

Require `.planarFloating` root, original compiled `.prescribedMotion` authority, a nonnil actual prescribedRoot binding, all-planar source, and `.completeTree`. Relations, geometry row IDs and constraint.geometry rows/drift/bias must all be empty: even retained structural-zero loop rows belong to an unsupported loop domain here, and are never dropped to enter this port. Require no named prescribed anchors or prescribedMotion program, only fixed joint anchors, and original dynamic descendant joint authority. Complete-tree declaration remains a caller assumption about unseen physical paths. Require finite zero `originalDrive` of full n size and zero values in every original generalized-force contribution. Identified body force/couple inputs remain admissible. Reject impulse meaning. Output frame rotation preserves XY/Z; retain actual world/frame reference points, including their actual z.

Recompute the original geometry sample and snapshot from the original compiled model/state through public builtin operations. Validate the supplied motion source and dynamics snapshot against this complete original sample: tree/layout/revision, bodies/joints/frames, every geometric column, coordinateRate, time bit pattern, velocity and motion frame. Require `motion.system === constraint.system`, original physical input dimension/inertia identities/frames and complete retained loads/gravity. The immutable constraint's original system/input is the physical inertia/load authority; compiled model/state is the kinematic/law authority. A supplier result may not replace either. Bind constraint.base to the original binding.program using builtin original base acceptance, not merely a matching sample metadata string. Reconstruct the canonical PrescribedRootConstraint from the original system, original empty geometry sample, canonical base and binding.rowIDs; compare every original root row, ID, normalization, drift and acceleration bias to the supplied constraint and motion layout. Check accepted root q/v/a against the original law; accepted acceleration root prefix is the original base.a, while D uses the supplied accepted motion values. Recompute builtin original rank with `WeightedConstraintAssembler.rank(_:policy:work:)` and `policy.mechanism.constraints`; compare every rank/independent/dependent row/nullity field: k=3 root identity rows have rank k, zero nullity; every row is retained. Check every normalized root velocity and acceleration residual under the original mechanism tolerance before force acceptance.

For every coordinate, reconstruct `sum(A/S * mu)` from all three original root rows and compare to the supplied generalizedReaction. P root effort equals original row multiplier divided by its coordinate scale; D reconstructed reaction is zero. Recompute original full inertial force with bias and physically identified known load projections. Require `inertial[i] - known[i] - reaction[i] = 0` on P and D under the existing original scaled acceptance policy. Also independently project original per-body inertial-minus-load wrenches through every original body column: D must vanish, P must equal canonical root effort. Neither assembled mass arrays nor a supplier diagnostic substitute for these original equations.

Subtract actual gravity at each original world COM and complete rotated/shifted raw known loads from each original inertial wrench. Shift each residual to a common world origin before subtree aggregation. Parent-on-child is the child subtree residual at the actual child-anchor point; child-on-parent is its negative at the same point. Recover support-on-root as the whole-tree residual at the actual root-body origin; root-on-support is its negative. Independently reconstruct each body's incoming/outgoing cut/support balance before publication. Project this root-origin physical support through the root body's actual original root columns; it must equal the same P coordinate effort. This separates root effort, root support and each cut while checking their physical correspondence. Root's own inertia/gravity/loads belong to support, not child cuts.

The output contains Fx/Fy/Mz only, in N/N m, at snapshot seconds/revision, with `.instantaneousContinuousForce`. `rootActuationEffort` is the chart's generalized effort (translation N, angular N m), not an inferred motor or bearing split. Conditional physical uniqueness covers net root support and each complete-tree cut only. Both signs share one point; change of reference uses `M_to = M_from + (from-to) cross F`, then rotation. Raw off-plane load references and cancelling transverse couples are shifted before planar reduction, preserving existing physical input admission. No additional cut/reference z==0 refusal or fake 3D inertia is introduced.

### Failure, work and phase lifetime

`PlanarPrescribedRootReactionError` cases are `invalidInput`, `invalidShape`, `staleSource`, `capacityExceeded`, `cancelled`, `unsupportedSupportDomain`, `unsupportedTemporalMeaning`, `unrepresentedConnections`, `unallocatableGeneralizedLoad`, `invalidRankEvidence`, `originalRootRow(row: UInt64)`, `originalGeneralizedReaction(index: Int)`, `originalRootEffort(index: Int)`, `invalidSupplierEvidence`, `supplierLedgerReplaced`, `loadLedgerMerge(LoadError)`, and nested `geometry(GeometricConstraintError)`, `motion(PrescribedMotionError)`, `mechanism(MechanismError)`, `constraint(ConstraintError)`, `tree(ReactionPathError)`, `core(CoreError)`, `dynamics(DynamicsError)`, `loads(LoadError)`, `numerical(NumericalError)`. Geometry rows/named anchors/non-prescribed or spatial roots use unsupportedSupportDomain; topology omission uses unrepresentedConnections; nonzero generalized drive/load uses unallocatableGeneralizedLoad. Original residual/body failures retain their existing nested cause. New callable unsupported branches require incomplete-implementation markers.

Use original `PhysicalRigidEquationComputing` public queries for inertia/full force and existing gravity/framed-wrench services. Injected inertial/full-force responses must pass positive caller pre-admission, monotonic budget/counter acceptance on success and failure, requested metadata/shape checks, and builtin original numerical recomputation under the same ledger. Compare then adopt canonical values; same body/frame/point does not certify original inertia. Gravity retains original body/mass/COM/field recomputation and exactly three successful LoadWork units per body (irreversible admission, actual supplier point, original builtin point). Preserve known opaque work prefix and original cancellation closure after failure/reset. A cancelled merge retains loadLedgerMerge and unavailable work semantics. Failed-supplier work availability delegates nested causes and marks reset/merge failures unavailable. No partial report or hidden retry.

All source/results/suppliers remain immutable Sendable across Native/WASM/Embedded. Workspace and both ledgers are operation-local. Policy bounds original bodies/joints/loads/rows/coordinates and checked simultaneous storage; arithmetic overflow and exhausted budgets fail before publication. Distinct noninline source acceptance, canonical force/body evaluation, subtree aggregation and report phases retain only necessary immutable owners; original 128 KiB phase boundaries remain part of root public qualification. No snapshot rewriting, shared mutable state, unsafe isolation, target-specific storage/conformance or internal WorldRigidBody/DynamicsArithmetic dependency.

Root authorized IM16.31.2 after committing the lower contracts. One owned source review traced actual canonical source/law/rows/rank acceptance, supplied and builtin original queries, identified raw load shifts, P/D balance, subtree support/root-column acceptance, failure ledgers and publication. Shared-state review found only immutable stored owners and operation-local workspaces across all targets; reused cancellation test flags retain their common Mutex. No concrete contract finding remains. `git diff --check` passed. The isolated owner Native execution below extends the source review; root still owns canonical full-graph Native and original Native/WASM/Embedded composition and original 128 KiB guards. Existing AF25 evidence stays valid until its actual premises change.

### AF26 isolated owner Native execution

The owner executed the frozen source and actual independent/refusal paths in `.build/af26-independent-support`, prepared from committed baseline `1fbf8f9`. Only ReactionPaths and MechanicsReactionPathTests were overlaid. The exact command was:

```text
python3 Scripts/run_with_timeout.py 240 /Users/1amageek/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swift test --build-path .build/native -j 4 --filter PlanarPrescribedRootReaction
```

The three initial cold all-test graph attempts exceeded the 240-second bound while progressing through production and unrelated test compilation, with no compiler errors; logs are `.build/af26-independent-support-native.log`, `-2.log`, and `-3.log`. After those processes exited, root authorized an isolated-copy-only registration reduction: retain the exact existing MechanicsReactionPathTests declaration and remove the other 38 one-line testTarget declarations. Production/executable targets, source, flags and dependencies were unchanged; the workspace manifest was untouched. This reduced registration graph, not the canonical package test graph, owns this evidence.

`.build/af26-independent-support-native-focused.log` completed with exit zero, build 42.97 seconds and test runtime 0.023 seconds: all 15 declarations in three suites, including 21 expanded cases, passed. Compiler executable reports `Apple Swift version 6.4 (swift-6.4-RELEASE)`, target arm64-apple-macosx27.0.0; host macOS 27.0.1 (26A434). Swift Testing 2084 reports test deployment target arm64e-apple-macos14.0. Baseline missing-exclude warnings remain; no owned compiler or behavior repair was needed. Canonical source/body/full-force, nonunit normalization, real point/frame/offset moments, wrong original force multipliers, D residual, source/law/time/row refusal and supplier reset/failure/cancel/resource paths actually executed. The source digest/inventory is `.build/af26-support-freeze.json`; copied production/test Swift source matches the workspace frozen source byte-for-byte.

This establishes only the selected isolated Native owner path. Root still owns canonical full-graph Native integration, new public caller composition, ordinary WASM/Embedded runtime and original 128 KiB guards. Existing qualified AF25 evidence is retained under unchanged premises. No commit or broader IM16 completion is claimed.

## AF25 additive reduced planar recovery

Existing spatial APIs/fidelity remain unchanged. The non-generic `PlanarTreeReactionRecovering.recover(_:acceleration:topology:outputFrame:policy:loadWork:work:)` consumes an actually admitted planar `PhysicalRigidDynamicsSystem`, `TreeReactionPolicy` and typed `ReactionPathError`. `PlanarTreeReactionRecovery(equations:gravity:)` injects `PhysicalRigidEquationComputing` and `GravityEvaluating`. Complete original MassProperties2D/snapshot/velocity/loads/gravity remain retained; no spatial tensor or generalized-to-body allocation is fabricated.

```text
actual admitted planar source + continuous acceleration + complete-tree assumption
 -> original body inertia -> original framed loads and gravity subtraction
 -> original reduced virtual-work acceptance -> world-origin subtree balance
 -> Fx/Fy/Mz cut pairs/root support -> immutable reduced report
```

`PlanarReactionWrench` exposes only `forceX`, `forceY`, `momentZ` (N/N m). `PlanarJointReactionWrench` and `PlanarRootSupportWrench` retain direction/identity, frame, actual world/frame reference point, time/revision and continuous temporal meaning. `PlanarTreeReactionReport` retains original system, reduced fidelity, caller topology assumption, generalized residual and both ledgers. Unrepresented transverse axes carry no physical-zero/bearing authority. References retain actual z; no cut-reference z==0 guard is invented. Output rotation must preserve XY/Z axes; a parallel translated origin does not mix these reduced quantities.

Original body-origin inertia and transformed known loads must be planar. Raw load points/couples remain complete until rotation/shift, preserving existing off-plane raw reference/transverse couple cancellation admission. Reduction occurs afterward. Original Fx/Fy/Mz pairing with original body columns accepts generalized equilibrium independently of assembled arrays. World-origin subtree sums are shifted to actual child-anchor points then rotated. Both cut signs share one point. Fixed-root support includes root's own gravity/loads; child cuts do not. Planar floating roots have no support and must satisfy reduced global balance. Nonzero generalized-only loads and unrepresented connections fail explicitly.

One separate noninline source extraction retains the original planar input in an immutable reference owner before body queries. Numerical supplier callbacks receive positive precharged prefixes, validate unchanged budget/monotonic counters on success/failure and restore known work after reset. Gravity callback admission is charged irreversibly into caller LoadWork before supplier dispatch; monotonic merge preserves caller cancellation on success/failure. Checked storage/arithmetic, body/load/edge/publication cancellation and failed-supplier work availability preserve the spatial contract's semantics. Source/results are immutable Sendable; all mutable workspace/ledgers are operation-local on Native/WASM/Embedded with original 128 KiB phase boundaries.

`BodyWrenchEvidence` identifies body/frame/reference but does not retain original inertia/source. A supplier can delegate to an actual foreign-mass system with identical metadata and alter transverse force invisible to a free X coordinate. The new planar port therefore recomputes original body inertia through builtin RigidEquationKernel under the same numerical ledger after supplier ledger acceptance, compares force/moment tolerance, and adopts the builtin value. No old spatial path changes. Gravity response similarly lacks field authority: a foreign Y field is invisible to the free X residual. Builtin original field/body/COM/mass point evaluation is compared with the supplied immutable response and adopted. Successful recovery uses three LoadWork units per gravity body (admission, supplier point, builtin original point); both evaluations and failed prefixes remain accounted. These source obligations cannot be replaced by metadata/array-length checks.

If the caller's original cancellation closure prevents merging a known opaque supplier increment, `ReactionPathError.loadLedgerMerge` retains the LoadError cause and marks failedSupplierWorkUnavailable. The caller retains its last charged prefix and original closure; unavailable supplier work is not reported as charged. Existing planar Joints admission makes anchor z==0, so actual off-plane raw loads, not fabricated off-plane snapshots, own the reachable reference-shift test.

Depends on [RigidEquations](../../Dynamics/RigidEquations/DESIGN.md) actual original physical query/input, [ArticulatedTrees](../../../Modeling/Joints/ArticulatedTrees/DESIGN.md) public topology/columns/anchors and [PassiveLaws](../../Loads/PassiveLaws/DESIGN.md) gravity point evaluation. The forthcoming planar loop recovery depends on this result and GeometricRelations allocation evidence. [MechanicsReactionPathTests](../../../../../Tests/MechanicsReactionPathTests/DESIGN.md) owns independent pendulum, subtree/root gravity, offset/framed loads, admitted off-plane raw/anchor references, residual/allocation refusal, supplier reset/cancellation and resources. Root owns actual qualification; full JT/TR completion remains open.

## Purpose and Scope
Parent: [Mechanisms](../DESIGN.md). Own continuous, physically identified tree joint and root support wrench recovery for selected JT-007 and TR-013 paths: existing spatial and reduced planar contracts plus the design-only AF26 prescribed planar root port above. No children. Complete JT/TR requirements remain owned by the root plan. Impulses, unrepresented loops, multiple-bearing allocation and mesh attribution are unavailable.

## Responsibilities and Boundaries
Recover net loads transmitted across each tree edge from original per-body Newton/Euler products minus identified external body loads. Require the caller to declare complete physical tree topology. Dynamics owns inertia/acceleration products; Loads owns gravity forces; Joints owns frame geometry. No generalized force allocation, equation solve, transmission constitutive model or accepted-state mutation.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Mechanisms](../DESIGN.md) | parent | Responsibility | Root owns registration and qualification | Excluded until source freeze |
| [RigidEquations](../../Dynamics/RigidEquations/DESIGN.md) | depends on | RigidEquationComputing.inertialWrench, original immutable input | Supplier returns world-frame original Newton/Euler force and torque about requested world point | Validate metadata and cumulative ledger; no internal arithmetic/body access |
| [ArticulatedTrees](../../../Modeling/Joints/ArticulatedTrees/DESIGN.md) | depends on | tree.joints/bodyIndex, snapshot frame/geometricColumns | Public topology and actual anchor poses | Supplier tree is breadth-first; construct parent indices through public identities |
| [PassiveLaws](../../Loads/PassiveLaws/DESIGN.md) | depends on | GravityEvaluating.point | Evaluate uniform gravity at world COM | Gradient distribution not admitted by Dynamics |
| [Core spatial](../../../Mathematics/Core/Spatial/DESIGN.md) | depends on | RigidTransform, SpatialWrench | Rotate vectors and translate explicit reference points | Never translate torque twice |
| [Tests](../../../../../Tests/MechanicsReactionPathTests/DESIGN.md) | used by | TreeReactionRecovering | Independent pendulum, subtree and framed bearing oracles | Native evidence only until root profile qualification |

## Architecture
```text
complete physical tree + immutable Dynamics input + supplied acceleration
 -> original per-body inertia at body origin
 -> subtract original framed external wrench and gravity at world COM
 -> original virtual-work residual rejection
 -> common world-origin residuals -> bottom-up subtree sums
 -> parent-on-child / child-on-parent, fixed-root support
 -> frame/reference conversion -> immutable report
```

## Contracts and Invariants
Admit spatial tree with positive velocity dimension, complete identified inertias and uniform gravity according to assembled Dynamics contract. Every nonzero generalized contribution fails because a six-axis physical allocation is nonunique. Known body loads are external to the tree edge interaction, including independently identified actuator torques; they must not duplicate the recovered edge load. Unrepresented physical connections fail explicitly. The caller's completeTree declaration is an assumption, not inferred loop completeness.

Original body-origin residual is inertialWrench minus physical external loads. Project each residual against the original body's geometric columns, sum by generalized velocity, divide by caller positive physical generalized-force scales, and accept against caller dimensionless tolerance. This uses original per-body products, not assembled M or generalized-force relabeling. A non-equilibrium acceleration fails; a support reaction cannot hide an unbalanced free joint coordinate. World-origin residual sums cancel internal subtree interactions. Parent-on-child is the subtree residual; child-on-parent is its exact negative at the same explicitly reported reference point and frame. Fixed-root support is whole-tree residual at root body origin; floating roots have no support and must satisfy six-axis global balance. Explicit temporalMeaning is instantaneousContinuousForce and fidelity is spatialRigidTreeBalance. Continuous force/torque units are N/N m; time is snapshot seconds and revision is tree revision. Output point is a torque reference, not an inferred contact location. Joint default world reference is the actual child-anchor origin; root default is root origin. Output frame may be any public snapshot frame.

## Runtime Flows
Check declaration, capacity, acceleration/scales, spatial domain and nonunique loads before allocating. Reserve retained Dynamics storage plus conservative owned scalar work/output storage with checked arithmetic. Each body receives one original inertial query, external load subtraction, gravity supplier evaluation and virtual-work projection. Before each gravity callback, charge one irreversible admission quantum to the caller LoadWork; the supplier receives that positive cumulative prefix, even when the caller entered with consumed=0. Admission and supplier point evaluation are separate logical work units; successful built-in gravity costs two LoadWork units per body. Success and failure both merge only monotonic supplier differences; supplier reset rejects with the admitted prefix retained. Reverse public body ordering aggregates child subtree sums. Independently reconstruct body balance from incoming/outgoing subtree loads before publishing and check separate force/torque tolerances. No retries or partial successful report.

## State, Ownership, and Lifecycle
Immutable Sendable input/results and protocol suppliers. Operation-local arrays and caller-owned inout NumericalWork/LoadWork; no shared mutable state, unsafe storage or target-dependent conformance/isolation. Native/WASM/Embedded have identical storage, read/mutation and release: local value arrays; synchronous operation; scope release. Returned report owns immutable result backing; callers account simultaneously retained prior reports. Suppliers receive same ledgers; Numerical budget replacement or decreasing counters restores last known pre-call ledger; Loads merging preserves the caller cancellation closure and rejects changed limits/decreasing counters and raises supplierLedgerReplaced with unavailable failed supplier work.

## Failure, Concurrency, and Constraints
Caller bounds bodies, joints, load count and numerical storage/arithmetic; LoadWork independently bounds gravity evaluations/storage. Cancellation checked at entry/body/load/edge/publication boundaries. Typed ReactionPathError retains Core, Joints, Dynamics, Loads and Numerics failures, original residual rejection and supplier work availability. Unknown supplier partial work is never claimed known. Gravity response metadata and original inertia metadata must match requested body/world point; mismatch rejects supplier evidence. Explicit unsupported markers guard unrepresented connections and nonunique generalized allocation. This layer does not infer missing physical inputs.

## Verification and Change Impact
Pendulum analytic COM acceleration/support/action-reaction; multi-body static offset loads and bearing moments; moving prescribed anchor; frame and reference conversion; floating global balance; ambiguous allocation, wrong acceleration, capacity/storage/arithmetic/cancellation/load failures and ledger replacement. Tests exercise public protocols with actual producers. Changes to Dynamics original inertia semantics, Joints geometric/reference conventions, Loads gravity or cumulative ledgers invalidate this consumer and downstream diagnostic profiles. Root performs final native/WASM/Embedded qualification after freeze.

### Frozen selected Native evidence
The isolated `.build/reaction-path-frozen` dependency/source copy exercised the physical and failed public paths with Swift 6.4 release on Native arm64 macOS27. The root review found that a supplier reset from consumed=0 could erase work; a focused red across zero/precharged prefixes and reset on success/failure reproduced it in `.build/reaction-path-ledger-red.log`. After caller-owned admission charging, `Scripts/run_with_timeout.py 90 swift test --package-path .build/reaction-path-frozen --jobs 6 --filter ReactionRecoveryTests` passed all nine tests, including four parameterized prefix/reset cases and cancellation-closure preservation, with no warnings/errors. `.build/reaction-path-ledger-green.log` owns this corrected snapshot's output (6.07 s build, nine tests passed in 0.006 s). Earlier `.build/reaction-path-native.log` evidence predates this accounting correction. This proves the selected Native paths only. Root still owns registered graph and exact Native/WASM/Embedded public composition qualification, integration and commit.

| Logical state | Native source | WASM source | Embedded source | Read/mutation/release |
|---|---|---|---|---|
| Body/subtree/generalized workspaces | Local value arrays | Identical declarations | Identical declarations | Synchronous recovery scope; no shared stored state |
| Numerical and load ledgers | Caller inout values | Identical declarations | Identical declarations | Supplier boundary validates monotonic work; caller scope owns release |
| Suppliers/results | Immutable Sendable values | Identical declarations | Identical declarations | Protocol requirements; no target conformance branch |

There are no `hasFeature(Embedded)`, `canImport(Synchronization)`, unsafe isolation or unchecked Sendable branches in this owner. WASM and Embedded execution evidence must be added by root; source identity is not runtime qualification.

### AF20 selected public profile evidence
Root executed the final unmodified Native, ordinary-WASM and Embedded-WASM compositions with all path completion witnesses and exit zero. [Exact profile evidence](../../../../../Verification/FoundationVerification/DESIGN.md#af20-selected-original-profile-qualification) owns toolchain, stack, runtime and test-snapshot qualification. This extends only the selected public paths documented there; the remaining domain and concurrency limitations above persist.
