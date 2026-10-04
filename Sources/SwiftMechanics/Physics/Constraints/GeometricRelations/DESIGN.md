# GeometricRelations

## AF25 physical-allocation certificate

The additive planar port owns a sufficient source-bound certificate for endpoint-wrench uniqueness, conditional on a compatible known generalized reaction and the original numerical rank policy. It does not solve dynamics or certify multiplier uniqueness, feasibility, unseen connections or bearing distribution. Existing geometry and physical-row ports remain compatible.

```text
canonical planar system/state + supplied sealed rows
 -> builtin original row acceptance -> builtin all-original-row rank
 -> dependent endpoint/original covectors exactly zero
 -> independent row IDs exactly all nonzero physical row IDs
 -> sealed physical-allocation witness; original rank/nullity retained
```

`GeometricPhysicalAllocationProviding.physicalAllocation(_:state:supplied:policy:work:)` is a non-generic requirement implemented by `GeometricPhysicalAllocationEvaluator`. `GeometricPhysicalAllocationPolicy(rows:rank:)` combines the physical-row policy and an allowRedundancy original rank policy. The immutable Sendable producer-only `GeometricPhysicalAllocationWitness` retains full recomputed rows, `originalRank`, `activeRowIDs`, `zeroRowIDs` and separate `physicalWrenchesUnique=true`; `multipliersUnique` remains original rank.reactionsUnique. `GeometricPhysicalAllocationAcceptance.validated(_:system:state:policy:work:)` recomputes builtin authority before returning accepted original evidence to upper opaque-supplier consumers.

Every original row and its order remain represented. Each dependent row must have exactly zero linear/angular covectors at both endpoints and exactly zero entries in its original normalized projected row. No tolerance or rank threshold converts a physical nonzero row to zero. Independent row IDs must exactly equal all nonzero physical row IDs in original order. Active dependent rows, including duplicates or a toggle whose projected row is zero but endpoint covector is nonzero, fail with `GeometricPhysicalAllocationError.ambiguousPhysicalRow`. Structural-zero multipliers remain nonunique; their zero physical covectors cannot change a wrench. Existing reduced planar fixed-root coincidence/stationary distance admission applies; spatial input is unsupported by this additive certificate.

Checked storage reserves canonical system/rows, rank work and certificate arrays simultaneously. Traversal/exact-zero checks are charged before execution; both original row/rank cancellation closures and Task cancellation are checked at operation/row/publication boundaries. Work is caller-exclusive and cumulative. No opaque callback, shared mutable state, unsafe storage or target-dependent conformance is introduced. Noninline production/acceptance phases retain original 128 KiB lifetimes. Failure publishes no witness and preserves known work.

Depends on original physical rows above and [AssemblyProjection](../AssemblyProjection/DESIGN.md) builtin rank. The forthcoming planar loop recovery consumes this certificate. [MechanicsGeometricConstraintTests](../../../../../Tests/MechanicsGeometricConstraintTests/DESIGN.md) owns ordinary fourbar rank2/nullity1 success, zero-row multiplier freedom, distance normalization, duplicate/toggle ambiguity, stale source/row/certificate, cancellation and resources. Root qualifies this lower contract before upper composition; source/design presence is not execution evidence.

## Purpose and Scope
Parent: [Constraints](../DESIGN.md). No children. Own immutable identified holonomic point coincidence, distance and axis-alignment equations evaluated on actual compiled spatial or admitted planar tree body/frame geometry. This is the lower IM16.9 contribution to CN001/004/006/007; time evolution remains an upper consumer responsibility.

