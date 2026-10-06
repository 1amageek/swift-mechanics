# General complex spectrum

## Purpose and Scope
Own bounded Float64 reference-CPU eigenpairs of a general dense complex nonsymmetric matrix. Parent [Numerics](../DESIGN.md); no children. This numerical prerequisite owns no mechanical damping or stability authority.

## Responsibilities and Boundaries
`ComplexSpectralSolving` owns the complete requested spectrum or explicit failure. No symmetric, diagonal, real-only substitution, regularization, external library or runtime metadata. Raw immutable matrices are admitted by each solve.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Numerics](../DESIGN.md) | parent | Component index | Uses the named boundary | Registration belongs to root |
| [LinearAlgebra](../LinearAlgebra/DESIGN.md) | depends on | NumericalWork and checked budgets | Uses the named boundary | Failed prefix remains charged |
| [ScalarFunctions](../../ScalarFunctions/DESIGN.md) | depends on | Platform hypot | Uses the named boundary | No approximation |
| [GeneralDampedSpectrum](../../../Analysis/StructuralAnalysis/GeneralDampedSpectrum/DESIGN.md) | used by | Full complex eigenpairs | Uses the named boundary | Consumer retains physical residual authority |
| [Tests](../../../../../Tests/MechanicsComplexSpectrumTests/DESIGN.md) | used by | Independent eigenpair evidence | Uses the named boundary | Native proof does not qualify other profiles |

## Architecture
```text
immutable matrix -> finite/size admission + reserve -> uniform scaling
 -> unitary Hessenberg -> implicit complex shifted QR + bounded deflation
 -> Schur back substitution + norm/phase -> ORIGINAL residual -> complete eigenpairs
```

## Contracts and Invariants
`ComplexSpectralMatrix(dimension:entries:)` is row-major. `SpectrumComplex(real:imaginary:)` is a raw value; solve rejects nonfinite coordinates/amplitude. `ComplexSpectrumPolicy` supplies maximum dimension, maximum QR iterations (zero allowed), finite positive deflation/eigenvector-pivot/original-residual tolerances, and immutable cancellation callback. Result has exactly n eigenvalues and n*n mode-major right eigenvector entries, sorted by real then imaginary eigenvalue. Each vector has Euclidean unit norm with largest component real nonnegative. Every original row satisfies |Av-lambda*v|/max(1,sum_j |a_ij*v_j|+|lambda*v_i|) <= originalResidualTolerance. This does not guarantee convergence for every matrix or independent eigenvectors near defectivity. Unresolved nonzero coupling at a repeated Schur diagonal is typed ill-conditioned eigenvector failure; no arbitrary replacement vector.

## State, Ownership, and Lifecycle
Immutable Sendable inputs/results/policies/service on every target. Mutable arrays and inout ledger are operation-local with no shared cache, unsafe buffers or recursion. Reused Hessenberg/QR arrays have conservative 30*n*n+20*n scalar reserve including input/output. Caller budgets retained aggregates separately. Cancellation callback owner synchronizes shared mutation identically on all targets.

## Failure, Concurrency, and Constraints
Typed errors distinguish invalid input/policy, capacity, nonfinite arithmetic, cancellation, nonconvergence, ill-conditioned eigenvector, original residual rejection and exact numerical budget error. Checked sizes precede allocation; each row/iteration polls cancellation. QR cap and NumericalWork iteration budget both apply. All throws preserve actual work; deflation alone cannot publish success.

## Verification and Change Impact
Independent triangular complex, coupled nonsymmetric, known similarity, semisimple/defective repeated, scale and real-root cases; cancellation, nonconvergence and storage/arithmetic/iteration limits. Loose deflation must fail original residuals. Changes invalidate direct damped/public consumers and profile evidence.
