# Structural Authoring Qualification

## Purpose and Scope
Parent: [Verification](../DESIGN.md). Children: none. This owner prepares independent public-path proof for [StructuralAuthoring](../../Sources/SwiftMechanics/Modeling/Machines/StructuralAuthoring/DESIGN.md): actual nested declarations, real gear rows, passive laws, constant relative torque and the existing mechanism consumers. The current complete registered1910 Native physical path and selected1608 ordinary/Embedded public cases are qualified below. Their source authorities remain distinct; whole-task integration and commits are root-owned.

## Responsibilities and Boundaries
Fixtures construct complete physical inputs through public declarations and policies. They never construct a compiled model, replace a physical supplier, fabricate a constraint row, invoke declaration lowering during motion or infer accepted Runtime authority. A supplied caller-owned stationary execution lease serves the actual loaded equation. Shared synchronous cases are reusable on portable profiles; the Native test owner adds an awaited actual Task cancellation case.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Verification](../DESIGN.md) | parent | Exact profile evidence | Root owns index and resource scheduling | No shared manifests or Git here |
| [StructuralAuthoring](../../Sources/SwiftMechanics/Modeling/Machines/StructuralAuthoring/DESIGN.md) | verifies | Definition, source draft, system compiler and mechanism factory | Actual public declaration-to-consumer path | Source creation alone is not behavioral proof |
| [AffineEvolution](../../Sources/SwiftMechanics/Physics/Mechanisms/AffineEvolution/DESIGN.md) | depends on | Actual motion and loadedMotion | Original constrained equations and momentum checks | Fixed-root scalar charts and nonempty real gear rows |
| [IdealNetworks](../../Sources/SwiftMechanics/Physics/Transmissions/IdealNetworks/DESIGN.md) | verifies composition | Original signed physical and normalized gear rows | Reaction map checked against independent mechanics | No tooth/contact or moving-support claim |
| [StationaryLoads](../../Sources/SwiftMechanics/Physics/Mechanisms/StationaryLoads/DESIGN.md) | depends on | Catalog and caller execution ledger | Original passive force/energy/dissipation consumption | Caller retains lifecycle and selection authority |

## Architecture
```text
complete nested Machine declarations -> real structural draft -> original model compiler
                                                      -> original gear compiler
                                                      -> passive catalog / actuation port
                                                      -> actual mechanism equation
independent two-rotor inertia/torque/energy equations -------------------+-> assertions
original typed refusal and retained caller ledgers ---------------------+
```

## Contracts and Invariants
The independent reference has two rotors with COM at their origins and polar inertias 2 and 4 kg m^2. The external gear teeth are 20 and 40, so v2=-v1/2 and a2=-a1/2. For a 6 N m first-joint torque, effective inertia is 2+4/4=3 kg m^2; a=(2,-1) rad/s^2 and reaction=(-2,-4) N m. At v=(2,-1), kinetic energy is 6 J and drive power equals kinetic power, 12 W. These constants are authored independently of supplier result fields.

For the declared first-joint spring/damper k=10 N m/rad, c=1 N m s/rad, q=(0.4,-0.2), v=(2,-1), its force is -6 N m, potential 0.8 J and dissipation 4 W. With 9 N m drive, acceleration is (1,-0.5), kinetic power is 6 W and potential rate is 8 W; total energy rate 14 W equals active power 18 W minus dissipation 4 W. Assertions consume the actual loaded equation's returned system, force channel, energy and motion.

Signed/phase cases include internal meshing and antiparallel parent mounts, nonzero phase and nonunit coordinate/time scales. Joint declaration order is reversed to expose accidental lexical packing. Nested placement and two explicit anchors must act once. Scoped IDs retain EntityKind and explicit namespace identity; labels and unsupported wider laws are not invented.

