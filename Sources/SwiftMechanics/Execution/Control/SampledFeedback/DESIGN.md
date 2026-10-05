# Sampled servo and computed-torque feedback

## Purpose and Scope
Parent: [Control](../DESIGN.md). Children: none. Own explicit controller clock, sample/hold/law association and tentative feedback evaluation for the initial CO-002/007 scope. DESIGN precedes source; qualification pending. General LQR/task-space/estimators/external co-simulation remain assigned future domains.

## Responsibilities and Boundaries
Reuse real DriveEvaluating/ScalarServo rules; do not implement a second PID or pretend an effort record is a physical plant result. Add a stated PD computed-torque acceleration request through real inverse rigid dynamics, followed by the existing effort-mode filter/limits. Produce candidate controller state/held effort only. MechanicalPlant owns stage physics/endpoint acceptance; Continuation owns staging, checkpoint association and actual post-commit release.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Control](../DESIGN.md) | parent | Selected law/clock dispatch | Root authority | No full CO completion |
| [Ports](../Ports/DESIGN.md) | depends on | Scalar typed sample/command | Input meaning | Endpoint-only exact observations initially |
| [DriveLaws](../../../Physics/Actuation/DriveLaws/DESIGN.md) | depends on | DriveEvaluating, ScalarServo, ActuatorState | Real PI/PD, filter, limits/antiwindup | Existing energy is start-sample approximation |
| [MechanicalPlant](../MechanicalPlant/DESIGN.md) | coordinates with | Real inverse solve and ZOH interval | Computed torque and physical response | Limits may change requested acceleration |
| [Continuation](../Continuation/DESIGN.md) | used by | Clock/sample/hold/PID candidate | Trial-only persistence | No mutable mirror |
| [Tests](../../../../../Tests/MechanicsControlTests/DESIGN.md) | used by | Independent law/clock oracle | Local evidence | Existing Actuation tests remain supplier evidence |

## Architecture
```text
actual bound trial at tick k + saved actuator state + exact feedback + timestamped target
 -> time/unit/mode association
 -> actual scalar servo OR desired acceleration -> actual inverse dynamics -> effort-mode drive
 -> existing limits/filter/antiwindup -> held applied effort + pending next controller state
```

## Contracts and Invariants
Clock configuration owns epochSeconds and a finite positive nominal periodSeconds. A saved UInt64 tick is converted only when exactly representable as Float64; checked multiplication/addition forms tickTime=epoch+tick*period. The next tick must not overflow, must advance representable time and must fall within caller time/tick bounds. Current physical time, controller time and actuator state.time must equal the current tick. Initial raw sourceTime equals sampleTickTime and actual physical time, but the fields remain separate to preserve their authorities. No delayed/previous-hold/interpolation policy is silently inferred.

Let end be the next tickTime and effectiveDt=end-start. Admission requires finite positive effectiveDt and start+effectiveDt==end. The servo receives this effectiveDt, not a guessed nominal dt; its returned state.time must equal end. This resolves Float64 boundary rounding explicitly. The candidate future actuator/controller state is pending during plant stages, then ready only at that exact endpoint. It is not required to equal the still-current trial physical time during preparation and cannot be checkpoint-admitted while pending.

Existing position mode uses Kp*deadband(qRef-q)-Kv*v plus integral effort; velocity mode uses Kv*deadband(vRef-v) plus integral effort; effort mode is direct filtered effort. Primary state is integral effort in N; secondary is the filtered target in the selected command units. Gains/limits must retain existing SI meaning: position Kp N/m, velocity Kv N s/m, integralGain N/(m s) for position or N/m for velocity, integralLimit/effortLimit N, speedLimit m/s, filterTimeConstant s. Derivative action uses measured velocity; there is no numerical differentiation or extra derivative filter. The existing BE target filter, deadbands, symmetric effort clipping, sampled-speed drive suppression and conditional antiwindup are retained exactly. Mode changes require explicit reinitialization of dimensioned filter state. Initial production does not claim a continuous hard speed limit merely from sampled suppression; endpoint envelope violations fail and roll back.

Computed-torque target is aRef+Kq*(qRef-q)+Kv*(vRef-v), with Kq in s^-2 and Kv in s^-1 and zero integral term in this initial computed-torque law. Real RigidDynamicsSolving.inverse includes admitted physical mass/bias/known force. Its requested effort passes through an actual effort-mode ScalarServo. Requested and applied efforts/accelerations remain distinct after filtering/saturation. The separate servo modes retain their real integral antiwindup law; no unimplemented computed-torque integral law is advertised.

The next held command is zero-order-held over [start,end]. Inputs must have the exact current tick timestamp and sequence; stale/out-of-order, skipped or future commands fail. This synchronous local contract is not an asynchronous co-simulation/network synchronization implementation. Controller randomness is absent in this deterministic initial law; any future stochastic law must use captured Runtime RNG and declared continuation rather than hidden global state.

## State, Ownership, and Lifecycle
Configurations, targets, saved clock records and outputs are immutable Sendable. Tentative PID/filter state is the actual ActuatorState staged in the original RuntimeTrial contributor; clock/sample/held command are a separate bounded controller contributor. No accepted controller state lives in an external mutable mirror. Call-local numerical workspace belongs to MechanicalPlant and is not a second accepted-state authority.

## Failure, Concurrency, and Constraints
Caller owns law domains, time/tick bounds, metadata and operation budgets, saturation/envelope rules and cancellation. Invalid gain, state/time/mode/source association, unrepresentable period, unsupported physical plant, uncheckpointable callback, cancellation and exhausted budgets are typed refusal. Successful/failed numerical and actuation supplier ledgers are reconciled before failure selection; all known prefixes and original cancellation closure authorities survive simultaneous reset/replacement. No old command reuse after failure.

## Verification and Change Impact
Independent scalar law arithmetic tests verify BE filtering, antiwindup blocked integration/recovery and clipping while actual plant trajectory tests verify tracking/disturbance, requested/applied separation and endpoint bounds. Non-dyadic period fixtures verify effectiveDt and future pending/ready times; incompatible modes, stale inputs and representability overflow refuse. Changing clock/law semantics invalidates its continuation schema and dependent consumers.
