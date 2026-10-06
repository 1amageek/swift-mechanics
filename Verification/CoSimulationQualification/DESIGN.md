# Selected physical CoSimulation qualification

## Purpose and Scope
Parent: [Verification](../DESIGN.md). Children: none. Own source-bound public fixtures for the two exclusive scalar prismatic participants of [CoSimulation](../../Sources/SwiftMechanics/Execution/CoSimulation/DESIGN.md). The selected original10 Native tests and9 public cases passed against a matching repaired2270 producer. Historical immutable Native2363 preparation is retained as source provenance only; its depot is unavailable. The current premise is committed f0325b0 Runtime, never live AF31 RuntimeSession work in progress.

## Responsibilities and Boundaries
Construct two real compiled spatial mechanical models with explicit masses, inertias, sources, IDs, effort servo laws, clocks, bounds and original default Control/Runtime factories. Use public CoSimulationCreating/Operating only. Never manufacture accepted states, encoders, integration receipts or replacement supplier behavior. Analytic constant-force motion and kinetic work are independent oracles. Spring energy and continuous damping are comparators; held-force defect remains a reported numerical defect.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [CoSimulation](../../Sources/SwiftMechanics/Execution/CoSimulation/DESIGN.md) | depends on | Creation, snapshot, step, status, shutdown | Actual held effort exchange | Selected equal-clock domain only |
| [MacroCoupling](../../Sources/SwiftMechanics/Execution/CoSimulation/MacroCoupling/DESIGN.md) | verifies | Actual evidence, full-prefix restore, work and poison | Macro publication owner | No distributed transaction claim |
| [MechanicalParticipants](../../Sources/SwiftMechanics/Execution/CoSimulation/MechanicalParticipants/DESIGN.md) | verifies | Original Control/encoder/RK4/checkpoint dispatch | Real participants | No arbitrary supplier injection |

## Architecture
```text
explicit identified 2-body model x2 -> compiled public plant/configuration
    -> original default CoSimulation factory -> equal-clock macro
independent constant-acceleration solution -> q/v/K/work/power/energy comparison
strict evidence or second-participant refusal -> both original restarts -> full accepted tuple comparison
common Mutex cancellation/reentry gate -> original policy callback -> actual failure/status evidence
shared synchronous cases -> public standalone and Swift Testing
Native Task cancellation -> awaited separate Swift Testing case
```

## Contracts and Invariants
All fixtures require original public physical/contributor/RNG values. Coordinate states are metres and metres/second; force is N, mass kg, interval seconds, work J and power W. For held forces F and -F with fixed disturbances G1/G2, independent accelerations are (F+G1)/m1 and (-F+G2)/m2. Analytic endpoints are q+v*h+a*h*h/2 and v+a*h. Kinetic changes must equal the independently integrated total-force work. Physical oracle tolerance is 1e-9 relative to max(1, abs(expected)); admitted held-force defect tolerance is 0.05 J plus relative 1e-10, and the intentional rejection tolerance is 1e-10 J. Energy tolerances are fixed before execution and are not enlarged on failure. A rejected macro must restore both entire RuntimeAcceptedState values, including contributors, random state and accepted-step sequence. Conservative cumulative reservations never reset during rejection/recovery. Pre-mutation capacity failure leaves both original prefixes unchanged. A failed actual restart poisons future snapshot/step admission. Reentrant public operations during an original supplier policy callback must fail busy; callbacks run outside the fixture's Mutex.

| Fixed case | Independent acceptance or refusal oracle |
|---|---|
| Held spring/damper with fixed disturbances | Two analytic endpoints, original K/work, independently integrated held power and defect |
| Pure damper | Analytic motion and nonpositive original held work/start/end power |
| Strict original energy-defect rejection | Nonzero analytic defect, full both-owner restoration twice, increased cumulative work |
| Second participant effort refusal | First attempted physical commit followed by original second refusal; both complete prefixes restored |
| Cumulative macro capacity | Successful macro followed by bounded refusal, physical prefix unchanged |
| Admission limitations | Interpolation/delay/identity/clock/domain refusal with typed failures |
| Stale order and shutdown | No accepted tuple change after stale refusal; closed lifecycle refusal |
| Reentrant supplier callback | Real original Control policy invokes public snapshot; busy refusal recorded |
| Persistent second policy cancellation | Actual first commit then second cancellation; failed second restart, poison and retained original prefixes |
| Native awaited cancellation | Task cancellation before macro admission, unchanged both prefixes and work |