The seven shared cases cover: declaration/layout/source identity; independent signed/phase placement; real constrained acceleration and nonzero reaction transfer; passive energy and loaded motion; explicit physical/model-only/unsupported failure; capacity and retained ledger failures; independent scoped definitions and legacy context cleanup. The Native wrapper additionally awaits actual cancellation before invoking the public system compiler and checks failure before caller numerical work is consumed.

## Runtime Flows
Each case owns fresh immutable declarations and independent inout ledgers. Only the compilation helper invokes the declaration builder; real equation motion consumes retained compiled records. A loaded case creates and closes its own original StationaryLoadExecution. Native setup borrows the root-authorized immutable producer module and original object paths directly, then compiles only fixture sources and links one library shared by tests/public entry. No object copies or production compiler run belongs to this owner without a causal root assignment.

The unloaded equation is consumed by the original explicit RK4 integrator and an original caller-created RuntimeSession/continuation; the factory receives no Runtime ownership. At t=0.2 s the independent constant-torque endpoint is q=(0.84,-0.42), v=(2.4,-1.2), with kinetic energy 8.64 J and drive work 2.64 J. The caller closes the session. Independent reaction assertions additionally consume the real retained network through the original evaluator, rigid kernel and constrained solver; no test-written physical row is supplied.

The direct rigid-kernel reaction fixture binds caller inertia records in the actual admitted tree-body order, resolving each complete record by its original EntityID. The first Native run exposed descriptor-order binding as `inertiaIdentityMismatch`; this fixture-only correction preserves every inertia value, physical oracle, tolerance and production source.

## State, Ownership, and Lifecycle
Fixture enums have no shared mutable fields. Every numerical/load/actuation ledger and execution lease belongs to one case. Cancellation executes in an awaited child Task; no timing sleep, detached task, static cancellation flag or platform-specific synchronization substitute is introduced. The compiler supplied immutable depot remains read-only.

## Failure, Concurrency, and Constraints
Native commands require root scheduling, jobs 4 and watchdogs (setup 900 s, tests 60 s, public 120 s). Private additional bytes are at most the root-assigned envelope; shared free space must preserve the root reaction reserve. No blind retry or oracle/tolerance adjustment follows a failure. A concrete failing original value identifies whether the fixture, this source owner or a lower owner must change. Every actual initial failure and causal recheck remains recorded.

## Verification and Change Impact
Preparation receipts remain source-only evidence. The recorded selected and complete registered Native executions below add actual behavior proof. Freeze subject and fixture SHA before the released Native slot; match all subject source bytes to the selected original compiled snapshot or obtain an explicitly matching producer. The same seven synchronous cases run in the test suite and public entry. Native runtime results do not establish portability or accepted integration. Root owns progress, registration and commits; this owner reports exact receipts and any source counterexample.

Native fixture composition keeps the macOS13 package baseline. Swift Testing rejects availability annotations on its suite macros, so each test guards the actual consumer API availability and throws explicit failure below macOS15; the current host satisfies that API contract. Production availability is unchanged.

## Selected Native Evidence
| Gate | Actual evidence | Scope |
|---|---|---|
| Matched producer | Original2363 with repaired Attachment13 and this factory comment1, current complete module and source-object bindings | Compiler authority only; historical unrelated AF31 divergence retained |
| Single library | Direct readonly2363 object response, no object copies, link exit0 | Same library for public entry and tests |
| Final Native tests | Eight passed, including awaited actual Task cancellation, process0.372s/framework0.005s | Selected fixed-root two-revolute physical composition, failure and accounting contracts |
| Public entry | Same seven synchronous cases passed, process0.373s | Original physical oracles and refusal/work checks |
| Causal fixture repairs | Explicit BodyRepresentations try, macro-compatible per-method API guard, tree-order inertia binding | No production body, oracle, tolerance or supplier change |

