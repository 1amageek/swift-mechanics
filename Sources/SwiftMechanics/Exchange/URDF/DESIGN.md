# URDF Exchange

## Purpose and Scope
Parent: [Exchange](../DESIGN.md). Children: none. Own IO-003/IO-008's selected URDF 1.0 semantic import and immutable admitted-document export. Root composition registration and exact portability qualification remain pending. Selected Native behavior for unchanged18 Swift sources is recorded by [URDF qualification](../../../../Verification/URDFQualification/DESIGN.md); that evidence is limited to the admitted witnesses and retained original producer graph. XML is the exact-source supplier qualified in [XMLQualification](../../../../Verification/XMLQualification/DESIGN.md).

## Responsibilities and Boundaries
Own bounded UTF8 markup admission, names/references, explicit SI and root placement, spatial fixed/continuous tree construction, physically validated supplied inertia, concrete sphere/box collision configuration, representation/extension loss reporting and deterministic XML export. Invoke a public MechanicalModelCompiling producer before publishing any result. Never manufacture missing inertia or claim that retained XML is a mechanical law. No filesystem/network resolution, model editing, Runtime admission, general mechanical-model serialization, or simulation driver is owned here.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Exchange](../DESIGN.md) | parent | Explicit semantic preservation | Composition owner | Parent owns registration |
| [URDF qualification](../../../../Verification/URDFQualification/DESIGN.md) | used by | Public codec, dynamics and collision providers | Independent selected Native physical and refusal evidence | No ordinary/Embedded or complete-format claim |
| [XML](../XML/DESIGN.md) | depends on | XMLDocumentCoding, XMLWork, immutable validated nodes | Bounded qualified grammar | No namespaces, DTD or arbitrary entities |
| [Compiler](../../Modeling/Compiler/DESIGN.md) | depends on | MechanicalDescriptor, MechanicalModelCompiling, compiled snapshots | Real compilation and pose/layout acceptance | Caller supplies producer CompilationPolicy |
| [Inertia](../../Modeling/Model/Inertia/DESIGN.md) | depends on | MassProperties3D, transformed | Supplied positive physical full tensor | No massless moving body substitution |
| [Joints](../../Modeling/Joints/DESIGN.md) | depends on | JointManifold, JointRecord, KinematicState | Fixed and scalar continuous joints | Continuous positions are unwrapped radians |
| [Collision shapes](../../Physics/Collision/Shapes/DESIGN.md) | depends on | CollisionShape, CollisionProxy | Actual analytic box/sphere configuration | No cylinder/mesh backend is supplied |
| [Rigid equations](../../Physics/Dynamics/RigidEquations/DESIGN.md) | depends on | RigidBodyInertia, RigidDynamicsInput | Complete real inertia inventory in snapshot order | V0 assembly and missing static-link inertia explicitly refuse |
| [Scalar ports](../../Physics/Constraints/ScalarJointPorts/DESIGN.md) | coordinates with | Published limit/friction capabilities | Identifies unsupported event/drive authority | Retained limits are never called enforced |
| [Transmissions](../../Physics/Transmissions/IdealNetworks/DESIGN.md) | coordinates with | Published ideal network compiler | Does not provide URDF actuator mechanicalReduction mapping | Transmission and mimic input explicitly fail |

## Architecture
```text
caller options / URDFWork / independent XMLWork / compiler policy
    -> XMLDocumentCoding.decode -> indexed owned node table
    -> strict selected URDF grammar -> topology + inertia + origins
    -> public model producers -> MechanicalDescriptor
    -> MechanicalModelCompiling.compile -> immutable URDFImportResult
                                      -> model + analytic collider bindings + losses/assets
immutable admitted markup -> canonical attribute ordering -> XMLDocumentCoding.encode
```

