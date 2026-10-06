# Sleep Mechanism Behavioral Evidence

## Purpose and Scope
Independent compiled two-body gear tests for [SleepContinuation](../../Sources/SwiftMechanics/Physics/Mechanisms/SleepContinuation/DESIGN.md).

## Responsibilities and Boundaries
This target owns mechanical, checkpoint, rollback and work-omission oracles. The system target owns combined target integration and Native/WASM/Embedded public profiles. It does not qualify absent topology migration or Hybrid contact authority.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [SleepContinuation](../../Sources/SwiftMechanics/Physics/Mechanisms/SleepContinuation/DESIGN.md) | depends on | full handler, sleep step, command and impulse | actual accepted continuation | stationary affine domain |

## Architecture
```text
Compiled M=diag(2,4) gears -> q0+2q1=0
    -> rest dwell -> physics omission -> command or generalized impulse
    -> q/v mechanical oracle + connected wake record + restored replay
```

## Contracts and Invariants
For torque [6,0], actual constrained acceleration is [2,-1]; for instantaneous generalized momentum [6,0], resulting velocity from rest is [2,-1]. Gear q/v constraints remain zero. Accepted rest age controls entry. Sleeping stages reduce actual supplier arithmetic. Nonzero velocity, even below thresholds, is physically evolved. Accepted bytes include exact q/v/time/sequence, command generation and event fields.

## Verification and Change Impact
CheckpointedSleepTests verifies dwell, omission, constant-force wake, instantaneous mass/constraint impulse, mechanical oracles and checkpoint replay. SleepCriteriaTests proves actual kinetic energy/normalized-speed thresholds and fresh-owner physical rest revalidation. SleepProofEvictionTests uses the actual explicit integrator and two independent real Runtime sessions sharing one owner, with distinct physical equilibria; another session replaces the global memo immediately after prepare, and the prepared sleeping stages/publication retain their local authority. SleepFailureTests verifies rejected trial/RNG/event rollback, active adaptive rejected trials, stale/missing/malformed and force-forged checkpoint rejection, capacity and cancellation. Run the focused target with an explicit timeout and Swift 6.4.0; deployment macOS13 is preserved and execution is availability-guarded for Mutex macOS15. No success inference is made for unexecuted targets.

