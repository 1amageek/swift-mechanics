# Tire Laws Qualification

## Purpose and Scope
Parent: [SwiftMechanics](../../DESIGN.md). No children. Own independent selected evidence for [TireLaws](../../Sources/SwiftMechanics/Physics/Vehicles/TireLaws/DESIGN.md) IM.AF34.7. The selected Native path passed in the complete registered1841-source graph with unchanged original fixtures. Ordinary/Embedded WASM also passed the original seven synchronous cases in the separately frozen1573-source graph; this is not the current full registered portable graph. This is not empirical calibration validation, transient tire/terrain/contact assembly or full EX002 closure.

## Responsibilities and Boundaries
Construct public immutable frame/calibration/sample/policy inputs and invoke TireRoadEvaluating. Independently check SI slip, force, moment, shared cone and actual wheel/road work, plus original typed failure/consumed-work lifetimes. No fabricated normal load solve, stored tire energy, alignment torque or integrated history is inferred. Original source explicitly defines radial-brush-v1; Chrono comparison is already pinned in production DESIGN and does not name this different radial combination Fiala.

## Related Designs
| Design | Relationship | Contract used | Cautions |
|---|---|---|---|
| [TireLaws](../../Sources/SwiftMechanics/Physics/Vehicles/TireLaws/DESIGN.md) | verifies | TireRoadEvaluating, explicit calibration/domain/slip/response/error | Supplied positive normal load; tangential law only |
| [Core Geometry](../../Sources/SwiftMechanics/Mathematics/Core/Geometry/DESIGN.md) | depends on | finite Vector3/UnitQuaternion | Literal90-degree force/power oracle does not rotate returned results with producer math |
| [Core Spatial](../../Sources/SwiftMechanics/Mathematics/Core/Spatial/DESIGN.md) | depends on | SpatialWrench/SpatialMotion | Independent scalar pair power at explicit references |
| [Model Identity](../../Sources/SwiftMechanics/Modeling/Model/Identity/DESIGN.md) | depends on | exact ModelReference including revision | Metadata equality charges before comparison |
| [ForcePorts](../../Sources/SwiftMechanics/Physics/Loads/ForcePorts/DESIGN.md) | depends on | FramedPointLoad, ForceParts, LoadWork/LoadBudget | Nonzero prefix preserved on failure |

## Architecture
```text
synthetic exact coefficients + world/road/tire identity + original physical motion
    -> public TireRoadEvaluating -> actual returned wheel/road/point loads
    -> literal or independently factored scalar mechanics witnesses
    -> original typed rejection and exact work-prefix witnesses
shared seven synchronous cases -> Native executable and Swift Testing
Native owned Task cancellation -> caller Task-aware LoadBudget callback
```

## Contracts and Invariants
Ck1000N, Ca2000N, mu.5, ell.02m, R.5m, Fz200N define a synthetic analytical reference; L100N and rolling capacity4Nm. Speed10m/s, spin20rad/s is pure rolling. The radius, load, velocities, slip and spin envelope is explicit and separately tested. No empirical defaults or measured-fit claim is made.

| Case | Independent SI scalar witness |
|---|---|
| Zero/pure curves and load | Pure rolling force0/rolling4Nm/loss80W. Q/L1 force1900/27N, Q/L3 saturates100N, both signs. L50/Q100 gives1300/27N; separate small-slip slopes1000/2000N |
| Unequal mixed stiffness | kappa.03/tangent.02 gives q=(30,-40)N, Q50N, magnitude2275/54N, force=(455/18,-910/27)N, slip loss1547/108W. Saturated q=(300,-400) returns(60,-80)N with shared100N cone |
| Signed travel/rolling jump | Reverse braking/traction use abs(vx) denominator and oppose actual surface slip. At spin0 rolling moment/loss0; one-sided spins give moments-4/+4Nm and nonnegative loss |
| World wrench/moving road/boost |90-degreeZ maps F to(910/27,455/18,0), center torque to(599/36,-455/27,0); road rolling couple(-4,0,0). For translating road(3,-2,0), power=-455/9W. Pair balances independently with physical slip+rolling losses; common boost preserves pair/losses |
| Calibration/arithmetic | Formulation/kind/domain/coefficient failures preserve exact errors. Individually finite demand components1.7e308 overflow combined norm and nonzero slip times least-nonzero stiffness underflows, requiring failure |
| Geometry/revisions/envelope | Exact frame/tire/road/calibration revisions, center-radius plane, relative normal speed, low-speed/radius/load/spin/slip bounds; no clipped success |
| Work/cancellation/lifetime | Exact charged metadata UTF8 byte total plus one law unit;192 scalar admission, budget failure prefix and cancellation before work. Older immutable response retains sample/calibration even after later calls |

