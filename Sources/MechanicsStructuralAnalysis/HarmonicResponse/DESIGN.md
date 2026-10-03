# Complex harmonic response

## Purpose and Scope
Own bounded linear steady harmonic solve of actual mechanical pencil. Parent ../DESIGN.md; no children. Initial admitted implementation domain; selected behavioral/profile evidence is recorded by the parent composition index.

## Responsibilities and Boundaries
Own the stated physical/numerical operations and immutable result evidence. Runtime evolution, accepted events, geometry generation, producer source changes and whole-target qualification belong to other owners. Public callable operations are protocol requirements.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Parent](../DESIGN.md) | parent | IM28 dispatch | Scope and registration | No execution qualification yet |
| [PhysicalModels](../PhysicalModels/DESIGN.md) | depends on | Identified physical pencils and finite complex values | Admission/value authority | Binding and original equations remain required |
| [Numerics](../../MechanicsNumerics/LinearAlgebra/DESIGN.md) | depends on | NumericalWork, budgets, linear solve | Explicit bounded computation | Failed nested work may be unavailable |
| [Flexible](../../MechanicsFlexible/Tetrahedra/DESIGN.md) | depends on | Actual mass/tangent assembly | Physical nodal producer | Tet4 does not certify beams |
| [Equilibrium](../../MechanicsEquilibrium/Linearization/DESIGN.md) | depends on | Actual reduced pencil | Operating point authority | Supplied reduction only |
| [Tests](../../../Tests/MechanicsStructuralAnalysisTests/DESIGN.md) | used by | Behavioral oracles | Local proof ownership | Root owns exact profiles |

## Architecture
```text
physical identified input -> admission/budget -> local owned workspace
 -> original mechanical equation checks -> immutable result or typed failure
```

## Contracts and Invariants
Convention Re(x exp(i omega t)); solve (K-omega^2 M+i omega C)x=f via a real 2n block system and actual Numerics reference LU. Excitation is explicit complex conjugate generalized effort; output is caller map with physical dimensions, identity and bound. Complex values reject nonfinite components or unrepresentable magnitude at construction. Response publishes complex coordinates/output, amplitude and atan2 phase (zero amplitude phase unavailable), original complex force balance and work. Frequency rad/s nonnegative and within caller linearization validity envelope; displacement magnitude must meet declared normalized small-response bound. Beam response additionally reconstructs retained/fixed Hermite dofs and checks conservative per-element derivative bounds: slope<=1.5*(|w0|+|w1|)/h+|theta0|+|theta1| and curvature<=6*(|w0|+|w1|)/h^2+4*(|theta0|+|theta1|)/h. Axial P/(EA) plus c*curvature must meet the declared linear strain envelope; exceeding a conservative bound is an explicit domain rejection. No transient, nonlinear harmonic balance or arbitrary nonlinear response claim. Solver success is checked against original complex equation and final cancellation. Singular/resonant system and unavailable failed supplier work are explicit typed failures; no shifted frequency/damping fallback.

## State, Ownership, and Lifecycle
All input/law/binding/result values are immutable Sendable. Per-call arrays and exclusive inout NumericalWork have one caller owner and no shared cache. Inputs remain unchanged on success/failure. Native/WASM/Embedded use identical storage/conformance and no conditional isolation. Cancellation callback is immutable @Sendable context; callers own its lifetime and any shared mutation through the same Mutex/actor on all targets. No unsafe buffers. Retained input/output arrays count in declared conservative peak reserve; caller separately budgets aggregate results retained across calls. Metadata bytes and coordinate count are admitted before allocation/traversal.

## Failure, Concurrency, and Constraints
Caller controls maximum coordinates/metadata, arithmetic/storage/iterations, positive-mass/spectral/original residual tolerances and cancellation. Checked sizes precede allocation, scalar finite checks precede publication. Each bounded row/iteration polls cancellation. No guessed cap, hidden backend or success on iteration exhaustion. Failed nested linear work is explicitly unavailable and caller must not continue under a fabricated remaining budget.

## Verification and Change Impact
Analytic damped beam single retained oscillator amplitude/phase; real beam modal resonance response, output map units, excitation scaling; zero frequency, zero output phase, exact undamped resonance failure, excessive response, cancellation and nested resource failures. Changes in equations, scaling, boundary/binding or residual authority invalidate this child and dependent root structural probes; unchanged supplier evidence is reused.
