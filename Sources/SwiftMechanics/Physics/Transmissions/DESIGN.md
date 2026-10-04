# Transmissions component

## Purpose and Scope
Parent: [responsibility owner](../DESIGN.md). IM13 owns TR-001..011 in [SPEC](../../../../SPEC.md). It owns identified ideal and constitutive transmission coordinate/effort ports, fidelity, phase, ratio and continuation. Children: [PortBindings](PortBindings/DESIGN.md), [IdealNetworks](IdealNetworks/DESIGN.md), [CompliantPorts](CompliantPorts/DESIGN.md), [ToothContacts](ToothContacts/DESIGN.md). The initial source is frozen after coherent review and the failure-ledger finding correction. The initial admitted ports have thirteen Native behavioral cases and selected Native/ordinary-WASM/Embedded-WASM public execution with exit 0. Full requirement ownership remains; broader transmission laws and coupled mechanism execution are unqualified.

## Responsibilities and Boundaries
The implementation owner owns child directories under Sources/SwiftMechanics/Physics/Transmissions and Tests/MechanicsTransmissionsTests. Root owns this index, Package.swift, public composition probes, progress and commits. Each supported transmission publishes its coordinate equation and conjugate efforts through actual supplied constraint/layout contracts. Tooth geometry/contact is IM47; accepted constrained evolution and dynamic bearing reactions are IM16. No ideal ratio implies a resolved tooth or self-locking model.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Responsibility owner](../DESIGN.md) | parent | Dispatch and composition authority | Disjoint ownership | Whole requirement closure remains IM48 |
| [Constraints](../Constraints/DESIGN.md) | depends on | Identified dimensionless coordinate equations, rank, projection and scalar ports | Verified initial stateless producer | General geometry, mixed charts and dynamic reactions are unavailable |
| [Nonlinear](../../Mathematics/Nonlinear/DESIGN.md) | depends on | Failed-work evidence of the actual assembly supplier | Preserves unavailable-work semantics | Direct import is required for exact Embedded specialization |
| [ToothContacts](ToothContacts/DESIGN.md) | child | Resolved compliant proxy evolution | IM47 owns genuine tooth forces and accepted history | External source fidelity and independent refinement are required; general Runtime codec remains separate |

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

### Consolidation contract
This directory is a component inside the SwiftMechanics module, not a separate SwiftPM target. Its existing public behavior and exact-profile evidence remain its contract authority. Cross-component access uses the documented contracts; internal visibility alone does not grant admission or publication authority. Source relocation requires integrated behavioral requalification.

## AF28 tooth-contact dispatch

nonlinear_mechanisms exclusively owns the new ToothContacts child and dedicated tests under IM47. It consumes externally supplied validated geometry/proxy records and qualified collision/contact/dynamics contracts and immutable accepted-value continuation, independently of the unfinished CAD adapter. Actual tooth forces and physical evolution, model fidelity/provenance and refinement precede qualification; an ideal coupling is not tooth-resolved authority. Existing children and suppliers stay read-only. Root owns this index/shared graph/public evidence/progress/commits. See [dispatch](../../../../IMPLEMENTATION_PLAN.md#af28-independent-frontier-dispatch).

Selected AF28 Native/ordinary-WASM/Embedded-WASM public behavior is qualified through the unchanged core profile. Exact integrated execution and remaining domain limits belong to [FoundationVerification](../../../../Verification/FoundationVerification/DESIGN.md#af28-integrated-selected-qualification); child contracts remain the API authority.