## Responsibilities and Boundaries
Own analytic target records, bounded canonical equation metadata, dimensionless tangent rows, original scalar geometry acceptance, source/domain validation and numerical work. Joints owns actual manifold kinematics. Dynamics owns mass, force, reaction and physical energy. No force or accepted Runtime state is inferred here. Literal disconnected/multiple-root trees and planar/spatial mixed bodies remain explicit unsupported domains; named prescribed frames follow the AF23 contract. The public evaluator protocol contains every existential operation as a requirement.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Constraints](../DESIGN.md) | parent | Requirement owner/index | Direct requirement/design owner | Root updates registration |
| [Joints](../../../Modeling/Joints/DESIGN.md) | depends on | Compiled snapshot, point Jacobian/motion, public body/frame/column access | Lower producer consumed by this component | No internal tree storage |
| [PrescribedMotions](../../../Modeling/Joints/PrescribedMotions/DESIGN.md) | depends on | Immutable quadratic and source-tagged trajectory programs, sampling and original acceptance | Mathematical imposed motion source | Qualified lower AF26 handoff; model binding remains here |
| [CoordinateEquations](../CoordinateEquations/DESIGN.md) | depends on | VelocityConstraintSample, layout, policy | Lower producer consumed by this component | Tangent columns are nv, not nq |
| [ManifoldProjection](../ManifoldProjection/DESIGN.md) | used by | Evaluation and sealed original acceptance | Consumer of this component | Initial chart must already be valid |
| [Tests](../../../../../Tests/MechanicsGeometricConstraintTests/DESIGN.md) | used by | Independent physical oracles | Consumer of this component | Root owns platform qualification |

## Architecture
```text
immutable compiled model + identified frame records + analytic target/domain
 -> bounded admission -> actual tree snapshot
 -> public point Jacobian/motion -> g, A, drift, bias
 -> independent original body-column geometry acceptance
 -> immutable sample or typed failure
```

## Contracts and Invariants

### AF25 prescribed floating-root binding
`GeometricConstraintSystem` adds optional `prescribedBase` and root motion row IDs, producing immutable `PrescribedRootBinding` from actual model root authority/frame/world/BaseLayout and existing sealed base law. It retains complete original geometry/J/bias. Binding owns known prefix P, complement D, full coefficient/chart metadata and exact state root q/v/a comparison. Only an admitted prescribed-base system may have zero original geometric rows; it evaluates real source snapshots with empty geometric arrays. Root rows are separate genuine motion rows owned by ConstrainedDynamics, never fabricated geometry. Existing anchor programmes/inventory remain separate and retain their existing fixed-root admission. All external initial root q/v/a must match the original law exactly. Planar floating root with planar laws/fixed planar anchors admits actual coincidence/distance and regular alignment; physical allocation capability remains independently frozen and may explicitly refuse new domains. Mathematical binding does not claim actuator/reaction force.

State q/v/time is SI; layout scales S and time T identify tangent coordinates. Rows satisfy dg/dt=(A*(v*T/S)+drift)/T and d2g/dt2=(A*(a*T*T/S)+bias)/T/T. Coincidence uses physical length scale; distance uses squared-length normalization; alignment uses unit directions. Actual centripetal and tree acceleration bias enter once through point motion. Explicit analytic targets are quadratic polynomials of physical time with exact first/second derivatives, distinguished from autonomous targets in canonical metadata. Fixed named frames resolve against the public tree body's frame or fixed joint anchors and preserve nonidentity local transforms. All original rows and IDs, including redundant zero rows, survive evaluation. Axis alignment declares exactly two original rows: firstAxis dot each of the two orthonormal transverse directions fixed in the second endpoint frame. Their moving-direction product derivatives supply exact tangent, drift and acceleration bias. The same/opposite hemisphere branch firstAxis dot secondAxis times axisSign > 0 is explicit. A separately retained full physical axis cross residual verifies actual alignment at final feasibility. No original declared row is discarded or rounded. The previous three-cross-component representation was never qualified or released: actual mixed assembly demonstrated off-manifold rank three becoming rank two at alignment, violating constant-rank local assembly. This regular local chart replaces that representation without changing rank producers or tolerances.

Canonical metadata version two includes the two stored frame-local transverse directions and the regular-chart rule. Canonical metadata is bounded before string allocation and includes model descriptor geometry, root/tree layout, coordinate IDs/dimensions/scales, row IDs/kinds/endpoints/local geometry, target coefficients, domains and normalization. Model stamp alone is insufficient. Output source state and snapshot are validated against actual supplied model geometry, body/frame motion and all public columns. A separate builtin original evaluator derives points and directions directly from body transforms/columns; supplied diagnostics never establish original acceptance.

