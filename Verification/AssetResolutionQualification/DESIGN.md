# Asset resolution public qualification fixtures

## Purpose and Scope
Parent: [AssetResolution](../../Sources/SwiftMechanics/Exchange/AssetResolution/DESIGN.md). Children: none. Own AF35.28's independent public behavioral fixture preparation: original opaque bytes, declared graph, actual memory reads/resolution/catalog queries and typed failure/accounting oracles. Initial fixture preparation performed no execution. Historical pass10 Native2353 execution passed the eight tests/seven cases below; those private artifacts were lost during capacity recovery, so the current AF37.6 phase completed the new matching common2270 producer proof below. The generated test runner strict-signature limitation remains recorded.

## Responsibilities and Boundaries
Own only this directory's shared Cases, Error, immutable minimal Fixture, Swift Testing wrapper and standalone executable entry. Root owns frozen production copy selection, shared package graph, PROGRESS and Git. This qualification owner owns its current private .build/af38-assets thin fixture package, artifacts and bounded Native commands; the previous private package is historical. Consume public SwiftMechanics contracts only; no @testable or production internal helper. MemoryAssetProvider is the actual provider; no custom provider fabricates data, reports invented reads/work, bypasses validation or substitutes geometry. Expected literal bytes/sources/revisions/ordered dependencies are independently authored inputs, not round-trip output or measured runtime values used as an oracle.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [AssetResolution](../../Sources/SwiftMechanics/Exchange/AssetResolution/DESIGN.md) | depends on | AssetProviding/AssetResolving/AssetCatalogReading and concrete implementations | Exact frozen producer under qualification | Original18 Swift source aggregate02a6c23e7a3a6048c172d6dc1bb615248f5f03beff6ebbe03c8197dd038c4d08; fresh Native8/public7 passed, exact current freeze below |
| [Schema](../../Sources/SwiftMechanics/Exchange/Schema/DESIGN.md) | depends on | NativeInlineAsset and SourceProvenance | Original public producer values | No physical interpretation |
| [Foundation profile](../FoundationVerification/DESIGN.md) | coordinates with | Fixed toolchain/SDK/runtime, watchdog, original stack guard | Root-selected future profile | No profile execution in this preparation |

## Architecture
```text
literal original bytes + independent expected source/revision/order/counts
 -> actual MemoryAssetProvider.read / BoundedAssetResolver.resolve
 -> public immutable catalog / nativeAssets / asset
 -> shared assertion + typed failure/address + retained work oracles
 -> Swift Testing wrappers and standalone same synchronous Cases
separate Native Task -> self cancellation -> awaited actual cancellation Case
```

## Contracts and Invariants
| Case owner | Independent falsification target |
|---|---|
| originalProviderAndExactWork | Literal [0,255,17], exact labels/source7, real single-record read has1 attempt/3 known bytes/14 charged operations; failure prefix2 consumes13 operations; actual duplicate provider ambiguity has1 read/0 bytes/11 operations |
| diamondAndNativeCatalog | A->[B,C], B/C->D, literal ten bytes across four independent sources/revisions, shuffled inventory/provider, roots[A,C], dependency-first[D,B,C,A],4 reads once/10 bytes, every original projected value and bounded lookup |
| dependencyAndMetadataRefusals | Reordered dependency declarations, changed byte/key/format/source/revision, oversized actual payload, exact Unicode identities; all typed failure, retained known reads, no catalog |
| graphAdmissionRefusals | Missing declaration/provider, duplicate roots/addresses/keys/edges, unsafe explicit path/base, unsupported format, selected cycle/depth; expected failing address and no invented traversal success |
| exactResolutionWorkAndBoundaries | Independently fixed one-record successful ledger50 resolver operations/13 metadata bytes/3 validated bytes, provider14 operations/1 read/3 bytes; exact admission boundaries and final-publication operation49 failure |
| providerAndCatalogLimits | Actual provider prefix failure, inventory/read/operations caps; tighter public catalog record/payload/dependency caps retain prior published values and perform no new provider read |
| checkedLedgerArithmetic | Public ledger overflow leaves previous counter intact; no provider is claimed to have consumed manually charged ledger utility work |
| cancelledTask (Native only) | Actual cancelled Task throws cancelled before publication/read and leaves initially zero ledgers; Task is awaited |

