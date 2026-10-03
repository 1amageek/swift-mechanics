# MechanicsContactResponse

## Purpose and Scope
Parent: [system/package](../../DESIGN.md). Own IM21: coupled contact assembly, response solve and identified force/impulse output. [SPEC](../../SPEC.md) owns unchanged requirements; [plan](../../IMPLEMENTATION_PLAN.md) owns prerequisites. Children: [WitnessPorts](WitnessPorts/DESIGN.md), [ImplicitNormal](ImplicitNormal/DESIGN.md). Initial handoff retains full eventual requirement ownership.

## Responsibilities and Boundaries
The worker owns this module's child component directories and corresponding tests. Root owns this module index, Package.swift, global probes, PROGRESS.md and commits. Public service operations are protocol requirements. Consume producer public contracts without accessing or changing their private state; read their actual implementations and behavior before fixing consumer contracts.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [WitnessPorts](WitnessPorts/DESIGN.md) | child | Current witness-to-law/body-point Jacobian binding | Independent owned responsibility | See the qualified handoff belowal evidence |
| [ImplicitNormal](ImplicitNormal/DESIGN.md) | child | Frozen-geometry compliant normal response and original physical evidence | Independent owned responsibility | See the qualified handoff belowal evidence |
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
Independent effective-mass/contact residuals, multi-contact coupling, framed wrench/virtual work and original momentum balance; invalid/stale witnesses, unsupported constitutive combinations, capacity, cancellation and failed-supplier work evidence. Test owner: Tests/MechanicsContactResponseTests. Root separately composes exact-profile public API execution. Changes in consumed producer assumptions invalidate only dependent evidence; report missing producer contracts instead of patching their owned files.

## Qualified Initial Handoff (2026-10-04)
Actual local proof: ten Native behavioral tests/two suites. Supported scope: current analytic collision witnesses, framed point Jacobians, actual dense rigid inverse-mass coupling and frozen-geometry frictionless undamped linear normal response with original law/cone/momentum/wrench/power residuals, dependent-row compliant-force uniqueness and stale/law/capacity/cancel failure. Root's selected public-protocol composition separately compiled/linked and actually exited 0 on Native and both exact Swift 6.4.0 release SDK IDs swift-6.4.0-RELEASE_wasm and swift-6.4.0-RELEASE_wasm-embedded. Embedded retained the existing EmbeddedUnicode trait; Node.js 24.19.0 WASI Preview1 ran both artifacts. Commands used project timeout guards. Root composite probe records its actual analytic/failure path in [FoundationVerification](../FoundationVerification/DESIGN.md); Native host is macOS27, not minimum macOS13 qualification. No parallel WASI/browser/iOS/Linux proof follows.

Remaining eventual owner scope: nonlinear/damped/frictional/cohesive contact, hard-impact response, pose evolution, physical non-associated Coulomb and complete CT domains. The initial handoff permits documented consumer composition and preserves full SPEC requirement ownership; it does not close whole-target IM48.

The original large fixed debug frame failed both WASM runtimes. An instruction-preserving private stack relocation proved causality; non-inlined bounded numerical phases with an exclusive operation workspace replaced the monolithic function. Supplier operations, equations, charge order and physical rejection criteria are unchanged. Final original-profile artifacts actually pass; diagnostic relocation is neither shipped nor profile evidence.
