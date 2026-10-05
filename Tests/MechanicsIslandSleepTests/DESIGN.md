# Mechanics Island Sleep Tests

## Purpose and Scope

Planned dedicated behavioral test owner for [IslandSleepContinuation](../../Sources/SwiftMechanics/Physics/Mechanisms/IslandSleepContinuation/DESIGN.md). Parent [Package](../../DESIGN.md); no children. It proves mixed accepted omission/wake/full-checkpoint semantics using qualified real island physics, not geometric root selection.

## Responsibilities and Boundaries

Own actual Runtime/Integration fixtures, independent physical/counter/RNG/receipt assertions and public fault participants/suppliers. Existing all-zero sleep and old Hybrid suppliers/tests remain unchanged. Root owns manifest, profile proof and commits.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Package](../../DESIGN.md) | parent | Test ownership | Root registration | No isolated cache until assigned |
| [Island Sleep](../../Sources/SwiftMechanics/Physics/Mechanisms/IslandSleepContinuation/DESIGN.md) | depends on | Planned step/query/wake/checkpoint operations | Sole invariant owner | Actual lower proof required |
| [Island Dynamics Tests](../MechanicsIslandDynamicsTests/DESIGN.md) | coordinates with | Qualified physical fixture assumptions | Independent lower evidence | No duplicated private authority |
| [Constrained Sleep Tests](../MechanicsConstrainedSleepEvolutionTests/DESIGN.md) | coordinates with | Accepted constrained contact endpoint | Upper proves root/event law | No hardcoded impact time |

## Architecture

```text
real whole model + issued islands -> real Runtime with all declared records
accepted dwell -> mixed omission -> supplier invocation comparison
actual constrained result -> real wake candidate/trial -> active real stepping
fresh owner + codec -> cold admission receipts -> replay and refusal
```

## Contracts and Invariants

Use mass2/Izz2 gear A/B and independent mass2 Y-striker, original retained row [1,1,0], zero external loads/drives. Choose finite precontact separation and negative C velocity so real accepted steps accrue gear dwell before contact. Initial/history fields are produced by actual public owners, not forged sleeping metadata. Prove A/B flags true and C false with C actual nonzero velocity; qAB/vAB/aAB stay zero while qC changes through real Dynamics. Instrument actual injected lower calls to show sleeping-island physical calls absent after preparation and awake C calls present; compare truthfully separate work with all-awake reference, including cold admission/encoding scopes.

After genuine AF30 e1 impulse, v=[-2/3,2/3,1/3], unchanged impact q/time and actual force-consistent a=0. A/B wake together and real constrained supplier calls resume; for elapsed h, qAB=[-2h/3,2h/3], vAB unchanged and qC increases by h/3. All source/next history time/q/v/global sequence use actual outer S+1 and RNG bits remain identical. Private query counters intentionally differ and are never imported. e0 instantaneous velocity [-1/3,1/3,-1/3] is admitted only with explicit support-domain refusal for unsupported continued contact.

Full required schema composition includes actual endpoint participant. Fresh cold restart before any warmup proves original force/rest under real lower calls and nonzero checkpointAdmission receipt; stage work is separate. Test immutable prepared proof with controlled alternate-source reentry/cache replacement. Independently corrupt physical/history bits, acceleration, program mass/drive/policy, sequence, event association, schemas/bytes/caps and participant ledger; assert typed refusal and exact accepted checkpoint/encoded bytes/RNG. Cancellation after real attempted work preserves known receipts and prior accepted prefix. No failed-work retry or fabricated Integration report is accepted.

## State, Ownership, and Lifecycle

Every test owns full session/model/program/callback receipts and shuts sessions down on every terminal path. Shared fault counters and reentry state use common Mutex with no callback inside lock. Actual source models/opaque proofs are retained normally; no global mutable fixture or target-specific synchronization.

## Failure, Concurrency, and Constraints

Use finite explicit Runtime/Integration/lower/query/record budgets and root-assigned timeout/resource slots. Capacity before callback must leave invocation counters unchanged; failed/reset/cancel outcomes must expose actual known numerical/load/encoding scopes and unavailable flag. Build-only evidence cannot qualify omission, history or concurrency.

## Verification and Change Impact

Root owns Native affected target and original Native/WASM/Embedded raw plus unchanged 128 KiB guard. This DESIGN is a proof contract, not a result. Changes to lower stationary authority invalidate only corresponding upper assumptions; event catalog/root/impact tests remain owned separately. No broader load, topology or contact-stack completion claim follows.
