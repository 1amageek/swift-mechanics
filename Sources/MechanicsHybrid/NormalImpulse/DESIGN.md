# Mass Based Normal Velocity Jumps

## Purpose and Scope
Own frictionless independent normal-mode impulses using actual Dynamics inverse-mass and independently recomputed original body inertia action. Parent: [MechanicsHybrid](../DESIGN.md). No children. Full DY006/TI005..006 remain IM24 after the admitted initial handoff.

## Responsibilities and Boundaries
Own the preceding responsibility and immutable public artifacts. Runtime owns publication/lifecycle, Integration owns smooth stages, Dynamics owns mass/original inertial operators, Collision owns geometric witnesses and ContactLaws owns selected threshold restitution. Constraint/wake reconciliation is an IM16 consumer obligation.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Hybrid](../DESIGN.md) | parent | IM24 dispatch | Sole module composition | Full eventual domains retained |
| [Runtime](../../MechanicsRuntime/DESIGN.md) | depends on | Required trials/checkpoint/contributors | Last accepted prefix | No nested Integration on outer owner |
| [Integration](../../MechanicsIntegration/DESIGN.md) | depends on | Actual Euclidean explicit reintegration | Isolated query owner | No dense-output guarantee |
| [Dynamics](../../MechanicsDynamics/DESIGN.md) | depends on | Actual inverse mass/original action | Hard jump | No compliant force substitute |
| [Collision](../../MechanicsCollision/DESIGN.md) | depends on | Exact analytic witness | Actual root gap | Translation CCD is not curved trajectory |
| [ContactLaws](../../MechanicsContactLaws/Impact/DESIGN.md) | depends on | Required impact prediction | Restitution/loss | No additional damping |
| [Tests](../../../Tests/MechanicsHybridTests/DESIGN.md) | verified by | Analytic jumps and bounce | Behavior proof | Selected profiles root-owned |

## Architecture
```text
accepted identified state -> independent trajectory query -> directed root/gap
 -> exact framed point row -> mass-based impulse -> original momentum/law/energy acceptance
 -> outer Runtime transaction -> accepted event history / retained failed prefix
```

## Contracts and Invariants
Solve M*deltaV=J^T*p and vNormalAfter=-e*vNormalBefore, selecting e through required ContactImpactPredicting with normal energy=0.5*vNormalBefore^2/Wii, W=J*M^-1*J^T. Admit closing ports and positive effective inverse mass. Independent modes require caller-declared normalized off-diagonal bound and original law/energy residual acceptance; coupled/frictional modes fail explicitly. Recompute original M*deltaV, M*vBefore and M*vAfter using RigidEquationComputing originalInertialForce(includeBias:false); the parameter values represent velocity increments, so the homogeneous mass action has SI generalized impulse meaning. Dynamics inverseMassProduct is reused only for this linear operator, never force times dt. Impulse references scale mixed translational/angular generalized entries for dimensionless residual; energy acceptance is separately in joules. Preserve pre/post kinetic energy, modeled restitution loss, momentum and normal-law residual evidence.

## Runtime Flows
Validate identity/domain/capacity -> operation-local bounded phases -> selected supplier witnesses -> independent original acceptance -> immutable result or typed failure. Non-inline phase boundaries return setup/root/impulse workspace before nested final Runtime validation; target-specific physics/memory fallbacks do not exist.

## State, Ownership, and Lifecycle
Immutable Sendable inputs/results/providers, exclusively owned inout ledgers/workspaces. Persistent event state is an explicit required contributor. Shared cancellation uses identical short Mutex<Bool> storage on all targets; attempt work/results are exclusively owned values; callbacks/supplier execution stay outside locks. Isolated query sessions explicitly shutdown after synchronous use; no queued ordering or global cache. Apple Runtime-dependent paths declare macOS15/iOS-tvOS18/watchOS11 availability.

## Failure, Concurrency, and Constraints
Caller provides count/byte/storage/iteration/operation/time/error limits. Hybrid query/root/event counts are separate from NumericalWork, CollisionWork, ContactWork and Integration charged-work reports. Successful supplier work remains in its original unit; failed unavailable work is marked and stops without retry. Bounded phases preserve all source inputs. Allocations/COW and wall-time latency are unmeasured; no performance claim follows from owned buffers or Sendable. Invalid revisions/direction/root, unresolved impulse, unsupported physics, capacity/cascade/spacing exhaustion and cancellation fail with actual accepted prefix.

## Verification and Change Impact
[Test owner](../../../Tests/MechanicsHybridTests/DESIGN.md) proves analytic momentum/restitution/energy, independent simultaneous modes/order, real bounce time and height/trajectory, restart equivalence, stale geometry/model, nonfinite/coupled mode, rejected jump/continuation and resource/cancel/last-prefix boundaries. Root proves exact selected Native/WASM/Embedded public execution. Domain/frame/impulse/continuation changes invalidate downstream impact derivatives, sensors and constrained wake consumers.

### Actual service and proof boundary

| Component | Actual selected production entry | Behavioral owner |
|---|---|---|
| ImpactPorts | ImpactPortAdapting.prepare / RigidHardImpactAdapter | HybridImpulseTests |
| NormalImpulse | NormalImpulseSolving.solve / IndependentNormalImpulseSolver | HybridImpulseTests |
| EventEvolution | HybridEvolving.advance / ReferenceHybridEvolution; required trajectory/environment witnesses | HybridEvolutionTests |
| Continuation | HybridContinuationProvider and HybridContributors required validation | HybridEvolutionTests |

No build/runtime qualification is inferred from these declarations. The root owns actual selected Native/ordinary WASM/Embedded qualification. Full simultaneous coupled, frictional, general event/manifold, support reconciliation, and nonsmooth time stepping remain IM24 obligations.

The mass-only Dynamics inverse operator is homogeneous: the SI generalized impulse RHS (N s or N m s) maps to velocity increment in the same basis, without applying a time step. The supplier's `acceleration` field names its algebraic output; this component gives it the velocity-increment interpretation only for `inverseMassProduct`. Owned row, inverse-row, Delassus and acceptance buffers are reserved before nested supplier scratch; supplier ledgers are absorbed in their own numerical units. Original inertial action with bias disabled supplies independent momentum and kinetic-energy evidence.