Original failing compiler/test logs and final input/output binding receipts are retained in `.build/af35-structural-authoring-qualification`. Private observed bytes92.9MB remain below128MiB and all observed free-space samples exceed640MiB. Ordinary WASM, Embedded, other joint charts, source registration, commit and whole-task integration remain separate gates. No current-live-whole-graph or portable behavior claim follows from these Native cases.

## Prepared Portable Graph
The authoritative committed4d16dfd profile selection admits1562 baseline Swift files. The selected portable composition replaces its older MachineDefinitionContext at the same path with the exact current Native-bound exclusive call-local context, adds the37 actual StructuralAuthoring sources and the separately qualified committed AffineRigidGravity8 sources:1607 production Swift files. All1561 other baseline bytes remain unchanged. AffineRigidGravity is an explicitly root-selected qualified addition; it does not silently import its complete producer graph or introduce gravity into these gear fixtures. New repaired Attachments13 and unrelated AF31 changes are excluded.

Shared synchronous fixture sources are copied byte-identically from the final Native-executed owner; Native awaited cancellation is not generalized to WASI. The prepared private manifest includes an Embedded-only Unicode library trait, exactSwift6.4.0 RELEASE ordinary/Embedded matching SDK identities, jobs4 and Embedded code generation threads4. Future execution requires a root lease, original131072-byte stack guard over every decoded global.set0 (guarded before raw), bounded build/decoder/runtime deadlines and exact source/module/body authority. Preparation does not invoke a compiler, linker, LLVM decoder or runtime and does not qualify either portable profile.

## Prepared Portable Execution Gates
The profile runner refuses execution until the root's canonical Native binding supplies exact receipt/log hashes, eight passing tests, seven passing shared cases, all final six fixture Swift hashes, macOS13 registration proof, all37 current Structural source hashes plus the exact Context replacement and the separately qualified8 gravity hashes. It also retains the completed matched-depot Native receipt as earlier selected-path evidence; that receipt is not silently promoted to canonical registration.

The byte-identical Native public entry emits one summary only after calling all seven throwing cases in order. Prepared validation checks each of those seven calls occurs exactly once in the frozen entry and requires exactly one corresponding successful summary in guarded and raw output. This preserves the Native-executed fixture bytes rather than adding unexecuted witness prints. Native cancellation stays a separate eighth test.

The runner captures the real WMO frontend filelist while the compiler runs, requires all1607 exact paths and threads4, records all emitted driver/frontends and object/module hashes, then performs full LLVM disassembly and audits every global.set index. Only after global0 decoded-write counts equal the inserted131072-byte guards does it execute guarded before unchanged raw. Preparation uses the original guard, WASI runner and bounded watcher unchanged; no cache cleanup, retry, source fallback or compiler suppression is provided.

## Bounded Pair Causal Native Evidence and Portable Preparation
The accepted MachineBuilder inferred return type changes to the non-generic ErasedPairMachine; explicit TupleMachine is unchanged. The selected original1797-plus-Pair producer has1798 exact sources, complete module emission,240 source-bound primary objects and1558 unchanged original objects. Reconstructed source bytes were unchanged for238 causally displaced objects. The one library serves fresh original6 Structural fixture sources, unchanged12 legacy sources and2 added Pair test sources. Actual22 tests (Structural8,legacy12,Pair2) and the original shared7 public cases pass; the current HEAD graph is not covered by this selected result.

[Native binding](../../.build/af35-structural-authoring-qualification/builder-pair-native/consumer-final-binding.json) owns the source/object/module/library authority. Initial planner representation, monitor rename race, fixed128MiB resource stop, mistaken test build-system selection and redundant direct public SDK-cache variant failures remain preserved. Lossless restored dependency/index retention and direct read-only SDK cache reuse close that resource gap without source, object, oracle or tolerance changes. Final observed private allocation130830336 bytes is below the fixed23531520-byte baseline plus128MiB; NativeB is released.

