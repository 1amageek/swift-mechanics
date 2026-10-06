# KinematicObservations

## Purpose and Scope
Body-mounted pose, geometric origin motion and joint chart encoders. Parent: [MechanicsObservations](../DESIGN.md). No children. Own selected IM25 SE-001..003; full domains remain tracked by the module owner.

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

## Architecture
```text
validated source + mounting -> required frame composer -> framed motion; identified joint layout -> chart encoder
```

## Contracts and Invariants
Fixed sensor-to-body mounting composes actual FrameMotion with a stationary relative transform. Returned velocity/acceleration are geometric derivatives at the sensor origin in world axes, not a world-origin spatial field. Encoder position/rate/velocity/acceleration arrays retain distinct q/v counts and explicit per-entry dimensions and convention; only published joint manifolds with an identified chart are admitted.
AF30's injected FrameMotionComposing port admits exact reference-equivalent successes only. The opaque call is preceded by its irreversible declared quantum; after successful return and cancellation checks, the original FrameMotionComposer is called for the same body motion and fixed relative mounting under an additional accounted quantum. Full pose translation, geometric velocity and geometric acceleration compare exactly; orientation compares original rotation matrices so quaternion sign does not manufacture a mismatch. Successful but unrelated or merely approximate supplier motion fails `invalidSupplierEvidence`. The observer publishes the canonical accepted meaning without changing equations, units, source or mounting. Original composition is verification, not a silent fallback after supplier failure.
[ObservationRecords](../ObservationRecords/DESIGN.md#contracts-and-invariants) owns the shared SI, exact-time, temporal, required-service and failure contract. This child adds only the quantity meanings above.

## State, Ownership, and Lifecycle
Source/result ownership and all-target Sendable are defined by [ObservationRecords](../ObservationRecords/DESIGN.md#state-ownership-and-lifecycle). This child retains no persistent state; its output owns the small result or encoder arrays.

## Failure, Concurrency, and Constraints
[ObservationRecords](../ObservationRecords/DESIGN.md#failure-concurrency-and-constraints) owns common current admission, metadata/work, cancellation and opaque-supplier accounting. Child-specific rejection is the unavailable quantity/domain described above.

## Verification and Change Impact
Independent analytic sensor-offset pose/velocity/acceleration, prismatic encoder dimensions, quaternion 7/6 position/rate separation, lowered current policy, cancellation and over-capacity mounting before a failing composer. [Test owner](../../../../../Tests/MechanicsObservationsTests/DESIGN.md) owns execution. Shared evidence/profile limits are in [ObservationRecords](../ObservationRecords/DESIGN.md#verification-and-change-impact). Changed quantity semantics require these affected oracles and consumers to be requalified.
The existing source-failure case also exercises a successful stationary-identity composer on the independently known rotating/offset fixture and expects typed refusal with known work preserved. This closes a concrete source-association counterexample; no encoder or sensor domain is added.
