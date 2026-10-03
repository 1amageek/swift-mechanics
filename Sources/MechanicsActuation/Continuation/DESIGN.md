# Required actuator continuation and Runtime composition
## Purpose and Scope
Parent [Actuation](../DESIGN.md). Children: none. Initial qualified IM14 component; eventual AC-001..008 ownership remains with the module.
## Responsibilities and Boundaries
Owns fixed scalar-header and bounded binding-trailer versioned actuator payloads, actual RuntimeContributorHandling registration/validation/migration, and scalar servo trial operation. Required contributor records are caller-owned, immutable and mandatory; no hidden mutable controller cache. Runtime owns accept/reject/shutdown and checkpoint codec. Supplier OS availability propagates only through the trial adapter. Every persistent selected law uses ActuatorState and can be registered; scalar law callers replace the returned record only in a Runtime trial.
## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Actuation](../DESIGN.md) | parent | dispatch domain | composition | root owns index |
| [Runtime](../../MechanicsRuntime/DESIGN.md) | depends on | contributor/trial requirements | accepted ownership | Runtime budgets separate |
| [Loads](../../MechanicsLoads/DESIGN.md) | depends on | point/cable mapping | original power | no inferred dynamics |
## Architecture
```text
immutable binding catalog + actuator payload -> Runtime required schema validation
accepted Runtime trial -> full binding/time check -> law trial -> contributor replacement
reject/restore -> original accepted prefix remains owned by Runtime
```
## Contracts and Invariants
Payload v1 starts with a 64-byte scalar header: model revision, law revision, state-kind byte, drive-mode byte, six reserved zero bytes, time, primary, secondary, sequence, binding revision-independent signature. A bounded binding trailer follows: counted UTF8 model identity/actuator/joint/frame keys, UInt64 q/v indices, scalar chart and authority tags, and four exact binary64 state-domain bounds. Schema maximumBytes is the actual header+trailer length established before allocation. Trailer byte equality is an exact continuation representation contract; changing canonically equivalent text spelling requires explicit migration/reset and is not silently normalized. Signature is an exact caller-selected continuation key in binding; any identity/chart/domain/configuration change requires a different key or law revision; it identifies configuration/chart identity in addition to model/law revision. Payload id is actuator key and registry binds it to full EntityID/model/frame/joint/chart/indices/domains. Full trailer verification detects stale frame/chart/index/model identity even if callers accidentally reuse the continuation key. Byte decoding is finite/strict and consumes explicit budget. Runtime validate callback has no physical checkpoint-time input: it checks immutable binding/model/layout/state domain, while actual trial adapter compares full law binding with the immutable required registry and scalar step entry requires state.time==sample.time==trial.time before advancing. This producer limitation is explicit. Migration admits coordinate-preserving Compiler transition and corresponding caller target binding only, changes stamp while preserving scalar/time/sequence state. dt=0 preserves sequence/state. Positive dt increments sequence with overflow guard. No arbitrary raw payload is admitted and no state normalization is silent.
## State, Ownership, and Lifecycle
All public configurations/bindings/states/outputs are immutable Sendable. Services are immutable Sendable values. Only exclusive caller inout ledgers and Runtime trial buffers mutate. No target-dependent state, global cache, unchecked isolation or hidden history. State lifetimes follow caller accepted/trial ownership; failed calls publish no new state.
## Failure, Concurrency, and Constraints
Nonfinite input/output, invalid SI parameters/domain, stale binding/revision/time, incompatible mode/authority, residual mismatch, capacity/work/sequence overflow and cancellation are typed failures. Caller bounds precede repeated scans/allocation; fixed scalar models have bounded phase functions and no per-iteration arrays. Explicit provider ledgers are not merged or reset. Float64/reference CPU is the selected implementation, with no silent backend substitution.
## Verification and Change Impact
[Test owner](../../../Tests/MechanicsActuationTests/DESIGN.md) checks actual drive modes, clipping/recovery, independent BE balances, transmission virtual work, stale/domain/budget/cancel failures and Runtime checkpoint/rejection/restoration. Root owns exact-profile integration. Changes to binding/state/energy semantics invalidate dependent contributors and orchestrators.
