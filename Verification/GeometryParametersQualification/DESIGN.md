# Geometry parameter qualification

## Purpose and Scope
Own independent behavioral witnesses for [GeometryParameters](../../Sources/SwiftMechanics/Analysis/Derivatives/GeometryParameters/DESIGN.md). Parent: [Verification](../DESIGN.md). No children. Production23 is source-frozen and unqualified; fixture preparation is not execution evidence. Root owns target registration and integration.

## Responsibilities and Boundaries
Exercise the public GeometryParameterDifferentiating requirement against the exact original2363 supplier closure. Construct real spatial KinematicTree records with fixed root and scalar fixed/revolute/prismatic/screw charts. q, v, acceleration and physical time remain identical during geometric perturbations. No new production algorithm, inferred CAD map, dynamics claim or physical fallback is introduced.

## Related Designs
| Design | Relationship | Contract used | Cautions |
| --- | --- | --- | --- |
| [GeometryParameters](../../Sources/SwiftMechanics/Analysis/Derivatives/GeometryParameters/DESIGN.md) | used by | Public source/chart/policy/direction/product and typed failures | Consistency residuals are not derivative accuracy oracles |
| [ArticulatedTrees](../../Sources/SwiftMechanics/Modeling/Joints/ArticulatedTrees/DESIGN.md) | depends on | Original tree constructor/evaluator/snapshot columns | Fixed revision, world and frame identities |
| [JointManifolds](../../Sources/SwiftMechanics/Modeling/Joints/JointManifolds/DESIGN.md) | depends on | Original normalized scalar axes and motion | No internal generator/pose helpers |
| [ScalarCalculus](../../Sources/SwiftMechanics/Analysis/Derivatives/ScalarCalculus/DESIGN.md) | depends on | Explicit supplier call ledger | Invocation count does not invent supplier arithmetic |

## Architecture
```text
actual public body/joint/tree records + SI state + explicit source charts
  -> public analytic direction -> returned pose/motion/J/bias directions
  -> independently rebuilt +/- chart trees -> original primal evaluator
  -> fixed central differences and literal physical vectors/matrices
  -> assertion or typed qualification failure
```

## Contracts and Invariants
Each shared case calls the public protocol requirement. The independent finite-difference oracle rebuilds complete public trees at h=1e-5 and h=5e-6 with no analytic jet helper, holds state fixed and compares every body/frame translation, matrix, velocity, acceleration, original geometric column, prescribed drift and acceleration bias. Component tolerance is fixed at absolute2e-7 plus relative2e-6. Literal vector/matrix witnesses use absolute2e-10 plus relative2e-10. Active R maps local coordinates into the parent/world; rotation perturbations multiply the original quaternion on the right. Root and both anchors have distinct nonidentity rotations and offsets. Raw-axis perturbations change the original nonunit vector before public normalization. Coordinate-rate derivatives remain exactly zero and original source identities/state are retained.

| Shared case | Independent rejection criterion |
| --- | --- |
| rootTranslation | Literal world translation and zero rotation/motion/J/bias directions, including additive same-target bindings |
| rootRotation | Literal R*hat(eta) at root plus all-field central differences in a moving scalar chain |
| parentAnchor | Combined parent translation/right-rotation at nonidentity placement, all-field differences |
| childAnchor | Combined inverse-child placement translation/right-rotation, all-field differences |
| rawAxes | Revolute/prismatic/screw normalized raw-axis derivatives and literal transverse derivative |
| sourceRefusals | Stale revision/provenance, wrong frame/chart, duplicate ID, invalid shape/direction, topology and unit mismatch refuse |
| exactWorkAndCancellation | Seeded cumulative operations/storage/calls, exact replay bounds, one-short refusal, caller cancellation before/after supplier, no publication |
| domainsAndSupplierFailure | Fixed-joint success; moving anchor/floating root/multi-axis refusal; actual joint nonfinite scaling preserves failed supplier call ledger |

Native adds one actually cancelled Task calling the same public requirement. Success cases include nonzero v/a to expose centrifugal/Coriolis/bias errors. Source/oracle/tolerance changes require matching affected evidence. No helper compares an analytic product to itself to claim accuracy.

## State, Ownership, and Lifecycle
Sources, fixtures and outputs are immutable Sendable values; temporary original trees and snapshots are local. The synchronous cancellation witness owns Mutex<Int> with identical Native/WASM/Embedded declaration/access. No shared mutable counter uses a raw/no-op platform branch. Its Apple availability is explicit macOS15/iOS18/tvOS18/watchOS11; the producer remains macOS13 and shared tests use a guarded available witness. No I/O or supplier callback executes under the lock.

## Failure, Concurrency, and Constraints
Qualification assertions are typed errors; underlying supplier failures are propagated. Refusal fixtures check concrete original error cases and consumed ledgers rather than swallowing errors. Geometry bound tests retain the production scalar reservation formula and seeded counters. Eight shared cases execute sequentially in the public executable; Native tests share no mutable fixture. Runtime Task cancellation is Native only and does not establish WASI parallelism.