## Runtime Flows
Admission/storage/work reservation precedes lower callbacks. Actual compiled makeState/evaluate is charged by a bounded structural envelope before invocation. Cancellation is checked before and after callbacks and before result publication. Original acceptance recomputes all rows at the supplied state and compares source, values, tangent rows, drift and bias.

## State, Ownership, and Lifecycle
Inputs, metadata and results are immutable Sendable values. Work and buffers are exclusive operation locals. There is no shared mutable state, no target branch and no unsafe storage. Caller-owned immutable arrays retain their backing through value ownership.

## Failure, Concurrency, and Constraints
Typed GeometricConstraintError distinguishes shape/domain/chart/source/original/branch/capacity/cancellation and supplier ledger replacement/unavailable work. Bounds cover bodies, q/v, rows, metadata bytes, numeric storage and arithmetic before allocation/callback. Opaque suppliers in consumers receive seeded ledgers only after irreversible caller admission; success and failure ledger preservation is mandatory, and unknown failed work prohibits retry.

## Verification and Change Impact
Dedicated tests own actual revolute fourbar independent sin/cos g/rate/bias, nonidentity frame offsets, sixDOF/spherical mixed q/v, explicit target derivatives, source/row/diagnostic rejection and capacity/cancellation. Any scale, bias, row or metadata change invalidates ManifoldProjection and future mechanism endpoint/reaction composition evidence.


### AF23 prescribed-anchor contract
This implementation consumes root-qualified Core d4cf223 and Runtime 06cbab9. New execution qualification is pending root's frozen focused and original-profile composition; AF22 fixed-frame regression remains required.

#### Confirmed source path and admitted partition
`Modeling/Joints/ArticulatedTrees/TreeKinematicsEvaluator.swift` validates each supplied frame/time, duplicate/unknown frames and the complete prescribed-frame set, composes actual parent/child frame motions, and returns both prescribed drift and acceleration bias. `Modeling/Compiler/Validation/ReferenceMechanicalCompiler.swift` admits a fixed static root, a zero-DOF fixed-authority joint with prescribed parent anchor and fixed child anchor, a prescribedKinematic child base, and dynamic descendants. A prescribed base requires no dynamic ancestor. These are existing public producer paths, not proposed fabricated kinematics.

AF23 admission is connected spatial fixed-root trees with one or more explicitly inventoried prescribed parent anchors on zero-DOF fixed-authority root-to-base joints, fixed child anchors, actual prescribedKinematic bases and dynamic descendant mechanisms. Every other free joint has dynamicState authority; zero-DOF joints retain fixed authority, including fixed joints on descendant branches. Complete spatial inertias remain upper requirements. Prescribed child anchors, prescribed free-coordinate authority, a fully prescribed floating root, mixed bodies and disconnected trees remain explicit unsupported domains; AF24 separately admits fixed-root planar point geometry. Fully prescribed floating-root partition requires independent separation of prescribed q/v from force-driven coordinates and is not completed by this anchor pathway.

#### Consumed immutable motion law and public witnesses
[PrescribedMotions](../../../Modeling/Joints/PrescribedMotions/DESIGN.md) owns the immutable mathematical program, exact analytic sampling and original law acceptance. Geometry consumes its public contract and binds the program to the complete public model/tree/layout/frame inventory and original initial samples. It does not own trajectory generation. Records declare the relative parent frame explicitly; Geometry compares this frame to the actual public anchor owner. The analytic law is defined only in PrescribedMotions.

