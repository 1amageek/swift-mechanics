# Selected URDF qualification

## Purpose and Scope
Subject and requirement owner: [URDF](../../Sources/SwiftMechanics/Exchange/URDF/DESIGN.md). Children: none. Own independent synchronous public cases and focused Native Swift Testing for the existing selected URDF1.0 fixed/continuous tree importer. Root owns registration, shared package configuration, profile admission and Git. Selected Native execution evidence is recorded below; ordinary/Embedded and canonical registration remain pending.

## Responsibilities and Boundaries
Exercise real bounded XML -> URDF admission -> supplied rotated full inertia -> MechanicalModelCompiling -> validated moving snapshot -> actual analytic collider -> RigidEquationKernel -> original-admitted export. Independent SI oracles and literal expected export bytes are authoritative, not a self round-trip. Refused bounded joints, mimic/transmission, nonzero dynamics, missing moving inertia and unavailable V0 dynamics remain refusals. No new laws, asset I/O, arbitrary native-model export or source-supplier edits belong to this scope.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [URDF](../../Sources/SwiftMechanics/Exchange/URDF/DESIGN.md) | subject | URDFDocumentCoding, URDFMechanicalConfiguring, URDFCollisionConfiguring | Admitted model and immutable original document | Producer bytes must match retained module/object inventory |
| [XML qualification](../XMLQualification/DESIGN.md) | depends on | Qualified bounded XML grammar and writer | Real syntax supplier | No general XML claim |
| [Compiler](../../Sources/SwiftMechanics/Modeling/Compiler/DESIGN.md) | depends on | CompiledMechanicalModel makeState/evaluate | Actual chart/frame acceptance | Stale or foreign state must fail |
| [Rigid equations](../../Sources/SwiftMechanics/Physics/Dynamics/RigidEquations/DESIGN.md) | depends on | RigidEquationComputing and PhysicalRigidEquationComputing | Original mass, forces and energy | Preserve exact frozen historical supplier; no generalized AF31 qualification |
| [Collision geometry](../../Sources/SwiftMechanics/Physics/Collision/Geometry/DESIGN.md) | depends on | CollisionGeometryQuerying | Real sphere/box witnesses | Unsupported geometry remains explicit loss/refusal |

## Architecture
```text
independent XML + explicit SI/source/root + local work
 -> URDF protocol -> actual compiler -> moving state
                     -> supplied rotated inertia -> real equations -> scalar/force/energy oracle
                     -> analytic proxy -> real witness -> original separation/point oracle
original admitted XML -> deterministic writer -> independently authored bytes
shared synchronous cases -> standalone public entry + focused tests
actual cancelled Native Task -> every public URDF operation -> typed refusal
```

## Contracts and Invariants
| Case | Independent witness |
|---|---|
| Rotated inertia and motion | Mass2, COM(1,0,0), Rz90 full tensor has xx3, yy2, zz4, xy-.25, xz-.4, yz.3; actual q/v/a rotates/advects the child and fixed descendant |
| Real equations | Hinge plus welded payload: M=11 kg m2, gravity torque -40 N m at q0, T=22 J at rate2, inertial projection33 N m at acceleration3; original spatial momentum and power checks |
| Moving collision | Sphere radius.25 at child offset3, q=pi/2, root box half extents1: separation1.75m and independent world witness points |
| SI/root variants | Fixed shifted/rotated world pose, floating initial q/v layout and common translational mass6kg; missing static inertia and V0 dynamics explicitly unavailable |
| Original export/loss | Literal canonical bytes, comments removed and UTF8 attribute ordering; evaluated moving state cannot modify exported original document; retained assets/losses stay unresolved |
| Refusals | Malformed XML/numbers, versions/units, invalid inertia/axis, graph identity/topology, unsupported laws and unsafe asset paths are typed errors |
| Budgets | Semantic and XML count/work/storage limits, actual compiler capacity, cumulative consumed work and output failure preserve prior accepted receipts |
| Native cancellation | Await a newly cancelled Task and check decode, encode, collision and dynamics refusal; synchronous portable cases do not claim task cancellation |

Numeric expectations use explicitly fixed fixture tolerances appropriate to Double roundoff, never subject-derived values. No timeout, mass, coordinate, source or unsupported-law fallback exists. Passing selected cases does not establish the complete URDF specification or runtime engine equivalence.

## Runtime Flows
Each case builds local immutable inputs and caller-owned work, invokes public protocol requirements, compares independent expected values or exact typed failure and throws on wrong/missing behavior. Native tests await cancellation completion. Export decode is supplementary; literal byte and source semantics checks remain independent. Actual commands must have watchdogs and effective jobs4.

## State, Ownership, and Lifecycle
Native, ordinary WASM and Embedded share the same immutable Sendable fixture values and exclusive local inout work. No shared mutable static state, streams, callbacks, raw storage or unchecked Sendable is introduced. Native cancellation owns and awaits its task. Test-only conditional support import chooses isolated or co-located composition without weakening production isolation.

