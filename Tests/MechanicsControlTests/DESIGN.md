# Sampled control physical verification

## Purpose and Scope
Test owner for [Control](../../Sources/SwiftMechanics/Execution/Control/DESIGN.md); children none. DESIGN precedes source. Initial behavior/profile qualification is pending; full CO-001..003/005..008 and complete210 remain open.

## Responsibilities and Boundaries
Prove the actual dimensioned sample/hold/servo or computed-torque path through real rigid mechanics, existing RK4 and original bound Runtime continuation. Scalar formulas serve independent test oracles only; no mock physics, second stepper or standalone admitted-state publication can satisfy completion.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Ports](../../Sources/SwiftMechanics/Execution/Control/Ports/DESIGN.md) | depends on | Identity/unit/feedthrough admission | Graph/input refusal | No unfinished sensor dependency |
| [SampledFeedback](../../Sources/SwiftMechanics/Execution/Control/SampledFeedback/DESIGN.md) | depends on | Effective interval/PID/filter/law | Numerical oracle | Existing Actuation tests remain supplier proof |
| [MechanicalPlant](../../Sources/SwiftMechanics/Execution/Control/MechanicalPlant/DESIGN.md) | depends on | Real mechanics/RK4/force/energy | Physical evidence | Original profiles separate |
| [Continuation](../../Sources/SwiftMechanics/Execution/Control/Continuation/DESIGN.md) | depends on | Real Runtime atomic state/replay | Lifecycle evidence | No bare value commitment claim |

## Architecture
```text
actual compiled mass/axis/COM + raw encoder + dimensioned target
 -> required control session -> actual drive/inverse/forward + RK4
 -> independent exact trajectory/force/work and bounded tracking oracle
 -> real reject/checkpoint/restart -> same next command/state/motion
```

## Contracts and Invariants
Closed initial plant m=2 kg,q=v=0,h=.1 s,held force3 N must use real mechanics/RK4 and yield a=1.5,q=.0075,v=.15; held work and actual deltaK=.0225 J. Keep nominal sampled servo work0 separate. Disturbance -1 N gives a=1,q=.005,v=.1 with actuator work.015/disturbance work-.005/deltaK.01. Computed torque aRef=.7 with that disturbance requires2.4 N before limits and q=.0035/v=.07. Use actual originalInertialForce/kernel energy, not only linear diagnostics.

Repeated periods compare original physical tracking/disturbance motion against an independently integrated sampled-state recurrence. Independent PID/BE filter/antiwindup/clipping expectations must use actual actuator outputs and tracking, including saturation/recovery and limits changing achieved acceleration. Non-dyadic tick/effectiveDt, mismatched raw sourceTime, command unit/sequence/mode, wrong frame/model and direct-feedthrough cycles fail. Axis orientation/COM/mass/source association and physical original force/energy poisoning detect misleading supplier acceptance.

## State, Ownership, and Lifecycle
Each test owns a cold control/session factory, immutable input and exclusive work. Genuine Runtime trial staging/rejection/restoration checks complete physical/controller/actuator/integration/RNG tuple and no external release on reject/failure. An injected reject-after-real-prepare test driver may call original session.performTrial/actual equation.prepare and nextRandom then reject; it does not implement a second numerical stepper. Actual subsequent ReferenceExplicitIntegrator behavior proves restored commands/motion. Test observation captures, one-shot rejection gate and cancellation owner each use a private let Mutex. Reads/mutations enter only withLock; no callback runs under those locks; release follows each test owner. The storage/isolation/access/release contract is identical on Native/WASM/Embedded. Shared fault counters/cancellation use the same Mutex owner on all targets with deployment guards inside test bodies; no global mutable fixture.

## Failure, Concurrency, and Constraints
Test caller graph/metadata/tick/payload/validation/physical capacity, operation/iteration/fill/supplier limits and cancellation before/after real work. Simultaneous numerical/actuation/load ledger reset on success/throw must preserve every known prefix and original cancellation closure. Missing/pending/corrupt or physically mismatched contributor records fail without replacing the accepted prefix. Native error-carrier layout must remain smaller than the original inline IntegrationFailure record; actual integrator invalid-target refusal and actual Runtime truncated-checkpoint refusal must retain the underlying code, accepted prefix and work evidence through indirect cases. These are failure-representation tests, not replacement mechanics. Real observer/restart/shutdown ownership, checkpoint compatibility, failed solver/work unavailable flags and stage order/reentry are exercised. No tests/build are run until root registers the stable source graph and assigns independent proof.

## Verification and Change Impact
One coherent owned review and finding-specific repair converge the stable snapshot. Dedicated Native behavioral proof and root original Native/ordinary-WASM/Embedded-WASM physical public probes retain the exact qualified toolchain/SDK and131072byte original stack acceptance. Root owns parent evidence, shared registration, integration and commit. Changes to temporal/law/energy/contributor contracts invalidate the corresponding local and consumer evidence; this initial domain does not qualify LQR/task-space/estimation/general external bridges.
