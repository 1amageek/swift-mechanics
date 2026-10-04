# Observations component

## Purpose and Scope
Parent: [responsibility owner](../DESIGN.md). IM25 owns SE-001..003. The stopped AF18 source handoff remains unregistered. AF30 resumes it on the qualified48cf8df supplier baseline. No live model_records writer exists; root transfers exclusive ObservationRecords, KinematicObservations, InertialObservations and WrenchObservations child/source/test ownership to reaction_paths. The existing selected13 physical cases and original contracts remain obligations, with the concrete successful-supplier association counterexamples closed before registration. Root owns this index, graph/probes/scripts/progress, producer changes and commits. Children are indexed only after their contracts exist.

| Child | Owned contract |
|---|---|
| [ObservationRecords](ObservationRecords/DESIGN.md) | Bounded identified source, mounting, exact time and shared quantity/provenance contract |
| [KinematicObservations](KinematicObservations/DESIGN.md) | Mounted geometric motion and identified joint chart encoders |
| [InertialObservations](InertialObservations/DESIGN.md) | Gyro and sensor-origin specific force |
| [WrenchObservations](WrenchObservations/DESIGN.md) | Identified physical wrench and limited axial reaction |

## Responsibilities and Boundaries
Own framed/time-bound mechanical observation meanings, mounting and exact force-versus-impulse distinctions. Read actual immutable compiled/kinematic/mechanical outputs; do not infer unreported reactions. Sensor scheduling, noise, buffering and shutdown belong to IM26. Producer implementations and frozen Mechanisms remain read-only; other workers' changes must be preserved.

## Related Designs
| Design | Relationship | Contract used | Cautions |
|---|---|---|---|
| [Joints](../../Modeling/Joints/DESIGN.md) | depends on | Actual tree motion, q/v conventions and required point motion | FrameMotion is geometric at the moving origin; q quaternion storage is not angular velocity |
| [Compiler](../../Modeling/Compiler/DESIGN.md) | depends on | Identified immutable model/state evaluation | Check complete stamp/layout; source acceleration is supplied state, not automatically dynamically certified |
| [Dynamics](../../Physics/Dynamics/DESIGN.md) | depends on | Actual framed inertial quantities/solved motion | Inertial resultant is not a support reaction; planar/n=0 limitations remain explicit |
| [Loads](../../Physics/Loads/DESIGN.md) | depends on | Identified physical wrench/force channel and gravity data | Generalized-only loads do not provide application/decomposition authority |
| [Mechanisms](../../Physics/Mechanisms/DESIGN.md) | depends on | Qualified source-bound ConstrainedMotion and explicit force/impulse meaning | General bearing six-axis reaction decomposition unavailable; rank representative is explicit |

## Architecture
```text
exact source stamp/time + actual pose/velocity/acceleration + fixed mounting
 -> explicit framed kinematic quantity / gyro / specific force
identified physical force or impulse + reference point + sign/compensation
 -> mounted observation retaining source and fidelity or typed unavailable
```

## Contracts and Invariants
Pose/encoder/velocity/acceleration reads retain SI units, continuous quantity and exact source time/frame. Distinct q/v charts stay distinct. Fixed body-to-sensor mounting yields sensor-origin acceleration from actual linear/angular derivatives plus alpha-cross-offset and centripetal terms; specific force is rotated (a-g), not world acceleration. Gravity data is explicitly bound to sample time; no inferred time integration. Dynamic acceleration authority is distinct from state-supplied derivatives. A solved generalized acceleration must be reconciled with its exact source pose/v/time/layout before body/point acceleration evaluation.
Physical wrench shift/rotation uses its declared reference point, mounting, sign and explicit gravity compensation at the true COM. Impulse is not divided by an invented duration. General six-axis bearing reaction and missing complete force-path decomposition fail explicitly. Known identified axial components preserve limited fidelity/reaction ambiguity. Selected statics use actual admitted spatial scalar mechanics rather than fabricate n=0 dynamics.
Public operations are protocol requirements with typed failures; immutable Sendable observations and exclusive caller budgets. Lower contracts fix exact owner/input/result/oracle before source declarations. Full SE-001..003 remains open outside admitted domains.

## State, Ownership, and Lifecycle
Stateless call-local computation and immutable returned records. Same storage/isolation/Sendable on Native/WASM/Embedded. No retained mutable sensor stream, hidden cache or asynchronous callback lifetime. Scheduling and contributor histories remain IM26-owned.

## Failure, Concurrency, and Constraints
Checked metadata/layout/work/storage envelopes before traversal/allocation; stale revision/time/frame/mount/acceleration, unavailable decomposition, units/temporal mismatch, nonfinite supplier output, resource/cancellation and known/unknown supplier work remain explicit. Producer changes require root coordination.

## Verification and Change Impact
Independent accelerated/rotating motion, frame/mount covariance, free-fall zero specific force, stationary supported minus-gravity, offcenter centripetal/angular acceleration, gyro and actual scalar static support reaction. Shifted wrench/sign/gravity compensation and force-versus-impulse failure; stale/missing acceleration and ambiguous reactions reject. Root registers only frozen handoffs, executes actual Native tests and selected original profiles; scheduling and full-domain claims remain separate.

### Consolidation contract
This directory is a component inside the SwiftMechanics module, not a separate SwiftPM target. Its existing public behavior and exact-profile evidence remain its contract authority. Cross-component access uses the documented contracts; internal visibility alone does not grant admission or publication authority. Source relocation requires integrated behavioral requalification.

## AF30 source-bound supplier qualification

The source owner closes two concrete original-path counterexamples: an injected FrameMotionComposing returning a stationary identity for a moving offset sensor, and an injected KinematicObserving retaining source/header IDs while changing the mounting offset. Original source/mount pose, linear/angular velocity and acceleration must match before IMU/wrench publication. Child contracts own exact association, typed refusal and additional bounded work before source declarations. Existing suppliers, sensor schedules, noise and general bearing decomposition stay outside this responsibility. Root freezes and registers the actual source/tests before selected Native and original WASM/Embedded public qualification.

AF30 frozen source/test Native and original selected public Native/ordinary-WASM/Embedded qualification passed; [canonical evidence](../../../../Verification/FoundationVerification/DESIGN.md#af30-selected-observation-qualification) owns exact execution and131072-byte guard results. This admission does not certify the unavailable bearing port or IM26 schedules.
