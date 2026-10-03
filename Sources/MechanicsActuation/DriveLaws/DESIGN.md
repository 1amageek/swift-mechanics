# Scalar drive control and explicit prescribed command
## Purpose and Scope
Parent [Actuation](../DESIGN.md). Children: none. Initial qualified IM14 component; eventual AC-001..008 ownership remains with the module.
## Responsibilities and Boundaries
Owns effort, velocity and position drives, BE target filtering, saturation, deadband, conditional anti-windup and observable effort/power. Position/velocity modes produce effort; prescribed velocity returns a distinct command with no effort/reaction. Reaction/constraint evolution belongs to mechanism orchestration. Unwrapped affine coordinates only, SI gains and limits selected by caller. No delay/event history API is declared.
## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Actuation](../DESIGN.md) | parent | dispatch domain | composition | root owns index |
| [Runtime](../../MechanicsRuntime/DESIGN.md) | depends on | contributor/trial requirements | accepted ownership | Runtime budgets separate |
| [Loads](../../MechanicsLoads/DESIGN.md) | depends on | point/cable mapping | original power | no inferred dynamics |
## Architecture
```text
accepted servo state + sample + command -> mode/time/domain gate -> BE filter -> PI/PD request -> limits/conditional integral -> trial state + effort/power
```
## Contracts and Invariants
State primary is integral effort, secondary filtered target in command units. Mode changes require explicit reset because filtered targets have different dimensions. BE filteredTarget=(old+dt*target/tau)/(1+dt/tau); tau=0 is instantaneous. Effort command is direct; velocity target is speed-limited; position servo uses positionGain*deadband(error)-velocityGain*velocity+integral. Velocity servo uses velocityGain*deadband(error)+integral. Integral advances dt*integralGain*error, retained only if limits do not oppose that increment. Effort clips symmetrically and positive power is suppressed at the speed envelope; braking remains admitted. Output requested effort is pre-antiwindup candidate, applied effort uses retained integral. Source work equals applied effort*velocity*dt; control/filter state is not a mechanical energy store. dt=0 observes effort and returns unchanged history.
## State, Ownership, and Lifecycle
All public configurations/bindings/states/outputs are immutable Sendable. Services are immutable Sendable values. Only exclusive caller inout ledgers and Runtime trial buffers mutate. No target-dependent state, global cache, unchecked isolation or hidden history. State lifetimes follow caller accepted/trial ownership; failed calls publish no new state.
## Failure, Concurrency, and Constraints
Nonfinite input/output, invalid SI parameters/domain, stale binding/revision/time, incompatible mode/authority, residual mismatch, capacity/work/sequence overflow and cancellation are typed failures. Caller bounds precede repeated scans/allocation; fixed scalar models have bounded phase functions and no per-iteration arrays. Explicit provider ledgers are not merged or reset. Float64/reference CPU is the selected implementation, with no silent backend substitution.
## Verification and Change Impact
[Test owner](../../../Tests/MechanicsActuationTests/DESIGN.md) checks actual drive modes, clipping/recovery, independent BE balances, transmission virtual work, stale/domain/budget/cancel failures and Runtime checkpoint/rejection/restoration. Root owns exact-profile integration. Changes to binding/state/energy semantics invalidate dependent contributors and orchestrators.
