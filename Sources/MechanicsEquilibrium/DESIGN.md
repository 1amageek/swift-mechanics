# MechanicsEquilibrium

## Purpose and Scope
Parent: [system/package](../../DESIGN.md). IM17 owns ST-001..004 and ST-008 in [SPEC](../../SPEC.md): equilibrium, quasi-static continuation, reaction ambiguity, smooth operating-point linearization and bounded sweeps. Children are indexed after actual source contracts exist. This dispatch qualifies no operation.

## Responsibilities and Boundaries
The implementation owner owns child directories under Sources/MechanicsEquilibrium and Tests/MechanicsEquilibriumTests. Root owns this index, Package.swift, global public probes, PROGRESS and commits. Equation providers own calibrated force/energy/domain meanings; this owner solves and independently accepts their original force/constraint equations. Numerical convergence does not establish stable equilibrium, uniqueness or a reaction decomposition. Dynamics and Constraints supply only their documented admitted physical/coordinate operators. Modal/buckling domains remain IM28.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Root](../../DESIGN.md) | parent | Dispatch/composition authority | Sole shared writer | Whole-target proof remains IM48 |
| [Nonlinear](../MechanicsNonlinear/DESIGN.md) | depends on | Required original-residual solve | Verified initial numerical kernel | Scalar normalization and physical acceptance belong here |
| [Constraints](../MechanicsConstraints/DESIGN.md) | depends on | Identified equations, rank and local assembly | Verified initial stateless kernel | General geometry/reactions are unavailable |
| [Dynamics](../MechanicsDynamics/DESIGN.md) | depends on | Admitted mass, bias and original physical action | Verified spatial tree producer | General constrained/recursive dynamics are unavailable |

## Architecture
```text
identified physical force / constraint / parameter domain and explicit seed
 -> bounded nonlinear equilibrium / continuation solve
 -> original force balance and rank / branch / stability-qualified result or typed failure
```

## Contracts and Invariants
Read actual supplier paths and coordinate/unit/resource/error contracts before defining children or APIs. Providers have required protocol witnesses and explicitly calibrated SI/reference scales. Final acceptance independently checks physical balance and every retained constraint row. Report rank, branch and reaction ambiguity without manufacturing certainty. Smooth linearization states coordinate reduction, units and nonsmooth exclusion. Sweep entries retain provenance and individual failures; failed entries do not seed successful continuation. Full assigned ST scope remains after any qualified initial subset.

## State, Ownership, and Lifecycle
Configurations/providers/results are immutable Sendable. Work and continuation values have explicit exclusive caller ownership; no hidden cache changes branch or accepted state. Shared mutable state preserves identical storage, isolation and Sendable/access contracts on all targets. External callbacks execute outside short control locks.

## Failure, Concurrency, and Constraints
Missing physical law, invalid/stale frame/chart, nonfinite or inconsistent balance, forbidden reaction ambiguity, branch/domain failure, nonsmooth linearization, cancellation and exhausted capacities are typed. Caller selects bounded dimensions, records, arithmetic, iterations and parameter domain before execution; supplier ledgers remain separate. Callable unsupported paths carry incomplete implementation markers and fail explicitly. Unknown failed supplier work stops without retry.

## Verification and Change Impact
Tests/MechanicsEquilibriumTests owns independent hanging-load/spring equilibria, implemented branch/continuation cases, actual rank/reaction ambiguity, smooth derivatives against independent directional checks and mixed successful/failed sweeps. Root qualifies stable selected public behavior on exact Native/WASM/Embedded profiles. No solver success implies physical stability or whole-feature completion. Changed force/chart/reaction/linearization assumptions invalidate direct and transitive analysis/control consumers.
