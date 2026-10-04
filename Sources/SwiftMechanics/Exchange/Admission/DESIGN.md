# Transactional native input admission
## Purpose and Scope
Parent [Exchange](../DESIGN.md). Children: none. Owns required feature/schema/asset checks and actual decode plus Compiler composition publication.
## Responsibilities and Boundaries
Codec preserves input; existing Compiler owns topology, q-v layout, coordinate authority, reference pose/inertia physical validity and extension validator meaning. Inline asset bytes are data-admitted through whitelist/key/provenance only. Geometry execution, external/base-path I/O and Runtime continuation are not provided.
## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Compiler](../../Modeling/Compiler/DESIGN.md) | depends on | MechanicalModelCompiling requirement | Actual mechanics validation | Required validator supplied by caller |
| [Schema](../Schema/DESIGN.md) | depends on | bounded document/catalog/work | Required associations | No inferred defaults |
| [Codec](../BinaryCodec/DESIGN.md) | depends on | strict decode requirement | Local staging | Result unpublished until compile success |
## Architecture
```text
caller bytes -> local decoded document/report -> bounded duplicate/catalog/asset association validation
 -> injected actual Compiler (with immutable Sendable extension validator)
 -> loaded model + original document/assets + normalization report
 failure at any stage -> typed error, no partial loaded model
```
## Contracts and Invariants
Public loader is generic over verified MechanicalModelCompiling; every load operation is a protocol requirement. Caller CompilationPolicy owns target, inertia/joint tolerances, capacities and supplier extension NumericalBudget; codec ExchangeWork does not pretend to include compiler work. Body/frame/joint/anchor/extension entity definitions, feature identities, requirements and asset keys must be unique. Pairwise comparisons are charged including text lengths; no lexicographic rewrite of Unicode semantics. Extension parameter names/references follow actual Compiler constructor/validator contracts. Unknown required feature/schema fails admission; known record can still fail actual Compiler domain. Required assets must match exact representation provenance. Initial source revision/time and coordinate arrays are passed unchanged to compile; no profile or formulation translation.
## State, Ownership, and Lifecycle
Compiler and codec are immutable Sendable injected providers. Extension callback lifetime is owned by the Compiler value and its same-target Sendable contract. No callback is invented here, no hidden caches/mutations/I/O. Failed loading leaves caller bytes and previously loaded model untouched.
## Failure, Concurrency, and Constraints
Bounded admission scans follow codec preflight; compiler failures preserved in ExchangeError.compilation. Wrong target, cyclic graph, stale initial revision, missing validator/law domain, invalid physics and model capacities remain producer failures. Cancellation checked before/after supplier call; no interrupted partial success. Supplier performs its own cancellation and budgets as verified producer contract.
## Verification and Change Impact
[RoundTripTests](../../../../Tests/MechanicsExchangeTests/RoundTripTests.swift) recompiles planar/spatial trees and floating/spherical/custom layouts, checks actual snapshots/motion/sparsity/manifest/dimensional law parameters/provenance and revision updates, and rejects missing asset/schema, stale/cyclic/malformed input. Exact-profile execution and eventual unsupported model families are root/IM48 integration evidence, not inferred from codec success.
