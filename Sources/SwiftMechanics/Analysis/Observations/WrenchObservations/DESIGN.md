# WrenchObservations

## Purpose and Scope
Explicitly supplied identified physical wrenches and limited identified joint axial reaction observations. Parent: [MechanicsObservations](../DESIGN.md). No children. Own selected IM25 SE-001..003; full domains remain tracked by the module owner.

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
| [Constraints](../../../Physics/Constraints/DESIGN.md) | depends on | Numerical reaction nullity evidence | Preserve representative ambiguity | Does not identify a body wrench |
| [Loads](../../../Physics/Loads/DESIGN.md) | depends on | Instantaneous gravity datum | Time supplied by observation binding | No field time integration |

## Architecture
```text
physical identified wrench -> shift/rotation/compensation/sign; source-bound reaction -> identified scalar axial observation
```

## Contracts and Invariants
Physical input declares body/world axes, reference point, source stamp/time, load path identity and force-versus-impulse meaning. Shift/rotate to sensor origin, explicit into/out-of-body sign, optional subtract-body-gravity at actual COM. The literal compensation is observed physical input minus the body gravity wrench exerted on that body; it is not an inferred tared support reaction. Sign is applied after subtraction. Compensation admits uniform spatial body gravity and force only. Axial reaction reports one identified scalar component and representative nullity, never a fabricated six-axis wrench. General bearing/loop reaction decomposition and n=0 dynamics support remain typed unavailable.
AF30 retains these observation-port limits. Qualified ReactionPaths now provides bounded spatial and reduced planar physical recoveries; this adapter has no recovered-report input and does not claim those producer domains are absent. Caller-declared IdentifiedPhysicalWrench remains explicitly supplied path evidence, while axialReaction remains a scalar generalized component with retained ambiguity. No bearing interface is expanded during this ownership transfer. Both existing wrench operations accept mounted supplier results through the shared exact source/mount/header/full-motion verification before shifting, rotating or compensating any input.
[ObservationRecords](../ObservationRecords/DESIGN.md#contracts-and-invariants) owns the shared SI, exact-time, temporal, required-service and failure contract. This child adds only the quantity meanings above.

## State, Ownership, and Lifecycle
Source/result ownership and all-target Sendable are defined by [ObservationRecords](../ObservationRecords/DESIGN.md#state-ownership-and-lifecycle). This child retains no persistent state; its output owns the small result or encoder arrays.

## Failure, Concurrency, and Constraints
[ObservationRecords](../ObservationRecords/DESIGN.md#failure-concurrency-and-constraints) owns common current admission, metadata/work, cancellation and opaque-supplier accounting. Child-specific rejection is the unavailable quantity/domain described above.

## Verification and Change Impact
Actual spatial prismatic mass/constraint support gives lambda=mg; mounting rotation, true reference-point moment and virtual power, literal subtract-body-gravity policy at COM, sign reversal, actual instantaneous velocity impulse, temporal mismatch and unavailable six-axis decomposition. [Test owner](../../../../../Tests/MechanicsObservationsTests/DESIGN.md) owns execution. Shared evidence/profile limits are in [ObservationRecords](../ObservationRecords/DESIGN.md#verification-and-change-impact). Changed quantity semantics require these affected oracles and consumers to be requalified.