## Runtime Flows
Nine unchanged synchronous cases are reusable on ordinary and Embedded profiles only after exact supplier/API admission. The tenth case requires Native Task cancellation and await. Portable execution remains unqualified. Native execution requires root's common-producer reader lease, fixed Swift 6.4.0 release, actual jobs4, command watchdogs and exact module/object/source/link bindings; producer source is not rebuilt by this fixture owner.

## State, Ownership, and Lifecycle
Only the cancellation/reentry gate is shared mutable fixture state, protected by the same Mutex on all targets. The gate checks out an immutable coordinator handle before callbacks, calls outside the lock and clears the handle outside lock at teardown to break fixture retention. Runtime alone owns physical/contributor/RNG state. Every created coordinator shuts down on every fixture exit. All physical expected values and checkpoint captures are local immutable values.

## Failure, Concurrency, and Constraints
Typed fixture errors identify failed original oracle, unexpected success or wrong typed refusal. Fixture gates never substitute physical suppliers. Numerical and actuation budgets, retained checkpoints and cumulative reservations are explicitly supplied. AF38 thin consumer allowance is1GiB with4GiB global free floor,2s allocated-size sampling and5s measurement watchdog; root owns resource ordering. The old128MiB consumer proposal was not executed and does not qualify this fresh composition. No broad production compilation. Concurrent shutdown and arbitrary interleavings are not certified by the deterministic reentry fixture.

## Verification and Change Impact
Original CoSimulation18 and Control Continuation13/MechanicalPlant12 match immutable2363 at preparation. Original RuntimeSession SHA is 28ea17df32f8ca84a949a744f2877eb3fb881920ee6dd43f6cf143d5acfa78f3; current live RuntimeSession differs and is explicitly unqualified here. Original source inventory aggregate is 80eb84d7d62cc30138b0c9fe705c5f73e4777024eb64e8f371f8477bd6b86aa3. Exact selected per-file SHA and dependency source admission will accompany execution handoff. Only actual executed cases can close the corresponding rows. No generalized external engines, delayed/iterative exchange, full FSI, distributed transactions, performance, arbitrary concurrency or portability claim follows from preparation or Native-only evidence.


### Historical AF38 selected preparation contract
The original18 production files and physical9 synchronous cases remain fixed. Fresh common producer ownership is delegated by root; this fixture owner builds no cold Core producer. Before and after Native10/public9, verify its exact committed2124 baseline plus eight owner-frozen features (the eighth is root-authorized SDF17), per-file source/object identities, three module metadata files and dylib link. Stable emitted compiler closure and matching SDK belong to the producer handoff. Native SwiftPM uses joined import-path arguments, jobs4, public/support deployment13 and actual Testing14. Cases and the shared Mutex gate retain their original macOS15 capability declaration; the unannotated test suite calls them only through body-level availability guards that throw the explicit fixture unsupported-platform error. The public executable uses the same guard. This changes only fixture capability dispatch, not original SI values, equations, cases, tolerances, budgets, cancellation or isolation. The awaited Native Task remains a separate tenth test.

The fixed gaps are actual held force/RK4 motion/work/energy, full physical/contributor/RNG rollback, effort refusal, cumulative work/capacity, reentry, poison and awaited cancellation. No concrete source counterexample has been observed before execution; speculative production changes are not authorized by this preparation. Historical source-admission JSON remains immutable; a distinct AF38 freeze binds the new supplier premise and final fixture bytes.


