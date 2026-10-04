# Selected electromechanical, fluid and muscle laws
## Purpose and Scope
Parent [Actuation](../DESIGN.md). Children: none. Initial qualified IM14 component; eventual AC-001..008 ownership remains with the module.
## Responsibilities and Boundaries
Owns explicit calibrated Float64/reference CPU scalar models with BE stepping and discrete power/energy balance. Mechanical motion is supplied as constant endpoint velocity over dt; no mechanical momentum solver is provided. DC motor: L>0,R>=0,K>0, reciprocal torque/back-EMF K, viscous b>=0, finite voltage/current/speed envelope; voltage clips, overcurrent rejects. Fluid: C=referenceVolume/bulkModulus>0, area>0, leakage>=0, fixed-compliance single-chamber linearization around reference volume; position/stroke and |A*x|/V envelope must hold. Negative pressure/cavitation and variable-compliance compressibility are outside domain. Muscle: BE activation, triangular active force-length, bounded Hill-like force-velocity, unilateral quadratic passive spring; positive lengths, speed/activation envelope. No metabolic or chemical energy claim.
## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Actuation](../DESIGN.md) | parent | dispatch domain | composition | root owns index |
| [Runtime](../../../Execution/Runtime/DESIGN.md) | depends on | contributor/trial requirements | accepted ownership | Runtime budgets separate |
| [Loads](../../Loads/DESIGN.md) | depends on | point/cable mapping | original power | no inferred dynamics |
## Architecture
```text
state + endpoint mechanical sample + bounded voltage/flow/activation -> closed scalar BE solve -> physical domain -> original balance acceptance -> trial continuation + effort + energy ledger
```
## Contracts and Invariants
Motor: L*(i1-i0)/dt=U-R*i1-K*w. E=L*i^2/2, effort=K*i1-b*w; U*i1*dt=deltaE+mechanicalWork+R*i1^2*dt+b*w^2*dt+L*(i1-i0)^2/2. Fluid: C*(p1-p0)/dt=Q-A*v-leak*p1. E=C*p^2/2, effort=A*p1; Q*p1*dt=deltaE+effort*v*dt+leak*p1^2*dt+C*(p1-p0)^2/2. The final square terms are numerical BE dissipation, separately reported from physical resistance/leakage. Muscle activation a1=(a0+dt*u/tau)/(1+dt/tau); fL=max(0,1-|length-optimal|/width). Shortening fV=(1+v/vmax)/(1-v/(curvature*vmax)); lengthening fV=(1+eccentricGain*v/vmax)/(1+v/vmax). Active tensile effort=-Fmax*a1*fL*fV. Passive endpoint effort=-k*max(0,l1-slack), l1=l0+v*dt. E=k*stretch^2/2; passive endpoint work equals deltaE plus nonnegative convex discretization loss. sourceWork is active mechanical energy exchange, not chemical/metabolic input. All original energy residuals are checked by caller SI-joule tolerance; unknown physiology and parameter calibration are caller authority.
## State, Ownership, and Lifecycle
All public configurations/bindings/states/outputs are immutable Sendable. Services are immutable Sendable values. Only exclusive caller inout ledgers and Runtime trial buffers mutate. No target-dependent state, global cache, unchecked isolation or hidden history. State lifetimes follow caller accepted/trial ownership; failed calls publish no new state.
## Failure, Concurrency, and Constraints
Nonfinite input/output, invalid SI parameters/domain, stale binding/revision/time, incompatible mode/authority, residual mismatch, capacity/work/sequence overflow and cancellation are typed failures. Caller bounds precede repeated scans/allocation; fixed scalar models have bounded phase functions and no per-iteration arrays. Explicit provider ledgers are not merged or reset. Float64/reference CPU is the selected implementation, with no silent backend substitution.
## Verification and Change Impact
[Test owner](../../../../../Tests/MechanicsActuationTests/DESIGN.md) checks actual drive modes, clipping/recovery, independent BE balances, transmission virtual work, stale/domain/budget/cancel failures and Runtime checkpoint/rejection/restoration. Root owns exact-profile integration. Changes to binding/state/energy semantics invalidate dependent contributors and orchestrators.