The single-record operation oracle counts public contract stages for the fixed one-byte address/key/format/source and three literal bytes: preflight identity/metadata16, five bounded scratch admissions5, selected-root lookup5, traversal/payload admission2, returned metadata/identity and three byte checks21, final publication1 =50. Provider oracle is attempt1 + one inventory inspection1 + two one-byte address comparisons4 + five metadata bytes5 + payload3 =14. These are fixed authored expected counts before execution; the cases never derive them from observed successful work. Exact logical storage bytes are ABI-dependent and are not guessed from a private frame layout; zero/tight caps and observed positive retained storage assert the public contract instead.

Malformed/failure helpers catch the exact typed production error inside a typed-do scope; assertion failures occur outside that scope so a missing failure cannot be disguised as success. Address equality assertions compare original UTF8, avoiding canonical Unicode aliasing. A later failed resolution is assigned to a local published variable only on success: original catalog must remain unchanged after expected failure. Resolver failure after already staged payload retains known consumed prefix but returns no partial catalog. Unexpected errors or failed assertions propagate through tests and standalone main.

## Runtime Flows
Native wrappers and standalone entry invoke the identical synchronous cases. Each invocation constructs new immutable fixtures and local ledgers. Provider and resolver protocol requirements are dispatched through public existentials where available; generic concrete resolver holds the actual MemoryAssetProvider. Standalone main prints a witness only after that complete case returns normally. Cancellation is a distinct Native test using a newly cancelled Task and checking Task.isCancelled before the public call; synchronous WASI fixtures make no Task scheduling/concurrency claim.

## State, Ownership, and Lifecycle
Fixture byte buffers/provider records are immutable Sendable values. Every ledger, result array, attempted publication and Task is case-local. No shared mutable static, file/network resource, provider retry, pointer escape or conditional storage/Sendable exists. Memory provider owners remain alive through actual calls and catalog values retain original backing afterward. The Native cancellation child Task is awaited before test completion.

## Failure, Concurrency, and Constraints
Small authored fixtures and explicit finite policies bound actual traversal/work. Synchronous cases have no external I/O or unbounded generator. Tests use suite timeLimit1 minute; future commands require the existing process-group watchdog. Root must freeze/copy exact producer/fixture sources before actual Native/ordinary WASM/Embedded qualification. Existing fixed profile uses Swift6.4.0 release, matching SDKs, Node24.19.0, setup1200s/behavior240s, jobs<=4, original131072-byte immediate stack-write guard FIRST then raw. Initial preparation created no package. The focused Native phase owns a fixture-only private package and does not assume Unicode/runtime linkage on another target without measurement. Callable qualification preparation markers remain until actual success/failure evidence closes the route.

## Verification and Change Impact
Source review must trace every expectation to an original fixture, public call and concrete failure branch. Later actual executions must match the frozen per-file SHA inventory and retain output/failure receipts; compiler success alone does not close these cases. Canonical tests can use Cases/Error/Fixture as co-located files or a support module with identical tests; standalone imports AssetResolutionQualificationSupport. Initial source-only preparation left behavior/profile gaps open. The selected Native evidence below closes only these Memory provider/catalog behavior cases; other profiles and custom external providers remain open. Custom external provider receipt violations, physical asset decoding/native model associations, browser, network/file providers and concurrent source mutation remain outside these selected Memory provider/catalog witnesses. Actual producer changes invalidate affected expectations and require focused repair/requalification under root ownership.

## Source preparation review
One comprehensive source review and focused finding recheck traced the concrete Memory provider/resolver/catalog call paths. Tightened a projection-limit matcher from alternative reasons to its case-specific expected resource/cap, and checked every projected native value against independent literal bytes/source/revision rather than only the first/last records. Added actual immutable duplicate-record ambiguity plus explicit empty/control base refusals to close the recorded lookup/base gaps. Mutable values are exclusively case-local; support-import conditional changes only fixture visibility, never storage or Sendable. No executable/profile evidence is claimed and producer18 sources remain unchanged.