### Concrete initial-assembly fixture correction
The original fixture gave the moving body's stored reference pose identity while supplying a nonzero initial prismatic q (second participant q=1m). The actual ReferenceMechanicalCompiler.validatePoses compares the TreeKinematicsEvaluator initial translation against that stored pose; this input violates its initial-assembly tolerance before any coupling occurs. The fixture now declares the body pose translation(q,0,0), matching the unchanged axis/anchors and initial q. This changes the input's assembly consistency only; masses, inertia, initial q/v, held forces, interval, energy/work oracles and all tolerances remain fixed. The historical and first AF38 fixture freezes remain immutable. No production defect or executed behavioral result follows from this source-path finding.


### Actual first Native failure
The first common2270 thin consumer compiled and linked successfully; Native10 runtime then exited with signal10 at a stack guard. Admission and stale/shutdown cases reported success before process termination; no public9 execution or overall success is claimed. The crash chain and original owned280,480-byte step frame are retained under .build/af38-cosimulation. The [macro design](../../Sources/SwiftMechanics/Execution/CoSimulation/MacroCoupling/DESIGN.md#AF38-concrete-Native-stack-lifetime-repair) owns the bounded phase/lifetime repair. Original failed logs/receipt, producer snapshot, and original rejected-assembly fixture bytes remain immutable. Revalidation requires a coherent repaired module/object supplier; no stack increase, serialization, energy/physics concession or lower WIP substitution is allowed.

### AF39 matched repair Native evidence
The actual repair consumer uses Swift6.4.0 release on arm64-apple-macos13.0, MacOSX27.0 SDK, Native SwiftPM engine and actual driver jobs4. Support/public deployment13 and Testing14 retain body-level macOS15 capability refusal. Native-engine deprecation warnings are retained in the original logs. No core source or objects were copied/recompiled by this consumer.

| Binding or stage | Exact evidence |
|---|---|
| Matching producer | `.build/af39-cosimulation-repair/handoff.json`, SHA256 `8f48ba1693311c041f1c7ccd557ded5e5025ad0def44d8ac78a1dd321d3e00d3`; committed2124 baseline plus146 frozen feature sources =2270 |
| Production repair | Only `MacroCoupling/HeldPrismaticCoSimulation.swift` changed; current18-file freeze SHA256 `7baa3fd86ac1e33d901172a8b0dc016f1dccb6b5eae12505c1b9fb76e8fa073f` |
| Fixed fixture bytes |8 Swift files, freeze SHA256 `75a31f61ee4f1966aa31acc165f2fb61e28d3bb422ab9f55064fef0c024a88fd`; original SI oracles/tolerances/case count unchanged |
| Native runtime receipt | `.build/af38-cosimulation/native-receipt-repair-1.json`, SHA256 `a5a85046194a66e77f92cb620a0e90a7179b4dcc0710ec591d99f59fe696841e` |
| Setup / tests / public |6.026s /2.012s /2.019s wall time, all exit0; Swift Testing10/10 (reported test time0.014s), direct public9/9 with exact original literal stdout |
| Identity and link | All2270 source/object identities,3 metadata files, dylib, owned18/8 source bytes, actual consumer emitted8 source/object bindings, consumer metadata and public executable verified before/after; exact repaired dylib dependency inspected |
| Resource boundary |2s sampler/5s measurement watchdog, setup900s/tests60s/public120s, cumulative private growth111,427,584 bytes below1GiB,4GiB global floor maintained; reader lease released |
| Causal object evidence | `.build/af39-cosimulation-repair/held-native-phase-evidence.json`, SHA256 `37f766639deb5035995bc5ca76f18d041d812c23c8eba617a5d7960b47f0790b`; original crash and old object evidence retained |

These executions close the fixed physical held-force/RK4 endpoint/work/energy, exact complete contributor/RNG restoration, effort refusal, cumulative admission, deterministic reentry, poison and awaited cancellation gaps. They certify the actual selected Native composition only. They do not certify uniform total stack bounds, general concurrent shutdown, delayed/iterative coupling, external engines, numerical engine equivalence, ordinary WASM or Embedded. A changed Runtime/Control commit or checkpoint authority invalidates the dependent runtime premise; changed phase lifetimes require matching emitted objects and affected physical tests. Root alone owns shared registration and integration.
