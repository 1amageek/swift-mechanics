# ConstrainedDynamics

## Purpose and Scope
Mass-weighted constrained accelerations and instantaneous velocity reconciliation. Parent: [MechanicsMechanisms](../DESIGN.md). No children. Full IM16 requirements remain owned beyond this initial admitted subset.

## Responsibilities and Boundaries
Actual assembled rigid mass, inertial bias and known loads; normalized original constraint rows; numerical independent-row evidence; physical generalized reaction and every original-row acceptance. No global equation rank or unique redundant reactions.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Parent](../DESIGN.md) | parent | IM16 ownership | Module composition | Root registers and qualifies actual paths |
| [Numerics](../../../Mathematics/Numerics/DESIGN.md) | depends on | Required linear solve and work | Independent Gram solve | Failed linear work may be unavailable |
| [Transmissions](../../Transmissions/DESIGN.md) | depends on | Required idealEfforts | Physical identified shaft reactions | Axial fidelity only |
| [Joints](../../../Modeling/Joints/DESIGN.md) | depends on | Actual source snapshot/layout | Reaction provenance | No graph internals |
| [Dynamics](../../Dynamics/DESIGN.md) | depends on | Rigid equations and solve | Real compiled physical mass | No diagonal proxy |
| [Constraints](../../Constraints/DESIGN.md) | depends on | Required rank and evaluation | Original identified rows | Rank does not imply force or feasibility |
| [Runtime](../../../Execution/Runtime/DESIGN.md) | coordinates with | Accepted physical transactions | Immutable accepted prefix | Model replacement has separate admission authority |
| [Integration](../../../Execution/Integration/DESIGN.md) | coordinates with | Equation and continuation witnesses | Actual stage/time acceptance | Exact chart readback |

## Architecture
```text
system + original rows -> free motion -> actual inverse mass columns -> independent Gram solve -> all rows + Newton-Euler acceptance
```
Actual dependencies used: RigidDynamicsSolving.forward/inverseMassProduct and RigidEquationComputing.originalInertialForce; required ConstraintRankAnalyzing.rank and LinearSolving.solve.

## Contracts and Invariants
Physical q scales S, time T and energy E are caller policy. Acceleration uses y=a*T²/S and reaction effort E*Abarᵀlambda/S. Instantaneous reconciliation uses u=v*T/S and impulse E*T*Abarᵀlambda/S. Redundant rows retain IDs; zero dependent multipliers select an explicitly reported representative, never uniqueness. Inputs remain immutable.
All values and public witnesses are Sendable on every target. Frames, model/layout revision, temporal force versus impulse interpretation and physical units stay explicit. Output is published only after original physical acceptance.

## State, Ownership, and Lifecycle
Source records are immutable; workspace and authoritative NumericalWork are caller-exclusive values. Required suppliers execute outside locks. No global cache or mutable shared producer state is introduced. Rich operation contexts may be immutable final Sendable owners to bound debug stack overlap. Structural scalar-slot budgets do not claim allocator or physical-copy measurements.

## Failure, Concurrency, and Constraints
Typed failures distinguish stale binding, shape/domain/physical residual, cancellation, overflow, capacity and supplier error. Caller maxima are checked before allocation; checked integer products bound workspaces. Supplier work is separate from orchestration work; unknown partial supplier failure stops without retry. Ledger replacement/reset is rejected. Unavailable callable paths carry FIXME(INCOMPLETE_IMPLEMENTATION) and typed failure.

## Verification and Change Impact
[Test owner](../../../../../Tests/MechanicsMechanismsTests/DESIGN.md). Planned actual evidence: Independent nonunit-scale two-inertia gear acceleration, redundant/inconsistent retained rows, Newton-Euler residual, lock momentum and energy, cancellation/capacity/failed work. Root owns Native and exact original WASM/Embedded qualification after source freeze; declarations alone grant no qualification. Changed mass/row/scaling/chart or lifecycle supplier contracts require affected composition requalification.

The Transmissions adapter consumes the actual compiled network and maps the computed joule multipliers through its required idealEfforts witness. Original phase/speed/power and generalized reaction consistency are checked; the returned port wrenches carry actual frame/origin/axis semantics. This ideal axial model does not infer geometric tooth force or bearing radial load.

`ConstrainedMotion` is an immutable final Sendable owner retaining the actual source snapshot and velocity basis through COW backing. This binds threshold/event consumers to the actual source pose/velocity instead of a same-time scalar reaction. It owns no mutable cache. Retention is accounted as source backing, not a fresh physical buffer copy; debug stack and allocator measurements remain unqualified.

### Selected AF17 execution evidence

Native original dynamics/redundancy/impulse and identified transmission cases passed. Public Native/WASM/Embedded executes required mass-weighted gear acceleration with original force/row checks; general reaction fidelity remains unavailable. Exact profile identity and root logs are indexed by the [parent design](../DESIGN.md); the corresponding test owner retains the independent physical oracles. Private stack diagnostics are not qualification.
