# Selected triangle-mesh behavioral qualification

## Purpose and Scope
Parent: [Verification](../DESIGN.md). Children: none. Own independent public behavioral evidence for [TriangleMeshes](../../Sources/SwiftMechanics/Physics/Collision/TriangleMeshes/DESIGN.md): unsigned point/nearest ray, original feature and barycentric attribution, outward tetrahedral signed distance, conservative world bounds, immutable refit and translating sphere CCD. Native proof is local to the frozen executed producer. General signed-volume, tangency and rotating CCD remain outside this selected success domain.

## Responsibilities and Boundaries
Own shared synchronous Cases, finite original fixtures, typed assertion errors, SwiftTesting adapter and standalone executable. Use only original public constructors and any TriangleMeshQuerying with HierarchicalTriangleMeshQueries; no internal triangle/BVH helpers or synthetic witnesses. The fresh common producer source/object/module/library authority is verified before and after direct prebuilt-library reuse; missing old2363 artifacts are not current evidence. The narrow package compiles fixture source only. Root owns parent registration, integration, resource leases, shared package/progress and Git.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Verification](../DESIGN.md) | parent | Focused bounded command execution | Integration owner | Registration root-owned |
| [TriangleMeshes](../../Sources/SwiftMechanics/Physics/Collision/TriangleMeshes/DESIGN.md) | depends on | TriangleMesh admission/refit and TriangleMeshQuerying | Actual subject | Original19 source must match linked module |
| [Shapes](../../Sources/SwiftMechanics/Physics/Collision/Shapes/DESIGN.md) | depends on | IDs, sphere proxy, policies and CollisionWork | Original inputs/work | Exclusive local ledgers |
| [Sweep](../../Sources/SwiftMechanics/Physics/Collision/Sweep/DESIGN.md) | depends on | CollisionSweep linear translation | Sphere trajectory | Rotations refused |

## Architecture
```text
literal original vertices/faces/IDs/provenance and public sphere trajectory
 -> public mesh admission/refit and HierarchicalTriangleMeshQueries
 -> original point/ray/contact/TOI records
 -> shared independent coordinate/feature/work/failure assertions
    -> SwiftTesting plus awaited Native cancellation
    -> standalone identical synchronous witness records
```

## Contracts and Invariants
| Case | Independent oracle |
|---|---|
| Point features and transform | Triangle (0,0,0),(2,0,0),(0,2,0): manufactured face/edge/vertex points, literal barycentrics/distances/normals and world transform |
| Hierarchy/ray ordering | Original separated faces and seam ties; nearest face ID independent of inventory order; true plane/coplanar misses; original reconstruction and bounds enclosure |
| Signed domain | Four independently outward-oriented tetrahedron faces: negative inside, positive outside, exact boundary convention; uncertifiable near band and non-tetra solid refusal |
| Refit/lifetime | New plane height/source/geometry revision, original connectivity/feature IDs preserved; retained old mesh/result/source remain unchanged; caller array mutation cannot mutate snapshot |
| Sphere advance | Literal face/edge/vertex impacts and positive/nonpositive original bracket; high-speed and moving-mesh relative motion; initial overlap and actual all-face miss |
| Exact work/capacity | Single triangle admission1624, point1096, ray hit2120/miss2112, refit1496, bounds2048; peak1200 scalar slots and19 retained records; refused charges retain counters |
| Typed refusals | Degenerate/nonmanifold/invalid identity/source/frame/fidelity, ray ambiguity, tangency, rotating/unsupported shape sweep, later refit failure and capacity errors |
| Native cancellation | Actual Task cancelled and awaited; mesh/refit/query refuse transactionally with zero new consumed work |

Coordinates and residuals use explicit1e-8 assertion tolerance, with policy absolute1e-9 and relative1e-10 at reference length1. IDs/features/order/counts/source and work are exact. The point/ray reference is independent literal geometry rather than a producer self round trip. A ray API returns one nearest original hit, not an invented all-hit catalog. Tetrahedron success does not certify arbitrary manifold solid interiors. A successful CCD upper record must reconstruct original sphere-to-mesh separation with positive lower and nonpositive upper values within explicit maximum time width.

## Runtime Flows
Prepare and review once before execution. Verify formal common producer receipts and individual source/object/module/library bytes before/after direct borrowed use. Consumer compiles only support3/test1/public1 through joined `-I<Modules>` and `-L/-lSwiftMechanics/rpath`; it copies no producer source or object and builds no SwiftMechanics target. Pinned Swift6.4.0 release/MacOSX27.0 SDK; actual support/public macOS13 and Swift Testing target/runner macOS14 are recorded from emitted drivers. Host runtime evidence does not claim a macOS13 deployment run. Jobs4 and process-group watchdogs bound build900/tests120/public120 seconds. Additional thin allocation has one fixed1GiB cap/global4GiB free floor with2s samples/maximum5s. No compiler runs before formal root lease and matching source19 admission. Portable compile/link/runtime and full131072 original guard remain separate pending qualification.

## State, Ownership, and Lifecycle
All factory/results are immutable values and each case owns local exclusive CollisionWork. No shared mutable fixture state, unsafe pointer, unchecked Sendable, callback or target-specific synchronization exists. Returned geometry retains original arrays and provenance. Refit creates a new snapshot, and caller publication changes only after a complete successful return. Cancellation is exercised through an awaited Native Task independently of standalone synchronous cases.