The new selected portable graph is the original1607 source/fixture snapshot plus only the frozen MachineBuilder replacement and new ErasedPairMachine:1608 sources. Original1607 RED artifacts, diagnostics and sourcefreeze remain unchanged. Source copies preserve the exact Context replacement and qualified AffineRigidGravity8 authority; all other baseline bytes and the original six fixture bytes remain unchanged. No current HEAD source cohort is imported.

The separate prepared runner performs full LLVM stdout streaming SHA/byte counts and all-match global.set Counter coverage through EOF, retaining no large plaintext disassembly. Every original write must exactly equal inserted131072-byte guards. Guarded success precedes raw execution of the same seven original throwing calls; Embedded additionally requires ordinary success and matching SDK WMO/codegen threads4. A root execution lease is required before any compiler or decoder. Its fixed per-lease baseline permits at most640MiB new private allocated bytes and retains768MiB global floor plus256MiB Native headroom: minimum1664MiB admission. It never resets the baseline during a profile. Preparation and selected Native success do not close the original portable metadata-stack counterexample.

## Selected1608 Ordinary Counterexample Closure
The original seven synchronous physical/refusal/resource cases now pass under the unchanged131072-byte guard before raw execution. The selected1608 frozen graph changes only the accepted builder return and new Pair relative to the original1607 snapshot. Full original LLVM stdout406963783 bytes was streamed and hashed through EOF: every39112 global0 writes exactly matches39112 inserted checks. Guarded and raw exits are both zero; original fixture bytes, independent oracles and tolerances are unchanged. Embedded was still pending at this ordinary checkpoint; its completed evidence follows below.

[Ordinary final binding](../../.build/af35-structural-authoring-qualification/profiles-builder-pair/ordinary-final-binding.json) owns all1608 source/object hashes,1616 link inputs, module metadata and runtime receipts. Official index generation is disabled; exact emitted WMO supplementary-map Make dependencies and module dependency-path outputs alone are omitted. Other source/SDK/semantic/frontend arguments are retained. The original failed planning wrapper attempt and its causal unmodified-manifest-wrapper continuation are preserved; production module/codegen were not repeated. This is actual selected-job compile/link evidence, not a successful whole SwiftPM build claim.

The fixed32432128-byte lease baseline observed190717952 additional bytes, below640MiB. Minimum sampled free space1743249408 bytes exceeds the768MiB floor plus256MiB Native headroom. Samples occur every2 seconds; this does not claim an exact continuous transient peak. Large Make dependency outputs and plaintext LLVM disassembly are absent. Heavy lease is released.

## Selected1608 Embedded Closure and Operational Admission
The same selected1608 sources and original seven physical/refusal/resource cases pass in matching Embedded Swift6.4.0 WASM. Actual complete module emission, WMO codegen and original emitted wrapper/consumer/link jobs pass. Official Embedded Unicode tables are linked. Complete original LLVM stdout61770850 bytes is streamed through EOF; every5185 original global0 writes equals5185 inserted131072-byte guard checks. Guarded cases pass before the unchanged raw artifact. Neither source, fixture, oracle, tolerance, stack reservation nor SDK semantics changes during this execution.

[All selected profiles binding](../../.build/af35-structural-authoring-qualification/profiles-builder-pair/all-selected-profiles-final-binding.json) owns exact1608 source/object bindings,1616 link inputs and9 target module metadata records before/after behavior. The original ordinary production objects/modules remain exact after Embedded. Ordinary raw/guard assets are recoverably relocated under root authority; Embedded reads the ordinary successful receipt/sourcefreeze/guard decision, not those artifact bytes. Old failed1607 proof remains preserved.

Root explicitly holds NativeA and permits only one NativeB128MiB allowance during this Embedded lease. Fresh admission is1536MiB=640MiB output cap+768MiB global floor+128MiB Native headroom. Historical two-Native1664MiB preparation is retained unchanged; this is an operational lease change, not a source/semantic change. The fixed129552384-byte baseline observes374153216 bytes growth and minimum sampledfree1297694720 bytes, above the939524096-byte floor/headroom reaction boundary. Sampling is every2 seconds, at most5 seconds per sample; exact continuous transient peak is not claimed. Heavy lease is released.

