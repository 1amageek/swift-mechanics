# Vehicle Laws Qualification

## Purpose and Scope
Parent: [SwiftMechanics](../../DESIGN.md). Own independent Native qualification source for the selected [TireLaws](../../Sources/SwiftMechanics/Physics/Vehicles/TireLaws/DESIGN.md) and [TerrainLaws](../../Sources/SwiftMechanics/Physics/Vehicles/TerrainLaws/DESIGN.md) public paths. Deliver shared public cases, Swift Testing wrappers, and an executable entry point. The original five Swift fixtures are frozen for fresh AF36 selected Native execution against the root-owned 2001-source producer. Root owns shared target wiring and registration; this component owns its private fixture-only consumer. Source availability and compile success are not behavioral qualification.

## Responsibilities and Boundaries
Issue inputs only through original public Core/Model/Load and vehicle-law constructors, consume TireRoadEvaluating/TerrainLawEvaluating requirements, and compare actual outputs against independently derived scalar curves, rectangle geometry, rigid transforms, force/moment/work and irreversible/recoverable histories. Production suppliers and their source remain unchanged absent a concrete counterexample. The numerical coefficients are explicitly synthetic analytic verification inputs, never measured tire/soil calibration or a proposed engineering default. Their provenance says synthetic qualification and their closed ranges are explicit.

## Related Designs
| Design | Relationship | Contract used | Cautions |
|---|---|---|---|
| [SwiftMechanics](../../DESIGN.md) | parent | Qualification ownership | Root wires and executes targets |
| [TireLaws](../../Sources/SwiftMechanics/Physics/Vehicles/TireLaws/DESIGN.md) | verifies | TireRoadEvaluating, admitted radial-brush-v1 | No Fiala/Pacejka equivalence or static/low-speed success |
| [TerrainLaws](../../Sources/SwiftMechanics/Physics/Vehicles/TerrainLaws/DESIGN.md) | verifies | TerrainLawEvaluating, sealed history/trial/checkpoint | Fixed Eulerian rectangular footprint only |
| [Core](../../Sources/SwiftMechanics/Mathematics/Core/DESIGN.md) | depends on | Vectors/quaternions/spatial wrench | Recompute original work from supplied velocities |
| [Model](../../Sources/SwiftMechanics/Modeling/Model/DESIGN.md) | depends on | EntityID/ModelReference | Original kinds and revisions |
| [Loads](../../Sources/SwiftMechanics/Physics/Loads/DESIGN.md) | depends on | LoadBudget/LoadWork | Failures retain actual charged prefix |

## Architecture
```text
synthetic bounded physical inputs + independent analytic expectations
    -> original public constructors -> protocol law -> original force/history/energy
    -> independent checks shared by Testing and Native executable
    -> explicit assertion/original supplier error, or per-case successful return
```

## Contracts and Invariants
| Case | Independent counterexample detector |
|---|---|
| Tire curves | Literal pure-slip anchors 0/244/500 N, signed forward/reverse slip, initial stiffness, alternate integral cubic magnitude for combined slip and friction bound |
| Tire frame/work | Rotated/translated contact geometry; original wheel center torque, equal/opposite road wrench and shifted-reference torque; direct wheel/road powers plus physical slip/rolling losses |
| Tire failures | Invalid formulation/envelope, low speed, incorrect frame/revision/contact geometry, out-of-range load/slip, work/storage and caller cancellation |
| Terrain geometry/normal history | Exact four clipped 0.375 m² subareas/centroids; n=1 and n=2 pressure integrals; literal normal loads, elastic energy, irreversible sinkage and compaction; unload/separate/reload without erasing peak |
| Terrain shear | Independent closed Janosi interval integral at fixed pressure, positive travel on slip reversal, small-travel series anchor, one interval versus two intervals physical loss equality |
| Terrain frame/work | Actual rotated force and moment about supplied world reference; equal/opposite wrench, direct interface/terrain work and independent original energy balance |
| Terrain ownership/failure | Trial does not mutate accepted state, accept rejects wrong base, issued checkpoint restores exact state, source/grid/calibration mismatch, moving footprint, initial preload, domain/cell/work/storage/cancellation failures |