The program's coefficient/axis/domain/metadata validity is proved by PrescribedMotions without a Compiler or Runtime dependency. Geometry checks the complete canonical prescribed placement inventory, relative parent frames, initial samples, body modes/coordinate authority and actual initial model state. It then incorporates the full lower law signature into model-bound canonical geometric metadata. Model stamp or matching frame IDs alone are insufficient. Every opaque sampling operation is a non-generic PrescribedMotionSampling requirement; its mathematical cost and original verification contract are owned by that lower component. Geometry preserves supplier ledger prefix and unknown-work failures when consuming it.

`GeometricConstraintSystem` receives an optional immutable program; existing no-program initialization and fixed-frame metadata stay compatible. A prescribed system uses a new metadata version incorporating the complete law and prescribed placement roles, not the AF22 fixed-only signature. No-program systems continue rejecting prescribed placements. A state must contain exactly the program's complete original samples at its own physical time. The compiled public makeState/evaluate path is still required after the consumed original motion validation; no direct KinematicSnapshot construction or internal prescribed-frame storage access is introduced. Stored state samples and snapshot frame/body/column witnesses participate in original source acceptance.

#### Actual moving endpoint geometry
Named body frames and fixed anchors retain the existing public column/offset path. A named prescribed parent anchor is also an admitted endpoint on its explicitly inventoried fixed root. Its actual world pose/velocity/acceleration comes from public snapshot.frame and the exact law sample; its generalized columns are zero because the admitted parent is the fixed static root. Endpoint point velocity includes frame origin velocity plus omega cross rotated local offset; acceleration includes actual origin acceleration, alpha cross offset and centripetal terms. Directions and the second-frame transverse basis use that moving frame's actual omega/alpha, not the owning static body's zero motion. Dynamic body/fixed-anchor endpoint bias retains the original state-acceleration subtraction and actual generalized columns. All g/J/drift/bias and full physical axis residuals remain independently recomputed. The existing analytic relation target remains separate from imposed anchor motion; both signatures and explicit-time status are retained. No additional Ndot term is added.

#### Verification and compatibility boundary
Tests must execute actual translating/rotating prescribed bases and dynamic descendants, independent parent/world frame composition, moving points/directions, original g/velocity/acceleration and centripetal/Coriolis bias. Wrong time, incomplete/duplicate/wrong frame sample, changed coefficients under the same ID, stale snapshot/source, bad interval, capacity, cancellation, reset success/failure and unknown work must fail. AF22 fixed body-frame rows, canonical metadata and original physical oracles are regression requirements. This lower component proves law/frame geometry, not dynamics, energy or Runtime continuation.

AF23 source tests: [PrescribedGeometryTests](../../../../../Tests/MechanicsGeometricConstraintTests/PrescribedGeometryTests.swift) verifies real named prescribed-anchor point g/rate/bias, nonidentity initial pose and independent world sin/cos formulas; mixed 4/3 retraction preserves exact samples. Root's public regular-axis coupled loop uses body-frame endpoints. Coincidence of equal rotor circles has off-manifold rank two and feasible rank one and does not qualify arbitrary perturbed constant-rank assembly. Existing original rows/rank producers are unchanged.

### AF24 planar geometry and physical row authority

This component owns the original geometry representation for both dimension admission and physical row covectors. The read-only trace established that existing original relation evaluation binds actual body points/axes, normalization and targets, while current admission excludes planar trees. A planar connected fixed-root domain may admit original point coincidence and distance with plane-preserving inputs. Alignment or other unsupported planar combinations remain explicit failures until corresponding physical evidence exists. Original redundant/zero rows are retained for rank and original acceptance; they cannot be erased to manufacture unique physical reactions. Existing spatial/AF23 motion-program behavior and source/chart identity remain compatible.

An additive non-generic protocol requirement publishes immutable source-bound physical row covectors. The producer owns row IDs, exact canonical geometry/layout/source/time/velocity, endpoint bodies, actual world points and force/couple conventions. Covector projection through each original body's geometric columns must reconstruct every original generalized row with its original normalization. The consumer owns multiplier coupling and reaction availability; it cannot construct authoritative geometry from unrelated array shapes or reuse a stale witness. Checked row/body/storage limits, charged work, explicit cancellation and supplier failure apply before output allocation/publication. Actual public record/requirement names and construction authority must be fixed in this lower component design before source edits.

