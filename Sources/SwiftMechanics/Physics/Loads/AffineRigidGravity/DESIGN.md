# AffineRigidGravity

## Purpose and Scope
Parent: [Loads](../DESIGN.md). Children: none. IM.AF35.32 owns the exact continuum resultant of a supplied spatial rigid body's complete COM mass properties in a symmetric affine gravity field. The selected public contracts below are behaviorally qualified on the declared Native and portable compositions. No accepted evolution, CAD mass inference, flexible-body quadrature or general nonlinear gravity is owned here.

## Responsibilities and Boundaries
Consume the immutable public `KinematicSnapshot` produced by `CompiledMechanicalModel.evaluate` or `TreeKinematicsEvaluator.evaluate`, identified `RigidBodyInertia`, and the original `AffineGravity`. The caller supplies an exact sampling time/revision and declares the gradient time derivative. Preserve the complete supplied tensor and original field; do not manufacture a ModelStamp or certify an unrelated inertia catalog. The result retains its exact original input including snapshot backing. Acceleration is neither needed nor certified by this instantaneous force/power query.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Loads](../DESIGN.md) | parent | Load authority boundary | Standalone constitutive law | Root owns registration |
| [PassiveLaws](../PassiveLaws/DESIGN.md) | depends on | AffineGravity, GravityEvaluating point force/potential/explicit rate | Qualified original COM point term | Symmetric G, no Gdot contract |
| [ForcePorts](../ForcePorts/DESIGN.md) | depends on | LoadWork and LoadError | Cumulative bounded work and cancellation | Fixed logical accounting is not physical allocator measurement |
| [Inertia](../../../Modeling/Model/Inertia/DESIGN.md) | depends on | Complete MassProperties3D | Supplied physical COM tensor | Original tolerance admission can admit a slightly indefinite second moment; this law refuses it without projection |
| [ArticulatedTrees](../../../Modeling/Joints/ArticulatedTrees/DESIGN.md) | depends on | Snapshot, world body-origin motion and prescribed drift | Original instantaneous source | No fabricated snapshot constructor |
| [CompilationRecords](../../../Modeling/Compiler/CompilationRecords/DESIGN.md) | coordinates with | CompiledMechanicalModel.evaluate | Original compiled-state producer | The load does not reproduce compiler validation or publish ModelStamp authority |
| [RigidEquations](../../Dynamics/RigidEquations/DESIGN.md) | used by | BodyWrenchContribution and public assembly | Explicit world body-origin wrench path | Its gravity parameter still refuses nonzero gradient; its wrench path has no explicit potential-rate field |

## Architecture
```text
qualified compiled/tree evaluator -> immutable snapshot ----+
complete identified mass/COM tensor ------------------------+-> source/frame/time admission
original symmetric AffineGravity + explicit Gdot=0 ---------+       |
                                                                  v
original point gravity at COM + continuum second moment -> body-origin wrench
                                                                  |
                                                   original power/rate residuals
                                                                  |
                                              immutable response retaining source
                                                                  |
                              static field + declared exclusive gravity ownership
                                                                  v
                         BodyWrenchContribution -> original JT and prescribed-power assembly
```

## Contracts and Invariants
All values use SI: positions m, mass kg, COM inertia and second mass moment kg m^2, G s^-2, Gdot s^-3, forces N, torques N m, energies J and rates W. Body-to-world rotation R is active: `RigidTransform` maps source body coordinates into destination world coordinates. Snapshot linear velocity is the geometric derivative at the body origin in world axes, not an origin-shifted spatial algebra field. Angular velocity is world angular velocity. Inertia is expressed in the identified body frame about its COM. The world frame must exactly equal the field frame. Sampling time and revision must exactly match the immutable snapshot. Only spatial bodies are admitted; a planar tensor is not completed with invented transverse moments.