Tire oracle uses `L * (1 - (1-Q/(3L))^3)` on the unsaturated branch, with independently computed force direction, and fixed literal pure-slip anchors. It does not call production internal math or use production diagnostic residuals as its oracle. Terrain normal oracles integrate `B*z^n`; n=1 fixture has B=2000 Pa/m, E=10000 Pa/m, footprint area=1.5 m² and peak sinkage=0.1 m: work=15 J, elastic energy=3 J, compaction=12 J, irreversible sinkage=0.08 m. n=2 at the same sinkage has endpoint pressure=20 Pa, integrated work=1 J and recoverable energy=0.03 J. Shear oracles integrate `strength*(1-exp(-j/K))` using Native standard scalar math and an independent small-ratio polynomial anchor; they do not call the production expm1/bounded series implementation. All tolerances are assertion tolerances, not changes to production passivity acceptance.

## Runtime Flows
Every case creates local work/state and a fresh protocol implementation. Terrain candidates become histories only through original accept; replay/checkpoint tests compare issued immutable values. Expected failures use exact typed law-error matching and reject an unexpected success. Unexpected original errors propagate; no catch replaces failure with successful data. Wrappers and executable invoke the identical public cases. Cases have fixed finite input arrays and bounded operation counts; Swift Testing gives each test a one-minute limit, and root must supply an external process timeout for execution.

## State, Ownership, and Lifecycle
Fixtures, cases, histories and results are immutable or exclusive local values. No static mutable state, shared files, processes, caches, observer handles, stream or shutdown owner. Native storage/isolation/Sendable is not weakened in target branches. Qualification intentionally imports Native Foundation scalar mathematics and makes no ordinary WASM/Embedded portability or synchronization claim.

## Failure, Concurrency, and Constraints
Production LoadWork budgets and cancelled callbacks are exercised through original errors, including an exhausted budget with a nonzero known charged prefix. No live terrain, fabricated measurement, external IO or unbounded numerical integration. Each method may run concurrently because it owns all mutable workspace. The root-controlled execution budget and exact frozen production snapshot are prerequisites for any qualified result.

## Verification and Change Impact
The first frozen Native execution passed six of seven cases and exposed the TerrainLaws pressure-cancellation defect documented in its child design. The rotated case intended zero local normal velocity, but its authoritative world velocities recover -1.214306433183765e-17 m/s through the qualified quaternion inverse, advancing issued peak by 1.3877787807814457e-17 m. Its old exact-zero compaction assertion was therefore stale. Replace only that assumption with an independent positive n=1 compaction integral A*B*deltaPeak*(qOld+deltaPeak/2)*(1-B/E) and its analytical upper bound A*B*deltaPeak*qNew, derived from original rounded issued peak growth; preserve force/moment/world-work oracles and all assertion tolerances. This detects zeroing/clamping a real positive loss as well as excessive loss. Extend the existing normal-history case with two independent branch-crossing oracles: initial gap h=0.05 m and descent 0.15 m yields normal work 15 J and mean load 100 N; separated z=0.07 m reloading to z=0.12 m across plastic 0.08 m and peak 0.10 m yields work 9.6 J, mean load 192 N, stored-energy change 4.32 J and compaction 5.28 J. The unchanged repaired oracles now pass on the fresh AF36 producer and consumer described below. Earlier missing `.build` receipts are historical context, not current execution evidence.
Before implementation, original public Tire/Terrain constructors, laws, cell kernel, sealed accept/restore, and qualified Core/Load identities and work paths were read. Later successful Native execution only covers these selected physical domains and failure branches. It may unlock a later selected Native assembly integration using these laws; it does not qualify complete vehicles, moving terrain footprints, soil meshes, contact solvers, arbitrary calibration, Native concurrency stress, or WASM/Embedded. Production/source changes affecting any curve, work, history or failure invalidate the corresponding frozen case evidence. The current selected Native evidence is recorded below. Full-root composition, the broader physical domains and portable profiles require their own evidence; this seven-case execution does not establish all 2001 production behaviors.