## Failure, Concurrency, and Constraints
Reuse the immutable original Native2363 depot read-only; verify every subject file SHA and actual object/module/source binding before linking fixtures. Preserve original historical AF31 divergence explicitly; do not claim latest-live graph compilation. Additional private fixture cache must remain at most256MiB beyond immutable prior proofs; monitor free disk and use the root-coordinated narrow fixture slot. No production cold compile or profile setup belongs to this phase. Root may separately authorize matched incremental URDF producer repairs only after an actual counterexample and subject DESIGN update.

## Verification and Change Impact
One source-path review and causal fixture correction converge before focused Native execution. Required evidence: actual compiler/link input, independent public synchronous cases, focused tests including Native cancellation, output and source SHA retained after execution, per-command watchdog/resource receipts and exact failure logs. Ordinary/Embedded portability sources will use the same synchronous cases; their execution remains separately gated. Subject semantic/source changes invalidate only affected receipts; source presence or compiler success is not physical qualification.

## Selected Native Evidence (2026-10-06)
Exact original Native2363 depot module `689c2037c5dc386fc2f19188202b892c04e7eada9b3428248f66bb1dbef1b85f` and all2363 objects were individually SHA/size verified before link and after runtime. All18 subject Swift files matched their producer source hashes and remained unchanged. Objects and metadata are borrowed directly from the immutable depot, with no duplicate producer cache. The historical original AF31 supplier divergence is retained; this is not a latest-live graph result.

The retained original-object library link succeeded. Actual verbose fixture compiler/frontend inputs include only the five frozen fixture Swift files plus generated test support; no production-source frontend inputs occurred. Native compiler is Swift6.4 RELEASE, MacOSX27.0 SDK, arm64 macOS27.0.1 runtime; subject target is arm64-apple-macos13.0 and generated Swift Testing runner target is arm64-apple-macosx14.0. Recorded actual fixture driver jobs are4. Root granted this narrow resource slot after canonical completion, with own cache128MiB and global free576MiB reaction thresholds.

| Execution | Observed result | Scope |
|---|---|---|
| Original2363 library link | exit0,0.449s,120s watchdog | Matching retained producer objects |
| Initial fixture build | exit1,4.530s | Two unsupported Foundation-only String replacement calls |
| Causal fixture build2 | exit0,9.257s | Explicit identical malformed-input generation, no Foundation dependency |
| Initial eight Native tests | seven passed,one literal-export mismatch,2.748s process | Fixture incorrectly expected self-closing empty tags |
| Causal fixture build3 | exit0,2.255s | Literal expected paired tags match qualified XML writer/test contract |
| Focused original export case | one passed,0.594s | Actual byte comparison and retained source/loss evidence |
| Final Native tests | eight passed,framework0.010s/process0.529s,60s watchdog | All independent physical/refusal/resource cases plus actual awaited Task cancellation |
| Same synchronous public cases | seven passed,0.348s,120s watchdog | Same public protocol calls and independent physical oracles |

The two fixture corrections are in `fixture-causal-repairs.json`: no production source, physical numeric oracle, tolerance or refused-law contract changed. The export expectation correction follows the already qualified XML writer's paired-empty-element contract, not a self round-trip. Initial failures/logs/freezes remain retained. Final object/module/subject/fixture hashes matched after runtime. Private observed peak99,510,674bytes is below128MiB; minimum observed shared free929,013,760bytes is above the576MiB threshold. No monitored resource stop occurred.

Standalone and library strict codesign verification succeeded; generated test bundle strict verification failed with `code has no resources but signature indicates they must be present`. The artifact was not resigned and its signature success is not claimed. Actual eight-test execution nevertheless succeeded. Linked-library identity/load commands and signature records remain distinct evidence.

Exact records reside in `.build/af35-urdf-qualification`: `reuse-freeze{,-pass-2,-pass-3}.json`, `source-review-freeze.json`, `fixture-causal-repairs.json`, `fixture-driver-proof.json`, `commands.json`, `artifact-inspection.json`, `native-qualification-receipt.json`, and original link/build/test/public/inspection logs. The same final five Swift sources are portable-ready; ordinary/Embedded compile/link/runtime, canonical registration/integration, and broader URDF law/format completeness are not established by these selected Native witnesses.

## Matching profile preparation
Root-authorized preparation owns only this section and `.build/af35-urdf-qualification/profiles`; fixture Swift and subject DESIGN remain with their owners. The original Native handoff SHA964b68c65d1c786b35d8e91b35d6db931a0f5eae6f2664de66c095683f480701 fixes subject18 and fixture5. Prepare qualified committed4d16 baseline selected1562 plus these exact18 URDF files, yielding1580 production Swift files and the same five Native-executed fixture files. No new protocol/oracle/target-specific fixture edit occurs in preparation.