For body-relative COM displacement r, `I = integral ((r dot r) Id - r r^T) dm`. Consequently `Q = integral r r^T dm = tr(I)/2 Id - I`. This relation and active tensor rotation follow the [MIT inertia tensor lecture](https://ocw.mit.edu/courses/16-07-dynamics-fall-2009/dd277ec654440f4c2b5b07d6c286c3fd_MIT16_07F09_Lec26.pdf). Let x be world COM, Qw=R Q R^T, field g=a+Gx, and G symmetric. Directly integrating dm*g gives:

| Returned quantity | Original continuum equation |
|---|---|
| Force | F=m(a+Gx), since integral r dm=0 |
| COM torque | tau=integral r cross (G r) dm; [tau]cross=G Qw-Qw G^T |
| Potential | U=-m(a dot x+x dot Gx/2)-tr(G Qw)/2 |
| Explicit potential rate | partial_t U=-m adot dot x, for the explicitly declared Gdot=0 |
| Moment rate | Qdot=Omega Qw-Qw Omega, Omega=[omega]cross |
| Total potential rate | Udot=-m(adot dot x+a dot vCOM+vCOM dot Gx)-tr(G Qdot)/2 |
| Mechanical power | P=F dot vCOM+tau dot omega |
| Body-origin torque | tauO=tau+(x-pO) cross F |

The gradient torque integral is also the general local gravity-gradient formulation in [NASA CR-188243, section 8.2](https://ntrs.nasa.gov/api/citations/19940025085/downloads/19940025085.pdf). Here an affine field is exact over the supplied mass distribution, rather than a truncation of a nonlinear field. Its complete second moment suffices; no samples, guessed radii or principal-axis assumption are used.

Every successful response checks both `P_origin-P_COM` and `Udot+P-partial_t U` against the caller's explicit W-valued tolerance. Rate evaluation uses the original continuum derivatives, not `Udot=-P+partial_t U` as a constructed identity. The response exposes Q/Qw/Qdot, original force-position derivative mG, COM torque, second-moment potential, both powers and residuals for independent verification. World covariance holds for a constant proper rotation of axes; translations require the corresponding transformed affine origin coefficient and change the declared potential zero. Time-varying coordinate frames are outside this stationary-world field contract.

The computed normalized principal minors of Q must be nonnegative. No diagonal shift, regularization, projection or tensor modification is introduced. Floating-point overflow, a zero computed second-moment scale, or a negative computed minor is an explicit failure. IEEE arithmetic and its roundoff remain part of the numerical contract; exact rational certification is not claimed. This selected strict domain can refuse near-boundary properties that the original inertia constructor admitted with its physicality tolerance.

## Runtime Flows
Admission bounds body count and each identity's UTF8 bytes before lookup/comparison, charges each visited byte, and checks time/revision/world/body frame. Reserve fixed 256 logical scalar slots before arithmetic. Charge 1024 logical units for the bounded matrix/vector algorithm and each gravity call separately. The fixed qualified original GravityEvaluator consumes the same exclusive ledger, and its typed failure propagates without retry. Only its non-generic public GravityEvaluating requirement is invoked. Arbitrary replacement point suppliers are outside this service's admitted dependency contract. Its force, potential and explicit rate are independently compared with original COM equations before use. Publication checks cancellation again.

`staticBodyWrench` requires `otherGravityAppliedToBody=false` as an explicit caller attestation and both Gdot=0 and adot=0. It returns the original world body-origin wrench, channel applied, complete U and zero dissipated power. Pass it as `RigidDynamicsInput.bodyWrenches` with the separately owned gravity for this body absent; the qualified kernel shifts about the original body origin, applies the original geometric-column transpose and splits actual/prescribed/virtual power. The consumer must assemble against the retained original snapshot and inertia inventory: BodyWrenchContribution carries no sampling source/time, so it cannot enforce subsequent reuse against a different state. There is no gravity-specific force channel. Its existing `gravity` parameter is unchanged and still refuses nonzero G. Nonzero adot may be evaluated by this standalone law but its body-wrench bridge refuses: existing BodyWrenchContribution cannot communicate partial_t U. A caller may read the response's force/power independently, but no complete kernel energy accounting or accepted state follows from that read.

## State, Ownership, and Lifecycle
Input, policy and result are immutable Sendable values. Snapshot arrays retain their original immutable backing; no new body arrays or copied catalogs are allocated. Only local fixed-size values and caller-exclusive inout LoadWork mutate. The same source, ownership, protocol requirements and conformance apply on Native, ordinary WASM and Embedded. There are no shared caches, C/unsafe boundaries, synchronization substitutions or platform branches. No allocation/copy performance claim is made.

## Failure, Concurrency, and Constraints
The typed failure preserves CoreError, JointError, LoadError and DynamicsError where supplied. It distinguishes stale source, frame mismatch, missing spatial domain, nonphysical moment, invalid supplier output, duplicate gravity ownership, residual failure and unsupported Gdot/temporal bridge. Immediately marked callable unsupported branches fail before success. The selected original point evaluator charges before its arithmetic, never replaces the ledger and exposes every typed failure with completed work retained. No arbitrary callback is admitted into that supplier boundary. The original cancellation callback remains authoritative. No retries, energy defaults or fallback law occur. Bounds cover declared logical work/storage and metadata; physical stack and allocator peaks remain unmeasured until profile execution.

## Verification and Change Impact
The independent qualification owner integrates a finite point distribution with the same complete moments, check asymmetric supplied COM tensors, rotated covariance, offcenter origin transport, finite-difference translation/rotation/time potential derivatives, gravity-gradient analytic torque, actual original dynamics JT/prescribed power through the static bridge, and wrong time/revision/frame, indefinite Q, temporal gradient/bridge, duplicate ownership, original supplier failure, overflow, capacity and cancellation. Native/ordinary WASM/Embedded compile/link/runtime proofs are separate. Source review is one comprehensive pass and one finding-limited repair review; root owns registration, integration and commits. Changes to source conventions, inertia, point gravity or body-wrench time fields invalidate this child and affected consumers. No Runtime, URDF, full joint-family or complete FL-001 closure is inferred.

### Source review boundary
The single comprehensive original-source review checked continuum signs, active R/COM transport, independently differentiated power, actual qualified point supplier and kernel wrench consumption, immutable ownership, three immediate incomplete-domain markers, and work/metadata/cancel paths. The finding-limited correction clarified the bridge consumer's source/time obligation and the floating-point principal-minor domain; it changed no producer or numerical oracle. The only mutable source variable is the exclusively local metadata byte counter. Native/ordinary/Embedded all share the same immutable records, protocol requirements and exclusive LoadWork; no platform branches, unsafe state, pointers, actors or shared mutable storage are introduced. At initial source freeze no behavioral or profile qualification had been executed; the handoff below owns the subsequent selected qualification boundary.

### Selected Native qualification handoff
The [independent verification owner](../../../../../Verification/AffineRigidGravityQualification/DESIGN.md#executed-selected-native-evidence) records the exact2361 producer/object/module bindings, real compiled point-distribution fixtures, first fixture geometry failure and causal correction, selected eight-test evidence and eight final public witnesses. Production8 was unchanged. The selected Native force/moment/potential/rate, source/domain/work/cancel and original static kernel JT/prescribed-power paths now have executed evidence. At the first Native handoff, ordinary WASM, Embedded WASM and canonical registration were still unverified. The executed boundary below supersedes that phase status; full FL-001/Runtime closure remains open. Signing/release capabilities are not inferred from that mechanical evidence.

### Executed selected registration boundary
The [qualification owner](../../../../../Verification/AffineRigidGravityQualification/DESIGN.md#executed-selected-registration) owns final byte-bound Native and portable evidence. The registered canonical1712 producer keeps macOS13; all eight final cases plus twenty-three retained regressions passed in one test binary. Ordinary and Embedded final fixtures each passed all eight witnesses under the original131072-byte guard before raw execution; complete decoded stack-write counts38360/2435 equal inserted guards. Selected continuum resultants, source/domain/work/cancellation and static original-kernel JT/prescribed power are qualified. NonzeroGdot, temporal body-wrench energy publication, planar completion, automatic CAD properties and Runtime evolution remain outside this child. No full FL-001/DN-002 requirement closure follows from selected service registration.