### Fresh AF36 Native evidence
The earlier private producer, scripts, depots and receipts were lost. No historical receipt or old warm/thin-cache result is reused. Root reconstructed committed HEAD `4ac336117d2a840ca79c344a62d79fd48ee6e9db` (1983 registered Swift sources) plus the unchanged Terrain18 into a fresh 2001-source package. Root producer receipt `.build/af36-head-native/producer-receipt.json`, SHA-256 `257ac71208d9223266259d0cccfeca3a04491c3a9172c070cc72a31394bf5f63`, binds all 2001 sources, 2001 objects, three module metadata artifacts and the linked dynamic library. Producer compilation/link took 35.63 seconds; this is not a proof of all production behavior.

The private `.build/af36-terrain-consumer` package owns Support3, Tests1 and Public1 and has no SwiftMechanics production target. It imports the fresh module with `-I` and links the original fresh dylib with `-L/-lSwiftMechanics` and an explicit rpath. Source freeze SHA-256 `5115aaf791f6b2f428813f070215043e02b5830aeaec244716e29a07e31be895` binds the original fixture5 and Terrain18. Native receipt `.build/af36-terrain-consumer/native-qualification-receipt.json`, SHA-256 `76179f2e793ba2c5d208bb79e2432fa9e763d8d903db1f1172efa0a2c3649701`, records all seven tests and the original seven public successes. All producer sources/objects/metadata/dylib and subject Swift hashes were checked before and after; no production or fixture source changed.

| Evidence | Actual result and limit |
|---|---|
| Original test7 | GREEN; command 1.155 seconds, original 7 tests in one suite |
| Original public7 | GREEN; 0.238 seconds; exact original stdout |
| Build | Successful fixture-only continuation 1.674 seconds; all actual final driver jobs four |
| Compiler/SDK/target | Pinned `swift-6.4.0-RELEASE` directory, MacOSX27.0.sdk; producer13, Support/Public codegen13, private Testing/generated runner and final links14. This execution is on the current Native host, not a macOS13 runtime certification |
| Original force/work/history | Approximately 200 Pa rotated world pressure, original world force/moment/interface work, positive tiny rounded-peak compaction, 15 J/100 N gap crossing and 9.6 J/192 N reload crossing with 4.32 J stored change/5.28 J plastic loss all retain their original assertions and tolerances |
| Source/object/link inspection | `.build/af36-terrain-consumer/source-object-link-inspection.json`, SHA-256 `10c7d7ce72597608b68cdf804bc8bb74c851f117082fae09facd2dc1254f561c`; original five fixture sources bound to emitted objects and original linked dylib |
| Deadlines | Build/test 120 seconds, public 60 seconds, inspection 30 seconds; process groups terminate on timeout |
| Strict signatures | Public executable and producer dylib exit0. Test bundle and inner binary exit1: code has no resources but signature indicates they must be present. Separate receipts preserve this artifact limitation; no manual resigning or physical-oracle substitution |
| Private storage | After runtime/signature inspection, unique allocated bytes were 142127104 and nominal file bytes 132823379; a later settled snapshot was 133554176 allocated bytes. These are snapshots, not a measured peak, cap proof or old thin128-cache claim |

Initial private runner failures are retained separately: CLI `-j4` was rejected before compilation and corrected to `-j 4`; Native generated test-runner argv had an orphan `-I`, resolved by equivalent attached `-I<same-module-path>` spelling in the private manifest; executable discovery encountered a debug symlink and its physical path, resolved by canonicalizing paths. Already-green tests were not rerun for the public-path fix. The initial generated-runner failure followed successful original Support/Public/Tests emission (58.785 seconds); those unchanged compiled inputs are preserved and hash-bound to the final execution. No source, physics, oracle, threshold, SDK or producer graph was changed to obtain GREEN.

The HEAD-only shared registration candidate adds Terrain's DESIGN-only exclusion and Support3/Tests1/Public1 wiring; root applies only this delta to the live WIP manifest and owns the individual commit. Ordinary WASM/Embedded, additional physical domains and signature repair remain separate unverified obligations.
