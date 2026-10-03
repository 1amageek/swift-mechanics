# Hermite beam discretization

## Purpose and Scope
Parent [Flexible](../DESIGN.md). Own a uniform straight Euler–Bernoulli bending beam family, its physical input and assembled elastic/geometric stiffness, consistent mass and Rayleigh damping. Initial admitted implementation domain; selected behavioral/profile evidence is recorded by the parent composition index. No children. Other IM19 families are unchanged.

## Responsibilities and Boundaries
Own interpolation and element mechanics. StructuralAnalysis owns boundary elimination, eigensolve, frequency response and buckling classification. No trajectory, nonlinear beam/material failure, shear/rotary inertia, torsion or hidden geometric mesh conversion.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Parent](../DESIGN.md) | parent | Flexible families | New disjoint component | Existing Tet4 unchanged |
| [Materials](../../MechanicsMaterials/Elasticity/DESIGN.md) | depends on | IsotropicElasticity bulk/shear | E=9/(3/G+1/K) | Small linear strain, homogeneous isotropic material |
| [Numerics](../../MechanicsNumerics/LinearAlgebra/DESIGN.md) | depends on | NumericalWork | Checked reserve and operations | No hidden solve |
| [StructuralAnalysis](../../MechanicsStructuralAnalysis/PhysicalModels/DESIGN.md) | used by | BeamAssembling and BeamAssembly | Analysis input authority | Retains boundary/fidelity |
| [Tests](../../../Tests/MechanicsFlexibleTests/Beams/DESIGN.md) | used by | Actual public assembly | Independent element energy/mass proof | Root profile evidence separate |

## Architecture
```text
identified uniform beam + calibrated elastic material -> Hermite cells
 -> elastic/initial-stress/consistent-mass operators -> immutable assembly
```

## Contracts and Invariants
SI L,A,I,rho and declared maximum fiber distance c are positive finite, with I<=A*c^2; frame/source/revision/identity explicit. Uniform cells have dofs [transverse displacement w in m, slope theta dimensionless] and x increasing along the beam. The identified beam frame has x along the member, y transverse and small rotation about +z; no arbitrary spatial bending basis is inferred. E is derived from actual isotropic bulk/shear; admissible small-strain/slender/small-slope envelope is caller authority, and finite harmonic response must check the published slope/fiber-strain limits, not a calibrated continuum guarantee. K0=integral EI Nsecond^T Nsecond dx, G=integral Nprime^T Nprime dx for constant compressive dead axial load P, M=integral rho A N^T N dx and C=alpha M+beta K0, alpha,beta>=0. Exact polynomial Hermite coefficients are assembled in dense row-major operators. K(P)=K0-PG has restoring-gradient sign. No boundary elimination occurs here. Rigid translation/rotation satisfy K0 null action. Element length/material divisions and every output are finite; no successful overflow.

## State, Ownership, and Lifecycle
Immutable Sendable beam/material/output, caller-exclusive NumericalWork and local four dense arrays. No shared cache, pointer or target condition. Caller retains inputs and outputs; conservative reserve includes input scalar metadata and four operators.

## Failure, Concurrency, and Constraints
Caller maximum elements/metadata bytes, NumericalBudget and immutable @Sendable cancellation closure are admitted before allocation. Checked n/square/products, finite scalar checks, bounded per-cell cancellation and final publication check. Typed error on malformed material/geometry, nonfinite result, cancellation/resource failure. All targets use identical Sendable/storage.

## Verification and Change Impact
Independent element bending energy, consistent mass total/rigid translation kinetic energy, initial-stress integral and Rayleigh relation; mesh assembly continuity, invalid dimensions/bounds/nonfinite/cancellation. StructuralAnalysis owns independent Euler frequencies and load mesh convergence from these actual operators. Changes require that consumer and root exact-profile probes to recheck.

Initial selected qualification: four Native beam cases passed before fifteen upper StructuralAnalysis cases; all fourteen Flexible cases and the full 346-case registered composition pass. Original Native/WASM/Embedded public execution calls actual required BeamAssembling, then modes/harmonic/buckling consumers. This establishes the declared uniform small-slope element domain, not nonlinear/shear/torsion or beam time evolution.
