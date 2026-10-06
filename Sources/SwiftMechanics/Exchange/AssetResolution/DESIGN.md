# Explicit Asset Resolution

## Purpose and Scope
Parent: [Exchange](../DESIGN.md). Children: none. Own AF35.28 / IO-008's bounded provider lookup, exact original-byte/source/reference validation, iterative declared-dependency traversal and transactional immutable byte catalog. This selected implementation has fresh common2270 Native Memory-provider/catalog evidence; canonical-source registration is a separate root-owned obligation. No filesystem/network backend, opaque-format parser, physical mesh/law inference, default base or model compilation is introduced.

## Responsibilities and Boundaries
The caller owns an explicit authoritative inventory of expected NativeInlineAsset values, addresses and complete dependency declarations. A real injected AssetProviding owns lookup/read and its immutable byte backing or external resource lifetime. The resolver validates actual returned values against that inventory and publishes only after all selected roots' declared transitive closure passes. An immutable memory provider performs actual lookup over caller-supplied original records; it creates no placeholder bytes. Errors preserve attempted reads, known consumed byte prefixes and earlier work; no partial catalog escapes.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Exchange](../DESIGN.md) | parent | Explicit bounded semantic/asset admission | Composition owner | Root owns registration and Git |
| [Schema](../Schema/DESIGN.md) | depends on | NativeInlineAsset, SourceProvenance | Exact opaque original values and flat native keys | ASCII native keys, exact source/revision, format whitelist; no physical interpretation |
| [Admission](../Admission/DESIGN.md) | coordinates with | NativeModelLoading | Caller may use the catalog in actual native loading | No internal NativeDocumentAdmission helper dependency |
| [Model representations](../../Modeling/Model/Representations/DESIGN.md) | depends on | SourceProvenance | Expected source identity/revision | Byte identity is stricter than canonical String equality |

## Architecture
```text
caller roots + expected inventory + semantic/provider work budgets
 -> bounded inventory/address/format/duplicate preflight
 -> AssetProviding.read(address, explicit limits, inout provider work)
 -> exact returned address/key/format/source/revision/bytes/dependencies validation
 -> local DFS frames and unseen/active/completed states
 -> dependency-first immutable AssetResolvedCatalog
 -> bounded nativeAssets projection -> public NativeMechanicalDocument / actual native loader (caller)
failure -> typed reason + retained work; no catalog publication/retry/fallback
```

## Contracts and Invariants
| Boundary | Assumption / guarantee |
|---|---|
| Address | Explicit nonempty bounded opaque base; bounded safe relative path; no absolute/scheme/backslash/percent/query/fragment/control, empty/dot/parent segments; Unicode bytes retained without normalization |
| Inventory | Caller-supplied exact original opaque bytes and full declared dependency set; unique byte addresses and native ASCII keys; known nonempty format; source/revision preserved |
| Provider | Requirement, not extension-only dispatch; immutable Sendable owner; one bounded read attempt per request; no hidden retry/fallback/default path; provider records actual consumed byte prefix via public work methods even on failure |
| Read limit | Resolver supplies remaining payload/metadata capacities and dependency/string maxima before the call; provider must honor limits; resolver independently checks returned values and monotonic receipts |
| Identity | All addresses, keys, formats, sources and dependency addresses compare exact UTF8; revision and payload count/each byte must match; no Unicode-equivalence binding or digest-only assertion |
| Dependencies | Provider's original declaration must contain exactly inventory's dependency addresses, in the same order; each is inventory-defined; duplicate edges and active-node revisit fail; completed DAG nodes read once |
| Publication | Successful root closure only; deterministic dependency-first order, selected root order retained; immutable NativeInlineAsset byte owners unchanged; no physical asset/format correctness is inferred |
| Native bridge | nativeAssets returns the actual validated payload values; caller's native codec/loader still enforces required representation associations, schemas and mechanics compilation |

Catalog queries apply the current caller's record, metadata, returned-dependency and payload caps, including when tighter than the resolution policy. They retain the existing validated COW bytes without copying or rereading them; a local checked projection-total byte count bounds each nativeAssets output separately from the cumulative provider/validation ledger.

The expected bytes are caller-owned truth, so this selected contract intentionally does not authenticate unknown external content without an expected original. The declared inventory/dependency records are authority for opaque references; hidden references inside an uninterpreted format are outside proof. Additional format-specific decoding must supply its own qualified complete declaration. Empty bytes are allowed when the original opaque asset is genuinely empty, with no fabricated geometry claim. Previously published catalogs remain untouched by subsequent failure.

## Runtime Flows
Preflight the complete caller inventory and format catalog, all references/metadata bounds and duplicate identities before reads. Selected root indices enter an operation-local DFS stack. For each unseen node reserve retained payload, invoke real provider read with remaining limits, preserve/check provider work, verify original bytes and dependencies, then stage the record. Visiting active children fails cycle admission. A parent completes only after its children; completed shared dependencies are reused by identity. Check cancellation before/after provider calls, per byte comparison and before final publication. On any failure staged arrays and frames are released; only the exclusive caller work survives.

## State, Ownership, and Lifecycle
All public providers/results/policies/records are Sendable. Memory provider retains immutable caller records; returned Arrays retain COW byte backing independently of provider lifetime. Input expected inventory storage is borrowed immutable and excluded from owned-storage charging. Catalog payload/table ownership is charged before retention; no raw pointer, weak reference or borrowed view escapes. DFS frames, visited flags, staged records and output arrays are local; work is exclusive inout. Native/ordinary WASM/Embedded use identical storage, cancellation, receipt and conformance contracts with no conditional isolation.