Independent magnitude is L times one minus the cube of remaining adhesion fraction, and literal anchors support it. Tolerances for assertions are1e-8 relative to max(1, magnitude). Producer power/cone tolerances remain1e-8 absolute and1e-11 relative, geometry/normal-speed1e-10. No returned acceptance residual is a force/power oracle. Negative losses or original cone excess are not silently clamped.

## Runtime Flows
Each public case owns a protocol law, explicit sample/frame/calibration/policy and exclusive LoadWork. Typed expected-error operations preserve TireLawError without casts, default replacements or partial successful response. Native cancellation uses local gate/owned Task, cancel before evaluation and await completion; the callback reads Task.isCancelled. It proves the caller callback boundary, not implicit cancellation with an unrelated callback.

## State, Ownership, and Lifecycle
All producer/fixture inputs and responses are immutable Sendable values. Exclusive local inout LoadWork preserves charges across multiple calls. No shared counter, cache, raw storage, Mutex, actor or platform conditional Sendable weakening is introduced. Native cancellation stream is local, finished on exit, and Task awaited. MacOS13 needs no extra availability annotation because fixtures do not use Mutex.

| Storage | Native | WASM | Embedded |
|---|---|---|---|
| Frame/calibration/sample/response | Immutable Sendable | Same source | Same source |
| LoadWork | Local exclusive inout | Same | Same |
| Native gate/Task | Separate owned async source | Outside shared synchronous cases | Outside shared synchronous cases |

## Failure, Concurrency, and Constraints
All loops have fixed finite witness counts and bounded original LoadWork. Metadata limits are exact UTF8, not grapheme counts. No retry or budget reset after failure is used as proof of consumed work. Historical selected preparation used exact original2363 read-only producer bindings. The complete registered Native execution instead used the fresh1841 module and all matching objects, with unchanged eleven subject source hashes; no Terrain supplier is called. Root serialized the warm canonical run with additional128MiB growth budget,768MiB global free floor, finaljobs4, build900/public60/Testing60 process-group watchdogs. Selected portable compiler/decoder/runtime results are recorded below; subsequent full registered portable composition remains a different proof.

## Verification and Change Impact
Read complete RadialBrushTireLaw evaluate/accept/chargeMetadata and all public calibration/domain/frame/sample/response/error/work producers, original ForceParts/FramedPointLoad/SpatialWrench and existing VehicleLawsQualification cases. Existing equal-stiffness Vehicle Native proof remains valid in its original domain; new anisotropic/load/arithmetic/exact work/lifetime witnesses are not generalized from it. Source counterexamples require production child DESIGN first and root coordination of matching objects/module. Native behavior, signing, ordinary/Embedded WASM profiles and final registration commit are distinct evidence. The actual Native records below qualify their selected executed path; portable preparation does not qualify a target.

## Selected Native Behavioral Evidence
Root released NativeA after preparation. Original2363 retained objects and matching module were used directly through one privately linked SwiftMechanics dylib; all2363 objects,3 metadata and unchanged Tire11 source bindings were verified. Six actual fixture-only Swift drivers ended with jobs4; no production frontend input or replacement producer was compiled. Public seven synchronous cases plus separate caller-owned Native Task cancellation and all eight Swift Testing cases passed with original independent oracles/tolerances. Original Tire Swift11 remained unchanged; no physical counterexample was observed.

