# Tetrahedra

## Purpose and Scope
Own objective Tet4 total-Lagrangian constant-F polynomial hyperelastic assembly with internal force, energy, tangent, reference mass and mass-proportional damping (initial FX-004/007 producer). Parent [MechanicsFlexible](../DESIGN.md); no children. Other IM19 families remain unqualified.

## Responsibilities and Boundaries
Consume [Mesh](../Mesh/DESIGN.md) validated reference geometry. Own current nodal state, physical equation and assembly work. No time evolution, attachment, contact, modes, reduction, plastic history or successful beam/shell/cable/hexahedron API.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Parent](../DESIGN.md) | parent | IM19 ownership | Initial producer | Full family audit later |
| [Mesh](../Mesh/DESIGN.md) | depends on | Reference cells, gradients, identified assignment | Interpolation authority | No geometry revalidation/inference |
| [Materials](../../MechanicsMaterials/Elasticity/DESIGN.md) | depends on | HyperelasticResponding evaluate/tangent | First Piola stress and direction | Fixed immutable polynomial only |
| [Numerics](../../MechanicsNumerics/LinearAlgebra/DESIGN.md) | depends on | NumericalWork | Outer arithmetic/storage | Material internal arithmetic unavailable |
| [Tests](../../../Tests/MechanicsFlexibleTests/DESIGN.md) | used by | Public assemble requirement | Physical proof | Native evidence local |

## Architecture
```text
validated reference gradients + current positions/velocities
 -> F=currentEdges*inverseReferenceEdges
 -> assigned material P, psi, dP -> assembled energy gradient / tangent
 -> reference mass and damping -> immutable nodal equation evidence
```

## Contracts and Invariants
Current state frame/revision/node order/count match mesh; positions in meters and velocities in m/s. Float64 baseline only. Affine F is constant, so one volume-weighted constitutive point exactly integrates this homogeneous linear-interpolation element. E=V*psi(F), internal force=V*P*gradN (positive energy gradient in N); evolution subtracts it as restoring force. Tangent N/m differentiates that gradient using actual firstPiolaDirection, including geometric prestress. Translation is a tangent null mode in all admitted states; rotational null modes apply at stress-free rest, while prestressed objectivity means force covariance, not zero tangent action. Tangent may be indefinite at finite compression; no unconditional SPD claim. Consistent mass blocks are rho*V/20*(2 diagonal,1 off diagonal)*I, row-sum lumping rho*V/4*I; conserve reference mass and are positive definite for a validated participating mesh. C=alpha*M is assembled per material, alpha in 1/s; dampingForce=C*v is positive resisting force and dissipatedPower=v^T*C*v. No accepted history mutation. Nodal output carries identified frame/order and mesh revision.

## Runtime Flows
Check layout/cancel -> checked dense reserve -> each cell F -> constitutive response -> energy/force -> 12 constitutive directions/tangent -> reference mass/damping -> damping-force/power -> final cancellation check -> immutable result. Current inversion/constitutive envelope failure propagates; no retry/substitution.

## State, Ownership, and Lifecycle
Immutable Sendable mesh/state/laws/output. Five local output arrays, with no per-direction arrays; Core matrices/vectors are fixed-size values. Conservative peak scalar storage is retained validated.scalarStorage + 3*(3N)^2 + 2*(3N), excluding borrowed nodal input. Caller owns aggregate previously retained outputs. ConstitutiveCallWork is exclusive caller inout: exactly 13 public calls per successful cell, charged before each invocation including failures. Materials tangent may internally invoke evaluate; those internal calls and arithmetic are not exposed by the frozen provider and are not counted as additional public calls or fabricated NumericalWork arithmetic. Fixed-law execution is finite; no custom provider admitted. NumericalWork separately charges known outer scalar arithmetic and input comparison units; no guessed constitutive cost. Frame equality consumes the Mesh metadata-admission contract before its semantic comparison. No shared cache, unsafe pointer, platform branch or weakened Sendable.

## Failure, Concurrency, and Constraints
Typed layout/nonfinite/Core/material/numerical/call-budget/cancel failures. Checked products/sums before arrays. Cancellation is checked before operation, cell and direction boundaries and immediately before publication. Caller callback is not invoked during the bounded dense damping block; Task cancellation is checked for every charged block. Failed work retains all charged outer operations/public calls, but no partial result escapes.

## Verification and Change Impact
Independent uniaxial P/energy/nodal force, finite rotation force covariance and rest null modes, prestressed energy/force directional checks, exact mass/positive damping power, affine centroid refinement energy/resultant/total mass, current inversion/domain/layout and call/storage/arithmetic/cancel boundaries. Changes invalidate downstream rigid coupling/contact/structural analysis and root platform probes. Affine refinement equality does not qualify non-affine mesh convergence.
