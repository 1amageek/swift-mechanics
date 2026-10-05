# MechanicsContactRangeObservationTests

## Purpose and Scope

Parent: [package design](../../DESIGN.md), through the native SwiftPM dedicated test target. No children. Verify the new [ContactRangeObservations contract](../../Sources/SwiftMechanics/Analysis/Observations/ContactRangeObservations/DESIGN.md) through public required APIs. The owner implemented and executed fifteen public behavioral tests in four suites after root dispatch. Root owns canonical/public/profile composition.

## Responsibilities and Boundaries

Own independent raw range/trigger/tactile physics, complete source association, issuer boundaries, immutable prior values and operation-local work/failure tests. Existing suppliers, their dedicated tests, SensorPipeline schedules/noise/buffers and Runtime transactions remain separate owners. Tests construct genuine compiled models/states/collider recipes and law-issued histories; no @testable import, internal admission constructor or fake query record supplies successful authority.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Raw child](../../Sources/SwiftMechanics/Analysis/Observations/ContactRangeObservations/DESIGN.md) | depends on | Source-bound issuer/observer methods | Test subject and public API authority | No Runtime acceptance inference |
| [Observation tests](../MechanicsObservationsTests/DESIGN.md) | coordinates with | Genuine compiler/mount fixture patterns | Preserve old13 cases | Read-only supplier tests |
| [Collision tests](../MechanicsCollisionTests/DESIGN.md) | coordinates with | Independent point/ray/trigger conventions | Original analytic supplier proof | Reuse public construction pattern, not internal records |
| [Current tests](../MechanicsContactCurrentTests/DESIGN.md) | coordinates with | Genuine law/history and force/power oracles | Constitutive supplier proof | No epsilon trial/current substitution |
| [Runtime tests](../MechanicsRuntimeTests/DESIGN.md) | coordinates with | Actual accepted state/publication | Pipeline integration prerequisite | Root/pipeline own accepted-time tests |

## Architecture

```text
real compiler + public body-local recipes + original law-issued history
  -> required scene issuer -> required raw observer
  -> independent analytic geometry/kinematics/force/moment/power oracle

genuine alternate source/provider output or reset ledger
  -> same observer -> exact typed refusal + retained known prefix + no publication
```

## Contracts and Invariants

Owned test files are ContactRangeFixtures.swift, RangeObservationTests.swift, TriggerObservationTests.swift, TactileObservationTests.swift and ContactRangeFailureTests.swift; fault providers occupy separate primary-type files. This target uses import SwiftMechanics, not @testable. Work/tokens/fixtures are local to each test; no shared mutable static catalog. If fault/cancellation owners need mutable state, use the same Mutex contract on all supported targets and the actual deployment availability. Each suite has the repository's bounded Swift Testing timeLimit; every command uses the pinned watchdog.

| Obligation | Independent oracle and failure discriminator |
|---|---|
| Genuine range | Sphere center(3,0,0),r1, mounted +X ray: distance2, hit(2,0,0), outward normal(-1,0,0); common nonidentity rotation preserves distance and rotates point/normal |
| Ray boundary meaning | True miss, finite max distance, inside outward exit, grazing, parallel box/plane, sharp box, margin/fidelity and deterministic distance/identity ordering; unsupported rounded box must fail, not miss |
| Source/body placement | Actual compiled moving body plus offset collider/mount: explicit trigonometric pose/rate; same model stamp/time with changed q, v, placement, catalog shape/revision must not reuse old authority |
| Trigger lifecycle | Genuine sphere outside -> inside -> outside: original entered/exited and sample indices0/1/2 with exact source times; original previous output unchanged; changed recipe/filter requires fresh prefix; duplicate/skipped/backward prefix rejects |
| Contact geometry | Two r.5 spheres at center distance.99 give separation-.01, original witness points/normal and pointB-pointA=n*separation; no force inferred from overlap |
| Tactile virgin/current | Effective k1000 yields Fn10 and U.05 at separation-.01; actual issued z.001 with kt1000 yields Ft-1 and Ut.0005; genuine positive trial issuance then matching source time, no dt passed to current sampling |
| Rigid point rates | Offset moving/rotating bodies: analytic v(p)=vOrigin+omega cross r and B-minus-A sign at actual shared midpoint; no substituted generalized velocity |
| Frame/reference/sign | Both mounted body choices, common-point action/reaction, shifted sensor-origin moment and nonidentity rotation; total force/moment balance and independent pair mechanical power |
| Material-axis/history | Actual first-collider tangent projection, anisotropic rotated basis, unchanged history/sequence/time; parallel material direction, wrong layout/pair/time and unloaded/nonzero bristles reject |
| Opaque successful output | Providers execute real original query/current/motion on a foreign pose/state/mount/separation/rate with identical metadata, then return success: invalidSupplierEvidence before issuance |
| Ledger failure | Zero/precharged caller ledgers; real provider work then reset on success/failure, budget replacement, cancel during verification, exact scalar/record/metadata limits and overflow; admitted prefix retained, unknown work marked |
| Temporal distinction | Tactile is current continuous force/couple, triggers geometric sampled events; no impact impulse or endpoint equivalent impulse accepted/converted to force |
| Ownership | Prior scene/result/history values unchanged on failure and repeated sampling; result retains original backing after local fixtures leave scope |

