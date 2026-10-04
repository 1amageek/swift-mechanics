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

Planned files are SleepTopologyPublicationFixtures.swift, SleepTopologyPublicationTests.swift and SleepTopologyReplayTests.swift with specific supplier fixtures only for defined failure/work counterexamples. They exercise the selected public protocol and immutable prepared owner; no lower private token/force algorithm is copied. Existing free-path tests remain unchanged evidence unless additive constructor/overload edits affect their behavior. Tests retain original capacities/stack profiles; root owns consolidated qualification. Source/tests are DESIGN ONLY until production; this handoff asserts contract consistency, not upper execution success.
