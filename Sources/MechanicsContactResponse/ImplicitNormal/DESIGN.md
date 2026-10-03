# ImplicitNormal

## Purpose and Scope
Parent [MechanicsContactResponse](../DESIGN.md); no children. Own coupled frozen-geometry implicit-endpoint frictionless linear compliant response and original normal/momentum/wrench/power evidence (initial CT-002/011/012 handoff).

## Responsibilities and Boundaries
Consume [WitnessPorts](../WitnessPorts/DESIGN.md). Return numerical/mechanical trial response; consumer owns state/time evolution and acceptance. No exact impact, hard unilateral reaction, associated friction, maximum-dissipation Coulomb, bristle friction or contact topology update qualification. Full IM21 accountability persists beyond this closed handoff.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Parent](../DESIGN.md) | parent | IM21 scope | Closed initial handoff | Full CT family remains IM21 |
| [Collision](../../MechanicsCollision/Geometry/DESIGN.md) | depends on | Witness points/normal/poses/features | Geometric authority | Stale identities/poses fail |
| [Dynamics](../../MechanicsDynamics/RigidEquations/DESIGN.md) | depends on | Immutable M, actual snapshot/bias/original inertia | Mechanical authority | Only published rigid spatial domain |
| [ContactLaws](../../MechanicsContactLaws/Response/DESIGN.md) | depends on | ContactInput/linear normal response/trial history | Constitutive authority | Frictionless undamped noncohesive only |
| [Complementarity](../../MechanicsComplementarity/Solve/DESIGN.md) | depends on | Orthant SPD solve/original residual | Numerical supplier | Associated cone is not Coulomb |
| [Tests](../../../Tests/MechanicsContactResponseTests/DESIGN.md) | used by | Public requirements | Analytic coupling and failures | Native evidence local |

## Architecture
```text
validated ports + rigid system + drive force + positive interval h
 -> actual forward mechanics -> free endpoint v*
 -> each actual inverse-mass Jt -> W=J M^-1 Jt
 -> positive compliance orthant solve -> endpoint force / velocity / linearized gap
 -> actual law reevaluation + original body inertia / wrench / power residuals
 -> immutable trial history and force observations
```

## Contracts and Invariants
Snapshot time is interval start; h>0. Geometry, Jacobian, prescribed drift, mass, bias and known forces remain frozen during the selected local response. This is a declared one-step linearized response, not full pose integration. Free v*=v+h*a from Dynamics.forward includes original bias and known forces. With B-minus-A normal row J, W=J M^-1 Jt, vnext=v*+h*M^-1*Jt*lambda; trialGap=g+h*(J*vnext+drift). Solve lambda>=0, trialGap+lambda/k>=0, their product=0. Nondimensional x=lambda/forceScale, dual=(trialGap+lambda/k)/lengthScale; matrix=(forceScale/lengthScale)*(h²W+diag1/k), rhs=(g+h*freeNormalVelocity)/lengthScale. Positive compliance makes this force problem SPD/unique even if W has dependent rows; effective-mass rank is unavailable and generic constraint reaction uniqueness is not claimed. Float64/referenceCPU explicitly selected; no fallback. Tangent force/couple zero follows the admitted disabled laws, never a replacement for selected friction.

Original evidence recomputes point velocity and law force independently of the assembled effective matrix. Constitutive evaluator receives linearized trial separation and endpoint actual relative velocity and returns an immutable trial history. Normal law mismatch and original orthant primal/dual/product/optimality are separately checked. Generalized momentum is checked by original body inertia evaluated at (vnext-v)/h including bias, against drive+known+independently mapped point forces; its scaled residual is h/timeScale times the Dynamics coordinate-scale/energy-scale force residual. Forces are equal and opposite at witness points; world-origin torques, normal-only cone membership, Jt mapping and actual/virtual/prescribed power are independently verified. Reports are endpoint forces plus h*force finite-interval equivalent impulses, not instantaneous impact impulses or average force inferred from impact. Active state is loaded/separated under caller force tolerance; friction regime is disabled. Caller original dimensionless residual tolerance is distinct from numerical supplier cone tolerance.

## Runtime Flows
Admission -> free dynamics -> C inverse-mass products -> orthant numerical solve -> trial velocity/gaps -> contact-law reevaluation -> original inertia and observation residuals -> final cancellation check -> publication. No warm cache or retry. Failed supplier halts immediately.

## State, Ownership, and Lifecycle
Immutable Sendable inputs/results/histories, local exclusive arrays. Retain prepared rows C*N, inverse images C*N and effective/scaled matrices 2*C² plus local velocity/force/residual vectors and immutable observations; conservative scalar-equivalent reserve stated in implementation. Supplier-returned output arrays are counted at their ownership boundary. No per-iteration output materialization in response; suppliers own their workspaces. No shared mutable state or target-dependent contracts. The response owns one exclusive local workspace across non-inlined admission, free-motion, inverse-image, matrix, cone, endpoint, per-contact law/wrench/mapping and original-momentum phases. These call boundaries limit fixed compiler stack frames without changing numerical algorithms, supplier selection or ledger order. The exact Swift 6.4 debug WASM profiles are tested with their existing SDK stack allocation; private relocated-stack artifacts are diagnostic evidence only.

## Failure, Concurrency, and Constraints
Caller outer NumericalWork bounds response arithmetic/storage/metadata; separate caller Dynamics NumericalWork bounds cumulative forward/inverse products/original queries; separate cone NumericalWork remainingBudget/absorb accounts the one numerical supplier; ContactWork retains actual constitutive work. These distinct units are not relabeled or reset; total simultaneously admitted capacity is the sum of disjoint ledger reservations, with borrowed producer inputs excluded where stated. Failed complementarity supplier partial work is unavailable; explicit error flag preserves that fact, known outer ledgers and underlying failure, and execution stops. Original rejection identifies law/cone/momentum/wrench/power phase. Caller limits/tolerances/scales/profile are explicit. Finite/overflow/cancel checks precede success; no accepted state changes.

## Verification and Change Impact
Single and coupled analytic normal compliance/effective mass, dependent contact rows with unique compliant force, separating state, framed lever-arm wrench/power, prescribed drift and known force, independent original residual rejection despite loose numerical acceptance, stale/unsupported/metadata/capacity/storage/work/iterations/cancel/supplier failures. No broad contact trajectory/grasp/tooth refinement claim. Changes invalidate contact evolution/observations/derivative consumers and root profiles.