## Verification and Change Impact
Preparation only: no compile/link/runtime performed until root NativeB grant. Consumer will hash-bind immutable original2363 sources/objects/metadata, production23 and final fixtures, then direct-link one private dylib without source/object duplication or cold producer. Additional private growth128MiB, free floor768MiB, jobs4 and process-group deadlines apply. Original qualified lower APIs are retained; latest unrelated AF31/source-only overlays are not used. Compile-only2363 evidence cannot qualify these derivatives. Ordinary/Embedded and canonical registration remain separate root-owned evidence after real Native success.

### Selected Native execution
The granted NativeB run linked exactly the immutable2363 objects once and compiled only seven fixture files. Production23 and all150 selected lower-family source bindings matched the original source bytes before/after; no production change or replacement producer was required. The final matching freeze is `6119b1bc9c149e860b37d18fac2e9779354a47711abb2db638b12d75b5da748e`; final fixture aggregate (sorted basename, NUL, contents, NUL) is `2d3ac3934b84c6ff648748334a2e1982019da631e7c57058c5674177167068e7`.

All nine Native tests passed, including actual cancelled-Task refusal, and all eight shared public cases passed. Original case bodies, input models, central-difference steps, literal oracles and tolerances remained fixed. Two fixture findings were corrected: the body mode spelling was aligned with the published prescribedKinematic case; the Native cancellation fixture moved source/policy/seeded ledger construction before cancelling its Task so the public derivative call actually observed cancellation. The initial compile failure and the earlier eight-pass/one-fail runtime log are retained. A receipt-parser finding was corrected to match the pinned SwiftTesting summary and independently count nine named passing tests; no behavioral rerun was used for that parser correction.

| Evidence | Actual result |
| --- | --- |
| Original object link | exit0, 0.376 seconds |
| Final fixture-only incremental build | exit0, 1.398 seconds, jobs4 |
| Final nine-test runtime | exit0, 0.416 seconds |
| Eight-case public runtime | exit0, 0.309 seconds |
| Recorded owner allocation through execution | 112615424 bytes; entire owner counted cumulatively, no reset |
| Execution-end global free bytes | 1309102080; original768MiB floor retained |

[Matched final generation proof](../../.build/af35-geometry-parameters-qualification/consumer/native-final-matched-generation-proof.json), SHA-256 `4eefd9bc619e9e26fd36e1e1e03bf458192e2d44e8cc420df545091c8f33f896`, owns exact final source/output-map/object bindings, real compiler argv and link/runtime/resource evidence. [Native execution receipt](../../.build/af35-geometry-parameters-qualification/consumer/native-final-receipt.json), SHA-256 `6e1d0ff4e1fc7950ec25598eabd1a6b1b4955d7c767afb746d62b2cfd27467ee`, binds the original module, private dylib and public artifact. Original producer and public/support compilation use macOS13; the pinned SwiftTesting target/runner actually emit macOS14. The same Mutex counter requires the explicitly guarded macOS15 availability. Generic receipt consumerTarget13 denotes the requested package/public baseline, not every emitted test target; actual argv and the matched-generation proof retain that distinction. The native backend deprecation warning is retained. These are selected Native physical/source/failure/work witnesses, not canonical registration, WASM/Embedded behavior or parallel WASI qualification. Document evidence is frozen separately after execution; earlier source/fixture/receipt freezes remain intact.

### Canonical Native registration
Root registered the complete committed Field1960 graph from `711cdb5d190b569a52f299e691552e6755a577cc` plus the unchanged Geometry23 sources, for 1983 production sources. The frozen source inventory is `d875ffea997ec5461afe3891d1f81819597a17f5f56a1c157dc27b2806fa20a5`; all seven fixture files retained the selected Native generation and aggregate above. All23 added primaries were actually emitted, the complete source list matched the freeze, and original nine tests and eight public cases passed. Source, module and object hashes remained unchanged after runtime. No production, input, oracle, tolerance or fixture changes were required.

[Canonical Native receipt](../../.build/af35-geometry-parameters-qualification/registration/canonical-native-receipt.json), SHA-256 `d15384a6a0090e11a64f8c75078b855b061068c1d3c4cf737f2d1c8f82a0ff9b`, binds the actual complete graph, emitted primaries, test/public links and execution. [Canonical production object inventory](../../.build/af35-geometry-parameters-qualification/registration/canonical-production-object-inventory.json), SHA-256 `0f15aefd3c239249b6831aa4785a85718117473289cfacb0caaee609561e4370`, owns per-source object and module metadata bindings. The actual jobs4 incremental build took 18.148 seconds; the nine-test runtime took 2.133 seconds and the eight-case public runtime took 0.478 seconds, all exit0. The producer/public target remained macOS13; actual pinned SwiftTesting availability is recorded separately, and the same logical Mutex witness remains guarded for macOS15. One cumulative128MiB allocation envelope and768MiB global free floor applied; the receipt records2-second resource observations and explicitly leaves between-sample peaks unmeasured. Ordinary and Embedded behavior remain unexecuted by this registration proof.