## Failure, Concurrency, and Constraints
Caller semantic policy bounds roots, references, edges, depth, per-string/metadata bytes, per-asset/total validated bytes, logical owned storage and operations. Provider policy independently bounds inventory scan, read attempts, known consumed bytes and operations. Before arithmetic/allocation use checked sums/products. Logical storage charges requested element strides and retained payload, excluding caller input backing/allocator overhead and independent supplier storage; no RSS/zero-allocation/throughput assertion follows.

AssetProviderFailure distinguishes missing, ambiguous, source failure, capacity, cancellation and invalid input. AssetResolutionFailure retains the original typed provider failure and address, or exposes missing declaration, mismatched metadata/bytes/dependencies, unsupported format, duplicates, cycle, capacity and cancellation. Partial provider failure publishes no bytes/catalog but its known consumed prefix remains in work. Resolver validates that policy/counters never reset and that one call does not hide multiple attempts; successful byte receipt exactly equals actual returned payload count. Failed-call receipt may consume a bounded prefix or fail before the attempt counter advances. A malicious/noncooperative injected implementation cannot be made bounded by the consumer; provider qualification must establish its actual read/receipt contract. No wall-clock guarantee or implicit resource rollback is claimed.

A provider receipt violation retains both previous and observed ledger snapshots plus the original provider failure, if any. A replaced policy or regressed counter restores the last trusted caller ledger; the rejected observed claims remain in the typed diagnostic and are not erased or credited as validated progress. Monotonic same-policy consumed work stays in the caller ledger even when it reveals an invalid retry/oversized return. No read is retried.

## Verification and Change Impact
The selected Native evidence is owned by [public qualification fixtures](../../../../Verification/AssetResolutionQualification/DESIGN.md): independently authored original bytes and declared graph through actual memory/injected read -> complete closure -> public native asset values, with actual native codec/loader association acceptance when composed. Cover missing source/declaration, duplicate key/address/edge, byte/source/format/address/dependency mismatches, diamond reuse, cycles/depth, unsafe paths, every policy boundary/overflow, real cancellation and a provider failure after a consumed prefix; no partial result and cumulative work must remain observable. Fresh Native common2270 compile/link and original eight tests/seven public cases passed for the selected Memory provider/catalog path. Ordinary WASM/Embedded and actual native codec/loader association composition remain open. Current supplier originals and AdmissionTests/ExchangeFixtures establish native opaque admission assumptions; this resolver's exact bytes/dependency/work/refusal behavior is demonstrated by its own qualification fixtures. Do not generalize another feature's execution.

### Source handoff
One comprehensive source review and focused finding recheck covered actual lookup/traversal, exact-byte/metadata/closure verification, staged publication, cancellation, failed-prefix accounting, checked budgets and public query ownership. Fixed findings: catalog projection/lookup honoring tighter caller caps, and provider receipt failures retaining their original typed cause plus previous/observed counters without erasing prior trusted work. No builds/tests/probes/benchmarks/profiles/new tests or Git operations occurred. The structural scanner's typed-throws parse limitations are not compile evidence.

| Logical state | Native / ordinary WASM / Embedded storage and entry | Release |
|---|---|---|
| Memory source/provider | Same immutable Sendable record/byte owners | Provider/result value lifetimes |
| Resolution/provider work | Same exclusive inout ledgers; no conditional fields | Caller lifetime |
| DFS/visited/staged/completed data | Same local arrays and value frames | Return/failure releases scratch |
| Catalog/native projection | Same immutable owned COW payload values | Catalog/output lifetime |

Open scope: format-specific hidden-reference discovery, physical geometry/law validation, unknown-content authentication without expected original bytes, filesystem/network backends and portable runtime/profile qualification. No callable placeholder route supplies these capabilities. Existing qualified supplier APIs are used without internal helper access or changes.

### AF37.6 fresh Native composition
The earlier pass10/Native2353 receipts and artifacts described by the fixture owner were lost during capacity recovery and are historical evidence, not an executable verification premise. The current source18 remains unchanged. Root owns a fresh common producer derived only from committed `f0325b053de62da95cabacbf48ad1efd3aa7cb78` selected2124 plus seven frozen cohort subjects129 and root SDF17, producing the final2270-source graph. The `.build/af38-assets` consumer borrows that exact completed source/object/module/dylib inventory read-only, with no cold producer or object copying. Independent original eight tests/seven synchronous cases preserve byte/source/revision/dependency ordering, exact resolver/provider counters, refusal causes, transactional previous catalog and awaited cancellation. All mutable state is operation-local exclusive inout; no production or fixture uses a macOS15-only Mutex dependency, so library/Support/public remain macOS13 and generated Testing target14 without a fabricated unavailable branch. The fresh matching consumer completed Native eight tests/seven public cases with all common2270 source/object/module/dylib bytes unchanged before/after execution. [Native receipt](../../../../.build/af38-assets/native-receipt.json), SHA256 `867297b94e58fb3e696d2923bf7954ef39262de7f6965ca913308204e3c7f717`, owns the exact commands, bindings and bounded execution evidence. Source18 and fixture5 remain unchanged. Public executable and borrowed dylib strict signatures passed; strict test signing was not checked. Portable/format decoding/physical association/external backends and root canonical registration remain open.
