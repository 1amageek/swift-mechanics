# Selected SDFormat 1.12 adapter

## Purpose and Scope
Own selected IO-004 semantic import and original-snapshot export. Parent: [Exchange](../DESIGN.md). No children. Pin the published [SDFormat specification 1.12](https://sdformat.org/spec/1.12/sdf/), not a libsdformat release number. Selected Native import/export/frame-motion/gravity is qualified by the AF37 evidence below; portable and wider format domains remain open.

## Responsibilities and Boundaries
Consume qualified restricted XML syntax (supplier 873adc9), public Core transforms, Model inertia/identity, Joints tree motion, Compiler admission and Loads uniform gravity. Admit a single world with models or one standalone model. Flatten nested models into each top-level connected spatial tree without adding artificial bodies, masses or joints. Resolve named initial-pose and dynamic-attachment graphs separately. Explicit COM inertia is rotated into each link frame through MassProperties3D.transformed; original XML is retained for export. Caller certifies source/revision, SI, inertial world, inertia quality, standalone gravity and opaque asset namespace. No filesystem, URI retrieval, CAD geometry or engine authority exists.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [XML](../XML/DESIGN.md) | depends on | BoundedXMLCodec / XMLWork | Actual bounded parse/write | Restricted XML; lexical normalization is retained, byte identity is not promised |
| [Model](../../Modeling/Model/DESIGN.md) | depends on | BodyRecord3D / MassProperties3D / SourceProvenance | Actual spatial inertia and IDs | No mass from geometry or format default is invented |
| [Core](../../Mathematics/Core/DESIGN.md) | depends on | RigidTransform / UnitQuaternion | Original transform operations | SI right-handed Cartesian poses |
| [Joints](../../Modeling/Joints/DESIGN.md) | depends on | JointRecord / JointManifold / TreeKinematicsEvaluator / FrameMotionComposer | Actual connected tree and dynamic frame attachment | Initial zero joint coordinates and floating-root rest are explicit selected profile |
| [Compiler](../../Modeling/Compiler/DESIGN.md) | depends on | MechanicalModelCompiling | Real compilation and initial pose/inertia gates | Caller CompilationPolicy bounds supplier work separately |
| [Loads](../../Physics/Loads/DESIGN.md) | depends on | AffineGravity / GravityEvaluator | Actual initial COM gravity responses | Import does not run time integration |
| [Native admission](../Admission/DESIGN.md) | coordinates with | original compiled descriptor authority | Export is associated with the admitted snapshot | Native codec and unqualified foreign siblings are not dependencies |

## Architecture
```text
UTF-8 -> qualified XML table
 -> pass 1: named model/link/joint/frame declarations + original records
 -> pass 2: pose dependencies / attachment dependencies -> two bounded graphs
 -> supplied COM inertia rotation + actual joint anchors
 -> injected qualified Compiler -> immutable scene / frame bindings / losses
 -> qualified tree motion and COM gravity operation
 -> original associated XML -> qualified bounded XML writer
```

## Contracts and Invariants
Version must be exactly 1.12. All values use metres, kilograms, seconds, radians and kg*m^2. Euler poses mean Rz(yaw)*Ry(pitch)*Rx(roll); quat_xyzw requires original unit quaternion components. Degrees are refused. Empty/missing pose is the published identity default. Link pose defaults to containing model, model pose to containing scope, joint pose to child link and frame pose to attached_to. __model__ addresses current model. Named nested relative_to references use :: within the referencing scope; no ancestor search or ambiguous global lookup occurs. world is available only in world scope (joint parent may name world). Names containing ::, reserved names and model-incompatible canonical-equivalent duplicates are refused.

Models dynamically attach to explicit canonical_link, first direct link, or first nested model; static model implicit frames attach to world. Explicit frames follow their same-scope attached_to chain; joints follow child link; links terminate attachment. Both graphs reject missing reference and cycles independently. World-scope frames may follow a model canonical link. Resolved frames retain initial world pose and fixed link-to-frame placement plus actual attachment body/assembly, so relative_to is never mistaken for dynamic ownership.

Each top model must flatten to a connected acyclic directed joint tree. Dynamic roots use actual spatialFloating coordinates at the resolved world pose, with zero initial velocity/acceleration. Static roots use fixed authority. Selected joints are fixed and continuous single-axis rotation; axis expressed_in is transformed from the named initial frame into joint coordinates. Finite limits, spring/friction/damping, sensors, geometry/material/plugin/engine fields have no executable binding here. Default policy refuses them; explicitly selected original-record retention emits losses. Unknown joint kinematics, world-parent joint, mixed nested static modes, placement_frame, include, auto inertia and spherical world coordinates always refuse. Unserved data is never entered as geometry or mass into compiled records.

All finite supplied inertia components are required for dynamic links; no format default mass/tensor is generated. Inertial pose is link-local as specified by 1.12. Gravity maps to actual AffineGravity and GravityEvaluator on transformed original COM samples; scene.frameMotion reevaluates the qualified tree and composes fixed attachment placement. Caller source equality is required for export and motion/loads. Result construction remains component-owned; original normalized XML/comment/attribute/text/unsupported record semantics are written back from that immutable imported snapshot. Export of changed arbitrary compiled models is outside this selected API.

Opaque uri/filename values are retained only under caller asset-root admission. Paths must match an explicit caller prefix ending in /, contain no .., absolute filesystem path, percent escape, query, fragment or backslash, and schemes must match caller whitelist. The original string is never resolved or opened. Includes remain unsupported even if their URI is admitted.

## Runtime Flows
Decode stages everything locally and publishes only after graph resolution, physical inertia and actual compiler success. Export checks expected source before writing retained original XML; writer validates syntax and returns complete bytes. Motion checks state revision through the original tree evaluator. Gravity evaluates original supplied masses/COM in each compiled initial snapshot with the caller LoadWork. Cancellation and failure preserve input/prior scenes; consumed semantic/XML work remains visible.

## State, Ownership, and Lifecycle
Public options, scene, bindings, losses, asset references and assemblies are immutable Sendable values. Documents own normalized strings and COW arrays; no borrowed index escapes without its document owner. SDFWork is caller-owned exclusive inout bookkeeping; all resolution/adjacency/stage arrays are local. No shared mutable state, unsafe memory or target-conditional Sendable/isolation exists.

## Failure, Concurrency, and Constraints
Caller bounds XML input/output/node/depth/payload/storage/operations, semantic named records/token/asset bytes and NumericalWork scalar/arithmetic/iteration budgets. DOM adjacency, retained semantic strings and buffers reserve the checked conservative logical upper bound nodeCount*(192+16*maximumTokenBytes)+2*XML.maximumDecodedBytes before creation; this does not count allocator overhead or the separately bounded compiler output. Bounded name/text comparisons charge their UTF-8 lengths, graph walks are iterative, and numeric/reference tokens use bounded incremental buffers before conversion rather than materializing an unbounded token list. Work is conservative charged arithmetic, not a performance measurement. Compiler and LoadWork own separate supplier budgets; no combined receipt falsely covers them. Missing/stale source, version/schema/domain/units, cycle/reference/topology, nonfinite/physical inertia, compiler, XML, budget, cancellation and unserved semantics are typed errors. Callable unsupported branches carry immediate incomplete markers and refusal or caller-selected loss.

## Verification and Change Impact
Primary published contracts: [model](https://sdformat.org/spec/1.12/model/), [link/inertial](https://sdformat.org/spec/1.12/link/), [joint](https://sdformat.org/spec/1.12/joint/), [world](https://sdformat.org/spec/1.12/world/) and [official frame semantics](https://sdformat.org/tutorials/specification/pose_frame_semantics/1.7/) (1.12 nested relative_to extension governs scoped names). Original XML writer/compiler/inertia/tree/gravity implementations and existing Compiler/Exchange/XML behavioral callers were inspected. Later IO-004 qualification must exercise nested world/model frames, independent graph cycles, dynamic attachment versus initial coordinates, rotated/off-centre inertia, actual gravity, joint axes, selected losses/assets, source-stale export, metadata roundtrip and budget/cancel failure. Build/tests/probes and new tests are deferred by current instruction. This source does not close general SDF, asset execution, sensors/contact/material laws, multiple worlds, model editing/export or IO-004 qualification.


## AF37 Native qualification ownership

Root owns the selected SDF17 implementation and five original fixture files. Historical private2353 evidence above is retained as historical evidence; unavailable original objects are not reused. The new proof consumes the committed f0325b0 baseline2124 plus independently frozen feature sources, with exact source/object/module/library binding. A direct prebuilt-module thin consumer retains Support/Public macOS13 and Swift Testing macOS14 boundaries. Seven original Native tests and the same six public witnesses own semantic frames, transformed inertia, gravity, actual q/v/a, original export, explicit unsupported losses and bounded failure/cancellation. No fixture or physical oracle was changed during preparation. Consumer allocation is bounded by one1GiB additional allocation baseline, a4GiB global free floor,2second sampling, four compiler jobs and process-group deadlines. This preparation record predates the final Native proof below; ordinary WASM, Embedded and wider IO-004 remain open.


## Qualified AF37 Native composition

The unchanged seventeen production Swift files and five original fixture files passed fresh Native qualification against the immutable actual2270-source producer: seven Swift Testing cases and the same six public semantic/physical witnesses. The consumer built in14.12seconds; tests and public process exits were zero under watchdogs. Actual Support/Public target13 and Testing target14 were observed. All2270 source bytes were rechecked after execution; producer objects, three metadata outputs and dylib remained identical. Actual fixture source-to-object maps, stable source lists, link filelists and emitted argument logs are recorded. Native receipt `.build/af38-sdf/native-receipt.json` SHA256 `2cf90e8c13138fecd399dd13cc0956bc0f9595ed0d38ac44b95892cf5673e6a0` and consumer binding SHA256 `0ed38cfd269289e1637939b79dc1b324391c39301b16cd017c0b8c2099c40c27` own the evidence. Library and public strict signatures passed. Driver temporary filelist bytes and test-bundle strict signature are not claimed; stable source lists and actual output mappings are retained. No physics, XML literals, tolerance, work or failure oracle changed. Root owns additive package registration. This selected Native import/export/frame-motion/gravity service does not qualify ordinary WASM, Embedded, minimum-version runtime or the wider IO-004 domain.
