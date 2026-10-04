# Reaction path behavioral evidence

## AF26 prescribed planar root proof contract

### Purpose and Scope

This test target belongs to the [package](../../DESIGN.md) and has no children. This target contains source for the selected additive prescribed planar root contract. Actual isolated Native execution is recorded below; canonical integration and public profile proof remain root-owned. Existing spatial/planar tests and their qualified evidence remain unchanged.

### Responsibilities and Boundaries

This target owns root support/cut correspondence; Joints owns law generation, ConstrainedDynamics owns original full-mass effort acceptance, and root owns public profile/build/commit evidence. Fixture values and supplier wrappers are test-owned and are never production physical authorities.

### Related Designs

| Design | Relationship | Contract used | Caution |
|---|---|---|---|
| [ReactionPaths](../../Sources/SwiftMechanics/Physics/Mechanisms/ReactionPaths/DESIGN.md#af26-additive-prescribed-planar-root-contract) | verifies | New public prescribed-root recovery, signs/source/ledgers | Selected complete reduced planar tree only |
| [ConstrainedDynamics](../../Sources/SwiftMechanics/Physics/Mechanisms/ConstrainedDynamics/DESIGN.md) | depends on | Original constrained root solve and sealed PhysicalConstrainedMotion | Test suppliers may produce genuine wrong evidence; recovery must reject it independently |
| [Package](../../DESIGN.md) | parent | Frozen qualification ownership | Root owns original profiles and commits |

### Architecture

```text
actual compiled prescribed planar root + law-bound state + original MassProperties2D/loads
 -> genuine original full-mass constrained solve
 -> new public protocol recovery
 -> independent scalar force/moment/effort and refusal checks
```

New files are `PlanarPrescribedRootReactionFixtures.swift`, `PlanarPrescribedRootReactionPhysicalTests.swift`, `PlanarPrescribedRootReactionFailureTests.swift`, `PlanarPrescribedRootReactionLedgerTests.swift`, and separate primary-type supplier helpers `PlanarPrescribedRootForeignEquations.swift` and `PlanarPrescribedRootGravitySupplier.swift`. Fixture model/source/assembly/solve/recover phases use actual public protocols and distinct noninline lifetime boundaries. Tests are named by the new contract and use one-minute declaration deadlines; root sets an external timeout for the focused filters `PlanarPrescribedRootReactionPhysicalTests`, `PlanarPrescribedRootReactionFailureTests`, `PlanarPrescribedRootReactionLedgerTests`. The frozen source has 15 declarations in three suites; two two-by-two argument declarations give 21 expanded cases. Owner isolated execution is complete below; canonical integration and profiles remain root-owned.

### Contracts and Invariants

| Independent physical oracle | Actual owner and expected result | Counterexample detected |
|---|---|---|
| Offset COM root: m=2, COM=(.4,-.3), Iz=5; initial Rz(.4); vx=.4+.3t, vy=-.2+.2t, omega=.2+.3t, alpha=.3 | Let theta=.4+.2t+.15t² and r=Rz(theta)COM. COM acceleration is (.3-alpha*r.y-omega²*r.x, .2+alpha*r.x-omega²*r.y). Support F=2*aCOM, Mz=5*alpha+r.x*Fy-r.y*Fx. P effort is [Fx,Fy,Mz] at root origin; no child cut exists | Relabeled effort without actual body force; omitted centripetal/COM moment; foreign inertia with matching metadata |
| Translating root with X-prismatic child: masses root1/child2, both COM at origins; child origin x=2, known root ay=1, other root rates/accelerations zero; D acceleration=0; no gravity/loads | Actual child-anchor cut parent-on-child=(Fx0,Fy2,Mz0); root-origin support=(0,3,4); P effort=[0,3,4], D residual0. Child and root independent inertia owners are explicit | Only child-body support; missing offset moment; hiding free-X residual with root support |
| Same translating tree with gravity gY=-10 | Child cut Fy22; root support Fy33 and Mz44. Root body's independent weight appears only in support | Double-counted/missing root gravity; foreign gravity invisible to free X |
| Actual translated/rotated output frame and physically identified offset load/couple | Independently shift full wrench to reported point, then rotate Fx/Fy/Mz; both signs use one actual world point. Root wrench power equals P effort dot actual base velocity | Missing moment shift, sign/reference disagreement, rotation-only conversion |
| Raw force at actual off-plane reference with cancelling transverse couple | Full world shift makes admitted body-origin load planar before reduction; scalar in-plane root/cut balance remains correct | Premature raw reduction or invented strict reference-z refusal |

The offset-COM scalar oracle is independent of production columns, mass matrices, body-wrench diagnostics and supplied report values. The existing `MechanicsNonlinearMechanismTests/PrescribedRootOracle.swift` establishes the algebraic fixture pattern, but this owner supplies its own scalar assertions without importing another test target. Genuine motion comes from `PrescribedRootMechanismSolving` using actual original source and nonunit normalization; row multipliers must scale while physical effort/wrenches remain unchanged. Root power correspondence is a check, not a substitute for force or moment acceptance.

### Failure, Concurrency, and Constraints

| Failure/authority fixture | Required behavior |
|---|---|
| Original law/state/source time, layout, revision, frames, root columns or coordinateRate changed | Refuse stale source before publication, with actual canonical original comparison |
| Foreign sealed motion system against original constraint, changed mass/inertia/body loads/gravity source | Refuse original association or invalid supplier evidence; same IDs and shape cannot establish source authority |
| Genuine different original root normalization/row IDs/constraint supplied against accepted motion | Refuse original row/layout/reaction mismatch; use actual producer outputs rather than fabricating sealed ConstrainedMotion |
| Root-only actual solver uses an injected original-force query delegated to an actual foreign physical system, while returning genuine sealed motion bound to the original system | Canonical original P force/effort acceptance refuses the resulting wrong root multipliers; no sealed value is fabricated and synthetic root mu cannot be adopted as body load |
| Actual descendant solver accepts nonzero dynamic-coordinate drive, while recovery declares originalDrive=zeros against the same source | Original D generalized residual failure; root support cannot absorb that undeclared drive |
| Impulse result, fixed/spatial/free root, missing compiled prescribed authority, any original geometry row including structural-zero row, named prescribed anchor | Exact unsupported temporal/support failure; preserve original rows instead of deleting them |
| Nonzero explicit drive or original generalized-only contribution; incomplete topology | unallocatableGeneralizedLoad or unrepresentedConnections |
| Injected original query delegates to actual foreign mass under same body/frame/reference; returns success/failure after reset | Builtin original recomputation or supplierLedgerReplaced; irreversible caller prefix retained |
| Gravity performs actual point work then resets zero/precharged ledger on success/failure | supplierLedgerReplaced; original cancellation closure and known admission prefix preserved |
| Original cancellation occurs while opaque gravity increments are merged | loadLedgerMerge(cancelled), unavailable marker and last charged known prefix; no partial success |
| Capacity/storage/operation overflow or exhaustion, cancellation at operation/phase/publication boundary, original supplier failure with valid ledger | Typed cause with retained known work; report never published |

Successful gravity paths independently assert three units per original body. Numerical callback tests assert positive pre-admission and monotonic known work on both success/failure; exact opaque unknown work is not invented. Helpers keep all work/source values local. Any cancellation flag uses the same `Synchronization.Mutex` declaration/read/mutation on every target, with actual platform availability guarded in the Native tests. No target-specific raw state or unchecked Sendable is introduced.

### Verification and Change Impact

One owned source review checked actual producer fixtures, independent scalar assertions, typed helper calls, callback reset/failure/cancellation and common state ownership. Concrete compiler/runtime findings receive only a targeted repair/recheck. The owner executed the actual isolated Native target; root independently validates the canonical graph and public protocol path in unchanged original Native/WASM/Embedded artifacts and the 128 KiB guards. Full prescribed-root loops, spatial support, bearing splits and other IM16 domains remain open rather than expanding this suite.

### AF26 isolated Native qualification

[ReactionPaths execution evidence](../../Sources/SwiftMechanics/Physics/Mechanisms/ReactionPaths/DESIGN.md#af26-isolated-owner-native-execution) owns the exact command, frozen baseline, compiler/host, logs and copy-only test-registration reduction. The owner actually ran all 15 declarations in three suites with 21 expanded cases, exit zero (42.97-second build, 0.023-second test run). No owned compiler or behavior finding required a source repair. All independent physical and refusal/supplier-work assertions passed. The reduced graph retained this exact testTarget and unchanged production/executable/dependency/flag paths; the workspace manifest was not changed. Source byte identity and digests are recorded in `.build/af26-support-freeze.json`. This is isolated Native evidence, not canonical full-graph integration, public WASM/Embedded execution or a 128 KiB lifetime qualification; those remain root-owned.

## AF25 reduced planar evidence owner
`PlanarReactionRecoveryTests` uses actual BodyRecord2D/MassProperties2D and PhysicalRigidEquationComputing. Independent pendulum, distinct root/child gravity and slider offset/frame rotation check Fx/Fy/Mz and retained points. Raw off-plane reference/couple cancellation, wrong acceleration/generalized allocation, malformed supplier evidence, zero/precharged gravity reset success/failure, cancellation preservation, numerical reset/resource/cancellation and floating support absence exercise the contract. Existing planar Joints admission requires anchor poses with z==0; no fabricated off-plane snapshot is used as evidence. Existing spatial tests remain unchanged. Owner: [ReactionPaths](../../Sources/SwiftMechanics/Physics/Mechanisms/ReactionPaths/DESIGN.md#af25-additive-reduced-planar-recovery). Root owns actual execution after freeze.

| Actual lower witness | Independent expectation |
|---|---|
| Pendulum m=2, COM X=1, Iz=4, omega=1, alpha=-10/3 | Hinge (-2,40/3,0); root (-2,70/3,0), reported axes Fx/Fy/Mz |
| Two serial X sliders, masses 2/3, first body Rz(pi/2), second X=2; identified world force (10,5) at world Y | Absolute accelerations 5/0; first cut (0,45,70), second (0,30,0), root (0,55,70); shifted and rotated real points |
| Original raw force +10X at world Z=1 and couple -10My | Full shifted transverse couple cancels; hinge (-12,40/3,0), root (-12,70/3,0) |
| Original X slider, prescribed +1Y acceleration, foreign mass 4 replacing mass 2 | Same IDs/frame/reference, unchanged zero X generalized projection, physical Fy 4 instead of 2; invalidSupplierEvidence |
| Same-frame gravity -20Y replacing original -10Y | X generalized projection stays zero; builtin original gravity rejects foreign response after exactly 3 charged units |
| Actual point work followed by zero/precharged ledger reset, success and failure | supplierLedgerReplaced; irreversible admission prefix and original cancellation closure retained |
| Actual point succeeds and then cancels original caller during merge | loadLedgerMerge(cancelled), unavailable marker, admission-only known prefix |

The test helper cancellation flag owns a single Synchronization.Mutex<Bool> with common storage/read/mutation for every target. Its macOS 15 availability is guarded in the test; there is no Embedded-specific state replacement. Remaining fixture arrays and work values are operation-local. Native deadline is one minute per declaration, with the external timeout owned by root. The suite has 11 declarations and 15 parameter-expanded cases.

Owner: [ReactionPaths](../../Sources/SwiftMechanics/Physics/Mechanisms/ReactionPaths/DESIGN.md). Public TreeReactionRecovering executes original Dynamics Newton/Euler and actual Loads/Joints paths.

| Oracle | Body/load owner | Rejected counterexample |
|---|---|---|
| Pendulum analytic F=m*(alpha cross r + omega cross omega cross r)-m*g and T=I*alpha+r cross F | Child body only for hinge; fixed root's independent weight included only in root support | Generalized torque labeled as six-axis support; doubled root weight |
| Vertical static two-link subtree force and offset transverse-load moment | Distinct first/second masses and physical force point | Only child-body balance instead of whole subtree; missing moment shift |
| Rotated frame and translated joint anchor | Actual public snapshot poses and same world reference for both signs | Rotation-only torque or inconsistent action/reaction reference |
| Floating body original free dynamics | Whole free tree; no support owner | Invented support hiding acceleration error |
| Failed paths and ledgers | Caller limits/cancellation; immutable suppliers | Report after ambiguous loads, wrong acceleration, exhausted resources or erased work; zero/precharged callback prefix with reset on both success/failure; original cancellation closure retained |

Native focused tests have deadlines through Scripts/run_with_timeout.py; root owns frozen-source registration and Native/WASM/Embedded public probes. Test fixture is owned independently here; no production source uses it. All mutable test data is local. Injected suppliers deliberately replace ledgers; they are failure oracles, never accepted physical producers.

### AF25 lower Native qualification

The frozen source executed 20 declarations in two suites, including all eleven PlanarReactionRecovery declarations/fifteen expanded cases. Exact Swift 6.4.0 release/macOS 27 arm64, `.build/ar01-native`, `-j 4`, and a 240-second external timeout were used. Logs: `.build/af25-lower-native-tests.log` and the allocation-only `.build/af25-allocation-native-recheck.log`. Original production did not change during test-helper corrections. Source/profile composition is canonical in [FoundationVerification](../../Verification/FoundationVerification/DESIGN.md#af25-lower-integrated-qualification); full upper/root/loop domains remain separate.

### AF26 finding-only lifetime preservation execution

The consumer lifetime correction is defined by the [production contract](../../Sources/SwiftMechanics/Physics/Mechanisms/ReactionPaths/DESIGN.md#af26-original-128-kib-lifetime-correction). Existing independent tests were unchanged. With only the owned production/test directories overlaid onto `.build/af26-independent-support`, the same fixed-toolchain timeout-wrapped focused command passed all 15 declarations in three suites (21 expanded cases), exit zero, build 10.61 seconds and runtime 0.008 seconds. `.build/af26-support-lifetime-native-focused.log` and `.build/af26-support-lifetime-freeze.json` own this frozen snapshot's evidence. Copy-only single-test-target registration remains unchanged; workspace manifest and other sources were untouched. This is isolated Native behavior preservation, not original WASM/Embedded stack qualification; root owns the actual 128 KiB guard executions.