## Focused Native execution contract
Root authorized only the immutable `.build/af35-sdf-qualification` pass10 reuse-freeze: each of2353 original objects plus3 module metadata files must hash-match before private copy/link and after behavior. Module SHA25675c5fcac39cd4900d2fc66d95900784027f6b30f42f3f2d343396af9133e936c and original Asset18 source inventory must match. Only fixture support/test/entry sources compile; all original producer objects link into the private dylib with no producer source compilation. Final actual Swift driver jobs4, pinned Swift6.4.0 release, Native arm64 macOS13 minimum target on the actual host/SDK, setup900s/tests60s/public120s existing process-group watchdogs apply. Explicit Swift Testing engine selection runs all8 owned tests; standalone runs the same7 synchronous cases. Strict codesign verification and actual linked-library paths are recorded, including any test runner signing limitation without resigning or claiming success. Original producers, shared build graph and Git remain untouched. Preparation markers are removed only after actual success/failure cases pass; this comment-only removal retains tests and gets a final narrow artifact refresh/behavior check if the build inputs change. Ordinary/Embedded/browser/external-provider qualification remains open.

## Selected Native behavior handoff (2026-10-05)
Original Asset18 Swift plus DESIGN stayed exactly unchanged (3fc727728132f80caab5b40b1223f95c659710102bdef4440e34daa1669764c0). All2353 pass10 original objects and3 module metadata were privately copied and individually SHA verified before link and after behavior, including the read-only SDF supplier copies. The retained SwiftMechanics module SHA is75c5fcac39cd4900d2fc66d95900784027f6b30f42f3f2d343396af9133e936c. No producer Swift source recompiled. Actual six setup drivers and the final refresh drivers end with jobs4; frontend inputs contain only owned fixture/generated runner sources.

| Native arm64 macOS27.0.1 / SDK27 / minimum target13 | Actual result |
|---|---|
| Original retained2353-object dylib link | exit0,2.24s |
| Initial five-Swift fixture-only setup | exit0,25.55s; setup900s watchdog |
| Initial8 Swift Testing cases / same7 public cases | exit0,4.10s / exit0,0.70s; tests60s/public120s watchdogs |
| Preparation markers removed | Only three comment blocks; initial bytes preserved, tests/original literal and work oracles unchanged |
| Final narrow fixture refresh | exit0,9.74s; no producer inputs |
| Final8 tests / same7 public cases | exit0,3.81s / exit0,0.60s; actual eight tests/one suite and seven witnesses observed |
| Strict signing | Actual public executable and producer dylib exit0; generated test inner executable and bundle exit1, resource-signature discrepancy retained; no resign |

The exact fixed single-record50 resolver operations/13 metadata bytes/3 validated bytes and actual provider14 operations/1 read/3 bytes passed without altered oracles. Independent diamond closure/source/revision/dependency order and read-once, original mismatch/refusal/capacity/prefix receipts, previous-catalog transaction, public arithmetic and awaited actual Native Task cancellation passed. This is behavior evidence despite the separately recorded generated runner signature limitation; strict test-runner signing is not qualified. No ordinary/Embedded/profile/browser or physical-model association evidence is inferred.

[Native receipt](../../.build/af35-asset-resolution-qualification/native-qualification-receipt.json) owns exact argv/watchdogs/artifact hashes/environment and remaining gaps. [Reuse freeze](../../.build/af35-asset-resolution-qualification/reuse-freeze.json), [after-behavior producer freeze](../../.build/af35-asset-resolution-qualification/post-behavior-producer-freeze.json), [driver proof](../../.build/af35-asset-resolution-qualification/fixture-driver-proof.json), initial/final source fixture freezes, marker-removal receipt and strict signing/load command logs retain provenance. Root owns shared registration, PROGRESS and Git. No supplier/shared source change or Git operation occurred.

## AF37.6 fresh shared Native consumer contract
Root owns the fresh common producer at `.build/af38-next-native`, selected committed `f0325b053de62da95cabacbf48ad1efd3aa7cb78` baseline2124 plus seven frozen cohort subjects129 and root SDF17: final2270 sources. The original eighteen AssetResolution sources and five fixture Swift files are frozen at `.build/af38-assets/early-source-freeze.json`; no physical interpretation, oracle, counter, tolerance or source body changes are introduced. The consumer copies only its three Support/one Tests/one public entry files and borrows the completed common source/object/module3/dylib inventory read-only before/after execution. Source18 must match producer inputs per path/SHA; all producer objects and output metadata must remain unchanged. No historical missing object/module or private cold rebuild is used.

