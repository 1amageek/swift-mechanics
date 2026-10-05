# Invariant hyperelasticity

## Purpose and Scope
Parent: [Materials](../DESIGN.md). One component owns six independently selectable isotropic energy potentials for FX-005/006: Mooney-Rivlin, Yeoh, Gent, five-term Arruda-Boyce, Demiray and compressible Blatz-Ko foam. Children: none. Its public conformers implement the existing [HyperelasticResponding](../Elasticity/DESIGN.md) requirements. No C target or new Swift module is introduced.

## Responsibilities and Boundaries
Owns calibrated energy, material stress, exact directional material tangent and parameter/domain refusal. Constitutive owns finite kinematic admission and push-forward; element, pressure multiplier, fitting, accepted evolution, temperature, history and Runtime authority remain external. Models use reference-volume energy in J/m^3 and stresses/moduli in Pa.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Materials](../DESIGN.md) | parent | Constitutive ownership | Selected extra laws | Full FX family stays open |
| [Elasticity](../Elasticity/DESIGN.md) | coordinates with | HyperelasticResponding requirements | Protocol injection into clients | No implementation dependency |
| [Constitutive](../Constitutive/DESIGN.md) | depends on | FiniteStrainKinematics public response factories, StrainDomain, SymmetricTensor | Admitted F, finite stress/tangent mapping | Only public supplier operations |
| [Core geometry](../../../Mathematics/Core/Geometry/DESIGN.md) | depends on | Matrix3/Vector3 finite operations | Constant-size tensor algebra | Core failures map to MaterialError |
| [Tests](../../../../../Tests/MechanicsSixHyperelasticTests/DESIGN.md) | used by | Six public protocol conformers | Independent energies, objectivity and tangent oracles | Native qualification only |

## Architecture
```text
six immutable potential parameters + F (+ H)
    -> admitted J/E and stable isochoric invariants x/y
    -> W and analytic invariant gradient/Hessian
    -> S and dS
    -> Constitutive public mapping -> P/Cauchy and dP/dCauchy
```

## Contracts and Invariants
Let C=F^T F, J=det F>0, x=J^(-2/3)tr(C)-3 and y=J^(-4/3)I2(C)-3. The first five laws add K/2*(J-1)^2 with K>0; this selected compressible penalty is explicit, not an exact incompressibility constraint.

| Law | Distortional/reference energy | Parameter admission |
|---|---|---|
| Mooney-Rivlin | c1*x+c2*y | c1,c2>=0, c1+c2>0 |
| Yeoh | c1*x+c2*x^2+c3*x^3 | c1>0, c2,c3>=0; selected monotone hardening domain |
| Gent | -mu*jm/2*log(1-x/jm) | mu,jm>0 and x<jm; equality is rejected |
| Arruda-Boyce | mu*sum(a_p/N^(p-1)*(I1bar^p-3^p)), p=1..5 | mu>0,N>1 and I1bar<3N; a=(1/2,1/20,11/1050,19/7000,519/673750) |
| Demiray | mu/(2*b)*(exp(b*x)-1) | mu,b>0; overflow rejected |
| Blatz-Ko | mu/2*(I2/J^2+2J-5) | mu>0; original compressible foam, no independent K |

Arruda-Boyce explicitly implements the five-term inverse-Langevin expansion, not the exact inverse-Langevin function. mu is its coefficient, not a silently normalized initial modulus. Blatz-Ko has its original compressible volumetric behavior; an incompressible second-invariant model is a different contract. Constants and equations are supported by [ANSYS material reference](https://ansyshelp.ansys.com/public/Views/Secured/corp/v252/en/pdf/ANSYS_Mechanical_APDL_Material_Reference.pdf), [FElupe original Blatz-Ko implementation](https://felupe.readthedocs.io/en/v9.1.0/_modules/felupe/constitution/tensortrax/models/hyperelastic/_blatz_ko.html) and [primary soft-tissue model study](https://currentprotocols.onlinelibrary.wiley.com/doi/10.1002/cpz1.381). Our implementation is independently derived from those equations.

S=2*dW/dC, P=FS, sigma=PF^T/J. Tangents include derivative of invariants, their Hessians, J and geometric push-forward; no numerical differentiation in production. Stable QR exponential remainders retain tiny nonnegative distortion energy instead of subtracting nearly equal traces. Exact mathematical energies are nonnegative for admitted parameters; computed nonfinite/negative energy is refused. Objectivity W(QF)=W(F), P(QF)=QP(F) holds for proper rotations. Fixed-size operations have O(1) time/storage and bounded 25-term near-zero remainder evaluation.

## State, Ownership, and Lifecycle
All public stored properties are immutable Sendable values. Each operation owns its local matrices/scalars; no shared workspace, retained state, pointers, unchecked Sendable or platform-dependent isolation exists. Potential calculations run independently and may be evaluated concurrently.

## Failure, Concurrency, and Constraints
MaterialError preserves invalid parameters, strain/J domain, chain locking and arithmetic/Core failures. Finite inputs never silently select another law, clamp a negative energy, or soften a locked material. Caller StrainDomain bounds are calibration policy. Native math imports differ solely at the existing scalar-math platform boundary; WASM/Embedded are not inferred from Native success.

## Verification and Change Impact
Each of six suites independently checks simple shear energy/stress, hydrostatic stretch, original potential derivative, all stress directional derivatives, superposed rotation, recovery, tiny shear energy and refusal. Common public factory tests verify frame/J terms and arithmetic rejection. Existing Materials tests requalify unchanged elastic/plastic clients after the additive public factory contract. Only changed factory/potential paths need rechecking; Runtime/element pairing, minimum macOS13, performance and portable profiles remain unqualified. Shared code edits invalidate all six potential suites; a single potential edit invalidates its own suite. One source review and finding-only recheck precede frozen source/hash receipts and source integration.

### Selected Native qualification (2026-10-06)
Canonical public product: 44 tests in seven concurrent suites passed; retained Materials product: nine tests in two concurrent suites passed. Swift6.4.0 release, arm64 macOS27.0.1, test producer target macOS14.0. Final changed-test build2.41s / execution0.002s; supplier build1.32s / execution0.001s. All analytic stress tangents and energy directional gradients passed two-step refinement, six independent 70-digit diagonal-stretch references distinguish first/second invariants, tiny shear retains positive energy, locking and failure paths reject explicitly. Initial test-only Arruda reference-expression type-check failure was repaired by splitting its arithmetic without changing production. One complete source review and its verification-gap recheck completed; Native-only evidence does not establish minimum macOS13, portable runtime, performance or element coupling. Frozen hashes/log receipts live in `.build/hyperelastic-evidence/`.