Selected1798 Native22 tests/public7 and selected1608 ordinary/Embedded seven cases now close the original bounded-stack counterexample. Complete registered1910 Native now provides the separate current root composition proof below. Whole-task integration still belongs to root. Frozen production comments remain unchanged by root instruction; unsupported domain markers continue to document callable refusals.

## Complete Registered1910 Native Evidence
The root applies exactly the frozen Machine40 production changes:37 child sources and new Pair1, plus existing Builder/Context replacements. The qualified predecessor is full registeredTime1872 at commit `cfb0a2c09441f72dc5827fec9ffa47af6b4c76bb`;38 added paths produce1910 selected production sources. Historical excluded Swift files retained physically in the canonical package do not enter the actual SwiftPM source list. The frozen source map is `ccfc62f480aaba2e400b4d6d063f063fba0f1ebdedde2e5ca35d2a9f33c8b463`.

The actual warm supported SwiftPM Native build emits the complete1910 production module and53 production primaries, including every40 changed/new owned source. All20 unchanged fixture sources freshly compile. Every retained production object must match its predecessor source and object SHA; both actual test and public link responses contain all1910 production objects. No selected1798 foreign module/library is linked into this registered result. The macOS13 package/target remains unchanged; individual consumer API guards explicitly require macOS15 where necessary on the tested host.

| Gate | Result | Authority |
|---|---|---|
| Complete registered Native | Structural8 + unchanged legacy12 + direct Pair2 =22 passing tests; same7 public cases pass | [Actual receipt](../../.build/af35-structural-root-registration-preparation/registration1910/canonical-native-receipt.json), SHA `f9c5544e938d201eac506d27668e21e6bcdbc62f06568edd96e81973c73100f5` |
| Source/object/link binding | Complete1910 inventory, fresh current module, all40 owned and20 fixture primaries, both actual link responses and post-behavior matching | [Bindings](../../.build/af35-structural-root-registration-preparation/registration1910/canonical-selected-bindings.json), SHA `aebe6dca006214544941f8c20e105e477998e5d3f72489c4f77a261eecee2db0`; production inventory SHA `1084a37cec7544e8449e65ff7b857624262e63c0cb1ce7ff59a9c9b00c4fc1e2` |
| Portable selection | Original7 ordinary and Embedded cases pass guarded before raw; original131072 stack reservation unchanged | [All selected profiles binding](../../.build/af35-structural-authoring-qualification/profiles-builder-pair/all-selected-profiles-final-binding.json), SHA `c339e02617ec4afed060b407c8f2d5f101f7d0dbb089cadc8c617a56a4857485`;39112 ordinary and5185 Embedded original global0 writes exactly equal inserted guard checks |

The Native lease fixes its starting allocation at951341056 bytes and allows at most128MiB new growth, stopping at112MiB; admission896MiB, floor768MiB and stop784MiB remain unchanged. Samples occur every2 seconds; exact continuous transient peaks are not claimed. Public strict code-sign verification exits0; the SwiftPM generated test-runner strict resource verification exits1 and remains a separate recorded tooling limitation, not a concealed successful signature check.

The original executed binding remains immutable: its unused `predecessorQualifiedReceiptPath` inherited a Rolling path, while the actual used `predecessorQualifiedReceipt` and frozen predecessor receipt/inventory point to the verified Time result. [Metadata correction provenance](../../.build/af35-structural-root-registration-preparation/registration1910/execution-binding-metadata-correction.json) records the discrepancy without rewriting execution history, source, argv or outputs. This Native1910 proof and selected1608 portable proof close their explicit obligations; they do not qualify unrelated registered components or the broader parent catalog.