```text
canonical geometry + actual source
    -> original rows and body/point covectors
    -> independent row projection acceptance
    -> immutable physical witness
          -> upper multiplier/body balance/tree-cut recovery
```

Initial physical reaction covectors admit stationary zero-target coincidence, stationary distance and spatial aligned-axis relations with connected dynamic endpoints. Time-dependent targets, nonzero coincidence offsets and independently prescribed endpoints require separate support/drive authority and are explicitly unavailable in this physical output port. This restriction does not weaken existing kinematic/evolution operations. Force and impulse consumers must distinguish temporal meaning; the first upper reaction composition admits continuous force only. If original reaction nullity is nonzero, individual physical-path allocation must fail with typed ambiguity rather than relabel a retained representative as unique.

[MechanicsGeometricConstraintTests](../../../../../Tests/MechanicsGeometricConstraintTests/DESIGN.md) owns original planar coincidence/distance assembly, rank/zero-row/toggle/refusal and covector projection/source tests. New output is checked against independent endpoint force/moment and virtual work, including normalization invariance and action/reaction. Root owns downstream profile qualification and actual registration. The complete full-domain requirements remain open; source presence does not establish behavioral qualification.

#### AF24 fixed API and construction contract
`HolonomicGeometryProviding.physicalRows(_:state:supplied:policy:work:)` is a non-generic requirement. Its default implementation is the sealed builtin original physical-row path, independent of an injected evaluator's diagnostics. `GeometricPhysicalRowPolicy` owns original diagnostic comparison tolerance, row projection NumericalTolerance, maximumBodies, and the existing ConstraintEvaluationPolicy for coordinate/row/revision/cancellation limits. `GeometricPhysicalRowWitness` is a final immutable Sendable class with a private constructor: only its builtin source-validating factory can produce authority. There is no public raw-row initializer. The witness retains model stamp, dimension, canonical geometry metadata and the complete original HolonomicGeometrySample (source state/time/velocity/acceleration/prescribed samples, layout, snapshot, original rows) plus ordered `GeometricPhysicalRow` records and explicit fidelity (`spatialBodyPointCovectors` or `reducedPlanarBodyPointCovectors`). Its temporal convention is a dimensionless geometric covector suitable for continuous-force energy multipliers; the witness is not itself a force/impulse or an allocation uniqueness certificate.

Each row owns rowID, relationIndex/componentIndex, kind, original normalizationScale, and two immutable `GeometricRowEndpointCovector` records. Each endpoint records body, world frame, actual world torque-reference point, linearGradient (1/m) and angularGradient (dimensionless pure couple). For body-origin columns C, row projection is sum(linearGradient dot (C.linear + C.angular cross (point-bodyOrigin)) + angularGradient dot C.angular), equal to original normalized A[row,i]/S[i] within caller projection tolerance. Original rows are independently recomputed before covector construction; each covector projection is independently checked before publication. A dependent row is retained and does not authorize a unique multiplier or individual physical-path allocation.

Stationary zero-target coincidence has first linear gradients X/Y/Z divided by length and opposite second gradients; distance has first gradient (xFirst-xSecond)/lengthScaleSquared and opposite second; spatial alignment has first pure couple axisFirst cross movingSecondTransverse and opposite second. Both endpoints must belong to distinct dynamic bodies in the actual connected tree and use body-fixed frames. Independently prescribed frames/bodies, stationary nonzero coincidence offsets and time-dependent targets are unsupported by this physical-output requirement only, through `unsupportedPhysicalRows`. Kinematic evaluation of those existing admitted spatial operations is preserved.