The actual supplier path is BoundedXMLCodec (17 XML files), ReferenceMechanicalCompiler -> KinematicTree/TreeKinematicsEvaluator -> supplied spatial inertia and RigidEquationKernel (29 rigid-equation files), plus Core, numerical work, Loads and analytic collision Geometry/Shapes. Per-path byte equality with Native2363 is the authority; earlier summary labels do not define file counts. Preserve original qualified MachineDefinitionContext instead of Native2363's unrelated uncalled structural-authoring draft. Preserve the exact historical dynamics bytes actually executed by Native; current live AF31 repairs are a different supplier and cannot enter this frozen graph silently.

```text
qualified1562 original baseline + Native-identical URDF18 + Native-identical fixture5
 -> read-only prepared graph1580
 -> root resource lease -> ordinary SDK -> full decoded writes == guards
                            -> original131072 guard run -> unchanged raw run
 -> root resource lease -> matching Embedded SDK + explicit Unicode tables
                            -> same coverage / guard-first / raw gate
```

Prepared execution selects exact Swift6.4.0 RELEASE and matching `swift-6.4.0-RELEASE_wasm` / `swift-6.4.0-RELEASE_wasm-embedded` SDKs, wasm32-unknown-wasip1, pinned Node24.19.0, final driver jobs4 and Embedded code-generating threads4. The same seven synchronous public witness records must pass; awaited Native Task cancellation is not claimed by portable main. Setup deadline1200 and decoder/runtime deadline240 seconds. Retain original guard helper, all decoded global.set indices and counts must equal exactly the inserted global.set0 guards, reservation131072; execute guarded before unchanged raw. Unicode tables are an explicit Embedded-only linker trait; ordinary SDK uses its own runtime.

The prepared storage envelope copies the existing ExternalCommands bounded watcher exactly, recording its original/copy SHA. Admission is2560MiB global available, local nonreserve limit2048MiB, recovery reserve512MiB and reaction margin256MiB. Watcher samples allocated file blocks/logical bytes and shared free space every2 seconds, rejects observation exceeding5 seconds, and terminates the child process group before reserve/limit exhaustion or deadline. These values are an admitted operational envelope derived from adjacent completed caches, not a measured URDF temporary peak or a guarantee against other concurrent writers. Root owns execution order and capacity lease. Preparation is source-only; no full build, LLVM decode, runtime or archive starts here.

## Executed Selected Registration
Both prepared profiles executed the frozen1580 graph (qualified1562 original baseline plus exact18 subject sources) and the same final five Native fixtures. [Ordinary receipt](../../.build/af35-urdf-qualification/profiles/wasm-receipt.json) SHAe5941e6e1c469adc8b5227ac4519db41262499ac63be6d120bc11a324f073d1d and [Embedded receipt](../../.build/af35-urdf-qualification/profiles/embedded-receipt.json) SHA1782df8638b01f413b5d040504a80c3aa231c3c84f964565af481ebb1ab3251a record actual compiler/link commands, source filelists, pinned6.4.0 release/matching SDKs, final driver jobs4 and Embedded WMOthreads4. Complete LLVM stdout was consumed and byte-count/SHA retained; all38484/2984 global.set0 writes equal inserted guards. Both reservations remain131072. All seven unchanged synchronous public witnesses passed guarded before raw; the separate awaited Native Task cancellation is not claimed as portable cancellation semantics. Raw artifact hashes are eb94f06c76d7c93eb590b6c7f296317334564b15b062c6294237451e58d9905a and9eb791f8dfcc55588bf5ed945e2885f18c410932aba151f53b63ffd9b1a405aa.

[Canonical Native receipt](../../.build/af35-urdf-qualification/canonical-native-receipt.json) SHA1fdf1d93c1ca713f6f9493f35cdfc770a6192786e94795487167ac63da621b8b records original warm1712 plus selected18 source incremental build7.259s and39 tests in5 suites1.007s. Eight final URDF cases plus the31 retained AffineRigidGravity/ExternalCommands/JointStops/MJCF cases passed in the same binary. [Actual source/object/link bindings](../../.build/af35-urdf-qualification/canonical-source-object-link-bindings.json) SHAd5153552a97bcfb9061a7c585e4bb1e087adc67b6c6f61cd2e32e1e3ea6c6be0 bind all1730 production and four co-located fixture/test sources. Producer and fixtures retain macOS13 compilation; executed Native host remains MacOS27. Source18, all physical/byte oracles and tolerances were unchanged. Original fixture-only build/export-expectation failures retain their records.

No full URDF semantics, physical asset validation/resolution, minimum-platform runtime, browser/concurrent WASI, limits/mimic/transmission enforcement or accepted Runtime-state interchange is inferred. Same immutable Sendable storage and exclusive operation work apply across all tested targets; no target-specific shared-state substitution was added. Registration composes these selected contracts; the original remaining210 obligations remain open.
