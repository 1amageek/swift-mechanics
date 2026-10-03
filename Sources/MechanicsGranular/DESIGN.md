# MechanicsGranular

## Purpose and Scope
Parent [system/package](../../DESIGN.md). Own IM43/EX-004 granular reference evolution. This is unregistered source dispatch; actual lower child contracts precede source and child links. Full requirement ownership persists until actual behavioral evidence exists.

## Responsibilities and Boundaries
linear_kernels owns new child directories and Tests/MechanicsGranularTests. Frozen MechanicsDerivatives remains read-only. Root owns this index, shared graph/scripts/probes/progress, producer changes and commits. Own physical particle distributions, neighbor/contact evolution and rigid boundaries; acceleration/coupled vehicle/fluid responsibilities belong to other owners.

## Related Designs
[Plan](../../IMPLEMENTATION_PLAN.md) owns IM08/21/24 prerequisites. [Runtime](../MechanicsRuntime/DESIGN.md), [Collision](../MechanicsCollision/DESIGN.md), [ContactResponse](../MechanicsContactResponse/DESIGN.md), [ContactLaws](../MechanicsContactLaws/DESIGN.md) and [Hybrid](../MechanicsHybrid/DESIGN.md) are read-only producers. Children establish actual consumed contracts and unavailable domains.

## Architecture
```text
identified particles/boundary + accepted random/contact state
 -> bounded neighbors/witnesses -> actual contact/mass evolution
 -> original conservation/work acceptance -> publish or reject complete prefix
```

## Contracts and Invariants
Declare physical SI quantities, frame/source/revision, shape/material and time discretization. Settling/shear/collision/refinement and seeded replay must execute real production paths. Numerical success does not certify momentum/energy or contact acceptance.

## State, Ownership, and Lifecycle
Explicit immutable accepted records and exclusive mutable trial workspace; continuation includes every used history/RNG contributor. Identical Mutex/actor/Sendable contracts on all targets. External callbacks and release outside locks.

## Failure, Concurrency, and Constraints
Checked particle/neighbor/contact/metadata and numerical budgets precede allocation/traversal. Unsupported shape/law/evolution and missing state fail explicitly. Failed supplier work stops execution; no empty successful particle/contact output.

## Verification and Change Impact
Source-first independent physical/failure tests and one coherent review precede root registration and execution. Changes in contact/discretization/state authority invalidate dependent root qualification. CPU evidence is not acceleration or full-system completion.
