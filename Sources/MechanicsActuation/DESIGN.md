# MechanicsActuation

## Purpose and Scope
Parent: [system/package](../../DESIGN.md). Dispatch responsibility: IM14, owning AC-001..008 in [SPEC](../../SPEC.md). Scope: actuator laws, bounded internal continuation, saturation and electromechanical/fluid/muscle ports with explicit power. This is a dispatch boundary; no implementation or public API is qualified yet. Children are indexed by root after the owner defines and verifies actual component contracts.

## Responsibilities and Boundaries
The implementation owner owns child component directories under Sources/MechanicsActuation and Tests/MechanicsActuationTests. Root alone owns this module index, package registration, global probes, PROGRESS.md and commits. The owner reads actual supplier paths before designing required protocol operations, values, units, ownership and failure. Numerical kernels do not infer missing mechanism dynamics or manufacture reactions.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Root](../../DESIGN.md) | parent | Dispatch/composition invariants | Sole graph/index authority | Full-target closure remains IM48 |
| [MechanicsRuntime](../MechanicsRuntime/DESIGN.md) | depends on | accepted/trial contributors, checkpoint and actual bounded work | Verified initial producer handoff | Consume only documented admitted domains; report missing producer contracts |
| [MechanicsLoads](../MechanicsLoads/DESIGN.md) | depends on | actual generalized/body/cable force ports and virtual work | Verified initial producer handoff | Consume only documented admitted domains; report missing producer contracts |

## Architecture
```text
verified identified supplier values / caller-owned equation or port domain
 -> component-owned bounded laws / residuals / state contribution
 -> independent physical acceptance and explicit output or typed failure
```

## Contracts and Invariants
Child designs precede declarations. Every operation identifies physical dimensions, coordinate/frame/revision meaning, supplied domain and exact output semantics. Missing models or providers fail explicitly. Original physical residuals and work/energy identities decide acceptance. Required Runtime contributors own persistent internal state; rejected transactions preserve physical, subsystem and random prefixes. Generic interfaces alone do not qualify unimplemented physics. Eventual full requirement ownership remains after an initial qualified subset.

## State, Ownership, and Lifecycle
Operation work is exclusive and bounded. Public services use required protocol witnesses; callbacks execute outside short metadata locks. Shared mutable state preserves identical storage, isolation and Sendable contracts on Native/WASM/Embedded. Immutable contributor values carry continuation across acceptance/checkpoint rather than hidden service caches.

## Failure, Concurrency, and Constraints
Invalid units/frames/domain, stale state, singular or inconsistent equations/ports, unsupported modes, nonfinite output, cancellation and resource exhaustion are typed. Budgets are caller-owned and checked before traversal/allocation; supplier ledgers remain separate and unknown failed work does not permit retry. OS API availability propagates from actual suppliers. No source backend or synchronization fallback is permitted.

## Verification and Change Impact
Tests/MechanicsActuationTests owns actual success/failure, analytic/independent residual and resource/cancellation tests. Constraint proof distinguishes consistent redundant rows from contradiction and nonunique reactions, actual closure/projection and explicit-time derivative terms. Actuation proof distinguishes effort from prescribed motion, validates clipping/internal-state rollback and port energy balance. Only the applicable responsibility's proof is owned here. Root composes selected Native and exact matching WASM profiles after a stable source snapshot. Changed domain/state/port assumptions invalidate dependent consumers, not unrelated supplier evidence.
