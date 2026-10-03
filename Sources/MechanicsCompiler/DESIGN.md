# MechanicsCompiler

## Purpose and Scope
Parent: [system/package](../../DESIGN.md). Responsibility IM07: Mechanical model compilation, immutable layouts, feature requirements and transactional validation. Children: [CompilationRecords](CompilationRecords/DESIGN.md), [Capabilities](Capabilities/DESIGN.md), [Validation](Validation/DESIGN.md), [Revisions](Revisions/DESIGN.md). Component contracts are established before their source and indexed at handoff. The complete target remains governed by [SPEC](../../SPEC.md) and [plan](../../IMPLEMENTATION_PLAN.md).

## Responsibilities and Boundaries
Mechanical model compilation, immutable layouts, feature requirements and transactional validation. Runtime, native exchange, CAD mechanical input consume published contracts and own subsequent state evolution/physics and integration. Component designs own exact domains, failure guarantees and verification; root alone owns target/manifest and module indexes.

## Related Designs
| Design | Relationship | Contract used | Summary | Cautions |
|---|---|---|---|---|
| [Root](../../DESIGN.md) | parent | Scope, owner and requirement DAG | Single-writer package composition | Full feature closure remains IM48 |
| [MechanicsCore](../MechanicsCore/DESIGN.md) | depends on | Units, frames and finite values | Verified producer handoff at f291f24 | Only documented operations/profiles are qualified |
| [MechanicsModel](../MechanicsModel/DESIGN.md) | depends on | Validated body records, IDs, inertia and representations | Verified producer handoff at f291f24 | Only documented operations/profiles are qualified |
| [MechanicsNumerics](../MechanicsNumerics/DESIGN.md) | depends on | Checked numerical capabilities and admitted rank/operator contracts | Verified producer handoff at f291f24 | Only documented operations/profiles are qualified |
| [MechanicsJoints](../MechanicsJoints/DESIGN.md) | depends on | Validated joint manifolds, trees and q-v layouts | Verified producer handoff at f291f24 | Only documented operations/profiles are qualified |

## Architecture
```mermaid
flowchart LR
  MechanicsCore --> Module[MechanicsCompiler]
  MechanicsModel --> Module[MechanicsCompiler]
  MechanicsNumerics --> Module[MechanicsCompiler]
  MechanicsJoints --> Module[MechanicsCompiler]
  Module --> Consumers[Runtime, native exchange, CAD mechanical input]
```

## Contracts and Invariants
Public service operations are protocol requirements. Accepted records/results satisfy the admitted original invariants, with explicit typed failures identifying unavailable/unsupported capability. Providers and consumers share immutable public values only. A feature declaration or registered callback does not prove its numerical implementation. Component contracts and behavioral tests establish concrete acceptance and failure paths before composition.

## State, Ownership, and Lifecycle
Immutable Sendable inputs/results and exclusively operation-owned mutable value workspace. Shared references require an identical Mutex/actor boundary on every declared target. No target-specific weaker storage/conformance or implicit current-caller isolation is admitted. Evolution/checkpoint acceptance remains IM08.

## Failure, Concurrency, and Constraints
Caller capacity/operation limits and tolerance/domain policy are explicit. Invalid input, incompatible references, cancellation, overflow, unsupported feature and exhausted policy propagate; no partial compiled success, invented force or silent alternate law is returned. Native/ordinary WASM/Embedded evidence is separately qualified with the exact toolchain/SDK/link profile from FoundationVerification.

## Verification and Change Impact
Tests/MechanicsCompilerTests owns actual analytic/manufactured behavior and invalid/failure proofs for its components. Root owns exact-profile runtime composition, integration and local commits. Changed producer assumptions invalidate affected compiler/runtime/dynamics/exchange clients; static structures and successful compilation alone are not mechanical evidence.

### Verified initial producer handoff (2026-10-03)
Native Swift 6.4.0 release passed 17 compiler tests in four suites, including actual connected spatial/planar chart/rank/motion, strict input admission, canonical-equivalent ID layout/migration, revision/cache/state independence and cancellation before publication. Root's single coherent path review findings were closed by registration bounds before sorting and equality-consistent canonical ordering plus actual-layout migration comparison. Selected two-body spatial descriptor compilation, real pure generic stiffness-schema validation, actual motion/pattern, stale state and inconsistent source pose rejection compiled/linked and ran with exit 0 on Native, ordinary WASM and Embedded WASM. Matching SDKs and Node.js 24.19.0 WASI Preview 1 were used; Embedded selected --traits EmbeddedUnicode. This is selected descriptor/kinematic producer evidence, not general execution capability, all validators/graphs or asynchronous Embedded cancellation. Native source tests own broader cases; mutable runtime/cache/extension-state evolution remains downstream.
