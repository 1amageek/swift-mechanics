# Rigid Material Attachments

## Purpose and Scope
Own AF34.6 selected FX-008 point-translation interfaces between IM06 rigid body frames and IM23.2 qualified Tet4 boundary material points. Parent: [Flexible](../DESIGN.md). No children. The selected repaired source has matching Native compile/link and behavioral evidence; WASM/Embedded profile qualification and coupled evolution are separate.

## Responsibilities and Boundaries
Issue immutable material-site bindings, evaluate original constraint equations and map caller supplied force multipliers to reciprocal nodal/generalized loads. IM06 owns rigid kinematics; IM19 owns Tet4 physical/nodal layout; IM23 owns surface topology and material interpolation. The caller owns boundary exclusivity and supplies all existing constraint rows sharing that boundary. This operation detects rank conflicts in that declared set; it cannot discover omitted constraints. No accepted-state mutation, integration, constraint solve, constitutive response or multirate publication is owned here.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Flexible](../DESIGN.md) | parent | FX-008 responsibility | Composition owner | Full coupled evolution remains separate |
| [Mesh](../Mesh/DESIGN.md) | depends on | Validated Tet4 mesh and provenance | Physical nodal owner | No AF32/AF33 suppliers |
| [Tetrahedra](../Tetrahedra/DESIGN.md) | depends on | NodalState Cartesian translation DOF | Nodal velocity layout | No independent nodal rotation |
| [MaterialGeometry](../../DeformingContact/MaterialGeometry/DESIGN.md) | depends on | MaterialSurface identity, updater and SurfaceMaterialPoint | Current material coordinates | Exact surface owner, layout, epoch and time required |
| [ArticulatedTrees](../../../Modeling/Joints/ArticulatedTrees/DESIGN.md) | depends on | KinematicTree, KinematicState and TreeKinematicsComputing | Evaluator-issued snapshot with its exact generating state | Tangent velocity v differs from coordinate derivative qdot for quaternion joints |
| [Jacobians](../../../Modeling/Joints/Jacobians/DESIGN.md) | depends on | PointJacobian and PointKinematics | Original rigid point derivative | Prescribed drift remains in affine constraint rate |

## Architecture
```text
qualified Tet4 snapshot -> owner-issued site -> attachment + declared boundary rows
tree + state + joint policy -> actual tree evaluator -> immutable rigid source
                                     (snapshot + exact state.v) --+
                                                            v
                   bounded current admission -> g, rate, bias, combined J
                                                            v
                    rank admission -> immutable query -> multipliers
                                                            v
               original equation acceptance -> nodal / rigid wrench / generalized loads
```

## Contracts and Invariants
`AttachmentRigidSource` is issued only by evaluating the supplied tree and state through the qualified `TreeKinematicsEvaluator` behind its `TreeKinematicsComputing` contract. It retains the exact generating state, snapshot and evaluation policy. There is no public constructor pairing a raw snapshot and caller supplied velocity. Evaluation preserves the original revision, coordinate count, prescribed derivative, time, frame and numerical failures. The tree's admitted capacity bounds this synchronous supplier work; its supplier has no NumericalWork interface, so this component does not invent a numerical work charge for source issuance.

Generalized Jacobian columns and effort are conjugate to `state.v`, never `snapshot.coordinateRate`. The latter is a position-coordinate derivative: spherical orientation has four coordinate derivatives and three tangent velocities; a spatial floating body has seven and six. The original snapshot-only source API had no validated tangent velocity and rejected these qualified layouts. Removing that constructor is an intentional API correction; no existing source caller was found in the current selected graph. All source creation now follows the actual evaluator path. Immutable source identity remains the force-operation gate, so reissuing an identical state does not acquire an earlier query's authority.

Directions are explicit independent unit vectors fixed in the common world/mesh frame. One to three selected translational DOF are admitted. For each direction a, g=a dot (x_material-x_rigid), rate=a dot (v_material-v_rigid), J=[-a dot J_rigid, N_i a], prescribed rate=-a dot rigid drift and acceleration bias=-a dot rigid point bias. Tet4 Cartesian nodal acceleration has no kinematic bias. Rank is checked on the combined declared existing and new rows with caller selected positive velocity-column scales and dimensionless relative pivot threshold after row normalization. Caller scales and per-rigid-coordinate effort tolerances must match the combined and rigid velocity layouts respectively; effort tolerances carry the units conjugate to each coordinate velocity. Dependent rows and zero rows fail. Boundary ownership, IDs, frames, node ordering, revisions, geometry epoch, time and physical provenance remain attributable through retained immutable inputs.

Force mapping applies +sum(lambda a) to the material site and its opposite to the rigid point. Nodal forces use the original barycentric weights; rigid torque is the moment of that opposite point force about the rigid body origin, expressed in world axes. Output separately retains rigid body-origin wrench, world-origin moment balance, generalized effort, prescribed rigid power and nodal power. Original g/rate, actual force/moment balance, row-transpose load correspondence, physical power versus multiplier-rate power and generalized plus prescribed rigid power are accepted at the force operation, using explicit tolerances. Partial translation selections also require total world moment balance for the requested load; separated force lines that create a free couple fail rather than silently inventing material rotational DOF.