Planar geometry admission requires a connected fixed-root planar model, no motion program/prescribed placements, fixed-root authority and plane-preserving endpoint points/targets/fixed transforms. Coincidence retains all three original rows; its z row is structurally zero. Planar physical covectors are restricted to in-plane force and z couple; the retained coincidence z row publishes two zero covectors with `isStructuralZero=true`, not an out-of-plane bearing-force authority. Distance remains an in-plane central force. Planar alignedAxes is explicit unsupportedDomain. Original zero rows and tiny nonzero toggle derivatives are never removed or rounded. Existing spatial v2/v3 geometry signatures and phase lifetimes remain unchanged; planar geometry uses a distinct `body-frame-planar-holonomic-v4` signature to prevent dimension aliasing.

Physical-row storage includes simultaneously retained system, original sample, endpoint work, result rows and metadata backing, with checked products/sums before allocation. Arithmetic is charged before each endpoint/row/column block; cancellation at every relation/row/column and before publication. No opaque callbacks are needed beyond the existing sealed builtin compiled-source/original path. Failure publishes no witness and preserves caller work. Tests own planar original derivatives/assembly/rank/zero/toggle, independent endpoint forces/couples, row projection, normalization/action-reaction and source/domain/capacity/cancellation failure. Root owns actual executions and registration; this source dispatch does not claim behavior qualification.

`GeometricPhysicalRowAcceptance.validated(_:system:state:policy:work:)` is the sealed original upper-consumer check for opaque physicalRows suppliers. It recomputes a builtin witness from the supplied original sample, verifies model/dimension/metadata/convention and every physical row, and returns the recomputed authority. Reuse at another time/state or against a different canonical system fails. This is a source and row-covector proof, not an allocation rank certificate.

A physical-row witness proves the original geometric derivative/source at its declared state, not feasibility or accepted dynamic force. The upper consumer must check original position/velocity/acceleration feasibility before continuous-force multiplier coupling. In particular, zero-target coincidence covectors evaluated off-manifold do not establish a physically coincident action/reaction point. No geometry, rank or kinetic-energy producer is changed to bypass this acceptance.

### AF25 verification boundary
The original compiled root frame/layout/authority and complete canonical q/v/a are bound outside anchor slots, with one distinct metadata version containing the full lower law, P/D inventory and root row IDs. Empty geometric rows retain the full original layout. [PrescribedRootGeometryTests](../../../../../Tests/MechanicsGeometricConstraintTests/PrescribedRootGeometryTests.swift) owns actual planar/spatial empty-row/rank/source/ID behavior; lower source review is not runtime qualification. Existing GeometricPhysicalAllocation producers and legacy geometry behavior are unchanged.


## AF26 source-tagged trajectory binding contract

This is the design handoff for IM16.33.1, not implementation or execution evidence. The qualified lower handoff is `56a57ba`. Existing quadratic getter types, constructors, field meanings, original sample bits and geometric metadata schemas remain unchanged. The new law family never manufactures a quadratic record.

### Confirmed execution path and additive API
`GeometricConstraintSystem.snapshot` validates prescribed source before actual public `CompiledMechanicalModel.makeState/evaluate`; `GeometricPrescribedBinding` binds the complete public placement inventory. `PrescribedRootBinding` binds root authority, actual root/world frames and BaseLayout separately from anchor slots. `GeometricMetadata` binds actual body/joint/frame/layout roles and full law metadata. The frozen physical-allocation files and physical-row behavior above remain unchanged.

The existing `GeometricConstraintSystem` initializer gains trailing arguments after `rootRowIDs`:

```swift
prescribedTrajectory: PrescribedTrajectoryProgram? = nil,
prescribedBaseTrajectory: PrescribedBaseTrajectoryProgram? = nil
```

The original arguments and typed `throws(GeometricConstraintError)` remain. Anchor quadratic/trajectory families are mutually exclusive; root quadratic/trajectory families are mutually exclusive; the current separate root versus prescribed-anchor domain is retained. New public getters are `prescribedTrajectory: PrescribedTrajectoryProgram?` and `prescribedTrajectoryRoot: PrescribedTrajectoryRootBinding?`. Existing `prescribedMotion` and `prescribedRoot` return only their original quadratic authority, and remain nil for a new trajectory authority. `isExplicitTime`, empty-geometric-row admission and canonical source checks recognize either actual law family.

