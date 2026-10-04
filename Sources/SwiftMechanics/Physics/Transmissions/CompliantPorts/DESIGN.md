# CompliantPorts

## Purpose and Scope
Parent [MechanicsTransmissions](../DESIGN.md); no children. Actual one-dimensional shaft inertia/passive torque, backlash flank law and direction-dependent dissipative drag. Initial TR-007/010 constitutive portion. Full TR-001..011 ownership remains after this closed initial handoff.

## Responsibilities and Boundaries
Own the contract below; consumer owns constrained evolution, model/snapshot binding and dynamic reaction solve. Tooth/contact geometry belongs to IM47, not this ideal ratio or constitutive port.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [Parent](../DESIGN.md) | parent | IM13 ownership | Initial subset only |
| [Bindings](../PortBindings/DESIGN.md) | depends on | Frame/axis/map and work units | Scalar power only |
| [Ideal](../IdealNetworks/DESIGN.md) | depends on | Physical affine rows | No ideal closure required by backlash |
| [Scalar ports](../../Constraints/ScalarJointPorts/DESIGN.md) | depends on | Actual passive torque/potential | Unwrapped scalar rotary shaft |
| [Tests](../../../../../Tests/MechanicsTransmissionsTests/DESIGN.md) | used by | Energy/branch/dissipation proof | Root owns exact profiles |

## Architecture
```text
immutable law + current scalar input + accepted contribution -> actual constitutive evaluation -> original power check -> immutable trial
```

## Contracts and Invariants
Shaft energy/inertia is the intrinsic one-dimensional generalized coordinate metric, not reconstructed world-frame body energy or moving-frame spatial inertia. Shaft rotational inertia J>0 contributes required inertial effort J*acceleration and kinetic energy J*omega²/2. Actual IM12 ScalarJointPortEvaluating supplies spring/damper torque and potential; attachment is the current supplied axial port map. Backlash uses physical phase s, clearance b>=0, z=s-b if s>b, z=s+b if s<-b, else zero. Potential=k*z²/2; restoring phase effort=-k*z. Flank damping acts only when moving further into an engaged flank: -c*sdot then, otherwise zero. Dissipation=-c*sdot² in that admitted closing branch. Phase effort maps with physical ci, preserving power=sum(Qi*vi)=phaseEffort*sdot. Continuation is immutable numerical contribution identified by network/row/law/layout/model revision, time/phase/branch/stored energy; initialization validates real phase and energy, trial does not mutate accepted state. Runtime serialization, integration and acceptance belong to the consumer. No contact impulse/engagement state or accumulated heat integration is fabricated. Directional drag uses caller positive/negative viscous/Coulomb magnitudes: effort=-cDirection*v-fDirection*sign(v), power<=0; zero-speed dry friction is an interval rather than a selected static effort. This is explicit loss, not a guessed efficiency or worm self-locking law.

## Runtime Flows
Admission precedes bounded traversal/allocation. Local non-inlined phases retain fixed stack boundaries. Supplier failure halts once; no retry/substitution. Final cancellation check precedes publication.

## State, Ownership, and Lifecycle
Immutable law and accepted/trial contribution records; no accepted-state mutation. Shaft/drag admit 64 scalar-equivalent slots before their fixed one-binding owner view, needed by the common binding validator. Backlash trial admits n+64*p+24 slots before owned effort/port/state publication; initialization admits 24 for continuation. Caller arrays remain immutable. No evolution, accumulated-heat state, runtime checkpoint or shared mutable storage is owned here.

## Failure, Concurrency, and Constraints
Consume [Bindings work/cancellation authority](../PortBindings/DESIGN.md). Shaft invokes the required IM12 passive service once with separate constraintWork, retaining its typed failure. Finite/domain and law revision/branch/energy checks gate trial publication. A stale contribution or nonfinite power fails. The law explicitly distinguishes compliant flank force from impulse, directional drag from guessed efficiency, and zero-speed static interval from a selected torque. Extended engagement/self-locking laws are not admitted.

## Verification and Change Impact
Shaft independent inertia power and spring-energy balance, backlash finite-difference potential derivative/free/reversal/closing/opening branches and accepted-value preservation, directional drag dissipation/static interval, stale continuation and actual supplier failure. Law/state changes affect IM16 and future runtime acceptance consumers.