### AF23 loaded behavioral evidence
Registered loaded tests exercise [StationaryLoads](../../Sources/SwiftMechanics/Physics/Mechanisms/StationaryLoads/DESIGN.md) and the shared loaded affine motion contract while retaining the existing zero-load fixtures. [FoundationVerification](../../Verification/FoundationVerification/DESIGN.md#af23-integrated-qualification) owns actual execution evidence for the frozen and repaired source, separately from the behavioral obligations below.

| Proof | Independent actual oracle / rejection |
|---|---|
| Nonzero gravity/passive equilibrium | Compile a spatial two-coordinate prismatic mechanism with actual positive masses and a retained connected affine row. Choose exact representable uniform gravity and spring rest/displacement/stiffness so each nonzero gravitational load is canceled by actual passive forces (e.g. mass 2, gravity -10, stiffness 20, displacement -1); derive original forces from m*g and -k*(q-rest), not production output. Assert real input contains nonzero gravity and passive contribution, exact v/a=0, rows, potential/dissipation and dwell |
| Physical omission / dependency | Compare explicit load/numerical receipts before/after sleeping stages, assert actual supplier calls/known work decrease and q/v/acceleration/selection remain invariant. A zero stiffness coefficient or zero instantaneous gravity torque retains the declared dependency and affected wake support |
| Changed load wake + active motion | Select an admitted different nonzero gravity/spring program; independently solve M*a = gravity+passive+drive+A-transpose*lambda with A*a=0. Assert actual endpoint acceleration, whole connected wake, kind/version/generation event and reset history, then genuine RK movement under the changed q-dependent spring |
| Fresh restored replay | Encode full checkpoint, advance, restore in fresh catalog-equivalent owner with cold memo, prove actual loaded equilibrium, and compare full subsequent physical/contributor/RNG/sequence state and separate receipt meaning. Wrong exact catalog coefficient/version/frame fails |
| Reject/cancel/failure | Actual attempted loaded mechanical evaluation followed by reject or cancellation preserves whole accepted physical/load/sleep/event/history/RNG. Known LoadWork is retained separately from numerical work; genuine nested unknown work stays unavailable and is never retried |
| Report scope / validation | Assert equationExecution receipt excludes separately owned required admission; actual public admitWithLoadReport cold proof reports checkpointAdmission scope, one invocation and real logical units. Tight whole validation work/scratch rejects before load callbacks when reservation cannot fit; cold work is included in actual RuntimeValidationEvidence, while cache hits report their actual association cost only |
| Boundaries | K=0 / marker exhaustion invokes no supplier; K exhaustion after a real prefix, term/catalog/metadata/scalar limits, overflow and stale generation/selection reject explicitly. Corrupt success/failure ledgers restore known prefix and preserve unavailable evidence; no fabricated physics |
| Prepared authority | Same owner, independent sessions at distinct loaded equilibria replace global memo; operation-local version-bound prepared proof survives. Changing selection cannot authorize use of the previous proof |
| Compatibility / target lifetime | Existing zero-load tests remain valid; root qualifies loaded Native/ordinary/Embedded original 128 KiB compositions after freeze. No renewed unrelated proof is required |

New tests validate the concrete actual loaded path and required full handler, not enum/type existence. Shared counters/cancellation use identical Mutex on all targets; phase/resource evidence is distinct from correctness and replay. Lower Runtime proof must be green before test implementation/registration/build.

The loaded fixture uses two mass-2 Y-prismatic bodies constrained by q0-q1=0 at q=[-1,-1], v=0. Actual uniform gravityY=-10 yields force -20 per body and k=20/rest=0 springs yield +20 per coordinate. GravityY=-8 version selection independently predicts a=[2,2]. A separately compiled equal-ID altered-mass model, changed solver policy, and changed canonical program must fail fresh-owner checkpoint restoration. New loaded owners and handler names follow SleepContinuation's additive composition contract.

AF23 new tests: LoadedCheckpointedSleepTests owns actual nonzero gravity+spring rest/omission, load-selection RK4 independent SI oracle, and loaded command/impulse. LoadedSleepCheckpointTests owns first cold invocation receipt, fresh exact replay, equal-ID changed mass/policy/catalog rejection, malformed complete source, and pre-supplier validation capacity. LoadedSleepFailureTests owns invocation K/work/scalar/cancel prefixes, rejected publication/RNG, known-marker retention on ledger reset, unavailable work/late lease, and close callback reentry. LoadedSleepProofEvictionTests interleaves independent actual physical positions through a shared owner and proves prepared authority survives memo replacement while all zero program dependencies remain. Root executed the Native focused tests and original-profile public composition; the canonical qualification linked above records the evidence. Test declarations alone grant no execution qualification.


### AF26 selected topology wake proof (DESIGN ONLY)
This test owner proves the [source retirement contract](../../Sources/SwiftMechanics/Physics/Mechanisms/SleepContinuation/DESIGN.md#af26-selected-topology-wake-consumer-contract-design-only). A real compiled model has a fixed static root and three independent Y-prismatic dynamic children A/B/C, each mass 2, center of mass zero and positive rotational inertia. Identity fixed anchors and zero q/v admit actual rows11(A-B=0) and12(B-C=0). Accepted generalized drives [4,-4,0] have zero sum; solving original M*a=drive+J-transpose*lambda with J*a=0 independently gives a=0, lambda11=-4/lambda12=0. The actual sleep owner must reach dwell and omit real dynamics before release; no initial flag injection is allowed. The source uses the additive outer TopologyCheckpointHandler base composition and inner SleepTopologySourceCheckpointHandler with the real topology provider registered from creation.

Release A through the actual subtree producer at the real accepted sleep time/global sequence. Explicitly retire row11 and removed A effort +4. Retain real row12 and B=-4/C=0. Build the target row at public mapped B/C position ranges; no constant-zero row is permitted. The actual sourceBoundModel: nonlinear equation adds sixDOF quaternion normalization, which cannot stand in for row12. Consume ReferenceNonlinearSubtreeAccelerationPreparer.prepare(release:equations:work:) through its public protocol, then the actual target handler. Free A has six zero accelerations; B=C=-4/(2+2)=-1. For elapsed h from release rest, expect B/C velocity -h, position -h*h/2 and acceleration -1; A pose/velocity/quaternion are unchanged. Independently check total kinetic energy=2*h*h, B-drive work=2*h*h, retained-row power=0, actual generalized reaction B=+2/C=-2 and source/row residuals. Actual projected evolution has positive supplier work.

| Invariant | Behavioral counterexample / oracle |
|---|---|
| Whole source authority | Real sleeping source with full topology/sleep/integration registry; changed q/v/time/sequence including signed-zero bits, mismatched integration global steps, drive/row/mass/policy, false sleeping flags or wrong owner fails. A pass-through injected outer handler cannot waive original Sleep proof; topology history ahead of the source fails original contextual association |
| Explicit law disposition | Missing/extra retired rows, retirement of untouched B-C, removed effort carried onto free connector or altered surviving force must fail |
| Physical target | Independent body pose/velocity, momentum/energy conservation and mass/retained-force acceleration oracle above |
| History and wake | Old sleep record is retired with source-bound event; topology/wake/integration target all use actual S+1 and same time; RNG unchanged |
| Real awake execution | Target uses NonlinearMechanismEquation and ProjectedNonlinearMechanismEvolution with positive actual supplier work and analytical nonzero B/C motion |
| Failure work | Cancel/capacity/ledger reset during preparation/real physical proof preserves complete accepted source, known prefix and unavailable evidence without retry |

Fixtures own immutable models and local ledgers. Shared cancellation/receipts use identical Mutex on every target. Owned files are SleepTopologyFixtures.swift and SleepTopologyRetirementTests.swift plus dedicated controlled supplier/cancellation fixtures if needed. The fixture and real source-bound target consume the qualified lower test paths QuadraticColdFixture.swift, QuadraticColdTests.swift and QuadraticColdFailureTests.swift as API/behavior references, not copied private algorithms. Lower qualification56a57ba already exists; the additive source and dedicated cases now execute against that immutable lower baseline. Root executes the frozen registered/integrated profiles; independent Native owner verification is recorded below; the frozen contract heading retains its original handoff anchor.

### AF26 dedicated production cases

| Test owner | Behavioral invariant |
|---|---|
| SleepTopologyRetirementTests | Actual balanced mass/drive equilibrium, accepted dwell omission, exact mapped row/effort retirement, invalid disposition refusal |
| SleepTopologyRetirementTests.completeSourceRejectsSequenceTimeAndExactPositionHistoryMismatch | Full source cold admission rejects global sequence, time and signed-zero physical/history differences without RNG publication |
| SleepTopologyRetirementTests.injectedContextCannotWaiveOriginalAwakeSourceProof | Arbitrary outer success cannot waive original sleep authority; zero capacity avoids callback |
| SleepTopologyRetirementTests.newRetirementSignatureBindsChangedSameIdentityMassAndPolicy | New source-law signature distinguishes actual same-stamp physical/policy changes |

SleepTopologyFixtures constructs the independent three-slider mechanics through public compiler/dynamics/integration APIs. It constructs no producer tokens or Runtime controls. Test contexts own sessions through shutdown; no shared mutable fixture exists. The only invocation counter is protected by the same Mutex storage and entry points on every profile. Independent setup and actual runtime evidence are recorded by the task owner after freeze.

Native source retirement and old sleep behavior passed 26 test definitions in 9 suites in the independent lower-baseline copy. Consolidated invocation/count/digest evidence is owned once by [the Topology test evidence](../MechanicsTopologyReleaseTests/DESIGN.md#af26-independent-native-evidence). Original profile integration remains pending.
