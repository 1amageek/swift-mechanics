# FrictionalImpulse

## Purpose and Scope
Parent: [Hybrid](../DESIGN.md). No children. IM.AF35.12 owns one selected physical frictional impact for DY-006/CT-011. The selected source is registered with Native behavioral qualification; ordinary and Embedded WASM execution remains unqualified. Simultaneous/coupled-normal, general frictional contact evolution and complete DY-006/CT-012 remain open.

## Responsibilities and Boundaries
Admit original analytic contact/point kinematics and physical spatial inertia; solve normal restitution and tangential maximum-dissipation Coulomb impulse; reconstruct actual post-impact state and physical energy. Collision owns witness authority; Joints owns q/v/frame mappings; Dynamics owns mass and original momentum/energy; ContactLaws owns restitution prediction. This child publishes tentative immutable impact evidence, never a Runtime accepted token. Continuous load, elastic tangential history and force-times-step are not impulse laws.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Hybrid](../DESIGN.md) | parent | Impact responsibility | Selected Native-qualified law | Portable execution and Runtime admission remain unqualified |
| [ImpactPorts](../ImpactPorts/DESIGN.md) | coordinates with | Original ImpulseContactBinding identity | Same real witness semantics | Existing normal adapter refuses friction |
| [Collision](../../../Physics/Collision/Geometry/DESIGN.md) | depends on | Original CollisionWitness/Snapshot/Proxy | Regular analytic points and pair identity | No new ConvexQueries dependency |
| [Joints](../../../Modeling/Joints/Jacobians/DESIGN.md) | depends on | Original point columns and actual velocity/drift | World point tangent | Post state reevaluates original tree |
| [Dynamics](../../../Physics/Dynamics/DenseDynamics/DESIGN.md) | depends on | Actual inverseMassProduct | M^-1*J^T and velocity jump | No ArticulatedDynamics dependency |
| [Equations](../../../Physics/Dynamics/RigidEquations/DESIGN.md) | depends on | Original inertia, assembly and energy | Physical acceptance | No mass-only energy substitution |
| [ContactLaws](../../../Physics/ContactLaws/Impact/DESIGN.md) | depends on | ThresholdRestitutionPredictor and ContactWork | Actual restitution/normal loss | Continuous friction selection must be none |
| [LinearAlgebra](../../../Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | Original Float64 Cholesky | Tangential 2x2 solves | Disc KKT is not an associated normal cone QP |

## Architecture
```text
actual tree/state + identified analytic contact + world ContactBasis
    -> original snapshots/point rows J and drift
    -> original M^-1*J^T -> full original 3x3 Delassus W
    -> original normal restitution -> pn
    -> tangent SPD disc maximum-dissipation -> pt and stick/slip
    -> actual M^-1*(J^T*p) -> delta-v
    -> original post KinematicState/Snapshot and physical system
    -> original momentum, point velocity, Coulomb, virtual-work and energy gates
    -> tentative immutable result
```

## Contracts and Invariants
Input retains one original unconstrained spatial tree/state/inertia inventory, CollisionSnapshot/revision, original ImpulseContactBinding and right-handed ContactBasis in the actual world frame/revision. Constraint and simultaneous-contact inventories have no representation in this selected API; their mass projection and impulse law are outside its result claims. One regular analytic zero-approximation witness must match actual proxy geometry/filter/poses and reconstructed collider/body transforms within caller tolerances. Contact separation, witness balance, basis and original q/v mapping are checked. No external arbitrary contact rows are accepted. State time/revision and all original anchors remain retained.

The hard law selects an explicit finite isotropic Coulomb coefficient mu>=0 in the new policy, plus the original pair's separateImpact restitution policy. Pair continuous tangential friction/cohesion/rolling/spinning must be none: elasticCoulomb stiffness/history is not relabeled as a hard law. The original ThresholdRestitutionPredictor produces effective e in [0,1], rebound and normal loss. Separating/grazing speed is refused. No finite force or step duration is fabricated.

Rows order normal, first tangent, second tangent, and map v to second-point minus first-point velocity. Actual relative velocity adds original prescribed drift. W=J*M^-1*J^T retains all original entries. Selected normal/tangent coupling must be below the declared dimensionless independence bound; the matrix is never silently zeroed. Original returned-row restitution and Coulomb checks remain acceptance even for roundoff coupling. Tangential symmetry roundoff is bounded before an explicitly averaged symmetric 2x2 solve representation is used; original W and post-point velocities decide success. Positive scaled normal pivot and tangential SPD pivots are required; no regularization or mass fallback exists.

Normal impulse is pn=-(1+e)*vnMinus/Wnn. Tangent maximum dissipation minimizes vtMinus^T*pt + 0.5*pt^T*Wtt*pt over norm(pt)<=mu*pn with pn fixed. First solve ptStick=-Wtt^-1*vtMinus; strictly interior gives sticking. Positive-radius boundary ties within caller impulse tolerance are typed ambiguity failure. Outside the disc, solve pt=-(Wtt+lambda*I)^-1*vtMinus with lambda>0, bounded doubling/bisection and original disc/KKT gates. mu=0 is explicitly frictionless pt=0; zero tangent speed with an interior solution is valid sticking. Failed bracket/iteration/budget/cancellation yields no result. This is tangential Coulomb with independent restitution, not an associated cone QP.

Mass scale kg and velocity scale m/s normalize W and impulse. Shift lambda is dimensionless in normalized tangent equations. Returned impulses are N s, angular impulses N m s, velocities m/s and generalized rad/s or m/s in original v order. Actual delta-v is a final original inverseMassProduct(J^T*p), independently accepted against original body Newton/Euler mass product; an assembled candidate delta-v is not authoritative. Original reconstructed post point motion must match full original W and restitution. Sticking gates tangent speed; sliding gates cone radius and pt opposite actual post tangent velocity. Original energy must match normal loss plus tangential disc work.

The homogeneous numerical inverse-mass operation consumes a generalized impulse right-hand side here; its numeric output is interpreted as delta-v only at this impulse boundary. Its acceleration/driveForce producer labels are not exported as continuous physical acceleration/force evidence. Final momentum acceptance uses explicit generalized impulse scales (N m s or N s) and final physical point/body impulse work uses joules.

Prescribed walls are admitted only where the original body geometric columns are exactly zero; movable bodies must have negligible original drift under the original angular/linear admission. Broader moving dynamic charts are explicitly refused. Actual midpoint contact impulse work includes drift; generalized virtual work excludes it. Prescribed-wall impulse work is -p dot relativeDrift in joules, separately retained, and ΔK+normalLoss+tangentLoss-wallWork is gated. It is not finite-duration power. q/time/anchors are unchanged at the jump; post v is actually reevaluated through TreeKinematicsEvaluator and a new original physical assembly. No accepted-state publication follows.

## Runtime Flows
Bound capacities/storage/cancellation -> original tree evaluation/contact admission -> original physical assembly -> guarded three mass products/full W -> normal law -> bounded tangent solve -> final original mass jump -> actual post reconstruction -> original physical/law/work/energy acceptance -> cancellation -> result. No retries or silent fallbacks.

## State, Ownership, and Lifecycle
Inputs/results are immutable Sendable values/final owners. Caller NumericalWork, LoadWork and ContactWork retain exclusive inout ownership with identical target contracts. Small arrays and result scratch are call-local; original snapshots/systems retain immutable source backing. No unsafe pointer, shared cache, Mutex replacement or target-specific conformance exists. Supplier phases retain original source and aggregate live storage; actual stack/lifetime/performance remains unmeasured.

The consumer reserves 24*B*N+4*N*N+1024*B+64*N+256 scalar slots before original tree evaluation; bounded published joint families have at most seven q coordinates/six velocity axes per body, and prescribed inventory is bounded by 2*B. Tree evaluation is charged conservatively at 8192*B+1024*B*N operations per snapshot because its public contract publishes no ledger. This is a source-derived allowance, not measured allocation/CPU cost or a zero-copy claim. Two live snapshots and physical systems, geometric/point rows, solver outputs and jump acceptance scratch are included. Nested mass/linear ledger peaks are additionally reserved and absorbed, deliberately conservative even where immutable backing shares storage.

## Failure, Concurrency, and Constraints
Typed failures distinguish shape/source/frame/pose/geometry/law mismatch, unsupported domain, nonapproaching speed, coupled normal modes, singular tangent mass, ambiguous boundary, nonconvergence, original momentum/velocity/cone/work/energy failure, budget and cancellation. Callable incomplete domains carry immediate markers. Physical supplier calls use seeded monotone subledgers, shape/source/original residual validation and terminal unavailable failed work. Linear supplier failure is terminal because no partial ledger is published. Contact/Load ledgers preserve their own units and known prefixes. Checked products/sums precede allocation; caller iterations and limits bound every root search.

## Verification and Change Impact
Selected behavioral proof owner: [FrictionalImpulseQualification](../../../../../Verification/FrictionalImpulseQualification/DESIGN.md). Its selected original Native2363 Native7/public6 supplier/fixture execution passed; the selected historical1774 Native composition and final public entry also passed; portable execution and whole-task integration remain root-owned and pending.
The initial source-only handoff carried no behavioral qualification. The selected Native proof linked above covers spatial translating/spherical effective tangent mass, sticking, sliding anisotropic SPD tangent response, e=0/1/threshold and energy, mu=0/zero tangent/interior, explicit boundary ambiguity, prescribed zero-row wall work, actual post kinematics, full original momentum and physical point/angular impulses, basis/pose/source/refusal, coupling/singular/limits/nonconvergence and all supplier work/cancellation. Selected original Native compile/link/runtime passed. Swift 6.4.0 ordinary/Embedded WASM compile/link/runtime and stack/scaling remain pending. Qualified original IM03/06/10/15/20/24 evidence belongs [FoundationVerification](../../../../../Verification/FoundationVerification/DESIGN.md); new consumer source does not inherit it. Root owns registration, Runtime/event integration and full multi-contact closure.

### Native registration boundary
The selected historical1774-source candidate retains its previously qualified1760 source subset, including the original registered MachineDefinitionContext. It omits22 tracked side-model sources (InvariantHyperelasticity8 and NonlinearKinematics14); current HEAD5aa868a contains1796 production sources, so this receipt does not prove a full-current-graph build. Its exact used frictional suppliers and selected behavior remain qualified; root owns full-graph composition. Seven focused tests and the six original public cases passed. A comment-only preparation-marker removal was qualified by a final macOS13-target compile and current-host public execution; the original seven test objects and all1774 producer objects/module bytes were retained unchanged. [Qualification evidence](../../../../../Verification/FrictionalImpulseQualification/DESIGN.md) owns exact receipts, minimum-platform limits and artifact-signature observations. This coherent Native source/registration sprint does not close the separate ordinary/Embedded execution obligation or general coupled/simultaneous-impact requirements.