## Runtime Flows
Bounds and checked count arithmetic precede allocation and traversal. Surface update re-admits current geometry and point query uses the published interpolation. Rigid point outputs are checked against the actual retained frame and rate. Query assembles dense combined rows and performs bounded elimination for rank only; it does not solve motion. Force proposals re-evaluate original query equations against the supplied exact current source before mapping and acceptance. Final cancellation gates precede material-site, query and force-proposal publication. Rigid source issuance follows the synchronous qualified tree evaluator's original capacity/failure contract and has no caller cancellation policy. No retry or fallback occurs.

## State, Ownership, and Lifecycle
All public records and services are immutable Sendable on Native/WASM/Embedded. Material-site tokens retain the exact MaterialSurface owner; query tokens retain exact rigid-source owner, snapshot and bindings. Query/proposal records retain their own operation policies and numerical ledger for acceptance attribution. Mutable row elimination, numerical work and force arrays belong exclusively to an operation. Array backing remains owned by immutable inputs/results; no escaped pointer or shared cache exists. Tokens convey query provenance only, never authority to mutate boundary or accepted state.

## Failure, Concurrency, and Constraints
Caller policy bounds attachment/row/scalar/metadata counts and sets separate gap (m), rate/velocity (m/s), acceleration (m/s squared), direction/rank (dimensionless), force (N), moment (N m), power (W) and coordinate-conjugate effort tolerances. Surface admission and NumericalWork retain their independent bounds. Storage preflight includes simultaneous retained rows, rank workspace, force arrays and supplier peak requirements; arithmetic charges include admission, dense row operations and elimination. Nonfinite arithmetic, overflow, rank loss, overconstraint, stale owner/epoch/layout/frame/revision/time, mismatched boundary ownership, cancellation and supplier failure return typed errors. Surface supplier failures retain the numerical ledger; typed JointError/CoreError are preserved from rigid suppliers and any untyped rigid supplier failure is exposed explicitly with no retry. Resource bounds are structural, not measured latency/allocation guarantees.

Actual material orientation has a callable explicit incomplete failure. A single material point cannot supply a material rotation. Flexible-flexible coupling, coupled evolution and shell/cable/Hex8/reduction interfaces are outside the declared API.

## Verification and Change Impact
The source correction requires independently analytic spherical (four qdot, three v) and floating (seven qdot, six v) fixtures, actual query/force/power execution, original state/revision failures and prescribed drift decomposition. The immutable original 2363 module and objects cannot qualify modified source: a separately emitted matching module/object set is required before fixture compilation. The behavior owner is [AttachmentsQualification](../../../../../Verification/AttachmentsQualification/DESIGN.md).

The matching Native qualification executes affine/deformed Tet4 interpolation, body-offset Jacobian/rate/bias, rigid torque and generalized effort, independent force/moment/virtual-work oracles, prescribed drift, rank/overconstraint, stale owner/time/epoch/layout and late cancellation. Its seven Swift Testing tests and six identical synchronous public cases passed using the separately emitted matched2363 module, all thirteen freshly emitted component objects and one actual linked dylib. Receipt: `.build/af35-attachments-qualification/consumer-pass-1/native-qualification-receipt-pass-3.json`, SHA256 `30c3c98811df1fa8848bb743181a781f11bf490d699e772636869475d90b0fbc`. Production Swift aggregate `cb857e1daa7372d4335c4d8f6927ed02063fdce7f8d8a620cf8ddd5a85ef18d7`; fixture aggregate `b4ed4331a06702a7acaede489fb0bb223aac301df3ca7a163bee7269360e73d5`. Native consumer requires macOS15 for its common Mutex counter; production Mac13 registration remains unchanged. This does not demonstrate macOS13 runtime or WASM/Embedded behavior. Strict public/dylib codesign passed; the generated test bundle's strict signature failure is retained without re-signing. Changes to site interpolation, rigid point derivatives or layout invalidate this component; new orientation supplier requires a new explicit rotation contract and independent couple/power evidence. No full flexible dynamics, Runtime synchronization or evolution claim follows from these selected point-interface proofs.

### Registered Repaired Point Interface

The exact13 repaired production Swift files are registered after the [qualification owner](../../../../../Verification/AttachmentsQualification/DESIGN.md) passed canonical1760 Native seven tests/six public cases and exact ordinary/Embedded six shared witnesses under complete original131072-byte guards. Final macOS13 declarations use explicit availability only for the fixture's Mutex resources case. That owner defines current state.v authority, original oracles, target evidence, storage/isolation matrix and limitations. Material orientation and full coupled evolution remain explicitly unsupported.