```swift
public protocol PrescribedRootBindingProviding: Sendable {
    var knownCoordinates: [Int] { get }
    var dynamicCoordinates: [Int] { get }
    var rowIDs: [UInt64] { get }
    func sample(time: Double, work: inout NumericalWork)
        throws(GeometricConstraintError) -> PrescribedBaseMotionSample
    func validate(_ state: KinematicState, work: inout NumericalWork)
        throws(GeometricConstraintError)
}
```

Existing `PrescribedRootBinding` conforms without changing its public record or sampling. New immutable final Sendable `PrescribedTrajectoryRootBinding` conforms, exposes `program: PrescribedBaseTrajectoryProgram` and the three partition/row getters, and has only a producer-owned model-binding constructor. `GeometricConstraintSystem.rootBinding: (any PrescribedRootBindingProviding)?` exposes the selected actual root authority. Every existential operation is a requirement; no generic operation or extension-only invocation is used.

### Authority, lifetime and failure
New anchor programs bind every required actual prescribed frame and its public owning parent frame, actual body modes, zero-DOF bridge authority, initial original sample, domain and full layout. New root programs bind actual root frame/world frame/BaseLayout, complete initial q/v/a and the original P/D/row partition. Matching count, stamp or IDs alone cannot establish association. Original builtin lower trajectory acceptance verifies every supplied pose/velocity/acceleration/time and root q/v/a/qdot; actual compiled source evaluation remains mandatory. Domain intersection is explicit. The new canonical metadata version includes full lower source-tagged law metadata, actual inventory/root partition and existing geometry rules. Legacy schema strings and bits do not change.

Selected domains preserve current admission: fixed-root spatial prescribed anchors, and prescribed planar/spatial floating roots with root-only or dynamic descendants. Planar prescribed anchors, prescribed nonroot free coordinates and root-plus-anchor combinations are not newly admitted. Harmonic and C2 piecewise laws use the qualified lower chart and plane restrictions. Non-C2 seams remain exact lower typed refusals; real discontinuity events remain incomplete KI-006 work.

```text
immutable trajectory program -> actual model/frame/chart inventory binding
 -> builtin original sample -> complete state at t -> compiled makeState/evaluate
 -> unchanged original geometry/J/drift/bias/all-axis acceptance
```

New program payloads and root binding are held by bounded immutable reference owners, not added as rich value payloads to every `GeometricConstraintSystem` copy. Public output materialization follows kinematics callbacks in existing noninline phases. No cache, mutable shared state, unsafe storage, target branch or new synchronization is introduced. Counts, identifier bytes, metadata, simultaneous sample storage and source traversal work are reserved before allocation/callback. Opaque trajectory ports use their sealed lower admission/seed/finalization contract on success and failure; known prefix and unknown-work classification survive Geometry's typed `.motion` error wrapper. Geometry does not own knot selection, actuator force or work.

### Change paths and behavioral owner
Production paths proposed for the next item: `GeometricConstraintSystem.swift`, `GeometricPrescribedBinding.swift`, `GeometricDimensionAdmission.swift` (new family recognition only), `GeometricMetadata.swift`, `PrescribedRootBinding.swift` conformance, and new `PrescribedRootBindingProviding.swift`, `PrescribedTrajectoryRootBinding.swift` plus a bounded immutable trajectory owner file. `GeometricPhysicalAllocation*`, frozen physical-row producers and Joints/Compiler are not changed.

[Trajectory binding tests](../../../../../Tests/MechanicsGeometricConstraintTests/DESIGN.md#af26-trajectory-binding-proof-contract) own actual model/frame association, analytic geometry derivatives, empty/root-only and D-only projection, changed same-revision law, source/time/plane/domain refusal, cancellation and capacity. [NonlinearEvolution](../../Mechanisms/NonlinearEvolution/DESIGN.md#af26-knot-aware-trajectory-evolution-contract) consumes this contract for original force/power and history. Root updates parent indexes and owns shared/profile integration after owner-isolated Native proof.
