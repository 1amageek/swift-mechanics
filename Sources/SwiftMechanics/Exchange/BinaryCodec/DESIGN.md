# Bounded native binary codec
## Purpose and Scope
Parent [Exchange](../DESIGN.md). Children: none. Owns SMNX v1 encode/decode, exact finite scalar/text traversal and explicit producer normalization reporting.
## Responsibilities and Boundaries
No file/network access, external resource loading or Runtime checkpoint serialization. No physical asset or extension execution inferred from round-trip. Current records are preserved; unavailable future fields require a schema version, not ignored data.
## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Schema](../Schema/DESIGN.md) | depends on | fields, values, budget | Wire authority | Cumulative admission counts |
| [Admission](../Admission/DESIGN.md) | coordinates with | required references/catalogs | Transactional semantic gate | Decode is not compilation |
| [Core/Model](../../Modeling/Model/DESIGN.md) | depends on | public value constructors | Finite/physical validation | Caller normalization/inertia policy |
## Architecture
```text
encode: bounded measurement + admission -> exact-sized logical output reservation -> second write pass
 decode: byte/count/UTF8 guards -> producer value construction + correction report -> reference admission
```
## Contracts and Invariants
Reader never indexes before remaining-length check. UInt64->Int conversion checks representability, count policy and checked products/sums. Variable arrays preflight count times minimum wire bytes and element stride before allocating; malformed huge count cannot allocate before truncation/capacity failure. Strings use bounded strict UTF8 byte validation then String(decoding:), preventing replacement characters from malformed bytes without using platform-new String(validating:) availability. Source representation order, unit dimensions and enum semantics are explicit. Quaternion/axis/inertia normalization is bounded/reported as Schema defines. Encoder array inputs are count-admitted before traversal; strings are scanned against per-string/cumulative byte/work limits without materializing intermediate byte arrays. Shared append buffer is reused, with no per-record byte buffer.
## State, Ownership, and Lifecycle
NativeWireReader owns an immutable COW reference to caller bytes only for the operation; returned arrays/strings own copied output payload. Writer uses a measurement flag with an empty buffer, then one reserved output owner. All mutation is operation-local/inout. Protocol encode/decode requirements are concrete non-generic witness calls on all targets.
## Failure, Concurrency, and Constraints
Typed error includes offset/domain/capacity where relevant. Unsupported version/unit/tag/feature/schema/asset, invalid UTF8, nonfinite scalar, duplicate definitions, producer rejection, truncation, trailing bytes, cancellation and resource limit fail without partial results. No fallback decoding or extra success on malformed input.
## Verification and Change Impact
[CodecTests](../../../../Tests/MechanicsExchangeTests/CodecTests.swift) freeze header/scalar byte order, strict malformed UTF8/truncation/count/tag policies, preserve Unicode IDs and signed zero, and test normalized inputs/report bounds. Byte/schema edits recheck loader recompilation and exact-profile probes.
