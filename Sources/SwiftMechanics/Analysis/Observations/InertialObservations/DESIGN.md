# InertialObservations

## Purpose and Scope
Rigid-mounted gyro, world acceleration and specific force. Parent: [MechanicsObservations](../DESIGN.md). No children. Own selected IM25 SE-001..003; full domains remain tracked by the module owner.

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
| [Loads](../../../Physics/Loads/DESIGN.md) | depends on | Instantaneous gravity datum | Time supplied by observation binding | No field time integration |

## Architecture
```text
mounted geometric motion + exact-time gravity -> sensor-axis gyro/specific force
```

## Contracts and Invariants
Gyro is R_SW omega_W; specific force is R_SW(a_sensor_W - g_W(x_sensor)). Gravity is explicitly bound to source stamp, exact time and world frame, and evaluated at that instant without integrating its time derivative. Fixed mounting offset uses actual alpha-cross-offset and centripetal terms. Acceleration provenance remains explicit.
[ObservationRecords](../ObservationRecords/DESIGN.md#contracts-and-invariants) owns the shared SI, exact-time, temporal, required-service and failure contract. This child adds only the quantity meanings above.

## State, Ownership, and Lifecycle
Source/result ownership and all-target Sendable are defined by [ObservationRecords](../ObservationRecords/DESIGN.md#state-ownership-and-lifecycle). This child retains no persistent state; its output owns the small result or encoder arrays.

## Failure, Concurrency, and Constraints
[ObservationRecords](../ObservationRecords/DESIGN.md#failure-concurrency-and-constraints) owns common current admission, metadata/work, cancellation and opaque-supplier accounting. Child-specific rejection is the unavailable quantity/domain described above.

## Verification and Change Impact
Free-fall zero specific force, stationary supported minus-gravity, offcenter centripetal/tangential acceleration and rotated gyro, instantaneous spatial gravity with no time-derivative integration, stale-time and actual supplier ledger replacement rejection. [Test owner](../../../../../Tests/MechanicsObservationsTests/DESIGN.md) owns execution. Shared evidence/profile limits are in [ObservationRecords](../ObservationRecords/DESIGN.md#verification-and-change-impact). Changed quantity semantics require these affected oracles and consumers to be requalified.
