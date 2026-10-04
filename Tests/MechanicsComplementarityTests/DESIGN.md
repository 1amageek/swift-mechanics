# Complementarity behavioral fixtures

## Purpose and Scope
Parent: [MechanicsComplementarity](../../Sources/SwiftMechanics/Mathematics/Complementarity/DESIGN.md). Tests own independent numerical reference evidence for SO-004/005 subsets; children: none.

## Responsibilities and Boundaries
Verify original complementarity/QP equations, cone geometry, exact semantic continuation identity and explicit resource/domain failures. Physical contact, geometry, non-associated Coulomb behavior, runtime persistence format and target-profile composition remain outside this target.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Problem](../../Sources/SwiftMechanics/Mathematics/Complementarity/Problem/DESIGN.md) | depends on | Immutable input/cache/policy | Semantic identities | Frozen tolerance scales |
| [Projection](../../Sources/SwiftMechanics/Mathematics/Complementarity/Projection/DESIGN.md) | depends on | Cone operations | Independent KKT projection oracle | Associated cone only |
| [Solve](../../Sources/SwiftMechanics/Mathematics/Complementarity/Solve/DESIGN.md) | depends on | Actual public solver protocol | Manufactured optima/failures | General dense SPD via verified Cholesky |

## Architecture
```text
Frozen analytic optima -> production solver -> original independent balances/KKT
Frozen invalid/budget/restart scenarios -> production rejection -> unchanged cache
```

## Contracts and Invariants
Dimensionless n=2 LCP optimum (.5,0), general non-diagonally-dominant SPD optimum (1,2), μ=.5 cone optimum (2,1,0) and dual (.5,-1,0). Acceptance bounds 1e-9+1e-10*1, solution oracle 1e-7+1e-9 relative. Projection oracle tolerance 1e-12+1e-11 relative. Test suites share no mutable resource and have one-minute time limits. Cancellation is established before entering the solver using the task's own cancellation state.

## Verification and Change Impact
Run `python3 Scripts/run_with_timeout.py 180 swift test --build-path .build/complementarity-kernels --filter 'ProjectionTests|SolveTests'`. Actual domain/algorithm/cache changes invalidate corresponding fixtures. Root owns exact Native/WASM/Embedded profile evidence and combined integration; no complete physical contact claim follows from these numerical tests.
