# Constitutive measures

## Purpose and Scope
Parent: [MechanicsMaterials](../DESIGN.md). This component owns symmetric tensor algebra and the finite-motion mapping from deformation gradient F to Green strain E=(FᵀF-I)/2, second Piola stress S, first Piola stress P=FS and Cauchy stress σ=FSFᵀ/J. Children: none. Strain is dimensionless; stress and strain energy density per reference volume use Pa and J/m³.

## Responsibilities and Boundaries
Tensor shear fields are tensor shear, not engineering shear. Full tensor contraction counts off-diagonal fields twice. Domain owners explicitly supply the maximum Frobenius strain norm and minimum positive volume ratio J. No element, corotational extraction, ANCF discretization, plane stress reduction or calibration is inferred. Material services own their constitutive equations; this component owns only their kinematic push-forward.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Module](../DESIGN.md) | parent | SI and explicit failures | Composition | Element pairing remains IM19 |
| [Core geometry](../../../Mathematics/Core/Geometry/DESIGN.md) | depends on | Finite Matrix3 operations | F and stress transformation | Arithmetic overflow propagates as typed material failure |
| [Elasticity](../Elasticity/DESIGN.md) | used by | Tensor/finite mapping | Elastic laws | Tangents are directional derivatives |
| [Plasticity](../Plasticity/DESIGN.md) | used by | Tensor/finite mapping | Reference plastic history | History is material-frame owned |

## Architecture
```text
F -> FiniteStrainKinematics -> E
(F,S) -> FiniteStressResponse -> (P,σ)
(F,H,S,dS) -> FiniteStressDirectionalResponse -> (dP,dσ)
```

## Contracts and Invariants
All public values are immutable Sendable. SymmetricTensor validates finite entries; its operation-local algebra rejects nonfinite results. StrainDomain requires finite positive maximum strain and 0<minimum J<=1; it validates actual E norm and J. Fixed-sized matrices/tensors require O(1) time/storage and never allocate size-dependent data. For proper rigid Q, E(QF)=E(F), P(QF)=QP(F), σ(QF)=Qσ(F)Qᵀ. Directional derivatives include dJ=J tr(F⁻¹H) and all geometric stress terms; tangent strain direction is sym(FᵀH). Inversion is only attempted for admissible J, with no model fallback.

## State, Ownership, and Lifecycle
Inputs, responses and domain records are copied values. There is no retained workspace, global state, actor, pointer, platform branch or shared mutable state. Caller owns trial and accepted histories supplied by material components.

## Failure, Concurrency, and Constraints
Invalid parameters, out-of-domain strain/J, overflow and singular core operations fail explicitly. No state is mutated by a failing operation. Domain bounds are caller calibration policy; fixture bounds are selected before evaluating tests.

## Verification and Change Impact
[Tests](../../../../../Tests/MechanicsMaterialsTests) use exact tensor contraction and simple stretch/shear kinematics, reject inversion/nonfinite/overflow, and exercise objectivity and stress directional derivatives through real laws. Fixture matrix/strain absolute tolerance 1e-12 plus relative 1e-10; stress directional tolerance 1e-3 Pa plus relative 1e-6 with central step 1e-6. Changes recheck elastic/plastic consumers and future IM19 pairing; Native evidence does not establish WASM/Embedded runtime.

### Additive public response mapping
Public `response(secondPiolaStress:energyDensity:)` and `directionalResponse(deformationDirection:secondPiolaStress:secondPiolaDirection:)` let admitted finite material providers use this owner without internal access. Response requires finite nonnegative energy; tensor/matrix arithmetic preserves typed failures. Existing internal mappings and clients are unchanged. [InvariantHyperelasticity](../InvariantHyperelasticity/DESIGN.md) consumes these factories; its public factory tests and existing Materials behavioral tests own additive contract/regression proof.
