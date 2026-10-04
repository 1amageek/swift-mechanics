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