Native6.4 required explicit TireLawError annotations on seventeen expected-error trailing closures; only those fixture signatures changed. Initial RED log/source and repaired freeze are retained. No cast, oracle, threshold, model, supplier or failure case changed. The grouped source review and focused signature repair recheck are in the private receipts. [Native qualification receipt](../../.build/af35-tire-laws-qualification/native-qualification-receipt.json) SHA-256 c5392121db0d8d6283d4ad83c30ccd47198510e39cb048f814957c24964a7fd9. This records selected Native behavior, without ordinary/Embedded WASM, registration or full leaf closure.

| Native artifact inspection | Actual result |
|---|---|
| Public executable strict codesign | exit0 |
| Privately linked original-module dylib strict codesign | exit0 |
| Generated test runner strict codesign | exit1: code has no resources but signature indicates they must be present; retained without resigning |
| Public runner / Swift Testing | exit0 / exit0, all8 tests passed |

Process-group watchdogs remained120s link/900s fixture build/60s public/120s tests. Observed minimum free1,473,900,544 bytes exceeded root640MiB reserve and maximum own allocated97,181,696 bytes was within128MiB; no timeout/resource refusal occurred. Signature discrepancy is a separate artifact result and is not converted into behavioral or release success.

## Historical Portable Profile Preparation
Private preparation in `.build/af35-tire-laws-qualification/profiles` selects qualified committed baseline1562 plus the exact unchanged original Native-executed Tire11 for1573 production Swift paths. The three Native-green common fixture Swift files are copied unchanged; all six final Native fixture Swift hashes remain frozen. A private synchronous entry point calls the same seven public methods. Native awaited Task cancellation is excluded from portable synchronous scope and remains a separate Native proof.

| Prepared public path | Original supplier authority |
|---|---|
| Explicit sample/calibration/frame/policy -> TireRoadEvaluating.evaluate | Exact original2363 Tire11 source/object binding |
| Original local velocity/slip -> radial shared friction force | Qualified Vector3/UnitQuaternion/ScalarMath; all actual fourteen direct supplier source bytes match |
| Force/lever arm/rolling -> wheel/road power and point load | Qualified SpatialWrench/ForceParts/FramedPointLoad, original exclusive LoadWork and immutable identity/reference |
| Portable graph composition | Committed4d16dfd baseline; one original MachineDefinitionContext difference is recorded and uncalled by this direct path. No Terrain dependency |

Pinned release6.4.0 and matching ordinary/Embedded WASM SDK metadata, private manifests, finalj4/WMO threads4 argv, full LLVM decode coverage and the existing successful Convex guard/runner template are prepared only. Acceptance requires the counter of ALL original decoded global.set operations to contain only stack global0 and equal the inserted immediate guard count, count positive, and original initial minus lower exactly131072. All seven original calls must pass the guarded artifact before raw runs; raw bytes/hash remain unchanged. No reservation, oracle, model, tolerance or backend weakening is introduced.

At preparation, no compiler, LLVM decoder, instrumentation, runtime or archive had started. Root subsequently admitted the selected execution below and committed Native registration01384c2. That preparation alone did not qualify a target; current full registered portable composition and full EX002 remain separate conditions. Original Native receipt/handoff and executed DESIGN remain immutable private evidence; the source freeze records the exact1573 paths, subject11, three common fixtures, all six Native fixture hashes and metadata/helper digests.

## Historical Registered Source Integration Preparation
Integration candidate authority is full committedHEAD5aa868a9033841ace4b8a238c511cacafb20de56, obtained from committed manifest and all registered source blobs, not current WIP or the historical warm subset. ActualHEAD1796 plus unchanged original Native Tire11 gives1807 before root serial Hex/TaskSpace integration; root refreshes this base before execution. Historical warm1774 omits22 registered InvariantHyperelasticity/NonlinearKinematics sources and has an older FiniteStrainKinematics body. That proof remains historical and is not substituted for the complete candidate module. Original Builder/context and all fourteen directly called Tire lower suppliers are retained byte-identically. This path calls no Terrain model.

