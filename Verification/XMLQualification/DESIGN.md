# Isolated XML prerequisite qualification

## Purpose and Scope
Parent: [Exchange XML](../../Sources/SwiftMechanics/Exchange/XML/DESIGN.md). Children: none. IM.AF35.8 qualifies only the AF34.2 bounded XML source prerequisite. No foreign mechanics adapter or shared package graph is enabled by this work.

## Responsibilities and Boundaries
Own independent original byte/document fixtures, public protocol calls, Native focused tests, synchronous target public probe and private isolated package under `.build/af35-xml-qualification`. Root owns registration, PROGRESS, shared manifests and Git. Production XML causal repairs, if required by an original fixture, remain in the XML owner only.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [XML](../../Sources/SwiftMechanics/Exchange/XML/DESIGN.md) | depends on | XMLDocumentCoding, exact admitted subset/budgets | Sole production copied supplier | Every copied Swift source must match the frozen original SHA |
| [Foundation profile](../FoundationVerification/DESIGN.md) | coordinates with | Fixed Swift6.4.0, SDKs, watchdogs and 131072-byte stack | Reuse original operational profile | No integrated shared build/test |

## Architecture
```text
frozen original XML17 Swift sources -> byte-identical private SwiftPM copy
original fixture or manually authored document -> actual public codec witness
 -> independent expected normalized records/bytes/failure/consumed ledger
 -> Native tests/public execution + ordinary/Embedded guarded first, then raw execution
```

## Contracts and Invariants
Independent fixtures assert mixed content/comment/CDATA/UTF-8/reference/declaration/parent and original-line locations, CRLF and raw-vs-reference attribute whitespace, exact escaped writer output from manually constructed records, malformed and unsupported input, structural writer failure, budget/depth/count/overflow/cancel. A codec self round-trip alone is insufficient. Native async cancellation runs in a newly cancelled Task; synchronous WASI public runs do not claim task scheduling or parallel/cancellation-runtime semantics.

Exact toolchain: `/Users/1amageek/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swift`, compiler release6.4.0. SDK IDs: `swift-6.4.0-RELEASE_wasm` and `swift-6.4.0-RELEASE_wasm-embedded`. Node `/usr/local/bin/node`24.19.0, WASI Preview1, empty environment/preopens through original `Scripts/run_wasi.mjs`. EmbeddedUnicode, only when required by actual Unicode linkage, links matching SDK swiftUnicodeDataTables and changes no production source/isolation. SwiftPM requested four jobs (actual emitted driver arguments are retained; no measured compiler concurrency bound is claimed), setup1200s / behavior240s process-group watchdog. Preserve original linker stack reservation131072 bytes. Immediate every-stack-pointer-write guard executes before its unmodified raw artifact. No stack increase, optimized alternate code, weakened guard or oracle qualifies behavior.

## State, Ownership, and Lifecycle
Immutable fixture records, operation-local work and output values; no shared mutable fixture state. Private copies/logs/artifacts stay isolated. Test async task is awaited; no stream/background owner remains. Borrowed views retain original immutable input owners.

## Failure, Concurrency, and Constraints
Unexpected typed failure or assertion fails the public process. Invalid fixtures must throw the expected reason rather than producing placeholder documents. Record actual source/object/link/artifact provenance and executed profile scope; signatures/linkage are prerequisites, not behavior. Commands exceeding a watchdog fail qualification rather than being reinterpreted as success.

## Verification and Change Impact
Frozen-source equivalence and selected exact-profile tests/probes establish the handoff below. A concrete XML repair invalidates this selected snapshot and requires focused behavioral plus affected target renewal. Browser, other OS versions, multithread WASI, general XML conformance and foreign schemas remain outside proof.

## Qualified Selected Handoff (2026-10-05)
The original17 production Swift files remained unchanged; no production repair, shared manifest, shared test graph or Git operation was performed. `.build/af35-xml-qualification/source-freeze.json` records exact canonical/private copy SHA256 equality. `qualified-provenance.json` freezes compiler SwiftFileList equality for all17 sources on all3 profiles, object hashes, original linked artifacts and link response records, exact driver/frontend/SDK/Node identities and immediate guard coverage. SHA256 of that provenance record: `320a3b66ecb2a5e3bc41ea5f21bb00159c0c720c329895e4963615b28290267c`.

