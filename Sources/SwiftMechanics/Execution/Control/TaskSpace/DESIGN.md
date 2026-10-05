# TaskSpace

## Purpose and Scope
Parent: [Control](../DESIGN.md). No children. AF34.5 owns selected CO-005 task acceleration and world body-origin wrench control. Selected Native behavior is qualified and registered; original ordinary/Embedded execution remains pending. Full constrained force control remains open.

## Responsibilities and Boundaries
Produce tentative generalized effort and independently replayed acceleration/power diagnostics against one retained original physical system. Joints owns frames and q/v layouts; Dynamics owns physical mass, bias, loads and original Newton/Euler residuals; Runtime owns publication. No actuator port, torque limit, controller clock or contact reaction authority is inferred.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Control](../DESIGN.md) | parent | Tentative command ownership | Additive controller | No Runtime publication |
| [Jacobians](../../../Modeling/Joints/Jacobians/DESIGN.md) | depends on | Point Jacobian/bias and geometric wrench transpose | Original world columns in v order | Torque is about stated body origin |
| [Trees](../../../Modeling/Joints/ArticulatedTrees/DESIGN.md) | depends on | Immutable snapshot/layout | Actual body/source identity | Fixed Euclidean tree only |
| [Dynamics](../../../Physics/Dynamics/DenseDynamics/DESIGN.md) | depends on | Inverse-mass, inverse and forward solves | Original physical residual | Supplier failures retain known work |
| [Equations](../../../Physics/Dynamics/RigidEquations/DESIGN.md) | depends on | Original source and known loads | Immutable physical association | No unknown constraint/contact allocation |
| [LinearAlgebra](../../../Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | Float64 reference Cholesky | Normalized task solve | Original task residual remains acceptance |
| [Constraints](../../../Physics/Constraints/AssemblyProjection/DESIGN.md) | coordinates with | Rank/ambiguity interpretation | Constrained projection is outside selected domain | No constraints are approximated by free dynamics |

## Architecture
```text
original physical system + declared point task
    -> domain/frame/layout admission -> J, point acceleration bias
    -> inverseMassProduct(M, J^T) -> weighted normalized task Gram
    -> rank policy + Cholesky -> generalized acceleration
    -> original inverse dynamics -> original forward replay
    -> original J*acceleration + bias acceptance -> immutable command

world body-origin wrench -> original geometric J^T
    -> original forward dynamics -> virtual/actual/prescribed power evidence
```

## Contracts and Invariants
The selected domain is a V>0 fixed-root connected Euclidean tree with fixed anchors, positive-definite physical M and equal q/v layout. Spherical/sixDOF and floating roots are refused. Spatial and original planar inertia sources remain dimension tagged; planar wrench force-z/torque-x/y and point z tasks are refused. Snapshot revision/time/world frame and immutable source are retained; commands declare the exact expected tree revision, time and world frame. All generalized vectors follow the original tree's velocity order: angular coordinates use rad, translational coordinates m, corresponding effort Nm or N. Point coordinates are body-local meters; task velocity m/s, acceleration m/s^2, torque Nm, force N and power W.

Point motion uses distinct Cartesian axes at one physical point and positive same-level weights within the primary task. Optional caller-owned secondary posture/feedforward acceleration is already expressed in the original v tangent; the controller has no independent q-state or posture estimator. Let Jw have rows sqrt(weight)*J, A=M^-1*Jw^T, G=Jw*A, c=sqrt(weight)*(desired-bias)*timeScale^2/lengthScale, and Gbar=G*energyScale*timeScale^2/lengthScale^2. Solve (Gbar+lambda^2 I)y=c; primary acceleration=A*y*energyScale/lengthScale. For secondary s, solve the same matrix with right side Jw*s*timeScale^2/lengthScale, then subtract A*ySecondary*energyScale/lengthScale from s. Add this projected secondary only after primary solve. The task dual point force is sqrt(weight)*y*energyScale/lengthScale, excluding secondary and bias/load compensation. Strict policy requires independent normalized rows and lambda=0; only this full-rank path claims a dynamically consistent inverse/nullspace. Damped policy explicitly permits deficient rank with lambda>0 and reports lambda, primary-only error, measured secondary task leakage and regularization defect lambda^2*y*lengthScale/(timeScale^2*sqrt(weight)). It never labels a regularized solution an exact inverse. Rank uses two-pass Gram-Schmidt on normalized J columns; caller relative threshold defines numerical independence. No rows are silently dropped. Original unweighted physical acceleration error, primary-only error and secondary task leakage each satisfy explicit caller gates even with damping.

Motion effort is original inverse dynamics, including compensation of already present known loads. Its replay uses the same original system and returned drive effort. Wrench effort is the geometric transpose without bias compensation: it requests an additional physical wrench, and forward dynamics determines the resulting acceleration. These semantics cannot be interchanged. A hybrid force/motion command is explicitly refused; constrained/contact force requests are refused before supplier invocation. Arbitrary physical wrench allocation from generalized effort is unavailable. Wrench commands declare the exact current world body origin as reference point. Reported generalized power equals wrench virtual power; actual wrench power adds prescribed drift. Motion reports task-dual virtual power separately from total drive power. Every accepted result retains the actual physical forward result and its original Newton/Euler residual.

## Runtime Flows
Forward replay also gates every generalized acceleration against the commanded primary-plus-secondary value in dimensionless q/time-scaled coordinates, using the caller's separate replay tolerance. Primary regularization defect and secondary regularization defect are independently compared with the measured original task error/leakage before publication.

Check cancellation/capacities -> reserve checked aggregate storage -> validate domain/source -> query original Jacobian -> derive normalized task -> guarded physical/linear calls -> independently measure physical task/dual-power equations -> cancellation check -> tentative result. No retry, fallback or accepted-state mutation.

## State, Ownership, and Lifecycle
All public input/output records are immutable Sendable values or final owners. Original system ownership is retained by reference. NumericalWork is call-local caller-owned exclusive state, identical on Native/WASM/Embedded; no shared mutable cache, pointer or target-dependent conformance exists. Simultaneously retained system/controller scratch is reserved outside nested supplier budgets. Arrays retain immutable COW backing; this design makes no measured zero-copy/stack claim.

## Failure, Concurrency, and Constraints
Typed errors distinguish unsupported domain, conflicting hybrid request, stale association, frame/reference/shape errors, nonfinite arithmetic, singular task, original task or power rejection, invalid supplier result/ledger, cancellation and numerical/Dynamics failures. Supplier calls use seeded subledgers, monotone budget reconciliation and terminal failed-work-unavailable status. Linear failure has no partial ledger and is terminal. Operation/storage/iteration budgets and maximum velocity/body count belong to the caller; checked products/sums precede allocation. Cancellation checks bracket suppliers and rows. No command is published on failure.

## Verification and Change Impact
The selected independent Native behavioral evidence covers analytic prismatic/pendulum/two-link point control with nonzero point bias and known gravity; exact forward/inverse agreement; point geometric power; same-level weights; strict deficient rank refusal; explicit damped tracking error and refusal above tolerance; body-origin wrench dual power and additional-load semantics; stale/frame/reference/q-v/contact/hybrid refusal; supplier reset/shape/wrong-success, budgets and cancellation. Fixed Swift6.4.0 Native execution and actual declarations are qualified within the evidence below; ordinary/Embedded execution remains pending. Relevant qualified original supplier evidence is [FoundationVerification](../../../../../Verification/FoundationVerification/DESIGN.md), specifically PG03, IM15 and AF24 lower; its unchanged lower contracts are composed with this consumer by the selected evidence below. Parent composition and future actuator mapping require their own evidence. No constrained/contact force allocation, hybrid force/motion, floating/manifold or accepted Runtime evolution is inferred; the corresponding incomplete-production markers and typed refusals remain.

Selected Native registration evidence: original immutable2363 source passed9 tests and8 public cases without physical/oracle changes. The complete committed Hex1813 graph plus unchanged TaskSpace17 was then compiled as1830 sources, with every added primary actually emitted, full object/module/source hashes and actual test/public link bindings retained. Same9 tests and8 public cases passed on the current host; production/public compile target is macOS13. Receipt `.build/af35-task-space-qualification/registration/canonical-native-receipt.json` SHA `b2f1a9809beaaf0eacf608beb0f96c094af6b65e4b6c74669e9b15d5175f01fe` records build8.136s, tests1.023s and public0.432s. [Qualification](../../../../../Verification/TaskSpaceQualification/DESIGN.md) owns exact numerical, source, target and refusal evidence. Native success does not qualify original portable profiles, older-host execution or full CO-005.