Private candidate manifest adds Tire child DESIGN exclusion, dedicated support/executable/test targets consuming exact six Native fixture Swift files, and no production/source/oracle changes. Candidate metadata stores committed blob/source digests without production byte copies. Root alone owns shared canonical cache mutation. A future Native consumer requires actual fresh complete candidate object/module/source receipt binding and root serial NativeA lease; missing gate fails before process start. The128MiB incremental consumer forecast is a bound, not a measured claim. Full candidate compiler closure/final registration remains pending. Unchanged original Native8/public7 evidence remains immutable.

Upcoming portable LLVM coverage may produce hundreds of MiB of plain text without changing its all-write proof. A separate prepared streaming decoder uses the URDF-validated TaskSpace process method: hash every stdout byte through EOF, count ALL global.set matches, retain only four contexts, retain stderr and original process exit, then compare the complete Counter to inserted guard count. Original plain-decoder preparation remains retained. Stack reservation131072, exact release SDK, guarded-before-raw ordering and original seven assertions remain unchanged; streaming preparation is not Tire profile execution or a successful canonical gate.

## Historical Registered6e592cb Candidate Refresh
The prior1807 preparation remains unchanged. Latest distinct candidate uses full committed6e592cb1714bc1a061adf2d97bd1d06ebea48540: registered1830 plus the exact unchanged Tire11 for1841. Root TaskSpace canonical receipt b2f1a9809beaaf0eacf608beb0f96c094af6b65e4b6c74669e9b15d5175f01fe and production inventory d5f27d469c5430ca7f1c40ed1f580bb8ecc714d13500fabb5cae3bc6f75865b9 establish the1830 source/object/module bindings. Every listed1830 source/object and metadata digest was checked against current actual files; all fourteen Tire lower supplier sources equal original Native2363.

The full1841 candidate binding records1830 actual original bindings and11 source-frozen pending fresh emission separately. Original2363 Tire objects are historical evidence and must never be linked against the1830 module as1841 proof. Root must first establish the fresh complete1841 source/object/module producer before the gated narrow consumer or registration proof. Exact original fixture6/Native8/public7 and all oracles remain unchanged; no compiler or heavy Tire profile starts during this refresh. Root patch inventory includes only Tire11, fixture6, their two child designs and the minimal committed-manifest candidate. Shared cache/manifest mutation remains root-owned.

## Complete Registered Native Evidence
Root executed the warm canonical package after its minimal registration patch. The full committed base is6e592cb1714bc1a061adf2d97bd1d06ebea48540: all1830 registered production sources plus original Tire11 give1841. This result supersedes the pending status of the historical preparations above. The predecessor1830 module was not combined with historical2363 Tire objects: all11 added primaries were actually emitted, the complete1841 production source/object inventory and fresh module were checked, and all selected source/object bindings were matched before linking. The six original fixture Swift files, independent equations, calibration, tolerances and error/work oracles remain unchanged.

| Actual evidence | SHA-256 / result |
|---|---|
| [Canonical Native receipt](../../.build/af35-tire-laws-qualification/integration/registered-6e592cb/canonical-native-receipt.json) |330df10fba26318b3e0881545d2c787d0ee23ccb764757dc37df4db58695803f |
| Full1841 production object/source inventory |e862319bc43945913c7115c25d6c4c91ef6de4fbe7d7d4139f86d858f0c44556 |
| Fresh SwiftMechanics module |84bcfe3fcddec3cdc79cbca82f2b50d73cd5227d6b9493492f8193fcd64b93f6 |
| Warm source freeze |e4ce065e0208df6e84db943a49bd7edace9160215c4c5ebf01dca4b2b081b0c6 |
| Selected actual source/object/link bindings |6d3c1dd189d35fe15c893b1f2a66d92e7e4193a052cc4f4e1ef7370405e29477 |
| Six unchanged fixture Swift aggregate |19d9d9b936e87d74e66f692edb59d62d78f003a2fb2feb87af9febe45c20b48d |
| Public link file list |b4b9df5426ab7133484186f9a506956c54dc1048b1d70b8fcd7a9554b5d52a7b |
| Native build, jobs4 / deadline900s |exit0,15.701s |
| Swift Testing8 / deadline60s |exit0,2.030s; all8 passed |
| Already-built public7 plus Native callback / deadline60s |exit0,0.471s; no redundant public recompilation |

