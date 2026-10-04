# Equilibrium behavioral verification
## Purpose and Scope
Test owner for [Equations](../../Sources/SwiftMechanics/Analysis/Equilibrium/Equations/DESIGN.md), [Statics](../../Sources/SwiftMechanics/Analysis/Equilibrium/Statics/DESIGN.md), [Linearization](../../Sources/SwiftMechanics/Analysis/Equilibrium/Linearization/DESIGN.md), [Continuation](../../Sources/SwiftMechanics/Analysis/Equilibrium/Continuation/DESIGN.md). Children: none.
## Responsibilities and Boundaries
Actual physical residual/retained rows, branch provenance and original dynamics/directional derivative paths are checked. Numerical convergence cannot establish stability/uniqueness/reaction decomposition.
## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Equations](../../Sources/SwiftMechanics/Analysis/Equilibrium/Equations/DESIGN.md) | verifies | original SI force/energy | spring and pendulum analytical authority | caller coefficient domain |
| [Statics](../../Sources/SwiftMechanics/Analysis/Equilibrium/Statics/DESIGN.md) | verifies | solve/rank/reactions | original retained balance | local stationarity only |
| [Linearization](../../Sources/SwiftMechanics/Analysis/Equilibrium/Linearization/DESIGN.md) | verifies | actual mass/reduction/probes | original derivatives and association | supplied basis |
| [Continuation](../../Sources/SwiftMechanics/Analysis/Equilibrium/Continuation/DESIGN.md) | verifies | value history and sweep | mixed failures and cumulative work | no branch switching |
Existing supplier behavioral proofs are assumptions only for their published contracts; new analytical expectations are independent.
## Architecture
```text
SI force/branch fixture -> public solve -> independent force/constraint balance
actual Dynamics mass + supplied N -> public linearization -> original directional checks
mixed load cases -> statuses + unchanged failed-case seed
```
## Contracts and Invariants
Caller scales, SI tolerances, branch domains and ledgers are explicit. Dynamics fixture inertia ordering follows actual snapshot.bodies, with identity-based lookup of the matching spatial descriptor inertia and an explicit failure for missing body/frame/inertia association. Canonical descriptor order is not treated as articulated tree order. Hanging load/spring closed-form values, redundant-support force sum and nullity, pendulum/spring state matrices and finite-difference directions refute wrong success paths. Invalid/stale/domain/nonsmooth/unsupported/budget/cancel conditions fail.
## Verification and Change Impact
| Owned invariant | Actual test owner |
|---|---|
| SI force/energy, support ambiguity, independent final residual, malformed/domain/budget/cancel failures | [StaticEquilibriumTests](StaticEquilibriumTests.swift) |
| Actual mass binding, retained reduction, original directional derivative and singular/probe-domain rejection | [EquilibriumLinearizationTests](EquilibriumLinearizationTests.swift) |
| Explicit multi-root branch, reversible loading, failed seed isolation, restart/stale/capacity, unknown work stop | [EquilibriumContinuationTests](EquilibriumContinuationTests.swift) |

24 behavioral cases exist; execution evidence is pending. Source freezes before root registration. Timeout180 focused/cohort tests and exact-profile probes are root-coordinated. No cross-suite shared mutable fixtures. Full ST closure is not inferred from this subset.

## State, Ownership, and Lifecycle
The late-cancellation fixture owns one instance-local Mutex<(completedCalls: Int, cancelled: Bool)> for all read/mutation paths. ReferenceLinearSolver runs outside the lock; successful completion updates the count/cancellation atomically afterward. The policy callback retains this Sendable owner for the test operation. Releasing the test-local owner and policy releases the mutex storage; no global fixture or resource remains.

| Target | Storage/isolation | Read | Mutation | Release/evidence |
|---|---|---|---|---|
| Native | identical Mutex tuple | withLock properties | withLock completion after actual solve | operation owner release; behavioral execution pending |
| WASM | identical Mutex tuple | same properties | same completion path | same lifetime; this test is not profile runtime proof |
| Embedded | identical Mutex tuple | same properties | same completion path | same lifetime; this test is not profile runtime proof |

The fixture declares actual Synchronization availability (macOS15/iOS18/tvOS18/watchOS11); production remains immutable and does not acquire this test-only restriction.
