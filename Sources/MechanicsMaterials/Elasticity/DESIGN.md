# Elasticity

## Purpose and Scope
Parent: [MechanicsMaterials](../DESIGN.md). Owns infinitesimal isotropic elasticity and an objective polynomial Green-strain hyperelastic material for FX-005 and constitutive FX-006. Children: none.

## Responsibilities and Boundaries
Linear service: infinitesimal symmetric ε, Cauchy stress σ=λ trε I+2με, W=λ(trε)²/2+μ ε:ε and dσ=C:dε. Finite service: Green E and second Piola S, W=λ(trE)²/2+μ E:E+β(E:E)²/4, S=λtrE I+2μE+β(E:E)E. It is a compressible isotropic polynomial model, extending St Venant–Kirchhoff when β=0; β>0 gives material nonlinearity. Arbitrary large stretch, incompressibility and universal stability are not claimed. The caller's calibrated finite E/J domain restricts use. Element formulation/ANCF pairing is IM19.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Module](../DESIGN.md) | parent | Qualified support | Composition | No complete FX-006 element claim |
| [Constitutive](../Constitutive/DESIGN.md) | depends on | Tensor contraction and objective F mapping | Measures and push-forward | Tensor shear convention applies |
| [Plasticity](../Plasticity/DESIGN.md) | used by | Elastic constants/operator | Recoverable energy | Same Pa and material frame |

## Architecture
```text
(K,μ) -> IsotropicElasticity -> (σ,W,C direction)
(elasticity,β,domain,F) -> PolynomialHyperelasticity -> (E,S,P,σ,W)
(F,H) -> analytic (dE,dS,dP,dσ)
```

## Contracts and Invariants
Elastic parameters bulk K>0 and shear μ>0 are finite Pa; λ=K-2μ/3 may be negative. β is finite >=0 Pa. Computed parameter arithmetic must remain finite. Linear law validates supplied domain norm; finite law validates J/E. Hyperelastic dS=λtr(dE)I+2μdE+β[(E:E)dE+2(E:dE)E]. Response and tangent services expose callable protocol requirements, including existential invocation. Elastic response recovers exactly on unloading and zero E stores zero energy. No global mutable state; operations use O(1) fixed-size local workspace.

## State, Ownership, and Lifecycle
Immutable Sendable material, parameter, response and tangent values are caller-owned. No history, synchronization, cancellation task or owned external resource exists.

## Failure, Concurrency, and Constraints
Invalid modulus/β/domain, invalid F, out-of-calibration norm/J and nonfinite results are typed failures. There is no iterative solve or constitutive nonconvergence route for these closed-form laws. No fallback or fake stress is returned.

## Verification and Change Impact
[ElasticityTests](../../../Tests/MechanicsMaterialsTests/ElasticityTests.swift) independently derive uniaxial/shear stresses/energies, unloading recovery and β stretch response, compare analytic tangents against central differences and superpose a rigid rotation. SI fixture K=1000 Pa, μ=400 Pa, β=800 Pa; domain norm<=0.5 and J>=0.2. Stress tolerance 1e-9 Pa+1e-10 relative for analytic values; directional 1e-3 Pa+1e-6 relative. Invalid and overflow routes fail on actual service calls. Changes to elasticity recheck Plasticity; finite mapping changes recheck objectivity. Exact platform evidence is recorded at handoff, with unexecuted profiles unverified.
