# MechanicsTopologyReleaseTests

## Purpose and Scope
Behavioral verification of [SubtreeTransitions](../../Sources/SwiftMechanics/Physics/Mechanisms/SubtreeTransitions/DESIGN.md) and [TopologyContinuation](../../Sources/SwiftMechanics/Physics/Mechanisms/TopologyContinuation/DESIGN.md). Root owns graph registration and exact profile execution.

## Responsibilities and Boundaries
Use actual compiler/Joints/Dynamics/Runtime/Actuation producers. Independently sum body linear/angular momentum and kinetic energy, check all world motions and raw coordinate mappings, independently inspect original target force equations, and exercise persisted contributor bytes through fresh checkpoint owners. No copied private source or type-only proof.

## Related Designs
Lower owner designs above define contract and change impact. Legacy AcceptedTransitions tests remain separate.

## Architecture
```text
moving chain fixture -> cut subtree -> independent body oracle -> actual target forward force solve
 -> complete catalog/history/actuator migration -> atomic owner replacement -> second cut/replay/restart
```

## Contracts and Invariants
Each fixture owns immutable models/providers and local ledgers. Failure cases check exact accepted checkpoint and RNG. Callbacks use local mutable work, with no shared mutable test resources.

## Verification and Change Impact
Root runs timeout-bound Native focused tests after registration, then selected original Native/WASM/Embedded paths. Full tests are not run by this worker before root provides a slot. Unsupported v1 import, loop/prescribed runtime and bearing-wrench trigger coverage remain explicit.