| Profile | Actual evidence | Selected gap |
|---|---|---|
| Native arm64 macOS27.0.1 | Build17.95s; original8 focused tests/1suite passed; one additional original public failure-work-receipt case passed without changed production/support/probe; strict codesign-verified public process exit0 | None for these9 cases and selected synchronous public fixtures |
| Ordinary Swift6.4.0 WASM SDK | Build10.38s; immediate131072-byte guard FIRST exit0, then unchanged raw process exit0; every public fixture witness reached | None for selected synchronous WASI path |
| Embedded matching SDK + EmbeddedUnicode | Build13.97s; immediate131072-byte guard FIRST exit0, then unchanged raw process exit0; every public fixture witness reached | None for selected synchronous WASI path |

Ordinary initial stack pointer1356336/lower1225264; all18069 instruction-decoded `global.set 0` writes received the immediate original-bound guard, with no other global writes. Embedded initial176736/lower45664; all567 decoded writes guarded. Both original raw artifact hashes and diagnostic copy hashes are separate in provenance. No enlarged stack, relaxed oracle, alternative XML implementation, runtime source substitution or conditional isolation supplies proof. Embedded compilation actually uses matching SDK Embedded/WMO/Concurrency plus Unicode data tables; Native/ordinary omit the Unicode trait and production sources remain identical.

Logs are under `.build/af35-xml-qualification`: `native-build.log`, `native-tests.log`, `native-public.log`, `native-receipt-{build,test}.log`, `{wasm,embedded}-build.log`, `{wasm,embedded}-guard-{generation,runtime}.log`, `{wasm,embedded}-raw-runtime.log`, and guard coverage JSON. Setup1200s/behavior240s process-group watchdogs and4jobs were retained. Stack-write coverage disassembly supplements actual guarded/raw execution; it does not replace behavioral fixtures.

### Canonical fixture composition
The actual package registers one test target, MechanicsXMLTests, from this directory with co-located XMLQualificationCases.swift, XMLQualificationError.swift and XMLQualificationTests.swift, dependency SwiftMechanics. DESIGN.md and standalone XMLQualification.swift are excluded from that test target. The isolated package alone owns its support/executable targets. Identical test bodies call the canonical module; the test-only support import is conditional, and @testable is solely for the owned checked-arithmetic primitive. Every mutable work value is local; tests have no shared resources.

Canonical setup uses the exact release binary and process-group watchdog: `python3 Scripts/run_with_timeout.py 1200 <pinned-swift> build --build-tests -j 4`. Focused execution uses `python3 Scripts/run_with_timeout.py 60 <pinned-swift> test --skip-build --disable-xctest --enable-swift-testing --filter XMLQualificationTests -j 4`, with the private canonical build path. Unchanged standalone source behavior and exact target premises permit reuse of the guard-first ordinary/Embedded evidence.

## Canonical composition handoff

Root registers XML in the actual SwiftMechanics module and the existing fixture files as MechanicsXMLTests. Test-only conditional support import allows the identical test bodies to run with co-located canonical fixtures or the isolated support module; no production branch changes. Canonical Native build passed in359.79s; explicit Swift Testing-only execution passed all9 tests/1suite in0.012s, process exit0, with a60s watchdog. The first combined-library invocation emitted no output and hit its60s watchdog before any test result; this failure is retained in canonical-native-tests.log, and no XML behavior is inferred from it. Selecting the actual Swift Testing library completed the owned test path; unrelated XCTest discovery is outside this XML qualification. Logs: canonical-native-build.log and canonical-native-swift-testing.log under the existing private evidence directory. Exact-source standalone target evidence remains valid. The current root has other unqualified excluded sources and an unrelated pending Machines context change; this handoff owns only XML behavior and test registration.

Canonical source annotation changes only the BoundedXMLCodec documentation sentence from pending qualification to the child evidence reference. No executable declaration, statement, fixture or budget changed; the retained exact-source profile evidence applies to the unchanged behavior.
