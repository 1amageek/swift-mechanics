# ObservationRecords

## Purpose and Scope
Immutable observation sources, mounting, units, exact-time gravity and bounded admission. Parent: [MechanicsObservations](../DESIGN.md). No children. Own selected IM25 SE-001..003; full domains remain tracked by the module owner.

## Responsibilities and Boundaries
This component owns the quantities and validation described below. IM26 owns schedules, noise, delays, streams and accepted-time publication. Existing suppliers are immutable dependencies. A stateless query does not itself certify Runtime acceptance or solve dynamics.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Parent](../DESIGN.md) | parent | Observation ownership | Module composition | Root qualifies actual execution |
| [Core](../../../Mathematics/Core/DESIGN.md) | depends on | SI dimensions and directional transforms | Actual frame arithmetic | Geometric origins differ from spatial fields |
| [Compiler](../../../Modeling/Compiler/DESIGN.md) | depends on | Immutable model/stamp/state evaluation | Complete actual tree validation | Initial acceleration is supplied state |
| [Joints](../../../Modeling/Joints/DESIGN.md) | depends on | Actual frame motion/layout/required composer | q/v and offset derivatives | No chart inferred from lengths |
| [Numerics](../../../Mathematics/Numerics/DESIGN.md) | depends on | Exclusive caller work ledger | Checked capacities | No allocation measurement |
| [Mechanisms](../../../Physics/Mechanisms/DESIGN.md) | depends on | Qualified source-bound ConstrainedMotion | Explicit force/impulse and rank representative | No general bearing decomposition |
| [Loads](../../../Physics/Loads/DESIGN.md) | depends on | Instantaneous gravity datum | Time supplied by observation binding | No field time integration |

## Architecture
```text
compiled model/state + optional solved acceleration -> bounded source admission -> immutable snapshot/source
```

## Contracts and Invariants
Required source preparation evaluates the actual compiled state. State-supplied acceleration is labeled as such. The constraint result carries kinematic source and original residual evidence, but no complete mass/catalog ModelStamp: the caller remains authority for supplying the result of its model/equation solve, and the observer does not re-solve or independently certify that catalog. A force-mode ConstrainedMotion can replace acceleration only after exact source time/layout/tree/pose/velocity checks; actual compiled evaluation with its acceleration produces the observed kinematics. No proof of an unreported force decomposition is inferred.
Kinematic supplied-vs-solved acceleration provenance describes the input authority; it does not imply accepted-time scheduling or dynamic certification of an unreported catalog. SI units, explicit destination frame/origin and exact finite sampling time accompany every result. Values are continuous instantaneous quantities; an instantaneous impulse has no invented duration or average force. Sampling either side of a discontinuity requires an explicit source. Every public service operation is a protocol requirement with typed failure. Missing callable fidelity uses an exact FIXME(INCOMPLETE_IMPLEMENTATION) marker and typed failure.

AF30 admits injected mounted-motion suppliers only in the exact reference-equivalent evidence domain. A successful result must be associated with the complete original source and mounting, including model, time, sensor, body, expressed frame, acceleration authority and temporal meaning. Matching headers alone cannot authorize its geometry. Original pose translation and full geometric velocity/acceleration must match the canonical fixed-mount computation exactly; rotation equality uses the original quaternion matrices, permitting equivalent quaternion signs. Close results from an alternative algorithm are not silently admitted. The canonical computation and comparison are additional bounded work within the caller's unchanged budget. Existing identity/time/frame binding failures remain `staleSource`; an associated result with incorrect motion, acceleration authority or temporal meaning fails `invalidSupplierEvidence`. No rejected evidence publishes an observation. This rule certifies a mounted query, not the mass/load catalog or Runtime acceptance of its supplied acceleration.

## State, Ownership, and Lifecycle
All returned values and source owners are immutable Sendable. A source retains validated model/state/snapshot immutable COW backing. Workspaces/ledgers are operation-local exclusive inout values. No shared mutable storage, callback, hidden cache or target branch exists. Mounting is fixed during this sample. Reused source backing is retained, not copied or measured as zero allocation.

## Failure, Concurrency, and Constraints
Cancellation is rechecked after each opaque evaluation before source publication. Current caller body/coordinate/reaction-row/metadata bounds are admitted before lookups/equality or arrays. The metadata capacity is per explicitly passed bounded group (model binding, each body/joint identity record, or mounting); the caller operation ledger bounds the aggregate traversal. UTF8 traversal stops at the caller capacity; checked scalar-slot products reject overflow. NumericalWork records declared logical orchestration cost, separately from opaque compiled evaluation/frame-composer supplier calls. Successful opaque calls are charged as one declared call quantum, not a numerical arithmetic count; failed opaque work is unavailable and is not retried. Structured failures distinguish invalid mounting/chart/frame, stale model/time/source, acceleration provenance, unsupported decomposition/compensation, capacity, cancellation and supplier failure. Same source/storage/Sendable/entry points apply on Native/WASM/Embedded. Stack, allocator and physical-copy usage are unmeasured until actual qualification.

AF30 preserves the irreversible pre-admission quantum for injected KinematicObserving calls and checks returned budget/operation/iteration/storage prefixes on both success and failure before using any result. Ledger replacement restores the known admitted prefix and reports unavailable supplier work. An original verification call uses the same exclusive caller ledger, never a replacement budget. Failure or cancellation retains completed known work and cannot publish a partially verified record. Verification reserves a fixed comparison envelope and charges its comparisons before traversal; opaque original composition retains the declared-call accounting above.

## Verification and Change Impact
[Test owner](../../../../../Tests/MechanicsObservationsTests/DESIGN.md) executes independent analytic rotating/accelerating mounted motion, distinct chart encoders, free fall/support/offcenter IMU, shifted wrench/sign/compensation, actual scalar static reaction and invalid/stale/cancel/capacity paths. Source tests are not execution evidence until root registers and runs them. Changes to frame convention, chart, gravity binding or reaction semantics require affected consumer/profile requalification. Full SE-001..003 and IM26 are not closed by this selected handoff.

AF30 transfers the stopped four-child/test source scope to reaction_paths. Existing 13 test declarations remain the selected compatibility cohort. Supplier-success refusal assertions are added to those cases: a composer returning stationary identity for a rotating offset sensor, and a genuine observer querying a different mounting with identical header identities. Independent owner Native execution and root Native/ordinary WASM/Embedded public composition are separate evidence. The original 131072-byte reservation remains fixed; this design update is not execution qualification.

The [test owner's executed AF30 evidence](../../../../../Tests/MechanicsObservationsTests/DESIGN.md#executed-independent-native-evidence) records the first actual owner proof: two specific diagnostic RED failures followed by13 Native cases/4suites passing on corrected immutable48cf8df-plus-owned-source composition. Quaternion-sign equivalence, reset on success/failure and original-verification capacity refusal are included inside that cohort. Public profile/stack composition remains root-owned and pending. Source/test ownership review has closed once; only concrete qualification findings reopen this snapshot.