The private thin consumer uses library/Support/public macOS13, actual Swift Testing target14, atomic `-I` joined with absolute Modules path, the single borrowed dylib with explicit -L/-l/rpath, pinned Swift6.4.0 and matching Native SDK. Neither production nor these fixtures contains Mutex/Synchronization/macOS15 availability dependencies; all mutation is exclusive operation-local ledgers/DFS/test values. Availability gates are added only for an actual published dependency, so no artificial15 restriction or passing skipped test is introduced. One additional1GiB disk baseline and4GiB global free floor applies across preparation/build/test/public, with2-second observations and reaction margins; setup900/test60/public120 process-group watchdogs and both SwiftPM Native/driver jobs4. Root grants the completed producer reader/consumer lease before compile. Actual original8/7 runtime, library bindings, source/object/module/dylib pre/post hashes and strict signing results define the Native proof. Canonical registration is root-owned; portable and physical asset/model decoding remain open.


## AF37.6 completed Native behavior (2026-10-06)
The formal common2270 read-only handoff has SHA256 `01e2ca4119bd0397a6f877d53f5a07955d3b4c00acdda4c94d33fbb752b097f1`. Its source inventory SHA256 is `0ebc4c519b31663a16411119c896a04ae6c38903fec713ecb0822a286df0d99b`, and output inventory SHA256 is `2b597dd053454774a1f2568bbb79a713ac1cadf8b4f9ba0cfa020ffa3a1df14d`. The consumer independently checked every2270 source and object plus3 metadata and the dylib before/after behavior. Its eighteen selected source inputs exactly matched the original sources per path/SHA. Source/fixture bodies and all original byte/counter/refusal oracles were unchanged.

| Actual fresh Native path | Result |
|---|---|
| Fixture-only build, Native engine, actual driver jobs4 | exit0,14.113s; setup900s watchdog |
| Original eight Swift Testing cases | exit0; actual eight tests/one suite passed in0.001s; watchdog elapsed2.026s |
| Same seven synchronous public cases | exit0,seven witness lines and terminal completion; watchdog elapsed2.031s |
| Exact counters and closure | Original50 resolver operations/13 metadata bytes/3 validated bytes, provider14 operations/1 read/3 bytes; diamond4 reads/10 bytes and dependency-first order passed |
| Refusals/publication/cancellation | Exact original typed causes, retained consumed prefixes, tighter query caps, previous catalog, checked ledger arithmetic and awaited actual Task cancellation passed |
| Link and availability | Support/public actual macOS13, Testing actual macOS14; both binaries link the same borrowed dylib and explicit rpath |
| Strict signing | Public executable and borrowed dylib exit0; strict test signature not checked in this phase |
| Immutable supplier boundary | Every common2270 source/object/3metadata/dylib SHA and original Asset18/fixture5 remained unchanged |

[Native receipt](../../.build/af38-assets/native-receipt.json), SHA256 `867297b94e58fb3e696d2923bf7954ef39262de7f6965ca913308204e3c7f717`, and [emitted consumer binding](../../.build/af38-assets/emitted-consumer-binding.json) retain original argv, actual target/job tokens, public/test library and rpath proof, tool identities, command deadlines, resource samples and artifact hashes. [Formal reader binding](../../.build/af38-assets/formal-reader-binding.json), [pre-lease](../../.build/af38-assets/read-lease-pre.json) and [post-lease](../../.build/af38-assets/read-lease-post.json) bind the producer's completed inventories. One unchanged additional1GiB baseline/global4GiB floor governed the entire thin consumer. No producer recompilation, object copy, source repair, historical missing artifact reuse, shared edit or Git mutation occurred. The reader/runtime lease was released after success.

This closes only selected Native MemoryAssetProvider/BoundedAssetResolver/catalog behavior. Root owns canonical registration and additive manifest composition. Ordinary/Embedded profiles, custom external providers, hidden format references and physical/native-model association remain open.
