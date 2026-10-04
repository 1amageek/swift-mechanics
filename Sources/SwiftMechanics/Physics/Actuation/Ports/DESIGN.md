# Identified scalar and transmitted mechanical ports
## Purpose and Scope
Parent [Actuation](../DESIGN.md). Children: none. Initial qualified IM14 component; eventual AC-001..008 ownership remains with the module.
## Responsibilities and Boundaries
Owns immutable model/joint/frame/chart/law-revision bindings, samples, budgets and affine transmission. Independent scalar charts admit one-q/one-v revolute, prismatic and screw joints only. q-rate equals v; spherical, floating, custom, nonlinear transmission charts require their own derivative contract and are not inferred. Scalar efforts are N for translation, Nm/rad for rotation; power is effort times measured rate. Multi-DOF rows publish output coordinate dimension and coefficient dimensions implicitly as output-coordinate/input-coordinate. Caller coefficients represent the current instantaneous derivative and prescribed drift; no position integration/Hessian is invented. Body mapping uses actual Loads point mapping; tensile tendon mapping uses actual CableRouteResponse gradient/drift. No dynamics or reaction solution.
## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Actuation](../DESIGN.md) | parent | dispatch domain | composition | root owns index |
| [Runtime](../../../Execution/Runtime/DESIGN.md) | depends on | contributor/trial requirements | accepted ownership | Runtime budgets separate |
| [Loads](../../Loads/DESIGN.md) | depends on | point/cable mapping | original power | no inferred dynamics |
## Architecture
```text
ActuationBinding -> sample/state full equality -> scalar law
coefficient row / Loads body Jacobian / Loads cable route -> transpose effort + original power balance
```
## Contracts and Invariants
Caller bindings identify actuator, law revision, model stamp, joint and world frame, q/v indices, scalar chart, coordinate authority and state domain. Effort laws require dynamicState authority; prescribed commands require prescribedMotion authority. Law revision is caller authority for immutable parameter identity; every parameter change requires a new revision and reset/migration policy. Bounds and per-text UTF8 metadata limits are explicit. maximumBindings bounds registry size and scanned compiled joint records. Control byte/scalar capacity reports peak logical phase storage, excluding caller inputs, runtime allocator overhead and supplier-owned storage; it is not a measured heap bound. Original virtual plus drift power must equal applied effort times actual port rate within caller tolerance. Work ledgers are distinct: ActuationWork control/traversal/payload, NumericalWork scalar algebra, LoadWork supplier mapping, RuntimeStepControl transaction work. Response requestedInput/appliedInput are command units: effort/velocity/position for the selected drive mode, volts for motor, m^3/s for chamber, dimensionless activation for muscle. Motor/fluid requestedEffort is the counterfactual unclipped-input BE effort, not an accepted over-envelope state; muscle requested/applied effort coincide because activation clipping is reported at the input port. No success implies transmission inertia or force from kinematics.
## State, Ownership, and Lifecycle
All public configurations/bindings/states/outputs are immutable Sendable. Services are immutable Sendable values. Only exclusive caller inout ledgers and Runtime trial buffers mutate. No target-dependent state, global cache, unchecked isolation or hidden history. State lifetimes follow caller accepted/trial ownership; failed calls publish no new state.
## Failure, Concurrency, and Constraints
Nonfinite input/output, invalid SI parameters/domain, stale binding/revision/time, incompatible mode/authority, residual mismatch, capacity/work/sequence overflow and cancellation are typed failures. Caller bounds precede repeated scans/allocation; fixed scalar models have bounded phase functions and no per-iteration arrays. Explicit provider ledgers are not merged or reset. Float64/reference CPU is the selected implementation, with no silent backend substitution.
## Verification and Change Impact
[Test owner](../../../../../Tests/MechanicsActuationTests/DESIGN.md) checks actual drive modes, clipping/recovery, independent BE balances, transmission virtual work, stale/domain/budget/cancel failures and Runtime checkpoint/rejection/restoration. Root owns exact-profile integration. Changes to binding/state/energy semantics invalidate dependent contributors and orchestrators.
