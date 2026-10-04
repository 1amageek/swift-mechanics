# Physical structural models and binding

## Purpose and Scope
Own analysis binding of the actual Flexible Hermite beam/Tet4 assemblies and actual Equilibrium reduced-pencil binding, plus the symmetric two-bar nonlinear stability model. Initial admitted implementation domain; selected behavioral/profile evidence is recorded by the parent composition index. Parent ../DESIGN.md; no children. Full ST-005..007 ownership persists through the analysis children.

## Responsibilities and Boundaries
Own the stated physical/numerical operations and immutable result evidence. Runtime evolution, accepted events, geometry generation, producer source changes and whole-target qualification belong to other owners. Public callable operations are protocol requirements.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Parent](../DESIGN.md) | parent | IM28 dispatch | Scope and registration | No execution qualification yet |
| [Numerics](../../../Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | NumericalWork, budgets, linear solve | Explicit bounded computation | Failed nested work may be unavailable |
| [Flexible](../../../Physics/Flexible/Beams/DESIGN.md) | depends on | Actual mass/tangent assembly | Physical nodal producer | Tet4 does not certify beams |
| [Equilibrium](../../Equilibrium/Linearization/DESIGN.md) | depends on | Actual reduced pencil | Operating point authority | Supplied reduction only |
| [Tests](../../../../../Tests/MechanicsStructuralAnalysisTests/DESIGN.md) | used by | Behavioral oracles | Local proof ownership | Root owns exact profiles |

## Architecture
```text
physical identified input -> admission/budget -> local owned workspace
 -> original mechanical equation checks -> immutable result or typed failure
```

## Contracts and Invariants
[Flexible Beams](../../../Physics/Flexible/Beams/DESIGN.md) owns Hermite element mechanics. This consumer retains its physical source, assembled operators, boundary indices and linear envelope; removes explicitly fixed coordinates and forms K(P)=K0-P G. Beam buckling means the conservative straight-branch tangent threshold. It is not postbuckling or material failure. Binding retains the actual uniform beam including slope/fiber calibration envelope, physical source provenance and original node/coordinate identities; Equilibrium binding retains the actual immutable force model, operating parameter and branch identity along with the reduction basis, with provenance explicitly unavailable when the producer has none. The axial compression strain P/(EA) must stay inside the declared linear envelope. Flexible input uses the actual assembler, state frame/revision/node association and coordinate elimination; no supplied arbitrary matrices. Equilibrium input uses actual returned reduced M/K/C and identified operating point; eta is dimensionless and supplied reduction remains the producer authority. The analysis does not infer a new nullspace or stability from convergence.

## State, Ownership, and Lifecycle
All input/law/binding/result values are immutable Sendable. Per-call arrays and exclusive inout NumericalWork have one caller owner and no shared cache. Inputs remain unchanged on success/failure. Native/WASM/Embedded use identical storage/conformance and no conditional isolation. Cancellation callback is immutable @Sendable context; callers own its lifetime and any shared mutation through the same Mutex/actor on all targets. No unsafe buffers. Retained input/output arrays count in declared conservative peak reserve; caller separately budgets aggregate results retained across calls. Metadata bytes and coordinate count are admitted before allocation/traversal.

## Failure, Concurrency, and Constraints
Caller controls maximum coordinates/metadata, arithmetic/storage/iterations, positive-mass/spectral/original residual tolerances and cancellation. Checked sizes precede allocation, scalar finite checks precede publication. Each bounded row/iteration polls cancellation. No guessed cap, hidden backend or success on iteration exhaustion. Failed nested linear work is explicitly unavailable and caller must not continue under a fabricated remaining budget.

## Verification and Change Impact
Uniform beam analytic cantilever/pinned/free modes and Euler refinement; real Tet4 six rest rigid modes; Equilibrium operating-pencil adapter association and stale rejection; invalid physical domains, fixed-coordinate bounds, work/storage/cancel failures. Changes in equations, scaling, boundary/binding or residual authority invalidate this child and dependent root structural probes; unchanged supplier evidence is reused.
