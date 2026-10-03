# MechanicsFlexible

## Purpose and Scope
Parent: [system/package](../../DESIGN.md). Own IM19 nodal/discretization layout, actual element mass/internal force/tangent, mesh validation and reduced interfaces. Full requirement ownership FX-001..004, FX-007, FX-011..012 remains IM19 after accurately declared initial handoff. [SPEC](../../SPEC.md) owns acceptance and [plan](../../IMPLEMENTATION_PLAN.md) owns prerequisite edges. Children: [Mesh](Mesh/DESIGN.md), [Tetrahedra](Tetrahedra/DESIGN.md), [Beams](Beams/DESIGN.md). Beams is an AF14 source dispatch with pending behavioral/profile qualification; existing Tet4 qualification is unchanged.

## Responsibilities and Boundaries
Consume physical units/geometry, identified model values, numerical equations and verified constitutive laws. Own element interpolation/quadrature/formulation, rest/current geometry, nodal DOF and material/boundary/source association. Materials owns stress/strain law meaning; rigid attachment/evolution, contact, modes/analysis and CAD mesh derivation are separate consumers. A matrix declaration or isolated mesh is not a flexible simulation.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Mesh](Mesh/DESIGN.md) | child | Identified reference cell validation and assignments | Independent implementation owner | Child contract is authoritative; admitted proof is recorded below |
| [Tetrahedra](Tetrahedra/DESIGN.md) | child | Actual total-Lagrangian tetrahedral assembly and nodal outputs | Independent implementation owner | Child contract is authoritative; admitted proof is recorded below |
| [Beams](Beams/DESIGN.md) | child | Identified Hermite element mass/elastic/geometric stiffness | AF14 additional exclusive material_kernels ownership | No qualified analysis until element behavior passes |
| [Root](../../DESIGN.md) | parent | Ownership and global invariants | Composition authority | Full closure remains IM48 |
| [Model](../MechanicsModel/DESIGN.md) | depends on | Identity, provenance and geometry/mass distinction | Identified physical source | Display mesh never becomes physical without explicit admission |
| [Numerics](../MechanicsNumerics/DESIGN.md) | depends on | Matrix layout, work budgets and original-residual acceptance | Numerical values/solve | Generic operators are not element implementations |
| [Materials](../MechanicsMaterials/DESIGN.md) | depends on | Actual stress/strain/tangent/history domain | Constitutive authority | Additive Green-J2 is not multiplicative plasticity |
| [Core](../MechanicsCore/DESIGN.md) | depends on | SI/framed vectors and tensors | Geometry algebra | Finite rotation/frame semantics remain explicit |

## Architecture
```text
identified rest mesh + material/formulation + nodal current state
 -> bounded validation and interpolation/quadrature
 -> actual internal force/energy/tangent + mass/damping and nodal layout
 -> immutable element/assembly evidence or typed failure
```

## Contracts and Invariants
Actual child contracts define closed element/formulation/material admission before source. Forces must be energy-conjugate in the declared nodal coordinates and tangent must agree with independent directional behavior. Rigid motion adds no strain in admitted objective formulations; linear small-displacement formulations state their rotation limit. Consistent/lumped mass and damping declare dimensions, conservation and definiteness. Connectivity, orientation/degeneracy, source revision and assignments are validated transactionally. Unsupported families and reduction envelopes cannot become successful placeholders.

## State, Ownership, and Lifecycle
Immutable mesh/model/element values may be shared. Nodal input, history/trial output and mutable workspace have explicit exclusive owners. No accepted-time state mutation or hidden constitutive cache. Any future shared reference state uses the same storage/isolation/Sendable contract on Native/WASM/Embedded; scoped views retain their owner. No unsafe optimization precedes measured resource need.

## Failure, Concurrency, and Constraints
Invalid/inverted/degenerate cells, missing material/assignment, revision/layout mismatch, outside constitutive/formulation domain, nonfinite force/tangent, unsupported reductions, capacity/work exhaustion and cancellation fail explicitly. Caller selected admissibility/resource policies bound allocation and traversal. Constitutive/numerical failures propagate with available work evidence, without successful zeros or altered model/backend.

## Verification and Change Impact
Test owner is Tests/MechanicsFlexibleTests once actual sources exist. Independent element/patch solutions, rigid rotation/objectivity, directional tangent, translation/rigid null modes, mass conservation, axial/modal analytic evidence, refinement preserving assignments and invalid/budget cases must exercise actual code. Root separately owns exact-profile selected public API execution. Nodal/formulation/material or conservation changes invalidate dependent coupling/contact/structural/mesh adapter contracts.

### Verified initial producer handoff
The registered Native package passed all 154 behavioral tests, including this owner’s ten tests. Tests execute actual Tet4 total-Lagrangian polynomial-hyperelastic assembly, independent directional tangent, rigid objectivity/null modes, reference consistent/lumped mass and material damping, affine centroid refinement, frame/material/orientation failure, late cancellation and bounded long-identifier admission. Mesh and Tetrahedra own the precise closed domains, equations and resource ledgers; this paragraph does not duplicate those contracts.

The selected public-service probe in [FoundationVerification](../FoundationVerification/DESIGN.md) separately compiled, linked and ran with exit 0 on installed Swift 6.4.0 release Native arm64 macOS 27, swift-6.4.0-RELEASE_wasm and swift-6.4.0-RELEASE_wasm-embedded with --traits EmbeddedUnicode. Node.js 24.19.0 WASI Preview 1 executed both WASM artifacts. The probe checks analytic affine energy/forces/mass/damping, rotation covariance, affine refinement conservation and exact frame/inversion failures. Native cancellation proof is not generalized to WASI parallel execution or minimum macOS 13. Beam, shell, cable, other solid formulations, plastic element history, reduction, non-affine refinement convergence, modes and coupled evolution remain unqualified IM19/integration obligations.
