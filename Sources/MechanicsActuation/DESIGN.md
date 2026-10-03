# MechanicsActuation

## Purpose and Scope
Parent: [system/package](../../DESIGN.md). Dispatch responsibility: IM14, owning AC-001..008 in [SPEC](../../SPEC.md). Scope: actuator laws, bounded internal continuation, saturation and electromechanical/fluid/muscle ports with explicit power. Children: [Ports](Ports/DESIGN.md), [DriveLaws](DriveLaws/DESIGN.md), [LumpedLaws](LumpedLaws/DESIGN.md), [Continuation](Continuation/DESIGN.md). The initial selected scalar domain has Native behavioral and selected exact-profile qualification below. Full AC ownership persists.

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
Tests/MechanicsActuationTests owns actual success/failure, analytic/independent residual and resource/cancellation tests. Actuation proof distinguishes effort from prescribed motion, validates clipping/internal-state rollback and port energy balance. Only the applicable responsibility's proof is owned here. Root composes selected Native and exact matching WASM profiles after a stable source snapshot. Changed domain/state/port assumptions invalidate dependent consumers, not unrelated supplier evidence.

The actual initial SwiftPM dependencies are Core, Model, Numerics, Joints, Compiler, Loads and Runtime. Compiler/model identify continuation binding; Loads supplies real body/tendon mapping; Runtime supplies accepted/trial ownership. Selected calibrated scalar models do not qualify prescribed constraint evolution, general charts, delay or general fluid/muscle physics. Test owner: [Actuation tests](../../Tests/MechanicsActuationTests/DESIGN.md).

### Initial handoff evidence (2026-10-04)
The final numerical closures preserve explicit NumericalError contracts; fixed Embedded code requires file-local imports of each consumed foreign declaration. These visibility corrections do not change equations or state. Eighteen Native behavioral cases/four suites passed: distinct servo modes, anti-windup/filter/braking, actual motor/chamber/muscle balances, actual Loads body/tendon/affine power, fixed payload/domain/stale binding, required Runtime validation/migration, rejected trial and checkpoint replay. Root coherent review covered actual binding, law, energy, transpose mapping, codec, registry and trial paths. Immutable configurations and exclusive value ledgers have identical storage/isolation/entry points on all targets; mutable Runtime lifecycle remains owned by its verified Mutex implementation.

The selected public probe separately compiled, linked and executed with exit0 on Native, ordinary WASM and Embedded WASM using Swift6.4.0 release and matching SDKs, EmbeddedUnicode and Node24.19.0 WASI Preview1. It executed a validated actual compiled revolute binding, motor circuit/energy, affine conjugate port power, required actuator contributor, actual servo rejection/checkpoint/restart and history continuation. Chamber/muscle/tendon/prescribed-command behavior is Native-local evidence, not inferred as executed WASM paths. Minimum macOS13, general charts/delay/fluid physiology, motor-driven mechanical evolution and prescribed reactions remain unqualified; IM48 is incomplete.
