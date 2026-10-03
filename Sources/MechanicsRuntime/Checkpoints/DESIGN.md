# Native Checkpoint and Contributor Admission

## Purpose and Scope
Own bounded native byte codec, exact continuation admission, contributor validation and explicit compatible-model migration. Parent: [MechanicsRuntime](../DESIGN.md). No children.

## Responsibilities and Boundaries
Native checkpoint serialization is separate from model exchange. Required generic contributor methods validate actual bytes and migrate their own schema; opaque state is never assumed compatible. Model migration consumes ModelRevisionUpdating required operations.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Runtime](../DESIGN.md) | parent | Initial runtime scope | Root composition | Full requirement family remains IM08 |
| [Compiler revisions](../../MechanicsCompiler/Revisions/DESIGN.md) | depends on | Transition/migrate and exact target binding | Physical migration | Equal counts alone do not qualify meaning
| [State records](../StateRecords/DESIGN.md) | depends on | Checkpoint/configuration schemas | Complete continuation | Missing/unknown payload is failure |

## Architecture
```text
accepted checkpoint -> bounded little-endian envelope + checksum -> owned bytes
bytes -> bounded parse -> structural/integrity validation -> required contributor validation + actual model.makeState
old checkpoint + compiler transition -> physical migration + each contributor migration -> complete target checkpoint
```

## Contracts and Invariants
Strict UTF-8 decoding uses the Swift validating initializer and requires macOS 15, iOS/tvOS 18 or watchOS 11 on Apple platforms; selected WASM/Embedded qualification is separate.
Format v1 owns magic/version/payload length/FNV-1a integrity checksum and exact little-endian UInt64/Double bit patterns. It is integrity detection, not cryptographic authentication. Model identity/revision checks and build/backend/precision continuation checks yield distinct failures. Encoding uses one payload and one final envelope buffer (at most twice the admitted byte capacity); decode borrows the owned input slice and materializes only output payload/scalar records. Strings require valid UTF-8, all input lengths/counts and total encoded bytes are bounded before allocation/traversal. Corrupt, truncated, trailing, nonfinite, oversized or schema-incomplete input produces no accepted result.

Required contributor ID/category/schema version/byte limits are explicit. Provider registration must match required schemas; each payload validates via required generic witness operation under cumulative work/scratch limits. Provider is immutable Sendable, deterministic, with no source mutation/reentry/external effects; supplier owns its behavioral proof and truthful accounting. Empty registry rejects unknown contributors. Preserve migration requires compiler's exact compatible transition and explicit supplier migration for each record, followed by actual target admission. Exact restart requires same build/backend/precision; reset/recompute external solver state is not silently attempted.

Physical checkpoint v1 stores fixed-anchor tree state; prescribed moving-anchor checkpoint requests are explicitly unsupported until raw quaternion/derivative continuation policy is implemented and proved. This does not replace moving frames with identity values.

## State, Ownership, and Lifecycle
Immutable records are Sendable value owners. Mutable work lives in an exclusive inout transaction; shared metadata/cancellation state uses identical Mutex storage on every target. Native/WASM/Embedded semantics are qualified only by selected actual target paths.

## Failure, Concurrency, and Constraints
Typed RuntimeFailure identifies domain, missing contributor, incompatible model/continuation, capacity, busy/closed/cancelled or validation failure. Session failures retain last accepted prefix. Limits precede allocation and publication is all-or-nothing. No silent fallback or unimplemented success.

## Verification and Change Impact
[Test owner](../../../Tests/MechanicsRuntimeTests/DESIGN.md): Actual uninterrupted vs restarted contributor/random trajectory, corrupt/truncated/missing/schema/revision/build/backend failures and compatible inertia-edit migration. Provider-specific internal state/future moving anchors remain explicit integration obligations.