The toolchain was pinned Swift6.4.0 release, Native arm64/macOS13 registration. Root registered the original four support sources, separate Runner executable and separate Tests target with disjoint source lists. Shared Package adds Tire11 and excludes only its child DESIGN; unchanged existing1830 production sources remain included. Candidate shared manifest SHA359a46e2c2b18b79af6311b2422706ff3bfa8c808d7808181cea7a43e401b4d1 and private canonical manifest SHA433b62f54cf9a1bf5995c99b741744241740b38329ab7ef48e878a395b28242e preserve those boundaries. Root owns shared staging/commit and subsequent base changes.

The focused production review read the actual constitutive/acceptance/metadata path, immutable public records and local exclusive work, and checked the selected live source/object/link bindings and all three fresh module metadata digests. It found no selected-contract blocker. Original guards reject unsupported low speed, geometry/revisions/envelope, invalid calibration/policy, nonfinite demand/capacity and physical acceptance; cancellation preserves original LoadWork failure instead of issuing a response. Native Task cancellation remains caller-supplied through LoadBudget. No shared mutable storage, conditional Sendable weakening or target-specific raw storage is introduced. This review does not claim newly executed LLVM stack instrumentation: the original131072 guard-first/raw portable plan remains preparation only.

The actual public artifact SHA isf367c07ed9df495bebde3ae7ac8936113a1ae53d1032b1ca43615c44c55bb28e; generated test artifact SHA is8c759c414e8319235c980f0c5f20bc1fb664550975657d5b02ade476f2d60471. The run records resource sampling every2s and explicitly leaves between-sample peaks unmeasured. This canonical behavioral proof does not supply a new strict-signing/release proof. Historical signing results retain their own artifact scope. Native registration was subsequently committed01384c2. Selected ordinary/Embedded WASM execution is recorded below; empirical fit suitability, current full registered portable composition and full EX002 remain separate conditions.

## Selected Portable Execution Contract
After Native registration commit01384c2, root leases one exclusive Heavy sequence: ordinary1573, then Embedded1573. The original frozen1562 baseline, Tire11 and three common fixtures remain unchanged. The first actual SwiftPM planning uses official `--disable-index-store` and driver-print-jobs; emitted temporary lists/maps are copied and hash-bound before cleanup. Actual WMO jobs retain every semantic/source/SDK/threads4 argument; only supplementary-map Make `dependencies` keys and module `-emit-dependencies-path` pairs are omitted. Original diagnostics, module outputs, modulewrap and ordered actual object/link inputs remain present. Module emission precedes WMO codegen; original SwiftPM wrapper drivers run only after their modules exist. Embedded uses its actual emitted Unicode tables link.

The sequence uses one immutable allocated-byte baseline,1664MiB fresh admission,640MiB additional-byte cap and768MiB global recovery floor with128MiB reaction headroom. Process-group deadlines apply to planning120s, production1200s, full LLVM decode600s and guard/raw120s. Samples every2s must take at most5s; between-sample peaks are explicitly unmeasured. All original decoded global writes must be stack global0, match every inserted immediate guard, and preserve initial-minus-lower131072. Seven original cases must pass guarded before raw; raw SHA must remain unchanged. Root's complete1841 Native proof and selected1573 portable proof remain different graphs. No Native Task cancellation, current full registered graph or empirical certificate is inferred from the synchronous portable execution. Preparation receipts and original plain-decoder plan remain immutable historical evidence.

## Selected Portable Behavioral Evidence
Root granted an exclusive ordinary-then-Embedded sequence after Native registration01384c2. Frozen original4d16dfdeed329eb425f8f54dc171793903bc55e5 baseline1562 plus unchanged Tire11 gives1573. Original source aggregate isf383ab4de74b861c41782c14159842504c12fb315cacb38a185f41752492f5cf; source-freeze SHA4511a2d15f0505b876baa4bf38116e3e7519aa9a1f13f74ed7adf0205807002d remains unchanged. All six Native fixture Swift digests match; the portable adapter calls the unchanged three shared fixture files and original seven synchronous methods. No physical source, equation, oracle, tolerance or error/work contract changed. Native awaited Task cancellation is outside this proof. The previously recorded uncalled MachineDefinitionContext baseline difference remains explicit.