## Contracts and Invariants
Normative format pin: official [urdfdom 6.0.0 README](https://raw.githubusercontent.com/ros/urdfdom/6.0.0/README.md), [link parser](https://raw.githubusercontent.com/ros/urdfdom/6.0.0/urdf_parser/src/link.cpp), [joint parser](https://raw.githubusercontent.com/ros/urdfdom/6.0.0/urdf_parser/src/joint.cpp), and [pose parser](https://raw.githubusercontent.com/ros/urdfdom/6.0.0/urdf_parser/src/pose.cpp). Selected version is 1.0, either absent or exactly `1.0`; 1.1 quaternion/capsule and 1.2 extended limits are rejected. The official wiki was inaccessible; the official tagged producer documents the selected pin. This implementation is an independent Swift interpretation, not copied C++ source.

| Input semantics | Admission / actual output |
|---|---|
| robot/link/joint names | Nonempty bounded strings; EntityID uses Swift string identity, so canonically equivalent duplicates are rejected; link/root/material references additionally require identical UTF8 bytes, avoiding accidental canonical-equivalence binding; XML names retain supplier byte equality |
| Units | Caller explicitly selects metres, kilograms, seconds, radians; no guessing or implicit conversion; alternate unit/version attributes fail |
| Numeric text | Bounded ASCII signed decimal with optional decimal point/exponent; no hex/NaN/infinity, overflow or nonzero underflow; vectors have exactly three ASCII-whitespace separated components |
| Root | Caller names the unique root and supplies world-frame ID and fixed/spatial-floating initial world pose; no world link is fabricated |
| Joint | fixed or continuous; axis defaults +X; finite nonzero direction normalized by public JointManifold; joint origin maps child/joint into parent at zero position; child anchor identity |
| Inertial | mass and six signed tensor entries required; positive finite mass/physical tensor through MassProperties3D; origin Rz(yaw) Ry(pitch) Rx(roll) rotates tensor at COM and translates COM; no parallel-axis shift of a tensor already at COM |
| Motion/inertia | Static paths may omit inertia; every dynamically moving path requires real supplied inertia; floating root is dynamic |
| Initial state | Explicit zero joint coordinates/rates/accelerations and caller root pose; compiled model validates all reference poses and coordinate counts |
| Geometry | collision sphere/box produce actual analytic CollisionProxy bindings; other geometry and visual/material have retained XML plus explicit representation loss only in caller-selected loss mode |
| Assets | mesh/texture relative references require an explicit bounded opaque base and bounded safe relative path; preserved references are unresolved and reported, never loaded; absolute/scheme/traversal/percent/backslash references fail |
| Laws | revolute/prismatic bounded joints, limits, nonzero dynamics, mimic, safety/calibration and transmissions fail even in loss mode; no force/friction/actuation law is silently removed |
| Extension | Unknown element/attribute fails in strict mode; explicit preserve-unserved-representations mode retains original markup and emits bounded loss evidence; laws listed above remain prohibited |
| Export | Only producer-admitted immutable results can be exported; retained original accepted markup represents import semantics, not later runtime state; attribute order is UTF8 lexical, comments removed, element/text preorder retained; not W3C C14N |

Unknown attribute preservation never overrides validation of recognized attributes. Unit declarations and later-version pose attributes fail even in loss mode. A permissive representation report states that the compiled model omits that representation, while export preserves its input markup. No lossy force-law conversion exists. Geometry configuration binds actual validated shapes to bodies and evaluates a model-validated state through the supplied compiled model; caller explicitly supplies filter/margin/frame revision and work.

The result publishes explicit dynamics availability. Its public provider evaluates a validated state, collects actual supplied spatial inertias in canonical snapshot order, and constructs the real public RigidDynamicsInput with caller-selected gravity/loads. Every body, including a static root, must have supplied inertia for this lower kernel; a structurally valid robot missing static inertia still imports but its dynamics provider explicitly refuses. V0 assembly is likewise unavailable. No RigidEquationKernel success is claimed by this source-only handoff; its caller-owned DynamicsAdmission/LoadWork/NumericalWork remain downstream authority.

## Runtime Flows
Import completes local parse, full topology traversal, public producer construction and compiler validation before output publication. Failure leaves no document/model partial success; caller retains cumulative work. Export builds a bounded new canonical table, then delegates both measured writer passes to the XML supplier and returns bytes only after success. XML byte budgets and URDF semantic budgets are separate and cumulative.

## State, Ownership, and Lifecycle
Numeric lexical validation borrows the XML-owned UTF8 view without a byte-array copy. Vector components materialize String only at the standard-library Double conversion boundary; temporary substring arrays have fixed admitted component bounds. Storage counters charge logical payload/table strides, while allocator bookkeeping and public producer scratch are governed by supplier count/capacity contracts rather than represented as process RSS.
All services/results are Sendable; document arrays own immutable values. XMLDocument retains its own nodes/strings; no borrow or raw pointer escapes. Work owns exclusive mutable counters passed inout. Adjacency, dictionaries, topology queue, poses, bodies/joints and canonical nodes are operation-local. No shared reference storage, conditional isolation, unchecked Sendable or target-specific storage exists. Result construction is internal and occurs only after actual compilation. Collision configuration remains immutable and checks snapshot revision/world/body before producing an actual public CollisionProxy.

## Failure, Concurrency, and Constraints
URDFPolicy bounds links, joints, geometry records, assets, losses, identifier/reference bytes, semantic operations and cumulative owned storage. XMLPolicy independently bounds input/output bytes, nodes, attributes, depth and supplier work. Compiler policy bounds its own allocation and work closure. Preflight semantic tables and per-record arrays before allocation; all loops charge work and check Task cancellation. Checked addition/multiplication rejects overflow. Count/name/asset limits and incomplete topology fail with a raw XML location; lower failures remain typed XML/CompilationFailure/CoreError/ModelError/JointError/CollisionError, with unexpected public-constructor errors represented explicitly. Failed charges retain earlier accepted work. No retries, remote I/O or fallback occurs.

## Verification and Change Impact
Independent moving-state fixtures must also execute the complete RigidDynamicsInput through the qualified equation kernel. Missing static-link inertia and V0 availability must refuse without invented inertia. Collision poses must come from actual compiled-model evaluation.
Proof owner: [URDF qualification](../../../../Verification/URDFQualification/DESIGN.md), with registration owned by root. Selected Native and exact portable witnesses are recorded there; broader format and Runtime requirements stay open. Independent robot fixtures must execute real decode -> transformed inertia -> compiler -> moving snapshot -> CollisionProxy and original-input export decode. Cover off-diagonal inertia/rotated COM, fixed/floating root and missing/massless moving inertia, XML failure, duplicate/disconnected/cyclic references, axis/units/version, malformed numeric grammar, mimic/transmission/law refusal, strict/loss geometry and safe asset references, all budgets/overflow/cancellation and transactional failure. The executed selected registration below fixes the current Native/WASM/Embedded evidence boundary. Source review alone is not behavioral evidence. Supplier contract changes invalidate only affected consumption paths; report unsupported lower authority instead of changing producer internals.

### Source handoff
One comprehensive source review and focused finding recheck covered real producer constructors, failure publication, root/tree pose and q/v flows, affine frame/tensor semantics, numeric/URI parsing, scalar/table budgets and the following ownership matrix. Findings fixed: nonzero decimal underflow, fixed split-slot bound, prohibition of unit/new-version pose attributes in loss mode, exact UTF8 reference binding despite native canonical String identity, node-located physical-inertia/axis failures, and complete-inertia/V0 dynamics availability. The structural scanner reports typed-throws parse limitations; it is not a Swift compile result. No build/test/probe/benchmark/profile/new test or Git operation occurred for this source handoff.

| Logical state | Native / ordinary WASM / Embedded storage and entry | Release |
|---|---|---|
| Codec suppliers/options | Same immutable Sendable values | Caller value lifetime |
| XML and semantic work | Same exclusive caller inout URDFWork / XMLWork | Caller owns counters |
| Admission tables/topology/numeric views | Same local struct/arrays and scoped borrowed UTF8 | Return/failure releases locals |
| Admitted model/document/geometry | Same immutable Sendable owned values | Result lifetime |

Open supplier/domain gaps: no enforced limits/friction/impact/mimic/URDF actuator reduction, cylinder/mesh collision law or display/material renderer, automatic asset resolution, arbitrary native-model-to-URDF export, changed runtime-state export or minimum-platform qualification. These domains have explicit refusal/loss or no callable API; they are not successful placeholders. Export covers only the producer-admitted immutable original document. Only the independently executed selected import/export/physical-consumer paths are qualified; the listed open supplier/domain gaps remain open.

### Executed selected registration
The [verification owner](../../../../Verification/URDFQualification/DESIGN.md#executed-selected-registration) binds unchanged18 production sources to real compiled moving-state/inertia/collision/dynamics and original-record export fixtures. Native all8 cases and matching seven synchronous ordinary/Embedded public witnesses passed; both portable profiles retain original131072-byte guarded execution before raw, with full decoded stack writes38484/2984 equal inserted guards. Canonical1730 production with this selected adapter and thirty-one retained cases passed all39 tests in5 suites. Root registers only this declared subset; unsupported limits/mimic/transmissions, asset resolution, broad collision/rendering, full format and accepted Runtime-state export remain separate responsibilities. Production's macOS13 compilation baseline is maintained; minimum-platform runtime is not inferred from MacOS27 execution.