### AF26 selected sleep topology composition (DESIGN ONLY)
This target owns publication, complete contributor catalog and replay boundaries for [TopologyContinuation's selected retirement path](../../Sources/SwiftMechanics/Physics/Mechanisms/TopologyContinuation/DESIGN.md#af26-selected-sleep-retirement-publication-design-only). The independent mechanical fixture and acceleration/motion oracle are owned once by [MechanicsSleepMechanismTests](../MechanicsSleepMechanismTests/DESIGN.md#af26-selected-topology-wake-proof-design-only); this target consumes that scenario without redefining the physical contract.

| Boundary | Required execution evidence |
|---|---|
| Source composition | Initial real sleep session contains sleep, integration and topology history; actual sleeping steps preserve the topology record. Outer additive TopologyCheckpointHandler(base:) and inner Sleep handler independently enforce original association; an ahead history or permissive injected base cannot waive it |
| Complete dispositions | Every source record handled exactly once; old sleep and chart retired explicitly; actual topology/wake/new history schemas all required and present |
| Target authority | Lower-issued genuine retained-row reconciliation and cold quadratic physical handler; free-forward B=-2/C=0 must fail and retained B=C=-1 must pass; altered q/v/a/time/global sequence, actual mass/law/policy or target integration signature rejected |
| Sequence initialization | Public provider record initializes real target point/time/step at S+1 with classicalRK4/nil error; existing initializeIntegration retains sequence-zero semantics. Both required target cold handler and subsequent projected advance associate exact global history; no Integration internals or fabricated control |
| Atomicity | Expected source staleness, cancellation, handler rejection, wrong capacity/profile or missing wake event leaves source model/configuration/checkpoint/RNG unchanged |
| Physical active continuation | Publish the real reconciled target, advance with actual projected evolution, assert the shared independent nonzero-motion oracle and source-bound work |
| Replay and fresh restore | Reexecute source sleep/release/active advance and compare exact bytes; fresh final model/equation/event catalog/handler admits saved bytes before warmup using explicit bounded bootstrap |
| Bootstrap/event refusal | Explicit sequence-zero cold bootstrap uses original-force-consistent reconciled acceleration and matching empty topology/wake records plus initial integration. Advancing bootstrap, erasing saved history/event, changed cut/retirement/source record or sequence-ahead event rejects without mutation |
| Supplier accounting | Physical/validation/event budgets enforced before allocation/callback, known failed prefix retained, reset work unavailable and no retry |

Existing history-only TopologyReadbackEquation remains solely the legacy integration-initialization fixture. It cannot satisfy this path's active dynamics or cold physical force proof. Actual target composition uses NonlinearMechanismEquation(sourceBoundModel:), NonlinearReconciledSubtreeRelease and NonlinearMechanismCheckpointHandler(equations:continuation:base:validationBudget:), qualified at56a57ba. Refusal asserts actual typed lower/runtime codes, exact checkpoint/RNG/model prefix and caller ledger after known/reset/opaque/cancel failure; handler local validation work is bounded separately and is not an invented aggregate receipt.

Owned files are SleepTopologyFixtures.swift, SleepTopologyPublicationTests.swift and SleepTopologyFailureTests.swift with specific supplier fixtures only for defined failure/work counterexamples. They exercise the selected public protocol and immutable prepared owner; no lower private token/force algorithm is copied. Existing free-path tests remain unchanged evidence unless additive constructor/overload edits affect their behavior. Tests retain original capacities/stack profiles; root owns consolidated qualification. The heading retains the original contract-handoff anchor. Implementation now executes under the independent Native evidence below; original profile qualification remains root-owned.

### AF26 dedicated production cases

| Test owner | Behavioral invariant |
|---|---|
| SleepTopologyPublicationTests.realReleaseWakesPublishesGlobalHistoryAndMovesUnderRetainedDrive | Real sixDOF release, original mass/reaction acceleration, single S+1 event and integration history; exact drive work/kinetic energy and rejected RNG rollback |
| SleepTopologyPublicationTests.freshOriginalSourceColdProofReissuesAndRestoresExactTargetReplay | Fresh source owner cold admission before warmup, new original retirement/reconciliation and fresh target bootstrap reproduce actual final bytes |
| SleepTopologyPublicationTests cold/preparation refusal cases | Missing/malformed wake, wrong acceleration or global sequence, duplicate/missing dispositions, stale publication and changed same-ID physical/policy catalog refuse atomically |
| SleepTopologyFailureTests | Genuine delegated constrained solver success/failure ledger reset, unknown work, known failure and cancellation retain the original source prefix/RNG; no retry or lower-local work reported as caller work |
| SleepTopologyFailureTests.coldHandlerCannotUseGenuineDifferentLawTokenToBypassRetirement | Public contextual constructor rejects a genuinely issued but different-law target token |

Fixture and fault suppliers use only original public mechanics APIs. Real lower cold work is controlled by its explicit validation budget; caller NumericalWork covers only actual upper preparation/encoding and its original prefix. Native cases establish these paths, while root owns Native/WASM/Embedded public composition and the original stack profile. All mutable fault counters use common Mutex declarations and access across targets.

### AF26 independent Native evidence

Owned source/test directories were overlaid alone onto `.build/af26-upper-independent-sleep`, whose AF26_BASELINE marker is qualified lower commit `56a57ba`. Its private manifest retains exactly the existing MechanicsSleepMechanismTests and MechanicsTopologyReleaseTests declarations, with all production/executable/dependency/flags untouched. Swift `swift-6.4.0-RELEASE` compiled against the existing baseline Native macOS27 SDK / deployment14 configuration. This evidence does not substitute for root's original deployment/profile public artifacts.

| Evidence | Result |
|---|---|
| setup.log | First build stopped on test-only missing try at two tolerance expressions; no behavioral or production finding |
| setup-green.log | Timeout1200s, `swift build --build-tests -j 4`, exit0, 5.19 seconds after fixture correction |
| test.log | Separate timeout240s, `swift test --skip-build`, exit0 |
| Existing definitions | Sleep21 + Topology9 retained:30 |
| Added definitions/cases | Sleep5 + Topology8:13 definitions /29 actual standalone or parameter cases |
| Complete owned run | Sleep26/9 suites + Topology17/5 suites:43 definitions /14 suites |

The one comprehensive owned review found that a public cold contextual constructor could combine original retirement with a genuinely issued different-drive nonlinear token. Original mapped-law validation now runs independently in that constructor's bounded noninline phase; `coldHandlerCannotUseGenuineDifferentLawTokenToBypassRetirement` is the limited behavioral recheck and passes. Complete source schema/source scalar-bit binding, finite lossless source-law fields, reserved contextual association work and opaque/known supplier work were checked in that same review. Source/tests are frozen after this evidence. Lower producers, root artifacts/graph and original stack settings were not edited. Final tree digests and overlay equality are recorded in the copy's OWNED_DIGESTS; root owns staging/commit and integrated target qualification.
