# Pinned MJCF semantic adapter

## Purpose and Scope
Parent: [Exchange](../DESIGN.md). Own selected IO-005 semantic import/export, not MuJoCo simulation equivalence. No children. Normative language is [MuJoCo 3.3.7 XML reference](https://mujoco.readthedocs.io/en/3.3.7/XMLreference.html), pinned to the [3.3.7 release](https://github.com/google-deepmind/mujoco/releases/tag/3.3.7), source tag commit f1d45bd. Selected behavioral qualification has completed on Native, ordinary WASM and Embedded WASM. Shared registration and each changed production target retain their own integration gate.

## Responsibilities and Boundaries
Own bounded MJCF interpretation, nested defaults, original node/name/entity mapping, SI conversion, explicit conversion losses and canonical retained-document export. Consume qualified XML commit873adc9, actual compiler/tree/inertia/native/affine/actuation public operations. CAD owners supply opaque BodyRepresentations/assets; this adapter never downloads, invents collision geometry or infers mass from geoms. Solver/contact/control/integration execution and rendering do not become executable metadata.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [Exchange](../DESIGN.md) | parent | IO-005 boundary | Root registration and qualification |
| [XML](../XML/DESIGN.md) | depends on | bounded XMLDocumentCoding | Restricted UTF8/no namespaces/includes/DTD |
| [Compiler](../../Modeling/Compiler/DESIGN.md) | depends on | MechanicalModelCompiling / CompiledMechanicalModel | Actual body authority, inertial and initial pose gates |
| [ArticulatedTrees](../../Modeling/Joints/ArticulatedTrees/DESIGN.md) | depends on | public fixed-anchor recurrences and coordinate layout | No private helper or assumed layout |
| [Inertia](../../Modeling/Model/Inertia/DESIGN.md) | depends on | MassProperties3D/transformed | Explicit inertial mass/tensor and physicality |
| [Actuation ports](../../Physics/Actuation/Ports/DESIGN.md) | depends on | AffineTransmission / ActuationTransmitting.affine | Original direct motor law, power-preserving gradient |
| [CoordinateEquations](../../Physics/Constraints/CoordinateEquations/DESIGN.md) | depends on | QuadraticConstraintEvaluator | Explicit bounded domain; mathematical rows, no soft solver equivalence |
| [BinaryCodec](../BinaryCodec/DESIGN.md) | depends on | NativeModelCoding.encode | Native structural export excludes MJCF sidecars explicitly |
| [MJCF qualification](../../../../Verification/MJCFQualification/DESIGN.md) | used by | original SI witnesses and selected failure contracts | Owns executable evidence, exact target scopes and retained receipts |

## Architecture
```text
owned MJCF bytes -> qualified XML codec -> iterative element adjacency
 -> inherited main/nested defaults + attributed effective fields
 -> local body/anchor/inertial transforms -> actual mechanical compiler
 -> actual compiled coordinate mapping -> affine tendons/motors/equality rows
 -> original retained document + SI records + losses + compiled model
 -> canonical XML export after actual semantic recompilation
 -> optional native structural export with explicit sidecar omission receipt
```

## Contracts and Invariants
Admit named spatial bodies, fixed world root, at most one hinge/slide per body, fixed attachments, local pos/quat, explicit positive mass and either diagonal principal inertia with inertial frame or full body-aligned tensor. No geometry inference. Each body on a moving path is dynamic; descendants of a moving body require their own explicit inertia even when their own attachment is fixed. Native generalized position is MJCF qpos minus ref; initial native q/v/a are zero, body reference poses are recursively composed local placements. Hinge refs convert compiler degree/radian to radians. Original names, IDs, source/revision, defaults and every supported original field remain in the retained XML document. Inertia is transformed through its inertial frame using the actual public mass-properties operation.

Defaults admit joint, motor, tendon, equality and material templates; nested classes inherit their parent's effective attribute tables. Explicit class wins, otherwise the closest body's childclass wins, otherwise main. Body/inertial transforms are not default-class attributes. Actuator shortcut collisions with other shortcut/general defaults are rejected. Unsupported template fields are rejected even if currently unused. Attribute provenance retains the defining original XML node and whether inherited; canonical export preserves the original defaults tree rather than flattening it.

Direct motor admits zero-state unit-gain/no-bias law, scalar gear with remaining components zero, no clamping or limits. Its signed effort gradient is an actual AffineTransmission and evaluation calls the qualified ActuationTransmitting.affine path. Fixed tendons admit nonzero linear coefficients of distinct slide coordinates only, no passive/limit laws. Length retains the sum of coefficient*ref offsets. Joint/tendon affine equality admits slide-based length units and uses deviations from each initial reference as required by the pinned specification; angular and nonlinear polynomial coefficients reject. MuJoCo soft-constraint solver semantics require explicit caller-selected loss before publishing mathematical native rows. Their finite SI coordinate/time domain, positive metre residual scale R and original-replay tolerance are supplied by the caller, never guessed. Native quadratic rows are dimensionless g=(c+a*q)/R, with coefficients a*S/R; the actual QuadraticConstraintEvaluator evaluates them. Independent original c+a*q and original gradient a are compared to supplier values*R and Jx*R/S. Initial nonzero physical residual is published, never treated as assembly success.

Selected sensors are noiseless/unfiltered scalar jointpos/jointvel/tendonpos/tendonvel/actuatorpos/actuatorvel. Caller creates state through CompiledMechanicalModel.makeState; sampling uses its actual evaluate path. Output units are SI/radian, position offsets are restored. Materials admit untextured rgba/emission/specular/shininess/reflectance descriptions and inherit defaults; rendering is explicit retained-only loss. Geometry, assets and unsupported solver/control features either reject or remain source-attributed retained-only losses selected by the caller. Includes, topology/mass inference, unknown interpreted schema, unsupported joint charts and unknown interpreted references reject even under loss policy. No loss record claims execution. Original body/joint/material/tendon/motor/equality/sensor names retain distinct deterministic EntityID namespaces and original node indices; no MuJoCo runtime numeric IDs are invented.

MuJoCo solver/integration execution is always a caller-selected loss because no MuJoCo engine is invoked. There is no implicit success for incompatible engine semantics. Export accepts only an immutable adapter-issued result and matching original stamp/source; it reinterprets the retained document through the same actual producers and requires identical native descriptor and loss mapping before encoding. It is semantic round-trip, not arbitrary mechanical-model-to-MJCF synthesis. Native structural export requires explicit sidecar-omission consent and returns an omission receipt; it uses the actual qualified native codec.

## Runtime Flows
Check work/cancel/context; decode XML; bound semantic node/attribute storage; build adjacency; admit compiler/options and loss choices; resolve defaults; construct world/body/joint/inertia records; compile; map actual tree scalar coordinates; construct native affine ports; evaluate selected equalities in the caller domain; final cancel; publish. Any failed supplier retains its actual cumulative caller ledger. Export reparses/recompiles before writing; no partial byte publication or I/O.

## State, Ownership, and Lifecycle
Immutable Sendable public source/result/policy/records on all targets. Only one synchronous invocation owns mutable adjacency/default tables/builder/ledgers. No shared cache, unsafe pointer or target-conditioned state. Retained document/native descriptor/assets preserve owners across result lifetime. XML, ExchangeWork, ActuationWork and NumericalWork are explicit supplier ledgers; semantic MJCFWork bounds its own cumulative operations/allocations and records compiler invocations without fabricating inaccessible compiler arithmetic.

## Failure, Concurrency, and Constraints
Caller bounds bodies/features/defaults/attributes, semantic operations/logical payload storage/identifier bytes plus original supplier policies. `maximumStorageBytes` owns cumulative reserved record/scalar/string payload, not allocator bookkeeping or externally retained CAD/assets/compiler storage; target heap/copy profiling remains a qualification gap. Checked count arithmetic precedes payload reservations; nested body/default traversal is iterative, depth bounded by original XML policy. Work is bounded by semantic ledger even for quadratic duplicate/default lookup paths. Cancellation applies per node/field/number/default/body/feature/query and before publication. Typed malformed/missing/duplicate/dangling/source mismatch/unsupported/loss-not-selected/overflow/resource/cancel and original XML/compiler/actuation/constraint/native supplier failures remain failures. No silent law fallback or fake resource receipts. Explicitly lost geom/asset subtrees are opaque retained XML: no MJCF engine schema validation or executable asset interpretation is claimed for those subtrees.

| Target | Mutable owner | Isolation | Release |
|---|---|---|---|
| Native / WASM / Embedded | synchronous local builders + caller inout work | exclusive value access | scope exit |
| Native / WASM / Embedded | imported result/ports/source document | immutable Sendable | value lifetime |

## Verification and Change Impact
The [qualification owner](../../../../Verification/MJCFQualification/DESIGN.md) records actual XML decode, mechanical compilation, q/v evaluation, actuation, canonical XML reimport and native decode/recompile against independent original SI witnesses. Native executed eight focused tests and seven standalone public cases. The selected committed 4d16dfd graph (1,593 production Swift files including this adapter) executed the same seven public cases on ordinary and Embedded WASM, first with the original 131,072-byte stack guard and then as raw artifacts. Full LLVM coverage counted 38,642 and 3,709 stack writes respectively, each matched by an inserted guard. These observations qualify the selected paths and graph, not every baseline feature or unsupported branch.

Canonical Native registration against committed 8614725 retained all 1,619 included production Swift files, used the exact proposed production target, and passed the original eight co-located tests. The later committed b29e152 target retained those 1,619 source bytes and added 13 committed Swift files; its exact 1,632-source incremental Native compile/link and the same eight tests also passed. This additional registration evidence preserves the earlier selected portability scope. Root owns shared indexes, manifest, PROGRESS and Git. Physical heap/copy profiling, concurrent WASI execution, full IO-005 coverage and MuJoCo numerical equivalence remain unclaimed.

| Public owner | Operation | Actual supplier boundary |
|---|---|---|
| MJCFSemanticCoding / PinnedMJCFAdapter | importModel, exportModel | injected XMLDocumentCoding, MechanicalModelCompiling; semantic replay on export |
| MJCFSemanticCoding / PinnedMJCFAdapter | exportNativeStructure | injected NativeModelCoding with explicit nativeSidecars loss |
| MJCFModelEvaluating / PinnedMJCFAdapter | sample | injected ActuationTransmitting and ConstraintEvaluating; compiled state/kinematics authority |
| MJCFImportContext | identity/source, opaque CAD/assets, finite coordinate/time/residual scales | caller authority, not inferred defaults |
| MJCFWork | cumulative semantic work and logical payload, cancellation | caller-exclusive local ledger, independent supplier ledgers |

One source review found and repaired a lower-contract mismatch: quadratic supplier rows require dimensionless g, so original metre residuals now use caller R and independent original replay. Native q/v layout equality is also explicitly established before reusing an affine gradient for both lengths and rates. No behavioral qualification follows from those source checks.
