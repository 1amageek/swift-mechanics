# ExternalCommands

## Purpose and Scope
Parent: [Control](../DESIGN.md). No children. Own CO008 selected scalar external command timing, explicit interpolation/delay, ordering and value checkpoint semantics. The selected scalar service is qualified and registered; transport, general vector signals and coupled participant convergence are separate owners.

## Responsibilities and Boundaries
Admit the actual ActuatorBinding against CompiledMechanicalModel through its original public validation. Command input retains producer/model/configuration/sequence/source and arrival timestamps and declared unit. Selection at the actual ControlClock tick consumes known arrived data and returns a tentative actual DriveCommand plus immutable next scheduling state. A query never commits Runtime, invents actuator state or changes plant time. Its drive operation invokes actual qualified DriveEvaluating.step with caller-owned original servo/sample/state/work, checks returned binding and exact interval endpoint, and returns both tentative actuator response and scheduling checkpoint. Its selection can also be passed directly by the caller.

## Related Designs
| Design | Relationship | Contract Used | Caution |
|---|---|---|---|
| [Control](../DESIGN.md) | parent | Control ownership | Selected service only; full CO-008 remains open |
| [Actuation Ports](../../../Physics/Actuation/Ports/DESIGN.md) | depends on | ActuatorBinding.validate and ActuationWork | Supplier admission remains original |
| [DriveLaws](../../../Physics/Actuation/DriveLaws/DESIGN.md) | depends on | DriveCommand and DriveEvaluating | Command selection is not actuator evolution |
| [SampledFeedback](../SampledFeedback/DESIGN.md) | depends on | ControlClock.time/end | Clock rounding remains original |
| [Core Units](../../../Mathematics/Core/Units/DESIGN.md) | depends on | UnitConverting/UnitDefinition | Conversion is explicit and failure preserves cause |

## Architecture
```text
bound model + external source + mode/dimension + delay/age/gap policy
 -> ordered timestamped arrival batch -> immutable retained command stream
 -> actual local clock tick - declared delay
 -> exact / zero-order hold / bracketed linear interpolation
 -> original-unit metadata + SI DriveCommand + tentative next checkpoint
 -> caller's actual DriveEvaluating (separate plant/Runtime authority)
```

## Contracts and Invariants
Spatial/planar scalar translation/rotation binding follows existing ActuatorBinding.validate. Effort means N or Nm, speed m/s or rad/s, position m or rad. Angle is an explicit physical dimension; torque follows existing SI newtonMetre energy dimension. Source/arrival/tick times are finite; source<=arrival, arrivals nondecreasing and sequences strictly ordered, source times strictly increase. Duplicate/out-of-order/stale inputs are typed failure; no silent sorting/reuse. Delay and maximum age/gap are caller-declared nonnegative finite values. Source time must be at least initial epoch. Admission rejects a late packet at or before an already selected query time, because it would change published command history.

All retained records bind exact actuator/model/law/continuation/source/configuration identity. Commands stay in declared units until explicit UnitConverting calls; original endpoint units and converted SI values survive selection. Maximum age is application time minus the older selected endpoint source time, including declared delay. Hold age, linear bracket gap, arrival availability and finite interpolation are independently checked. Exact mode requires a timestamp equality; linear mode requires a known right endpoint unless the target exactly equals a packet time. Extrapolation and unseen future endpoints fail. Ticks strictly advance; each selected target equals original ControlClock.time(at:tick) minus delay, with finite and representably distinct checks. Same checkpoint replay produces same selected command with original packet sequences/weights.

## Runtime Flows
Create: actual binding validation -> producer/config/mode/metadata and clock admission -> immutable empty checkpoint. Append: validate prior checkpoint and incoming batch/capacity/work -> exact SI conversion -> atomic immutable checkpoint with retained ordered packets. Select: actual tick time -> immutable state validation -> arrived packet lookup -> declared selection -> actual DriveCommand initializer -> next checkpoint only after success. Drive calls the actual supplier only after source selection and exact original binding/sample-time/mode admission; actual ControlClock.end determines dt, and no scheduling/actuator proposal escapes on supplier failure. No partial stream/state escapes on failure; consumed work remains charged. Explicit prune retains at least the packet immediately preceding the last selected target and all later packets, and never changes the last selected timestamp.

## State, Ownership, and Lifecycle
Immutable Sendable bound stream, packets/checkpoints/selection. Mutable arrays/counters are operation-local inout, with checked cumulative storage/work and cancellation. Caller owns trial acceptance and rollback; no hidden process-global queue, socket, callback, raw state, unsafe pointer or target-conditioned Sendable. Raw restored checkpoint receives full bounded identity/time/order/unit checks before use; it is not a Runtime admission token. This component owns value checkpoint representation; binary wire persistence remains separate.

## Failure, Concurrency, and Constraints
Policy bounds packets, input batch, metadata bytes, allocation bytes and work. Checked arithmetic precedes retained arrays, metadata traversal is charged before equality, and cancellation precedes operation/iteration/publication. Typed errors distinguish source/binding/units/order/time/tick/stale/insufficient synchronization, capacity, overflow, nonfinite, supplier Core/Actuation/Control and cancellation. No hidden hold on failed linear/exact query, fallback units or unacknowledged command reuse.

## Verification and Change Impact
Later independent delay/hold/bracket/late/out-of-order/zero-step/clock-rounding tests, original unit conversions, checkpoint replay/pruning, actual DriveEvaluating mechanical command/energy path, and work/cancel failures on fixed Native/WASM/Embedded. New code alone does not qualify CO008. Changes to timing/identity invalidate caller checkpoint/plant/Runtime composition.

### Source review closure
The operation preserves original supplier errors (ControlFailure through an immutable indirect payload), never coerces error to a command. Maximum input age includes delay and is measured at application time. Metadata budget is cumulative across all comparisons; allocation budget covers both new retained packet and SI arrays by checked actual element stride. Same read/mutation contract across Native/WASM/Embedded: immutable stream/checkpoint/packets; inout operation work and local arrays; no shutdown owner or shared mutable callback queue exists. Selected behavioral and exact-profile evidence is owned by [ExternalCommandsQualification](../../../../../Verification/ExternalCommandsQualification/DESIGN.md); coupled plant and Runtime acceptance are separate obligations.

### Qualified selected service
Seven Native cases and the same six synchronous public cases pass on Native, matching ordinary WASM and Embedded WASM. Canonical registration passes seven service cases and sixteen retained JointStops/MJCF regressions. The [qualification owner](../../../../../Verification/ExternalCommandsQualification/DESIGN.md) records original equations, failures, source/object bindings and exact target limits. Original scalar timing/actuator contracts are unchanged; this handoff does not certify transport, vector channels, coupled participant convergence or full CO-008.
