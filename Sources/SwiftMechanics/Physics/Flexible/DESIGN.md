# Flexible component

## Purpose and Scope
Parent: [responsibility owner](../DESIGN.md). Own IM19 nodal/discretization layout, actual element mass/internal force/tangent, mesh validation and reduced interfaces. Full requirement ownership FX-001..004, FX-007, FX-011..012 remains IM19 after accurately declared initial handoff. [SPEC](../../../../SPEC.md) owns acceptance and [plan](../../../../IMPLEMENTATION_PLAN.md) owns prerequisite edges. Children: [FieldOutputs](FieldOutputs/DESIGN.md), [Refinement](Refinement/DESIGN.md), [Mesh](Mesh/DESIGN.md), [Tetrahedra](Tetrahedra/DESIGN.md), [Beams](Beams/DESIGN.md). Beams records its AF14 selected behavioral/profile qualification; existing Tet4 qualification is unchanged.

## Responsibilities and Boundaries
Consume physical units/geometry, identified model values, numerical equations and verified constitutive laws. Own element interpolation/quadrature/formulation, rest/current geometry, nodal DOF and material/boundary/source association. Materials owns stress/strain law meaning; rigid attachment/evolution, contact, modes/analysis and CAD mesh derivation are separate consumers. A matrix declaration or isolated mesh is not a flexible simulation.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [ModalReduction](ModalReduction/DESIGN.md) | child | Mass-orthogonal reduced state and explicit-work physical Tet4 stress output | Selected Native7/public6 at frozen2124 | Legacy unchargeable stress signature refuses; portable and broader modal domains remain open |
| [Mesh](Mesh/DESIGN.md) | child | Identified reference cell validation and assignments | Independent implementation owner | Child contract is authoritative; admitted proof is recorded below |
| [Tetrahedra](Tetrahedra/DESIGN.md) | child | Actual total-Lagrangian tetrahedral assembly and nodal outputs | Independent implementation owner | Child contract is authoritative; admitted proof is recorded below |
| [Beams](Beams/DESIGN.md) | child | Identified Hermite element mass/elastic/geometric stiffness | AF14 additional exclusive material_kernels ownership | No qualified analysis until element behavior passes |
| [Responsibility owner](../DESIGN.md) | parent | Ownership and global invariants | Composition authority | Full closure remains IM48 |
| [Model](../../Modeling/Model/DESIGN.md) | depends on | Identity, provenance and geometry/mass distinction | Identified physical source | Display mesh never becomes physical without explicit admission |
| [Numerics](../../Mathematics/Numerics/DESIGN.md) | depends on | Matrix layout, work budgets and original-residual acceptance | Numerical values/solve | Generic operators are not element implementations |
| [Materials](../Materials/DESIGN.md) | depends on | Actual stress/strain/tangent/history domain | Constitutive authority | Additive Green-J2 is not multiplicative plasticity |
| [Core](../../Mathematics/Core/DESIGN.md) | depends on | SI/framed vectors and tensors | Geometry algebra | Finite rotation/frame semantics remain explicit |

| [FieldOutputs](FieldOutputs/DESIGN.md) | child | Physical Tet4 field evaluation and assembler diagnostics | Native1960 qualified; fixture owner records selected domains | Portable and finite-strain objectivity remain open |
| [Refinement](Refinement/DESIGN.md) | child | Certified conforming Tet4 subdivision and physical transfer | Native1944 qualified; fixed portable and broader refinement domains remain open |

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

The selected public-service probe in [FoundationVerification](../../../../Verification/FoundationVerification/DESIGN.md) separately compiled, linked and ran with exit 0 on installed Swift 6.4.0 release Native arm64 macOS 27, swift-6.4.0-RELEASE_wasm and swift-6.4.0-RELEASE_wasm-embedded with --traits EmbeddedUnicode. Node.js 24.19.0 WASI Preview 1 executed both WASM artifacts. The probe checks analytic affine energy/forces/mass/damping, rotation covariance, affine refinement conservation and exact frame/inversion failures. Native cancellation proof is not generalized to WASI parallel execution or minimum macOS 13. Beam, shell, cable, other solid formulations, plastic element history, reduction, non-affine refinement convergence, modes and coupled evolution remain unqualified IM19/integration obligations.

### Consolidation contract
This directory is a component inside the SwiftMechanics module, not a separate SwiftPM target. Its existing public behavior and exact-profile evidence remain its contract authority. Cross-component access uses the documented contracts; internal visibility alone does not grant admission or publication authority. Source relocation requires integrated behavioral requalification.

| [Attachments](Attachments/DESIGN.md) | child | Source-issued rigid/material point interface | Selected repaired exact-source Native/WASM/Embedded qualification; child owns proof domains |

## Selected Hex8 solid

[Hexahedra](Hexahedra/DESIGN.md) owns the selected objective, full-integration eight-node solid and its reference/state/energy/force/tangent/mass/damping contracts. Its child design records exact Native qualification and pending portable obligations; accepted evolution, mesh convergence and locking behavior remain separately unqualified.


## Selected spatial beam service

Child [SpatialBeams](SpatialBeams/DESIGN.md) owns identified linear12DOF Euler-Bernoulli/Timoshenko assembly, response and section fields. Its qualification owner records Native7/six public cases on frozen2270. Finite rotation, resolved transverse/torsional stress and global evolution remain explicit unsupported domains; portable is unqualified.


## Selected Shells Native composition

Child [Shells](Shells/DESIGN.md) owns flat-q4 mindlin/mitc4 mechanics. Its original Native7/public6 behavioral evidence is qualified against fresh immutable2387, with original source/physical/work acceptance and typed failures preserved. The child and qualification owner retain exact evidence and remaining portable/domain obligations.
