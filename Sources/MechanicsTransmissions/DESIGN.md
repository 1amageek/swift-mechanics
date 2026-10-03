# MechanicsTransmissions

## Purpose and Scope
Parent: [system/package](../../DESIGN.md). IM13 owns TR-001..011 in [SPEC](../../SPEC.md). It owns identified ideal and constitutive transmission coordinate/effort ports, fidelity, phase, ratio and continuation. Children are indexed by root after actual contracts exist. This dispatch does not qualify any API or physical behavior.

## Responsibilities and Boundaries
The implementation owner owns child directories under Sources/MechanicsTransmissions and Tests/MechanicsTransmissionsTests. Root owns this index, Package.swift, public composition probes, progress and commits. Each supported transmission publishes its coordinate equation and conjugate efforts through actual supplied constraint/layout contracts. Tooth geometry/contact is IM47; accepted constrained evolution and dynamic bearing reactions are IM16. No ideal ratio implies a resolved tooth or self-locking model.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Root](../../DESIGN.md) | parent | Dispatch and composition authority | Disjoint ownership | Whole requirement closure remains IM48 |
| [Constraints](../MechanicsConstraints/DESIGN.md) | depends on | Identified dimensionless coordinate equations, rank, projection and scalar ports | Verified initial stateless producer | General geometry, mixed charts and dynamic reactions are unavailable |

## Architecture
```text
identified shafts / rack / explicit transmission fidelity and law
 -> transmission-owned phase / ratio / constitutive port
 -> actual constraint equation or conjugate effort and independent power evidence
```

## Contracts and Invariants
Read the actual supplier implementations and published units/layout/error contracts before defining children or declarations. Every supported mode identifies frames, joint signs, coordinate units, revisions and phase; ratios do not silently choose absent geometry. Original coordinate residuals and conjugate power determine acceptance. Loss and stored energy remain distinct. Stateful engagement/backlash uses explicit immutable trial/accepted continuation, not hidden caches. Unsupported geometry/fidelity fails explicitly. Full TR-001..011 ownership persists after a qualified initial subset.

## State, Ownership, and Lifecycle
Operations own exclusive bounded work. Required protocol services expose behavior; immutable values identify continuation lifetime and binding. Shared mutable state, if necessary, preserves identical owners, isolation, Sendable and access contracts on Native/WASM/Embedded. External callbacks run outside short control locks.

## Failure, Concurrency, and Constraints
Invalid count/radius/axis/frame/phase, stale layout, contradictory networks, missing loss/contact models, nonfinite output, cancellation and exhausted resources are typed. Supplier work remains separate; unavailable failed work prevents retry. Callable unsupported branches carry incomplete implementation markers and fail. No backend or synchronization fallback is allowed.

## Verification and Change Impact
Tests/MechanicsTransmissionsTests owns analytic signed external/internal 20:40 ratio, phase, rack travel/force–torque power and each implemented network/constitutive state law, including real malformed/stale/resource failures. Each child states its precise supported fidelity and independent oracle. Root qualifies stable public operations on Native and exact matching WASM SDK/runtime profiles. Changed equations/units/port/state assumptions require dependent IM16/IM38/IM47 owners to recheck composition. Broader planned domains remain explicitly unqualified.