## Failure, Concurrency, and Constraints
Typed TriangleMeshError and original CollisionError causes are asserted without swallowing unexpected errors. A producer defect must have an actual counterexample, owned DESIGN/source correction and fresh matching producer module coordinated with its compiler owner. Old modules cannot qualify repaired source. No silent truncation, fake feature/TOI, tangency fallback or filesystem asset lookup is introduced. Fixture preparation markers remain until actual selected success/failure evidence exists.

## Verification and Change Impact
Cases is the single synchronous oracle owner, shared by Tests and standalone. Supplier/source changes invalidate affected evidence. Unrelated module composition differences are recorded explicitly and cannot justify latest-graph claims. Historical Native2363 module689c2037c5dc386fc2f19188202b892c04e7eada9b3428248f66bb1dbef1b85f executed original8 tests and same public7 successfully, with no producer repair or literal oracle correction. Those earlier `.build` objects/metadata/receipts were subsequently lost; this prose is historical and cannot qualify current source or a new common graph. Original19 executable source and fixture5 are now frozen for fresh Native proof. The immutable first freeze .build/af38-triangle/initial-source-freeze.json SHA8b186e2b2ad584eb22f00830509a4beb0ce4b89c41a735d792f543bf51c3d508 records production aggregate32ce85ace943b0a3e70d4ec70c0e9f3f34f577aa213c7cde3767444e062a9ebf and fixture aggregatef1f60a5995de1eb3694e50f8c1d465b3f13d4a99b623c15f2e55d5b529dc3cef using sorted repository-relative path UTF8/NUL/original bytes/NUL. No source/fixture/physics/tolerance/work edit has been made during AF37.1 preparation. The selected concrete feature/BVH/refit/ray/CCD paths and immediate CollisionWork/policy/sweep dependencies were read; current selection remains a runtime obligation, not a type/structure success claim.

Root owns one common producer from committed f0325b053de62da95cabacbf48ad1efd3aa7cb78 and seven independently frozen cohorts. Taskspace owns its generation and reader handoff. The formal common2270 source/object/metadata/dylib handoff and root thin lease admitted the original8 tests and unchanged7 public witnesses against one borrowed dylib. Actual Native results are recorded below. A concrete counterexample will retain RED, require owned DESIGN-first causal source correction and a new matching producer before affected retest. Signed/tangency/rotation boundaries and existing incomplete marker remain. Root applies the minimal additive registration candidate to its actual later HEAD; private fixed-base candidate itself is not registration or integration proof. Portable profiles and general signed-volume/rotation/tangency success remain open.

### Fresh AF38 Native selected behavior
Formal immutable common2270 [handoff](../../.build/af38-next-native/handoff.json) SHA01e2ca4119bd0397a6f877d53f5a07955d3b4c00acdda4c94d33fbb752b097f1 binds committed baseline2124 atf0325b053de62da95cabacbf48ad1efd3aa7cb78 plus eight independently frozen cohorts. Producer source inventory SHA0ebc4c519b31663a16411119c896a04ae6c38903fec713ecb0822a286df0d99b and output inventory SHA2b597dd053454774a1f2568bbb79a713ac1cadf8b4f9ba0cfa020ffa3a1df14d map all2270 original source/object pairs and metadata3/dylib. This composition is a frozen common graph, not a later full HEAD claim. No missing old2363 evidence was reused.

[Fresh Native receipt](../../.build/af38-triangle/native-receipt.json) SHA00323f276a1d4eb840c0b18367d6c1a6d8a2a440eb0d730487d70e3ca0ce9e1b records fixture-only build11.957s, original8 tests1.986s and same public7 .257s, all exit0. No first-run failure, source/fixture correction, physical oracle change, tolerance change or work-ledger change occurred. Feature/BVH/refit/nearest-ray/tetrahedron/sphere-CCD success and original typed refusals/work prefixes/cancellation executed through original public requirements. All2270 source/object hashes and module metadata3/library matched before and after runtime. Consumer rebuilt no SwiftMechanics target, duplicated no producer objects and used one actual linked dylib SHA8c349c725804d5f37ccb77c211d522615def9bbefd23dba2aacb79ad65b4da0d.

Actual final jobs4 drivers retain macOS13 support/public and macOS14 Swift Testing target/runner, with MacOSX27 SDK and pinned6.4 release. Original fixtures have no Mutex15 dependency or suite availability annotation. The single thin baseline records maximum sampled additional51,810,304B <1GiB and minimum free169,483,792,384B >4GiB; sampled values do not claim unsampled peaks. Build900/tests120/public120 deadlines and2s/max5s sampling were retained. Reader/runtime lease was released immediately; other common producer readers remain independent.

This qualifies only the declared selected original triangle Native query domain. General signed-solid volume, tangent/rotating CCD success, portable profiles, Runtime acceptance and later root union remain outside this evidence. Existing rotating-CCD incomplete marker/typed failure remains. Root owns subsequent shared target/index/Git registration; the f0325b0-based additive private candidate records product/support/test names without changing shared files.