Fault providers return only genuine producer-issued values from deliberately wrong inputs. No fabricated result constructor or unsafe mutation is used. Source-swap tests keep headers/IDs/time identical where possible, so metadata-only verification provably fails the oracle. Native-only task cancellation proof does not certify WASI multithreading.

## Runtime Flows

Use separate noninline public fixture phases for model/scene/history construction and observer invocation when rich values overlap. The fixture passes real operation-local NumericalWork/CollisionWork/ContactWork. Opaque failure tests assert typed error and exact known admitted prefix; success tests check full original geometry/current force and history rather than only finite fields or nonzero work.

Pipeline integration will construct scenes from original RuntimeAcceptedState.physical and prove exact physical source matching and rejected-trial suppression. It is not simulated with a time-only label inside this target. This raw target does not certify schedules or Runtime publication.

## State, Ownership, and Lifecycle

Immutable fixture/result owners and exclusive local ledgers. Any test-only mutable fault/cancellation counter is Mutex owned, with no target-conditioned state/Sendable branch. No copied generated cache or shared evolving-source build supplies independent evidence. Root assigns immutable baseline/owned-overlay proof setup after source freeze.

## Failure, Concurrency, and Constraints

Dedicated tests retain caller original tolerances and accounting limits; never widen stack/budget/tolerance to suppress a correctness finding. Tests cover admission limits before supplier calls and completed work before failure. Lower unavailable geometry/current law remains typed failure. Shared-state tests, if required by actual fault ownership, use one consistent synchronization mechanism. No concurrent session/scheduler design is introduced.

## Verification and Change Impact

Root registration requires one new testTarget named MechanicsContactRangeObservationTests, production child DESIGN exclusion and parent child indexes; no supplier registrations/implementations change. Owner focused Native execution follows coherent source/test freeze with exact6.4.0, four jobs, original watchdogs and immutable baseline plus owned overlay. Root owns canonical composition/public physical assertions, ordinary/Embedded execution and original131072-byte guards. Existing qualified supplier evidence remains valid when untouched.

One comprehensive owned source/test review and the finding-only correction below close this scoped Native handoff. Original public/profile integration remains root-owned.

### Independent Native execution (AF31.1)

Private source root: /Users/1amageek/Desktop/3D/swift-mechanics/.build/af31-independent-raw-observations/swift-mechanics, committed625f759 plus only owned source/test overlays. Root-prepared registration retains the dedicated test target only; production/executable dependencies and flags are unchanged. Cache: /Users/1amageek/Desktop/3D/swift-mechanics/.build/ar01-native. No generated cache was copied into the immutable source copy.

From that private source root, run with the exact release toolchain and two-argument job option:

```sh
python3 Scripts/run_with_timeout.py 1200 /Users/1amageek/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swift build --build-tests --build-path /Users/1amageek/Desktop/3D/swift-mechanics/.build/ar01-native -j 4
python3 Scripts/run_with_timeout.py 240 /Users/1amageek/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swift test --skip-build --build-path /Users/1amageek/Desktop/3D/swift-mechanics/.build/ar01-native --filter 'RangeObservationTests|TriggerObservationTests|TactileObservationTests|ContactRangeFailureTests'
```

Logs reside in .build/af31-independent-raw-observations/ under the workspace:

| Log | Exit and evidence |
|---|---|
| native-setup.log |0; actual111.79s setup |
| native-tests.log |1;15 declarations/4 suites executed, one test-only oracle failure |
| native-recheck-setup.log |0;4.15s after only the test correction |
| native-recheck-tests.log |0;15 declarations/4 suites passed,.012s |

The only failure was the maximumHits=0 test: sensor mounted on B at x.99 emitted a +X ray toward A behind it. The original query correctly returned no hit. Selecting B's sphere gives the actual inside-origin exit hit and verifies capacity refusal without a source/physics/policy workaround. Production Swift stayed frozen. All fourteen other initial declarations passed; the stable recheck passed all fifteen. Cases are the fifteen declarations with additional in-case loops and assertions, not fifteen independently enumerated parameter cases.

Owner source inventory: .build/af31-independent-raw-observations/owner-freeze.json (relative paths and SHA-256 per file). No owner build/test process remains; cache ownership returned to root. These results certify the selected Native paths only. Root separately qualifies canonical graph/public callers, ordinary/Embedded and original131072-byte stack guards.