| Actual selected evidence | Ordinary WASM | Embedded WASM |
|---|---|---|
| Exact SDK ID |swift-6.4.0-RELEASE_wasm |swift-6.4.0-RELEASE_wasm-embedded |
| Production sources / actual WMO threads |1573 /4 |1573 /4 |
| Module / WMO codegen seconds |3.577 /39.929 |17.577 /37.683 |
| All decoded global.set counter |{0:38343} |{0:719} |
| Immediate guard writes |38343 |719 |
| Initial / lower stack pointer |2030208 /1899136 |213888 /82816 |
| Original reservation bytes |131072 |131072 |
| Complete LLVM stdout bytes hashed, not retained as plain text |398230009 |7301418 |
| Decode / instrument seconds |10.785 /.448 |.513 /.308 |
| Guarded7 / raw7 seconds, both exit0 |.436 /.315 |.319 /.319 |
| Raw bytes, unchanged after runs |49862562 |58154285 |

[Ordinary receipt](../../.build/af35-tire-laws-qualification/profiles/wasm-selected-receipt.json) SHA-256 dd3e23d76966edbf1a7b853e389dcf8d2f2f05dcc739606454cdd10e07ae92da; [Embedded receipt](../../.build/af35-tire-laws-qualification/profiles/embedded-selected-receipt.json) SHA-256 fe7c0ce790950582ef75b7d84a318576bf565b9e875458b21741dd1b657b6978. Producer bindings record each1573 source/output-object pair, all objects in the actual ordered1580-object link list and fresh3 module metadata: ordinary adf69618997ad096bf5d3613f5621ab2e5be66bc11d41b94b7a9ae46daccbf0c; Embedded d593e19c59585061e513846543a36840596d6e6bfe72137388637d14c8eb8457.

Actual planning used official index-store disable and retained emitted temporary input lists/maps. Planning's missing-module wrapper refusal is preserved; it does not claim full SwiftPM build success. The selected actual module-first/codegen/wrapper/support/entry/link jobs succeeded, omitting only the approved nonsemantic Make dependency outputs. All module/link driver final jobs are4, WMO codegen threads4. Embedded jobs actually enable Embedded and link Unicode tables. Original SDK linker stack reservation is retained. Ordinary tool assertions initially inspected the Swift link driver and then autolink job0; actual clang job1 and its executed wasm-ld argv contain stack-size131072. Both assertion refusals and the distinct compiler/link acceptance are retained. Successful codegen/link was not repeated to repair those evidence assertions.

Embedded raw size is largely debug metadata: .swift_ast36117043 bytes, .debug_info7071588 and .debug_names5020929. Its actual Embedded frontend and complete LLVM coverage remain independently recorded; artifact size is not substituted for backend identification. Raw SHA is64548792cad11c5a2e2dd376f39ee9a7768454c4ff9c035814fadd72a587d1b0 ordinary andc50a4efc0ede25aa388f236ae36123561b4aed9a3a9e0010feb069aebaf061f0 Embedded. Guarded artifacts ran all seven assertions before those unchanged raw artifacts.

The single immutable allocated baseline was9310208 bytes; maximum sampled additional493395968 bytes stayed below671088640. Minimum sampled global free2240471040 bytes exceeded805306368 recovery floor and reaction headroom. Maximum sampler cost.162198s stayed below5s, with2s cadence. Between-sample peaks remain unmeasured. [Selected portable handoff](../../.build/af35-tire-laws-qualification/profiles/selected-portable-handoff.json) SHA846351710a86c242b745260f304857af355047dc8591ce72f4e4ed3dc16d5aed fixes both profiles, actual producer/source/artifact/resource bindings and released Heavy lease.

These results qualify the selected synchronous Tire law on exact Native, ordinary WASM and Embedded paths. They do not qualify Native Task behavior on portable targets, full current root portable composition, empirical calibration certificates, unsupported model domains or full EX002. No further review, source changes, compiler run or cache mutation is required for this selected proof. Root owns parent/index/registration/commit integration.
