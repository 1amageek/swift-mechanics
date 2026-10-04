# General damped mechanical spectrum

## Purpose and Scope
Own bounded complex right modes of (s*s*M+s*C+K)phi=0 for an identified existing StructuralPencil with SPD mass and finite symmetric K/C. C may be nonproportional and K indefinite. Parent [StructuralAnalysis](../DESIGN.md); no children. Existing Pencils unsupported branch stays unchanged; the new service carries complex modes for all 2*n roots.

## Responsibilities and Boundaries
PhysicalModels retains pencil/binding authority. `GeneralDampedModalAnalyzing` verifies expected binding, constructs normalized companion and accepts ORIGINAL quadratic equations. ComplexSpectrum owns general eigensolve. No nonlinear/global stability, defective eigenspace completeness or evolution claim.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Parent](../DESIGN.md) | parent | IM28 index | Uses the named boundary | Root integration |
| [PhysicalModels](../PhysicalModels/DESIGN.md) | depends on | StructuralPencil, binding/scales | Uses the named boundary | No invented physical metadata |
| [ComplexSpectrum](../../../Mathematics/Numerics/ComplexSpectrum/DESIGN.md) | depends on | General eigenpairs/live work | Uses the named boundary | Independently validate supplier and physical residual |
| [LinearAlgebra](../../../Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | NumericalWork | Uses the named boundary | No reset or hidden unknown work |
| [Tests](../../../../../Tests/MechanicsDampedSpectrumTests/DESIGN.md) | used by | Coupled analytic roots/modes | Uses the named boundary | Native evidence only until root profile execution |

## Architecture
```text
physical M/C/K + binding -> bounded finite/symmetric admission
 -> Mhat=S*M*S/(E*T^2), Chat=S*C*S/(E*T), Khat=S*K*S/E
 -> positive-mass Cholesky + triangular solves
 -> A=[0 I; -Mhat^-1*Khat -Mhat^-1*Chat]
 -> injected complex solver + remaining-budget ledger
 -> s=sigma/T, phi=S*u -> complex mass norm/phase
 -> ORIGINAL physical quadratic residual -> immutable modes
```

## Contracts and Invariants
`ReferenceGeneralDampedModalAnalyzer(spectrum:)` injects the lower protocol; required `modes(_:expectedBinding:policy:spectrumPolicy:work:)` returns binding, poles(s^-1), mode-major complex displacement modes(root*n+coordinate), maximum original quadratic residual, maximum mass-normalization error and actual work. Each phi obeys phi^H*M*phi=1 within structural original tolerance. Original row residual uses untransformed M/C/K, both complex quadratures and scale S_i*T/sqrt(E), normalized by max(1, amplitudes of Kphi,sCphi,s*s*Mphi). Every 2*n mode passes. No Rayleigh or real-basis assumption. Normalized SPD mass pivots exceed positiveMassThreshold. Defective/unresolved vectors fail explicitly.

## State, Ownership, and Lifecycle
Immutable Sendable service/input/result; operation-local workspace and ledger. Same source/storage/conformance across profiles; no shared state or target branch. Noninline construction/lower solve/publication phases limit stack lifetimes. Checked conservative 40*n*n+40*n plus retained binding scalars reserves upper live storage; lower receives only remaining capacity and successful/failed prefix is absorbed. Caller owns retained aggregate outputs.

## Failure, Concurrency, and Constraints
`GeneralDampedSpectrumFailure` carries cause, actual caller work and failedSupplierWorkUnavailable. Causes distinguish structural admission, numerical failure, lower spectral failure, invalid supplier ledger/output and physical residual rejection. Both cancellation callbacks and all capacities/budgets apply. The upper owner checks spectral cancellation before invocation, after absorbing successful supplier work, and immediately before publication; an injected supplier cannot bypass the caller policy. Supplier reset/change/overreport cannot publish success; known failed prefix remains charged and unavailable work is explicit. No result after stale binding, bad mass, nonsymmetry, nonfinite algebra, exhaustion or residual rejection.

## Verification and Change Impact
Genuine noncommuting off-diagonal damping with independently factored quartic roots and complex mode ratios. Perturbation/refinement against independent determinant roots, original physical rows/mass norms. Overdamped/unstable roots, scale, stale/bad mass, cancellation/resource faults and malicious suppliers. Child Native proof is restricted to tested matrices; root owns original128KiB Native/WASM/Embedded profiles and legacy rejection remains independent.
