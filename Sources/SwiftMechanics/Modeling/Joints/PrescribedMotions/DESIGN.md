# PrescribedMotions

## Purpose and Scope
Parent: [Joints](../DESIGN.md). No children. AF23 component owning immutable identified analytic relative frame trajectories and mathematically valid pose/velocity/acceleration samples at a requested physical time. Production and dedicated source tests are implemented; execution qualification is root-owned and pending this frozen handoff.

AF26 is a design-only additive lower handoff for harmonic and C2 piecewise trajectories. The contracts below are proposed production interfaces, not declarations or execution evidence. They do not extend the qualified old trajectory domain until their own lower and consumer behavior is executed. Actual discontinuity events remain outside the selected domain and SPEC KI-006 remains open for that requirement.

## Responsibilities and Boundaries
Own finite coefficients/axis/rotation/domain validity, bounded canonical law metadata, sampling requirements, independently recomputed original law samples and mathematical failed-work accounting. ArticulatedTrees owns PrescribedAnchorState/FrameMotion and actual tree composition. Geometry/upper own binding to actual compiled model, parent frame/complete required anchor inventory/body modes/coordinate authority and physical closure. Dynamics owns inertia/energy/work. Runtime/history/checkpoint/cancellation control have no dependency in this component. The programme does not retain CompiledMechanicalModel or ModelStamp; Joints-to-Compiler dependency would be a backedge. A complete motion program is not by itself proof of a force-driven domain or full prescribed floating-root partition.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Joints](../DESIGN.md) | parent | Motion conventions and component index | Mathematical kinematics owner | Root owns parent index |
| [ArticulatedTrees](../ArticulatedTrees/DESIGN.md) | depends on | PrescribedAnchorState, JointAnchor, FrameMotion | Identified relative motion input/output | Actual required frame/time set is tree authority |
| [KinematicAlgebra](../KinematicAlgebra/DESIGN.md) | depends on | FrameMotion convention/composition | Parent axes and moving-origin derivatives | Do not invent world-frame substitutions |
| [Core geometry](../../../Mathematics/Core/Geometry/DESIGN.md) | depends on | finite vector/pose/quaternion operations | Analytic scalar/vector mathematics | Raw initial rotation must remain validated, not silently normalized |
| [LinearAlgebra](../../../Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | NumericalWork and bounded arithmetic | Explicit mathematical resource contract | No reverse Joints dependency |
| [GeometricRelations](../../../Physics/Constraints/GeometricRelations/DESIGN.md) | used by | immutable program, sampling and original verification | Consumer binding law to actual model/frame geometry | Geometry does not become law authority |
| [NonlinearEvolution](../../../Physics/Mechanisms/NonlinearEvolution/DESIGN.md) | used by | actual-time sampling requirement | Stage sampling and physical/history association | No Runtime/history dependency back into motion |

## Architecture
```text
bounded immutable identified coefficients + reference relative pose + interval
 -> mathematical admission + canonical law metadata
 -> explicit-time analytic sample (pose, first derivative, second derivative)
 -> independent original law verification -> canonical PrescribedAnchorState array
 -> actual tree / geometry / physical evolution consumers
```

## Contracts and Invariants
### AF25 prescribed-base mathematical authority
The additive `PrescribedBaseMotionProgram(law:layout:policy:work:)` owns one existing analytic law and a nonfixed BaseLayout, separate from the anchor inventory. Its frame is the root frame and parentFrame is the world frame; actual compiled root identity and coordinate authority remain consumer checks. No Compiler dependency is introduced. Canonical metadata `analytic-base-v1` includes the full original law, root chart and planar angle branch. Planar admission requires exact XY translation coefficients, exact zero quaternion x/y and axis +z or -z. The initial planar angle is the sign-invariant principal rotation-vector z component; subsequent angles retain the unwrapped analytic increment. Spatial q retains the original pinned quaternion bits at reference time; v angular and a angular are R-inverse times the original world omega and alpha. For this fixed-world-axis law the body-axis transport term omegaBody cross omegaBody is zero. qdot uses the public quaternion bodyRate operation, never qdot=v.

`PrescribedBaseMotionSampling.sampleBase(_:time:policy:work:)` is a non-generic Sendable protocol requirement. `AnalyticPrescribedBaseMotionSampler` returns a sealed immutable `PrescribedBaseMotionSample` with metadata, layout, frame, worldFrame, time, q, v, a, coordinateRate and original FrameMotion. External suppliers may return actual producer values but cannot construct unchecked samples. `OriginalPrescribedBaseMotionAcceptance.validated(_:program:time:policy:work:)` directly recomputes the original law and compares every field bit exactly. Its `sealedBaseMotion(_:time:policy:sampler:work:)` performs the original computation first, reserves the caller boundary and seeds a separate remaining supplier ledger before the opaque witness. On both success and failure it validates unchanged budget and monotone operations/iterations/storage, absorbs the known prefix, then propagates error/cancellation; a reset restores the seed as the known prefix and reports unavailable supplier work. Comparison and final cancellation precede publication. A supplier cannot spend work reserved for original verification because that work executes before its allowance is formed.

Program metadata and scalar storage bounds are checked before metadata construction. Sampling reserves bounded scalar workspace and declared arithmetic before mathematics/output allocation. Immutable reference phase contexts keep original evidence off the deepest callback stack. There is no mutable shared state or target-specific branch. Root-only samples are ordinary nonempty planar/spatial base coordinates, not anchor samples; periodic and piecewise laws are outside this analytic operation.

Immutable Sendable `AnalyticPrescribedMotion` records declare anchor frame and relative parent frame IDs, reference time t0, pinned initial relative pose (p0,R0), parent-axis translation rate u0/acceleration c, fixed unit parent-frame rotation axis k, angular rate w0/angular acceleration alpha, and a finite validity interval. Duplicate frame IDs, non-frame identifiers, incompatible axes or invalid raw rotations are rejected. For dt=t-t0, the law is:

```text
p(t) = p0 + u0*dt + c*dt^2/2       pdot(t)=u0+c*dt       pddot(t)=c
R(t) = Rot(k, w0*dt+alpha*dt^2/2) * R0
omega(t)=k*(w0+alpha*dt)           angularAcceleration(t)=k*alpha
```

Translation derivatives are at the relative frame origin in parent axes, as required by FrameMotion. A fixed parent-frame axis makes the displayed angular derivative exact. World motion/Coriolis transport belongs to the existing FrameMotionComposer. At t0 the pinned pose remains exact; no identity pose or zero derivative replaces input. Finite coefficient/time products and quaternion/vector results are checked at every requested time. Time outside the declared interval fails rather than clamps/extrapolates.

`PrescribedMotionProgram` stores bounded canonical frame-ordered records and metadata `analytic-anchor-v1`, including both declared frame IDs, every original coefficient/reference pose/raw rotation/t0, law kind and validity interval. It owns no mutable callback state, model ID authority or Runtime state. Programme capacity includes record/sample count, identifier UTF-8 bytes, metadata bytes, scalar workspace and checked arithmetic before allocation. Consumers independently verify the declared parent frame and complete required frame set against the actual model/tree; a mathematically valid partial program cannot stand in for a complete model sample set.

`PrescribedMotionSampling: Sendable` declares a non-generic requirement `sample(program, time, policy, work)` returning immutable `PrescribedMotionSample` with canonical metadata/time and complete identified samples through typed PrescribedMotionError. All existential operations are witnesses. Builtin analytic sampling is concrete mathematical implementation. Sealed `OriginalPrescribedMotionAcceptance` recomputes the immutable original law, validates metadata, exact time/frame/order/raw pose/velocity/acceleration and returns original samples as authority. Supplier diagnostics, matching IDs, copied mutable callbacks and within-tolerance changed law values cannot alter the imposed motion. Exact model.makeState admission remains a separate consumer requirement.

## Runtime Flows
This section describes synchronous mathematical operations only. Consumer reserves irreversible admission and a seeded remaining NumericalWork before opaque sampler invocation. Both success and failure validate supplier budget/counters and absorb known prefix before propagation. Original verification is a bounded direct builtin operation. A policy may expose a Sendable cancellation predicate; there is no RuntimeStepControl, Task/history/clock dependency. Requested time is an explicit input, never a hidden wall clock.

## State, Ownership, and Lifecycle
All records/programs/samples/policies are immutable Sendable. Work and output buffers are exclusive operation locals. No shared mutable cache, target branch, unsafe storage or synchronization exception exists. Output ownership retains immutable sample backing; consumer construction and publication retain complete arrays by value ownership.

## Failure, Concurrency, and Constraints
Typed PrescribedMotionError distinguishes invalid coefficient/axis/frame/law, shape/time/domain/metadata/source, nonfinite arithmetic, capacity, cancellation and supplier ledger reset/unavailable work; nested mathematical failures preserve meaning. Every output/sample/identifier bound passes before traversal/allocation/callback. Success and failure cannot reset seeded budget/counters. Unknown failed opaque work stops and cannot be retried under a smaller step. An analytic interval limit is mathematical correctness, not an estimated operational default.

## Verification and Change Impact
AF25 [PrescribedBaseMotionTests](../../../../../Tests/MechanicsJointsTests/PrescribedBaseMotionTests.swift) owns independent planar unwrapped-angle and noncommuting spatial quaternion/rate/acceleration checks, reference quaternion bits, explicit time/chart/frame/plane/canonical-law refusal, wrong real supplier source, seeded reset-success/reset-failure, known failure prefix, late cancellation and work/storage bounds. The test owner does not claim force, COM, energy or replay authority. Root owns registered Native and original three-profile qualification; no mathematical proof generalizes to unrun mechanical composition.

Dedicated mathematical tests are [PrescribedMotionTests](../../../../../Tests/MechanicsJointsTests/PrescribedMotionTests.swift). Component registration and exact-profile proof remain root-owned. Independent analytic translation and fixed-axis quadratic rotation oracles verify pose, velocity and acceleration at t0 and nonzero times, nonidentity pinned rotation/translation, parent-axis conventions, exact interval boundary, canonical metadata and bad coefficient/axis/time/frame/capacity cases. Injected sampler wrong-law/time/source/reset-success/reset-failure/late-cancel tests must exercise the actual supplier and original verifier paths. Consumers additionally require actual tree/geometry/dynamics/Runtime proofs; mathematical tests never qualify moving-base mechanical work, checkpoint replay, or fully prescribed floating-root partition. Motion metadata or derivative changes invalidate those upper assumptions and require their affected behavioral evidence to be renewed.

## AF26 Additive Lower Trajectory Contract

### Verified baseline and compatibility boundary
`AnalyticMotionEvaluation.motion` executes only the original quadratic translation and fixed-parent-axis quadratic angle. `PrescribedMotionProgram.motions` is `[AnalyticPrescribedMotion]`; `PrescribedBaseMotionProgram.law` is `AnalyticPrescribedMotion`. Geometric anchor binding reads the actual frame/parent inventory; root binding reads the law frame/domain and recomputes canonical q/v/a. Nonlinear consumers use both original ports and embed the complete program metadata in their equation chart/history authority. Those public getter types, coefficient meanings, constructors, sampler sample bits, metadata encodings and signatures remain unchanged. In particular an old constant acceleration field must not become a harmonic law's reference-time derivative. Reaction consumers of the frozen old root binding/program/sample remain valid.

The new authority uses distinct records and explicitly tagged input. No empty legacy inventory, fabricated quadratic law, arbitrary point callback or mutable phase is used to represent a new trajectory. A tagged quadratic trajectory may delegate to the original mathematics, but an old program still emits its old signature; a new trajectory program emits the new complete schema even when its tag is quadratic.

### Immutable records and mathematical domain
Proposed records are `HarmonicPrescribedMotion`, `PiecewisePrescribedMotion`, `PrescribedTrajectory`, `PrescribedTrajectoryProgram`, `PrescribedBaseTrajectoryProgram`, `PrescribedTrajectoryPolicy`, `PrescribedMotionJet`, `PrescribedMotionSegment` and `PrescribedTrajectoryDerivative`. Each owns one file and contains only immutable Sendable values. The tagged enum has `.quadratic(AnalyticPrescribedMotion)`, `.harmonic(HarmonicPrescribedMotion)` and `.piecewise(PiecewisePrescribedMotion)`; segments contain endpoint jets, not nested trajectory enums.

All laws bind one identified frame, parent frame, validated pinned relative pose, fixed unit parent-frame rotation axis and finite physical-time domain. The world/compiled-root authority and complete admitted anchor set remain consumers' responsibilities. Reference rotations are validated without silently normalizing or choosing a different quaternion sign. Translation derivatives are measured at the relative moving origin in parent axes. A scalar angle acts as `Rot(axis, angleIncrement) * initialRotation`; world transport and Coriolis composition remain the existing FrameMotion contract.

Harmonic records retain finite positive angular frequency `frequency`, finite `phase`, vector sine/cosine amplitudes and scalar angular sine/cosine amplitudes, plus reference time and inclusive minimum/maximum times containing it. With `d=t-referenceTime`, `x=phase+frequency*d`, and `x0=phase`:

```text
p = p0 + As*(sin(x)-sin(x0)) + Ac*(cos(x)-cos(x0))
pdot = frequency*(As*cos(x)-Ac*sin(x))
pddot = -frequency^2*(As*sin(x)+Ac*cos(x))
angleIncrement = Bs*(sin(x)-sin(x0)) + Bc*(cos(x)-cos(x0))
angularRate = frequency*(Bs*cos(x)-Bc*sin(x))
angularAcceleration = -frequency^2*(Bs*sin(x)+Bc*cos(x))
```

At the exact reference time the pinned pose is returned without cancellation-sensitive reconstruction, while nonzero reference derivatives remain analytic. Sampling checks all time products, phase values, frequency factors and results for finiteness. There is no hidden modulo wrap, accumulated phase or full-cycle reset; the scalar angle increment and planar coordinate remain unwrapped. This selected law implements one bounded harmonic motion, not arbitrary Fourier series or changing-axis rotation.

`PrescribedMotionJet` contains displacement from the pinned origin, unwrapped angle increment, linear velocity/acceleration and scalar angular rate/acceleration. `PrescribedMotionSegment` contains finite `startTime < endTime`, start/end jets and one fixed interpolation meaning: quintic Hermite of physical position and scalar angle from the two endpoint second-order jets. `PiecewisePrescribedMotion` retains an explicitly bounded, nonempty ordered segment array. Its reference time is the first start, domain is first start through final end, and the first start displacement/angle increment is zero. Identifiers/pose/axis belong to the law, not each segment. Gaps, overlaps, unsorted/duplicate times, nonfinite jets, nonfinite duration/inverse-duration factors, or unrepresentable interpolation arithmetic fail explicitly. Derivatives use normalized segment time and the exact `1/duration` and `1/duration^2` chain-rule factors.

Adjacent end/start jets must match exactly as numerical values, treating signed zero as the same physical zero. There is no guessed tolerance or smoothing policy. Comparison first checks position/displacement and unwrapped angle, then velocity/angular rate, then acceleration/angular acceleration. The first mismatch throws proposed `PrescribedMotionError.unsupportedDiscontinuity(time: Double, derivative: PrescribedTrajectoryDerivative)`, where the derivative enum is `.position`, `.velocity`, or `.acceleration`. Metadata still preserves each original raw bit, including signed zero. Non-C2 input has no successful program/sample; no event/reset is implied by this refusal.

Internal knot lookup selects the following segment at the exact knot, while the final domain endpoint selects the last segment. Exact endpoints return the stored canonical jet rather than the floating polynomial reconstruction. For a shared knot the following start jet is canonical. A mismatch of unwrapped angles is a position discontinuity even if rotations happen to differ by a full turn. Jerk or higher derivative changes are admitted with a declared knot: their smooth-segment integration treatment belongs to the upper boundary consumer, not a fabricated discontinuity event.

`PrescribedTrajectoryPolicy` has initializer `init(motion: PrescribedMotionPolicy, maximumSegments: Int) throws(PrescribedMotionError)`. Its `motion` supplies existing sample/identifier/metadata/cancellation limits; `maximumSegments > 0` bounds the total retained segments in an anchor program, or its single base law. Counts are checked before traversal/copy/allocation. No fixed operational cap is guessed. The caller supplies capacities and NumericalBudget; changing a cap cannot alter the law or silently change its evaluation.

### Proposed public ports
Program constructors are `PrescribedTrajectoryProgram(trajectories: [PrescribedTrajectory], policy: PrescribedTrajectoryPolicy, work: inout NumericalWork) throws(PrescribedMotionError)` and `PrescribedBaseTrajectoryProgram(trajectory: PrescribedTrajectory, layout: BaseLayout, policy: PrescribedTrajectoryPolicy, work: inout NumericalWork) throws(PrescribedMotionError)`. The anchor program exposes canonical frame-ordered `trajectories`, `metadata`, `policy`, `minimumTime`, and `maximumTime`. Its common domain is the nonempty intersection of every law domain. The base program exposes `trajectory`, `layout`, `metadata`, `policy`, `minimumTime`, `maximumTime`, and `initialPlanarAngle`. It admits exactly one nonfixed base chart, separate from the anchor inventory.

The following are nongeneric Sendable protocol requirements; every operation used on an existential must have an actual witness:

```swift
public protocol PrescribedTrajectorySampling: Sendable {
    func sample(_ program: PrescribedTrajectoryProgram, time: Double,
                policy: PrescribedTrajectoryPolicy, work: inout NumericalWork)
        throws(PrescribedMotionError) -> PrescribedMotionSample
}
public protocol PrescribedBaseTrajectorySampling: Sendable {
    func sampleBase(_ program: PrescribedBaseTrajectoryProgram, time: Double,
                    policy: PrescribedTrajectoryPolicy, work: inout NumericalWork)
        throws(PrescribedMotionError) -> PrescribedBaseMotionSample
}
public protocol PrescribedTrajectoryBoundaryQuerying: Sendable {
    func nextBoundary(_ program: PrescribedTrajectoryProgram, after time: Double,
                      through limit: Double, policy: PrescribedTrajectoryPolicy,
                      work: inout NumericalWork) throws(PrescribedMotionError) -> Double?
    func nextBaseBoundary(_ program: PrescribedBaseTrajectoryProgram, after time: Double,
                          through limit: Double, policy: PrescribedTrajectoryPolicy,
                          work: inout NumericalWork) throws(PrescribedMotionError) -> Double?
}
```

Concrete proposed witnesses are `AnalyticPrescribedTrajectorySampler`, `AnalyticPrescribedBaseTrajectorySampler` and `PrescribedTrajectoryBoundaryQuery`. Queries validate finite `time <= limit` inside the program's closed domain; no clamping/extrapolation is allowed. They return the earliest declared internal piecewise knot satisfying `time < knot <= limit`, or nil when none exists. Anchor programs take the earliest across their complete inventory. Knots equal to the accepted time are skipped, preventing duplicate/zero-duration steps. Harmonic/quadratic inputs have no internal knots. Search work/storage is bounded by the admitted inventory and segment counts before traversal; no boundary list is allocated per query.

The non-overridable authority functions are proposed `OriginalPrescribedTrajectoryAcceptance.validated(_:program:time:policy:work:) -> PrescribedMotionSample`, `OriginalPrescribedTrajectoryAcceptance.sealedMotion(_:time:policy:sampler:work:) -> PrescribedMotionSample`, `OriginalPrescribedBaseTrajectoryAcceptance.validated(_:program:time:policy:work:) -> PrescribedBaseMotionSample` and `OriginalPrescribedBaseTrajectoryAcceptance.sealedBaseMotion(_:time:policy:sampler:work:) -> PrescribedBaseMotionSample`, all `throws(PrescribedMotionError)`. Each uses the corresponding new concrete program/policy and nongeneric sampler protocol. They execute builtin original-law evaluation before opaque work, reserve the comparison/storage allowance and irreversible boundary seed, invoke the supplier on a remaining independent ledger, validate/absorb known work on either outcome, and return only the independently recomputed original sample after exact comparison and final cancellation. Derived acceptance is not a conformer-overridable witness.

`OriginalPrescribedTrajectoryBoundaryAcceptance` owns analogous nongeneric `nextBoundary(_:after:through:policy:query:work:)` and `nextBaseBoundary(_:after:through:policy:query:work:)`, with the new corresponding program, `any PrescribedTrajectoryBoundaryQuerying`, and `Double?` result. It computes the builtin earliest knot first and accepts only an identical optional time bit pattern after the same seeded success/failure ledger contract. An injected query cannot suppress, invent or move a knot.

Existing outcome public fields and types are reused. The new builtin anchor path produces the complete frame-ordered PrescribedMotionSample; the base path produces the sealed PrescribedBaseMotionSample with complete metadata/frame/world/layout/time/q/v/a/qdot/FrameMotion. Only this owner may add an internal source-header constructor; no public unchecked base-sample initializer is introduced.

### Chart, source and lifetime guarantees
New mathematical evaluation returns both original FrameMotion and unwrapped scalar angle increment. A shared internal base-coordinate conversion uses the existing BaseLayout conventions: planar world translation rates and signed unwrapped yaw; spatial world linear rates, `R^-1*omega`, `R^-1*alpha`, and the actual quaternion bodyRate for qdot. For a fixed parent-frame axis the body angular transport cross term is identically zero; it is not added again. Planar admission checks exact XY translation pose/amplitudes/all endpoint jets, planar initial rotation and signed z axis. No projection of an invalid spatial law onto XY succeeds. Reference quaternion bits and original planar principal-angle branch remain explicit source data.

Shared internal mathematical/chart phases preserve old operation association and output bits when reused by legacy sampling; they must not duplicate the physical coordinate algorithm. Existing analytic coefficient evaluation stays the old builtin branch. Programs and accepted evidence retain immutable backing through fixed-count reference owners; loop work and buffers remain exclusive. All targets use identical storage/conformance and no shared cache/unsafe/conditional synchronization is added.

New canonical schemas `trajectory-anchor-v1` and `trajectory-base-v1` include the full tagged law/inventory, identifiers, pinned pose/raw quaternion, axis/reference/domain, every harmonic coefficient/frequency/phase or ordered segment time/endpoint jet, interpolation kind, C2 admission and endpoint/lookup convention. Base metadata additionally includes actual layout and initial planar-angle branch. Bounds use checked arithmetic before metadata allocation; metadata equality alone never replaces original sampling acceptance. Pure operational capacity/cancellation choices do not become physical coefficients. No legacy metadata/signature is rewritten.

Supplier error propagation follows ledger validation and known-prefix absorption. Budget replacement or counter/storage reset retains the original admission seed and reports unavailable work. Unknown work is terminal; neither smaller steps nor another law are automatic retries. Cancellation checks bracket construction, builtin evaluation, callback and final publication. Domain/continuity/chart/source failures publish no mathematical success value. Fixed-count reference phase records and checked NumericalWork storage cover new lifetime; original 128KiB/profile proof remains root-owned.

### Lower-to-upper handoff and behavioral proof
The additive upper adapter will bind either old program or new trajectory authority to the actual compiled inventory/root chart and complete law metadata, then use the same physical solver/energy/endpoint/history algorithm. Old public binding/program/sample getters remain unchanged. Lower Joints must not import Compiler, Geometry, Dynamics, Runtime or Integration. This design-only handoff changes none of those consumers. The upper must consume the sealed earliest knot to keep an integration attempt inside one smooth segment; current projected preparation clips only at target time. No event authority is supplied for non-C2 laws.

[MechanicsJointsTests](../../../../../Tests/MechanicsJointsTests/DESIGN.md#af26-lower-trajectory-proof-plan) owns independent harmonic sin/cos derivatives, scalar quintic derivatives and knot-sided limits, both canonical charts, complete source/metadata/bounds and opaque ledger success/failure/cancellation/refusal. Old exact program/signature/sample regression is mandatory. Geometry/evolution/force/work/history/cold replay and original-profile stack evidence belong to their later consumer/root owners. A smooth piecewise success or an explicit discontinuity refusal does not complete SPEC KI-006 discontinuity events.
