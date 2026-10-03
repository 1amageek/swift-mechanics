# MechanicalSensitivities

## Purpose and Scope
Parent: [module](../DESIGN.md). Children: none. Own exact smooth rigid-tree mass, kinematic/gyroscopic bias, force and implicit forward acceleration products. Initial implementation domain; profile qualification pending. Full OP-001/002 ownership persists.

## Responsibilities and Boundaries
Consume TreeTangents and actual RigidEquationComputing/RigidDynamicsSolving primal services. Differentiate body mass, body COM, symmetric COM inertia, uniform gravity, framed wrench data and generalized force data at fixed provenance/layout. Differentiated custom generalized force callbacks provide required original value and directional operations with actual immutable state, snapshot and computed TreeTangent; parameter identity/dimensions are retained in the result. Callback derivative correctness is a supplier assumption to be established by that law's independent oracle, not certified from finite output alone. No finite difference backend, contact mode, mass singularity/rank transition, passive nonsmooth branch or runtime accepted-state evolution.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [TreeTangents](../TreeTangents/DESIGN.md) | depends on | Actual frame/J/bias directions | Spatial transport | q chart and v layout differ |
| [Dynamics](../../MechanicsDynamics/DESIGN.md) | depends on | RigidEquationComputing/RigidDynamicsSolving | Actual primal and mass solve | Failed work may be unavailable |
| [Loads](../../MechanicsLoads/DESIGN.md) | depends on | Uniform gravity input, LoadWork | Actual primal gravity ledger | No inferred finite-angle load derivatives |
| [ScalarCalculus](../ScalarCalculus/DESIGN.md) | depends on | Checked arithmetic | Product rules | Callback budgets retained |
| [Tests](../../../Tests/MechanicsDerivativesTests/DESIGN.md) | used by | Independent physics | M/C/COM/gyro/implicit products | Qualification pending |

## Architecture
```text
tree/state -> primal snapshot + exact tangent -> actual dynamics assembly/forward
       body/load directions -> exact COM Newton-Euler products
       M da = dDrive + dForce - dBias - dM a -> actual mass solver
       -> original differentiated body-equation residual -> immutable result
```

## Contracts and Invariants
Iw=R Ic R^T; r=R c; Jc=Jlinear+Jangular cross r. M=sum(m Jc^T Jc+Jomega^T Iw Jomega). Bias uses actual world omega, COM acceleration bias and omega cross Iw omega; every geometric stress/transport term differentiates. Physical mass/inertia parameter directions describe an admitted smooth physical neighborhood at fixed body/frame/revision; caller supplies neighborhood extent, validated by the actual Model constructor at both endpoints (domain check only, not derivative approximation). Input wrench reference points and frames retain their meaning: world load transforms are fixed-world; body load transforms differentiate orientation/point transport. Gravity time direction includes declared uniformTimeDerivative*dTime. Generalized force derivative is an explicit supplied physical contribution, not a geometric KKT reaction. Implicit acceptance recomputes differentiated Newton-Euler generalized force independently of assembled dM and uses caller dimensionless residual tolerance after each physical conjugate effort is mapped by S_i/E. Primal scalar agreement uses a separate caller tolerance in that component's units; the two tolerances are distinct. Coordinate/energy/time solve scales change conditioning only, not the physical derivative.

## Runtime Flows
Validate captured shapes/revision/provenance and capacities; execute tree tangent; evaluate callback original and directional outputs with poisoned reusable buffers; actual primal assembly then forward; exact body products; build implicit RHS; actual inverseMassProduct; independent physical derivative residual; final cancellation and publication. Nested solvers use remaining budget plus reserved live storage; actual successful work absorbed once. Any failed supplier terminates once with typed cause and unavailable consumption flag.

## State, Ownership, and Lifecycle
Immutable parameter/load/callback records, exclusive local workspace, no callback mutation of accepted state. Callback metadata binds the ordered parameter IDs and dimensions, coordinate count and revision; all captured array counts are checked before bounded equality. Invocation-attempt ledger includes metadata getter attempts. Callback numerical budget and cumulative operation/iteration/storage ledger are captured before each value/direction call. Replacement/reset is rejected, restores the known prefix and reports explicit unavailable failed supplier work; neither following derivative call nor primal assembly runs after this failure. Callback metadata captured before invocation and rechecked afterward; output buffers must retain captured count and overwrite poison. Full acceleration Jacobian publication covers the complete configuration-chart, velocity, or drive block selected by the caller; it uses repeated exact basis products with caller maximum columns and explicitly budgeted output/copy storage; FD is test oracle only.

## Failure, Concurrency, and Constraints
Unsupported missing derivatives, nonsmooth/physical-neighborhood violation, wrong metadata, stale frame/layout, nonfinite, resource/cancel and original residual failure are typed. Required synchronous Sendable callback operations and identical isolation across all targets. No shared state. Logical initialized scalar storage is conservatively bounded by 500*B+60*B*N+8*N*N+36*N+20*P+2048 (P is the captured parameter count) plus retained initialized workspace slots and, for a full Jacobian, the published N*N result, 6*N basis values, 13*B inertial directions, 9*W framed directions, P parameter zeros and 18*A prescribed-motion direction values. Retained workspace is preflighted before new allocation and is reinitialized through its exclusive owner; unused allocator capacity is outside this logical scalar unit. Borrowed immutable parameter/input scalar arrays are not copied by the derivative kernel; allocator rounding/unused Array capacity is not a scalar-storage unit. Fixed anchor/root reference pose and axis orientation sensitivities are not yet published; body inertia, screw pitch, gravity, framed/generalized force and callback parameter products are published. Kinetic and gravity potential derivatives do not claim availability of arbitrary custom potential/dissipation derivatives.

## Verification and Change Impact
Two-link dM/dC coupling, asymmetric free-body Euler product, COM parameter sensitivity, frame/wrench/gravity derivative, scaled implicit equation and failed callback/each resource boundary. Recheck dynamics and derivative consumers when producer assumptions change.
