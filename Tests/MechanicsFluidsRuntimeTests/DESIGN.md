# MechanicsFluidsRuntimeTests

## Purpose and Scope
Behavioral owner for [PlanarContinuation](../../Sources/SwiftMechanics/Physics/Fluids/PlanarContinuation/DESIGN.md); parent [package](../../DESIGN.md), no children. Actual execution/profile qualification pending.

## Responsibilities and Boundaries
Exercise exact public codec/required contributor/checkpoint handler/trial contracts with an actual compiled spatial static-root carrier and real MAC/Cholesky services. Own untrusted-field rejection, whole accepted-prefix/RNG rollback and replay. Frozen projection tests own full discretization refinement; no duplicated solver or mock result.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [Continuation](../../Sources/SwiftMechanics/Physics/Fluids/PlanarContinuation/DESIGN.md) | verified by | Wire/binding/time/sequence/ledgers | Sole contributor and one step per accepted transaction |
| [Projection](../../Sources/SwiftMechanics/Physics/Fluids/PlanarProjection/DESIGN.md) | depends on | Actual pressure/flow | Independent analytic velocity/pressure association |
| [Runtime](../../Sources/SwiftMechanics/Execution/Runtime/DESIGN.md) | depends on | Whole checkpoint/restart/RNG | Actual prepublication handler |
| [Compiler](../../Sources/SwiftMechanics/Modeling/Compiler/DESIGN.md) | depends on | Real compiled carrier | No fabricated model |

## Architecture
```text
real compiled carrier + independent solenoidal field -> Runtime required handler
 -> actual MAC trial -> accept/reject/checkpoint/restart -> exact owner comparison
forged full wire / exhausted real solver / cancellation -> typed failure + unchanged prefix/RNG
```

## Contracts and Invariants
Fixtures admit bounded deterministic n/time and all three distinct work ledgers. Initial nonzero Taylor–Green field generates an actual nonzero projected pressure and dissipative flow; periodic divergence is computed independently from face samples. Shear amplification uses the analytic discrete viscous eigenvalue. Restart forgeries preserve outer checkpoint structure while changing field time or sequence; rejection must occur before accepted publication. Session admission itself rejects initial incoherent history. Equality compares full checkpoint contributors, physical state, RNG and accepted sequence.

Supplier ledger tests delegate to the real ReferencePlanarFlowSolver before replacing NumericalWork with a fresh same-budget value, then either return the correct result or throw. Test zero and precharged incoming ledgers, exact restoration of the pre-invocation snapshot including the documented boundary operation, unavailable supplier-work propagation, whole prefix/RNG preservation and one invocation. The invocation counter is protected by the same Synchronization.Mutex<Int> contract across all targets; numerical output is never fabricated.

## State, Ownership, and Lifecycle
All field/model fixtures immutable and locally owned. Shared cancellation uses Synchronization.Mutex<Bool> with identical read/cancel paths; a real-solver wrapper cancels only after delegate success. No target storage or Sendable branch. Sessions shut down at test scope exit. Availability checks live inside SwiftTesting test bodies.

## Failure, Concurrency, and Constraints
No source/build/graph mutation of producers. Root runs timeout-wrapped tests after source freeze. Typed malformed/stale/physical/capacity/cancel/numerical unknown-work failures are checked independently. Supplier wrappers delegate real operations; no fake numerical output or retry.

## Verification and Change Impact
Codec corruption/bounds, carrier/required migration, exact accepted/rejected state/RNG, restart to same owner and fresh owner, forged time/sequence and failed-supplier/cancellation cases close the selected continuation contract. Changes to wire/identity/association invalidate those cases; actual target qualification remains root-owned.

| Profiles | Shared storage | Isolation | Read | Mutation | Release |
|---|---|---|---|---|---|
| Native / ordinary WASM / Embedded | Mutex<Bool> | same withLock | policy hook | cancel after real solve | retained immutable owner through call |
| Native / ordinary WASM / Embedded | Mutex<Int> | same withLock | invocation count | increment on delegated step | retained immutable owner through call |
