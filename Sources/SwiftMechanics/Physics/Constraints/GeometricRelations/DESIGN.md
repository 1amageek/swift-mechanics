# GeometricRelations

## Purpose and Scope
Parent: [Constraints](../DESIGN.md). No children. Own immutable identified holonomic point coincidence, distance and axis-alignment equations evaluated on actual compiled spatial tree body/frame geometry. This is the lower IM16.9 contribution to CN001/004/006/007; time evolution remains an upper consumer responsibility.

## Responsibilities and Boundaries
Own analytic target records, bounded canonical equation metadata, dimensionless tangent rows, original scalar geometry acceptance, source/domain validation and numerical work. Joints owns actual manifold kinematics. Dynamics owns mass, force, reaction and physical energy. No force or accepted Runtime state is inferred here. Literal disconnected/multiple-root trees, planar/spatial mixed bodies and prescribed frames remain explicit unsupported domains. The public evaluator protocol contains every existential operation as a requirement.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Constraints](../DESIGN.md) | parent | Requirement owner/index | Direct requirement/design owner | Root updates registration |
| [Joints](../../../Modeling/Joints/DESIGN.md) | depends on | Compiled snapshot, point Jacobian/motion, public body/frame/column access | Lower producer consumed by this component | No internal tree storage |
| [PrescribedMotions](../../../Modeling/Joints/PrescribedMotions/DESIGN.md) | depends on | proposed immutable program, sampling, original law verification | Mathematical imposed motion source | Planned AF23 dependency; source production waits for lower proof |
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


### AF23 planned prescribed-anchor contract
This section is design-only. Existing Swift still rejects prescribed placements/samples and its qualified AF22 fixed-frame behavior is unchanged. Production work starts only after root's exact complete-sample Runtime trial/v2 checkpoint prerequisite has actual green evidence.

#### Confirmed source path and admitted partition
`Modeling/Joints/ArticulatedTrees/TreeKinematicsEvaluator.swift` validates each supplied frame/time, duplicate/unknown frames and the complete prescribed-frame set, composes actual parent/child frame motions, and returns both prescribed drift and acceleration bias. `Modeling/Compiler/Validation/ReferenceMechanicalCompiler.swift` admits a fixed static root, a zero-DOF fixed-authority joint with prescribed parent anchor and fixed child anchor, a prescribedKinematic child base, and dynamic descendants. A prescribed base requires no dynamic ancestor. These are existing public producer paths, not proposed fabricated kinematics.

AF23 admission is connected spatial fixed-root trees with one or more explicitly inventoried prescribed parent anchors on zero-DOF fixed-authority root-to-base joints, fixed child anchors, actual prescribedKinematic bases and dynamic descendant mechanisms. Every other free joint has dynamicState authority; zero-DOF joints retain fixed authority, including fixed joints on descendant branches. Complete spatial inertias remain upper requirements. Prescribed child anchors, prescribed free-coordinate authority, a fully prescribed floating root, planar/mixed bodies and disconnected trees remain explicit unsupported domains. Fully prescribed floating-root partition requires independent separation of prescribed q/v from force-driven coordinates and is not completed by this anchor pathway.

#### Consumed immutable motion law and public witnesses
[PrescribedMotions](../../../Modeling/Joints/PrescribedMotions/DESIGN.md) owns the proposed immutable mathematical program, exact analytic sampling and original law acceptance. Geometry consumes its public contract and binds the program to the complete public model/tree/layout/frame inventory and original initial samples. It does not own trajectory generation. Records declare the relative parent frame explicitly; Geometry compares this frame to the actual public anchor owner. The analytic law is defined only in PrescribedMotions.

The program's coefficient/axis/domain/metadata validity is proved by PrescribedMotions without a Compiler or Runtime dependency. Geometry checks the complete canonical prescribed placement inventory, relative parent frames, initial samples, body modes/coordinate authority and actual initial model state. It then incorporates the full lower law signature into model-bound canonical geometric metadata. Model stamp or matching frame IDs alone are insufficient. Every opaque sampling operation is a non-generic PrescribedMotionSampling requirement; its mathematical cost and original verification contract are owned by that lower component. Geometry preserves supplier ledger prefix and unknown-work failures when consuming it.

`GeometricConstraintSystem` receives an optional immutable program; existing no-program initialization and fixed-frame metadata stay compatible. A prescribed system uses a new metadata version incorporating the complete law and prescribed placement roles, not the AF22 fixed-only signature. No-program systems continue rejecting prescribed placements. A state must contain exactly the program's complete original samples at its own physical time. The compiled public makeState/evaluate path is still required after the consumed original motion validation; no direct KinematicSnapshot construction or internal prescribed-frame storage access is introduced. Stored state samples and snapshot frame/body/column witnesses participate in original source acceptance.

#### Actual moving endpoint geometry
Named body frames and fixed anchors retain the existing public column/offset path. A named prescribed parent anchor is also an admitted endpoint on its explicitly inventoried fixed root. Its actual world pose/velocity/acceleration comes from public snapshot.frame and the exact law sample; its generalized columns are zero because the admitted parent is the fixed static root. Endpoint point velocity includes frame origin velocity plus omega cross rotated local offset; acceleration includes actual origin acceleration, alpha cross offset and centripetal terms. Directions and the second-frame transverse basis use that moving frame's actual omega/alpha, not the owning static body's zero motion. Dynamic body/fixed-anchor endpoint bias retains the original state-acceleration subtraction and actual generalized columns. All g/J/drift/bias and full physical axis residuals remain independently recomputed. The existing analytic relation target remains separate from imposed anchor motion; both signatures and explicit-time status are retained. No additional Ndot term is added.

#### Proposed verification and compatibility boundary
Tests must execute actual translating/rotating prescribed bases and dynamic descendants, independent parent/world frame composition, moving points/directions, original g/velocity/acceleration and centripetal/Coriolis bias. Wrong time, incomplete/duplicate/wrong frame sample, changed coefficients under the same ID, stale snapshot/source, bad interval, capacity, cancellation, reset success/failure and unknown work must fail. AF22 fixed body-frame rows, canonical metadata and original physical oracles are regression requirements. This lower component proves law/frame geometry, not dynamics, energy or Runtime continuation.
