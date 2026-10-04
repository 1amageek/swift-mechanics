# ReactionPaths

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
Parent: [Mechanisms](../DESIGN.md). Own continuous, physically identified spatial tree joint and fixed-root support wrench recovery for selected JT-007 and TR-013 bearing-load paths. No children. Complete JT/TR requirements remain owned by the root plan. Impulses, unrepresented loops, multiple-bearing allocation and mesh attribution are unavailable.

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
