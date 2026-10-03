# Hard Impact Geometry Ports

## Purpose and Scope
Own exact analytic Collision witness/model/frame/geometry validation and actual Joints point-normal rows for hard impacts. The compliant ContactResponse adapter deliberately rejects separate-impact laws and is not this operation. Parent: [MechanicsHybrid](../DESIGN.md). No children. Full DY006/TI005..006 remain IM24 after the admitted initial handoff.

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
Use actual world point velocities J*v without prescribed drift. A port normal points first→second, gap grows under positive normal relative speed, and scalar impulse p>=0 acts as +n on second and -n on first at witness points. Jpoint includes angular cross lever-arm terms. Geometry and model revisions, body/frame/collider identities, analytic fidelity, actual body/proxy poses, unit normal and witness balance are validated before any prepared output is returned. Row storage is reserved before per-row validation, and invalid rows cannot escape as a prepared impact. No force/timeStep input or compliant stiffness inference is used.

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

### Measured hard-port lifetime boundary

After the real Integration trial lifetime correction, Native 299 tests/public execution and ordinary WASM passed. The root's immediate stack-boundary diagnostic identifies first-impact row preparation as the new Embedded peak: prepareRow 57,312 + prepare 39,680 + evolution impactSegment 19,008 and the other callers total 138,816 static bytes. This is an owned hard-port lifetime defect; no profile change or diagnostic relocation qualifies the original artifact.

The public prepare boundary now retains an immutable request owner, while input/snapshot admission and rigid system assembly finish before the row loop. Each row uses immutable geometry/body/point-column owners between non-inline validation and construction phases. Proxy metadata, witness geometry/filter/fidelity, norm/balance/witness poses, body lookup/poses, selected law, lever arms and columns, then numerical charging/construction retain their original order. Rigid assembly still precedes row storage admission and sorting; per-row cancellation and duplicate priority are unchanged. Only the final phase produces PreparedImpact after every row succeeds.

```text
prepare -> immutable request
 -> admitSnapshot -> immutable snapshot owner
 -> assembleSystem -> immutable assembly owner
 -> prepareRows
    -> geometry pair -> metadata/witness validation
    -> body pair -> pose/law validation
    -> point columns -> original Jacobian row arithmetic
 -> final immutable PreparedImpact
```

All intermediate owners are final Sendable with let fields and strong immutable COW backing retention. The request/snapshot/assembly have one synchronous prepare lifetime; row geometry/body/column owners have one row lifetime bounded by maximumContacts. Column ArraySlices retain actual snapshot column backing per the public Joints contract. Rows and NumericalWork/LoadWork remain exclusive inout values, never stored in these owners; callbacks execute without cancellation locks. Public signatures, SI/frame meanings, budget charge/order, typed errors, physical acceptance and unsupported-domain admission remain unchanged on every target. Counts bound structural owner creation; allocator/copy and changed stack margin are unmeasured pending root original-profile qualification.
