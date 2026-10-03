# MechanicsContactResponse

## Purpose and Scope
Parent: [system/package](../../DESIGN.md). Own IM21: coupled contact assembly, response solve and identified force/impulse output. [SPEC](../../SPEC.md) owns unchanged requirements; [plan](../../IMPLEMENTATION_PLAN.md) owns prerequisites. Children are indexed by root once their actual responsibility contracts exist. Initial handoff retains full eventual requirement ownership.

## Responsibilities and Boundaries
The worker owns this module's child component directories and corresponding tests. Root owns this module index, Package.swift, global probes, PROGRESS.md and commits. Public service operations are protocol requirements. Consume producer public contracts without accessing or changing their private state; read their actual implementations and behavior before fixing consumer contracts.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Root](../../DESIGN.md) | parent | Composition and global invariants | Sole registration authority | Whole closure remains IM48 |
| [MechanicsComplementarity](../MechanicsComplementarity/DESIGN.md) | depends on | original numerical residual and associated-cone domain | Verified initial producer | Only admitted domains may be consumed |
| [MechanicsCollision](../MechanicsCollision/DESIGN.md) | depends on | framed geometric witnesses and revisions | Verified initial producer | Only admitted domains may be consumed |
| [MechanicsDynamics](../MechanicsDynamics/DESIGN.md) | depends on | actual mass operators, framed motion and force mapping | Verified initial producer | Only admitted domains may be consumed |
| [MechanicsContactLaws](../MechanicsContactLaws/DESIGN.md) | depends on | minimal constitutive inputs, paired laws and explicit histories | Verified initial producer | Only admitted domains may be consumed |

## Architecture
```text
verified identified producer inputs
 -> child-owned bounded admission and actual transformation/equations
 -> independently validated output or typed failure
```

## Contracts and Invariants
Children must define exact admitted domain, units/frames, revisions, provider assumptions, resource ledger, output meaning and failure contract before source. Missing laws/formats/backends cannot become successful placeholders. Numerical acceptance checks original physical equations; exchange acceptance preserves declared semantics and provenance.

## State, Ownership, and Lifecycle
Immutable input/output may be shared. Mutable work/trial state has explicit exclusive ownership. Any shared reference state preserves identical storage/isolation/Sendable contracts on Native/WASM/Embedded. External callbacks and I/O occur outside short metadata critical sections; borrowed data cannot outlive its owner.

## Failure, Concurrency, and Constraints
Admission, stale revision/layout, unsupported domain/schema, nonfinite output, capacity/work exhaustion and cancellation fail explicitly. Limits are caller-selected, checked before unbounded traversal/allocation and accounted separately from supplier work. No silent physical or backend fallback.

## Verification and Change Impact
Independent effective-mass/contact residuals, multi-contact coupling, framed wrench/virtual work and original momentum balance; invalid/stale witnesses, unsupported constitutive combinations, capacity, cancellation and failed-supplier work evidence. Test owner: Tests/MechanicsContactResponseTests once sources exist. Root separately composes exact-profile public API execution. Changes in consumed producer assumptions invalidate only dependent evidence; report missing producer contracts instead of patching their owned files.
