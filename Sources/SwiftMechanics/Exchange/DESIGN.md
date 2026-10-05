# Exchange component

## Purpose and Scope
Parent: [SwiftMechanics](../DESIGN.md). Own IM35: versioned native mechanical model exchange and bounded extension/asset admission. [SPEC](../../../SPEC.md) owns unchanged requirements; [plan](../../../IMPLEMENTATION_PLAN.md) owns prerequisites. Children: [Schema](Schema/DESIGN.md), [BinaryCodec](BinaryCodec/DESIGN.md), [Admission](Admission/DESIGN.md). Initial handoff retains full eventual requirement ownership.

## Responsibilities and Boundaries
The worker owns this module's child component directories and corresponding tests. Root owns this module index, Package.swift, global probes, PROGRESS.md and commits. Public service operations are protocol requirements. Consume producer public contracts without accessing or changing their private state; read their actual implementations and behavior before fixing consumer contracts.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Schema](Schema/DESIGN.md) | child | Versioned model-input values and budgets | Independent owned responsibility | See the qualified handoff belowal evidence |
| [BinaryCodec](BinaryCodec/DESIGN.md) | child | Bounded strict binary record preservation | Independent owned responsibility | See the qualified handoff belowal evidence |
| [Admission](Admission/DESIGN.md) | child | Required schema/asset checks and actual recompilation | Independent owned responsibility | See the qualified handoff belowal evidence |
| [SwiftMechanics](../DESIGN.md) | parent | Composition and global invariants | Sole registration authority | Whole closure remains IM48 |
| [MechanicsCompiler](../Modeling/Compiler/DESIGN.md) | depends on | actual native mechanical input, immutable descriptor and validation/revision services | Verified initial producer | Only admitted domains may be consumed |

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
Supported-record semantic round-trip and actual recompilation; malformed, duplicate, missing, oversized and unsupported schemas/extensions/assets must fail transactionally. Codec data is model input, not Runtime checkpoint continuation. Test owner: Tests/MechanicsExchangeTests. Root separately composes exact-profile public API execution. Changes in consumed producer assumptions invalidate only dependent evidence; report missing producer contracts instead of patching their owned files.

## Qualified Initial Handoff (2026-10-04)
Actual local proof: sixteen Native behavioral tests/three suites. Supported scope: SMNX v1 bounded strict UTF8 finite current Compiler records, exact SI/provenance/opaque assets, explicit unit-component correction, actual required extension recompilation and valid q-v/joint modes, malformed/duplicate/missing/stale/domain/budget/cancel rejection. Root's selected public-protocol composition separately compiled/linked and actually exited 0 on Native and both exact Swift 6.4.0 release SDK IDs swift-6.4.0-RELEASE_wasm and swift-6.4.0-RELEASE_wasm-embedded. Embedded retained the existing EmbeddedUnicode trait; Node.js 24.19.0 WASI Preview1 ran both artifacts. Commands used project timeout guards. Root composite probe records its actual analytic/failure path in [FoundationVerification](../../../Verification/FoundationVerification/DESIGN.md); Native host is macOS27, not minimum macOS13 qualification. No parallel WASI/browser/iOS/Linux proof follows.

Remaining eventual owner scope: external file/network I/O, physical opaque-asset validation, foreign formats and producer-unsupported model families. The initial handoff permits documented consumer composition and preserves full SPEC requirement ownership; it does not close whole-target IM48.

## Qualified XML Child

[XML](XML/DESIGN.md) owns bounded restricted markup syntax. [XMLQualification](../../../Verification/XMLQualification/DESIGN.md) owns independent original records/bytes, typed malformed/unsupported/budget/cancellation/consumed-work fixtures, canonical Native9 tests and exact-source ordinary/Embedded guard-first public execution. Foreign semantic adapters remain separate responsibilities.

## Qualified MJCF Child

[MJCF](MJCF/DESIGN.md) owns selected MuJoCo 3.3.7 format semantics through qualified XML and mechanics suppliers. [MJCFQualification](../../../Verification/MJCFQualification/DESIGN.md) owns the exact selected Native eight cases, seven synchronous ordinary/Embedded public cases with original 131072-byte guarded execution, and registered Native composition. Full format support and numerical MuJoCo equivalence remain separate obligations.

## Qualified URDF Child

[URDF](URDF/DESIGN.md) owns selected fixed/continuous semantic import and original-record export through qualified XML and mechanics contracts. [URDFQualification](../../../Verification/URDFQualification/DESIGN.md#executed-selected-registration) owns independent Native8, same seven ordinary/Embedded original131072 guarded/raw witnesses and canonical39-case evidence. Full format, limits/mimic/transmissions, assets and Runtime-state exchange remain separate obligations.
