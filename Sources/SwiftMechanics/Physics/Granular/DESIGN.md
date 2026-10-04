# Granular component

## Purpose and Scope
Parent [system/package](../../../../DESIGN.md). Own IM43/EX-004 granular reference evolution. The frozen AF16 source is registered for root behavioral qualification; actual lower child contracts precede source and are indexed below. Full requirement ownership persists until actual behavioral evidence exists.

## Responsibilities and Boundaries
linear_kernels owns new child directories and Tests/MechanicsGranularTests. Frozen MechanicsDerivatives remains read-only. Root owns this index, shared graph/scripts/probes/progress, producer changes and commits. Own physical particle distributions, neighbor/contact evolution and rigid boundaries; acceleration/coupled vehicle/fluid responsibilities belong to other owners.

## Related Designs
[Plan](../../../../IMPLEMENTATION_PLAN.md) owns IM08/21/24 prerequisites. [Runtime](../../Execution/Runtime/DESIGN.md), [Collision](../Collision/DESIGN.md), [ContactResponse](../ContactResponse/DESIGN.md), [ContactLaws](../ContactLaws/DESIGN.md) and [Hybrid](../../Execution/Hybrid/DESIGN.md) are read-only producers. Children establish actual consumed contracts and unavailable domains.

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

## Frozen Source Children

The child source/test snapshot is frozen for root registration and actual behavioral qualification. Source availability is not execution evidence. The [implementation plan](../../../../IMPLEMENTATION_PLAN.md#frozen-af16-source-handoff-and-actual-build-edges) owns the current dependency/ownership handoff.

| Child design | Relationship | Contract used | Cautions |
|---|---|---|---|
| [ParticleState](ParticleState/DESIGN.md) | child | Selected public operations defined by the child | Exact admitted domain and behavioral qualification belong to that child |
| [NeighborContacts](NeighborContacts/DESIGN.md) | child | Selected public operations defined by the child | Exact admitted domain and behavioral qualification belong to that child |
| [ParticleEvolution](ParticleEvolution/DESIGN.md) | child | Selected public operations defined by the child | Exact admitted domain and behavioral qualification belong to that child |
| [Replay](Replay/DESIGN.md) | child | Selected public operations defined by the child | Exact admitted domain and behavioral qualification belong to that child |
| [RuntimeContinuation](RuntimeContinuation/DESIGN.md) | child | AF27 bounded accepted-step journal and genuine original-physics replay | Selected canonical Native/WASM/Embedded original-profile proof passed; [evidence](../../../../Verification/FoundationVerification/DESIGN.md#af27-integrated-selected-qualification) |

## Selected AF17 Qualification

Root registered the fixed source graph after lower review and exercised actual implementations. All 436 Native behavioral tests in 30 registered modules passed in `.build/af17-integrated-native.log`. Selected public compositions compiled/linked and exited 0 on original Native arm64 macOS27, swift-6.4.0-RELEASE_wasm and its matching Embedded SDK with EmbeddedUnicode, Node24.19.0 WASI Preview1; `.build/af17-{native,wasm,embedded}-run.log` owns execution output. Original stack reservation and unmodified produced artifacts were used. This is selected-path evidence, not all Native test paths on WASM, target-wide performance, actual WASI parallelism or full requirement closure.

Native: nineteen actual contact, angular momentum, prescribed work, settling/refinement, seeded sampling/value-history replay and failure cases. Public profiles: required real two-sphere collision, original impulse/work, value replay/rejection and physical weighted sampling. Finite-mass boundary/Runtime transaction/wire/nonsphere/impact gaps remain open.

### Consolidation contract
This directory is a component inside the SwiftMechanics module, not a separate SwiftPM target. Its existing public behavior and exact-profile evidence remain its contract authority. Cross-component access uses the documented contracts; internal visibility alone does not grant admission or publication authority. Source relocation requires integrated behavioral requalification.

## AF27 accepted Runtime continuation dispatch

reaction_paths exclusively owns the new RuntimeContinuation child and Tests/MechanicsGranularRuntimeTests, consuming existing granular evolution/history/RNG and Runtime contributor/publication contracts. Actual state authority, reject/commit behavior and fresh-owner continuation must be defined before source. Existing granular children/tests and all suppliers remain read-only. This explicit reassignment supersedes earlier linear_kernels ownership only for this new child. Root owns this index, registration, public composition and commits. See [AF27 dispatch](../../../../IMPLEMENTATION_PLAN.md#af27-independent-source-and-verification-dispatch).
