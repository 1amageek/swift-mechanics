# Native Checkpoint and Contributor Admission

## Purpose and Scope
Own bounded native byte codec, exact continuation admission, contributor validation and explicit compatible-model migration. Parent: [MechanicsRuntime](../DESIGN.md). No children.

## Responsibilities and Boundaries
Native checkpoint serialization is separate from model exchange. Required generic contributor methods validate actual bytes and migrate their own schema; opaque state is never assumed compatible. Model migration consumes ModelRevisionUpdating required operations.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Runtime](../DESIGN.md) | parent | Initial runtime scope | Root composition | Full requirement family remains IM08 |
| [Compiler revisions](../../../Modeling/Compiler/Revisions/DESIGN.md) | depends on | Transition/migrate and exact target binding | Physical migration | Equal counts alone do not qualify meaning
| [State records](../StateRecords/DESIGN.md) | depends on | Checkpoint/configuration schemas | Complete continuation | Missing/unknown payload is failure |
| [Core geometry](../../../Mathematics/Core/Geometry/DESIGN.md) | depends on | Checked exact unit-quaternion component restoration | Anchor pose reconstruction | Restoration checks unit norm without normalization |

## Architecture
```text
accepted checkpoint -> bounded little-endian envelope + checksum -> owned bytes
bytes -> bounded parse -> structural/integrity validation -> required contributor validation + actual model.makeState
old checkpoint + compiler transition -> physical migration + each contributor migration -> complete target checkpoint
```

## Contracts and Invariants
Only this component's checkpoint handler publication file issues immutable `_RuntimeStateAdmission`, after preflight, required contributor validation, cancellation gates and actual model.makeState. Its explicit fileprivate initializer carries the exact physical handle and normalized checkpoint. RuntimeAcceptedState consumes that token, with no raw-field initializer or exposed token.

Strict UTF-8 decoding uses the Swift validating initializer and requires macOS 15, iOS/tvOS 18 or watchOS 11 on Apple platforms; selected WASM/Embedded qualification is separate.
Formats v1/v2 own magic/version/payload length/FNV-1a integrity checksum and exact little-endian UInt64/Double bit patterns. It is integrity detection, not cryptographic authentication. Model identity/revision checks and build/backend/precision continuation checks yield distinct failures. Encoding uses one payload and one final envelope buffer (at most twice the admitted byte capacity); decode borrows the owned input slice and materializes only output payload/scalar records. Strings require valid UTF-8, all input lengths/counts and total encoded bytes are bounded before allocation/traversal. Corrupt, truncated, trailing, nonfinite, oversized or schema-incomplete input produces no accepted result.

Required contributor ID/category/schema version/byte limits are explicit. Provider registration must match required schemas; each payload validates via required generic witness operation under cumulative work/scratch limits. Provider is immutable Sendable, deterministic, with no source mutation/reentry/external effects; supplier owns its behavioral proof and truthful accounting. Empty registry rejects unknown contributors. Preserve migration requires compiler's exact compatible transition and explicit supplier migration for each record, followed by actual target admission. Exact restart requires same build/backend/precision; reset/recompute external solver state is not silently attempted.

Zero-anchor encoding emits exactly the existing v1 envelope and payload bytes. Nonempty anchor state emits v2: the unchanged v1 physical prefix through q/v/a, then UInt64 anchor count and each ordered sample's frame-key string, time, quaternion(w,x,y,z), translation(x,y,z), velocity(angular xyz,linear xyz), acceleration(angular xyz,linear xyz), followed by the existing contributor tail. Decoder supports v1 and v2; v2 requires a positive count. Every anchor consumes 20 reserved physical slots before sample allocation/read and frame keys consume cumulative metadata. Samples retain order, quaternion sign, signed zeros and all finite scalar bit patterns. Core's public `UnitQuaternion.init(unitW:x:y:z:)` validates exact components without normalization; invalid rotations are corrupt checkpoints. Model-independent parsing cannot prove expected frame identity; decode rejects duplicate keys, and complete admission uses actual model.makeState to reject missing, duplicate, unknown or stale samples. Format support does not certify a prescribed time law.

## State, Ownership, and Lifecycle
Immutable records are Sendable value owners. Mutable work lives in an exclusive inout transaction; shared metadata/cancellation state uses identical Mutex storage on every target. Native/WASM/Embedded semantics are qualified only by selected actual target paths.

Admission phases end their temporary lifetimes before invoking required contributor witnesses or compiled-tree admission. One operation-owned immutable registry/record owner connects preflight, metadata preparation and validation; physical publication follows validation. The order of checks, cumulative validation budget, cancellation gates, canonical contributor order, error mapping and all-or-nothing publication remain unchanged. No additional lock, mutable cache, target branch or alternate WASM stack profile is introduced.

## Failure, Concurrency, and Constraints
Typed RuntimeFailure identifies domain, missing contributor, incompatible model/continuation, capacity, busy/closed/cancelled or validation failure. Session failures retain last accepted prefix. Limits precede allocation and publication is all-or-nothing. No silent fallback or unimplemented success.

## Verification and Change Impact
[Test owner](../../../../../Tests/MechanicsRuntimeTests/DESIGN.md): Actual uninterrupted vs restarted contributor/random trajectory, corrupt/truncated/missing/schema/revision/build/backend failures and compatible inertia-edit migration. Provider-specific prescribed-law/history validation remains a consumer obligation; Runtime preserves samples without certifying their generator.

The IM24 consumer exposed a measured 33,712-byte Embedded debug admission frame on a nested actual integration/validation path. Admission lifetime changes require the sixteen Native Runtime behavioral cases and the existing original-profile Native/WASM/Embedded public probes to execute again; the failing nested Hybrid path is additional composition evidence. The sixteen Runtime cases passed in the registered 299-test Native cohort; the final original-profile Native/ordinary-WASM/Embedded-WASM public probe exited 0, including the nested Hybrid path. This requalifies the exercised lifetime revision only.

### AR01 owner qualification
Accepted checkpoint state receives only the admission-issued token. Required-contributor rejection and actual invalid tree coordinates cannot publish an accepted state. Integrated test, foreign-access refusal and public profile evidence are owned by [root integration](../../../../../DESIGN.md#ar01-integrated-qualification-2026-10-04) and [FoundationVerification](../../../../../Verification/FoundationVerification/DESIGN.md#ar01-public-profile-execution).
