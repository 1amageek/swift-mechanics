# Selected heightfield query qualification

## Purpose and Scope
Parent subject: [Heightfields](../../Sources/SwiftMechanics/Physics/Collision/Heightfields/DESIGN.md). Children: none. Own independent public fixtures, shared synchronous witnesses and focused Native Swift Testing for CL-002/008/010. Root owns canonical registration, profile leases, integration and Git.

## Responsibilities and Boundaries
Exercise actual GridHeightfield admission/refit and HeightfieldQuerying closest/ray/overlap/bounds/refusal paths using qualified Core/Model/Collision inputs. Independently authored scalar coordinates and equations are the oracle. No internal triangulator, interval helper, substitute geometry supplier or custom physics engine is used by fixtures. Source approximation provenance is distinct from exact distance to the supplied open triangle surface.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Heightfields](../../Sources/SwiftMechanics/Physics/Collision/Heightfields/DESIGN.md) | subject | GridHeightfield, HeightfieldQuerying | Original grid triangles and typed failures | No signed-volume claim |
| [Shapes](../../Sources/SwiftMechanics/Physics/Collision/Shapes/DESIGN.md) | depends on | CollisionProxy/Work/Policy | Supplied sphere and resource authority | No invented wall mass |
| [Geometry](../../Sources/SwiftMechanics/Physics/Collision/Geometry/DESIGN.md) | depends on | CollisionRay/Bounds | SI finite ray and conservative bounds | Original all-face rejection required |

## Architecture
```text
hand-derived terrain heights + explicit identity/provenance/budget
 -> actual public grid admission -> protocol query
 -> independent feature/barycentric/point/normal/distance assertions
 -> shared synchronous cases -> public executable and focused Native tests
historical2363 failure -> H1/H2 source repair -> historical2353 proof
fresh committed2124 + frozen cohorts -> matching original Heightfields22
 -> thin fixture-only consumer -> original unchanged runtime oracles
```

## Contracts and Invariants
The fixed selected proof consists of seven synchronous groups and one Native task cancellation case. Flat unit-square triangles prove face, original boundary edge, original vertex, below-surface unsigned distance, zero-distance normal and exact diagonal tie order. The slope `z=x` has an independently projected point `(0.5,0.25,0.5)`, normal `(-1,0,1)/sqrt(2)` and distance `sqrt(0.5)`; transformed coordinates use a right-angle rotation and supplied translation. A saddle with heights `[0,0,0,1]` has center ray height0.5 for lower-left/upper-right and0 for the opposite diagonal.

Finite ray cases assert both-sided hits, coplanar first entry, original seam ties, origin/endpoint hits and misses from same-side planes, outside barycentric footprint, root outside range and coplanar separation. These misses must traverse both original faces through their interval rejection path; insufficient operations must fail rather than return nil. Near-plane and near-endpoint unresolved bands explicitly refuse. No broad tangency or moving-surface claim follows.

Sphere cases independently compute radius plus margin and surface clearance, both boundary points and their balance, above/below normal direction, exact touching, intersection and ambiguous near-zero clearance. Approximation sum and measured triangle edge resolution are checked as fidelity admission, not replaced by numerical residuals. Refit requires a deforming snapshot, new source/geometry revisions and the same source key; old witnesses and heights remain owned immutable originals, and old reference use on the new snapshot fails.

Capacity/identity/admission cases cover malformed shape/count/coordinate collapse, numerical triangle rank refusal, stale source/frame, forbidden static move/dynamic/signed/non-sphere branches, and exact typed storage/record/operation failures with cumulative consumed work. Native cancellation checks actual GridHeightfield admission and closest/ray/overlap/bounds/refit/signed paths after cancellation. The synchronous executable omits Task cancellation and does not claim WASI behavior.

## Runtime Flows
Every case owns local inputs and work. Assert the exact selected failure kind and never accept any failure as equivalent. Stable fixture bytes are copied into private support/test/public targets. Before and after runtime, every retained production object and module metadata hash is checked, and subject Swift bytes are compared to their producer inventory. Supplier source defects invalidate the matching module and require root coordination; fixture compiler repairs must preserve original equations and assertions.

## State, Ownership, and Lifecycle
Fixtures have no shared mutable state, I/O, persistent handles, streams or unsafe buffers. Immutable Sendable values and operation-exclusive work are identical across targets. Native cancellation awaits its cancelled task. Test-only conditional import selects co-located/private support composition without changing production ownership or isolation.

## Failure, Concurrency, and Constraints
Fixture budgets are explicit sufficient inputs, not production defaults or performance claims. Build/link/runtime commands use watchdogs and effective jobs4. Existing ordered heavy-profile leases are preserved: the current AF37 phase reads a fresh root-owned common producer and compiles only original fixture5. Earlier2363/2353 artifacts are historical and unavailable; they are not current binding evidence. No owner cold production compiler or portable profile is launched. Compiler, linker, strict signature inspection and behavior evidence remain separate; no failed strict signature is relabeled successful.

## Verification and Change Impact
One source review and concrete causal repair rechecks converge this fixture snapshot. The original2363 runtime passed seven of eight tests and refused the coplanar miss at `origin=(-1,2,0), direction=+X, maximum=3` as ambiguous. H1 affine endpoint enclosures alone retained that failure. H2's necessary barycentric upper bound of one rejected the same original triangles, without changing numerical tolerances or fixture oracles. Earlier source/object/binary/log receipts are historical context; the prior `.build` products were lost and are not reused as current evidence.

Root-authorized coherent H2 Native2353 outputs were individually verified, privately linked, and executed using pinned Swift6.4.0, arm64 macOS and effective jobs4. The original failed group passed, final eight Swift Testing cases passed, and seven unchanged shared public groups passed. Every2353 object and three module metadata files, subject Swift bytes and five fixture bytes were verified before and after execution. Retained public module/doc bytes are valid for this internal noninlinable body change; the changed object and sourceinfo bind the new source. The public and test binaries' recorded load paths select the fresh H2 library. Strict library/public executable signatures pass; strict inspection of the generated test inner binary reports the existing resource-signature mismatch and is not relabeled successful. The historical private receipt `c21a18d904ef567bc228cb888ff928f703ff6f8588abab86d632b99de86e44de` is not available in the fresh workspace and grants no current source/object/module binding.

Ordinary/Embedded profiles and root integration remain separate, and baseline membership is not qualification. Changes to triangle semantics, tolerances, identity/refit, rejection certificates or supplier bytes invalidate affected behavioral receipts.

## Historical Portability Source Preparation Premises
Earlier private profile preparation used the same committed export `4d16dfdeed329eb425f8f54dc171793903bc55e5` and inventory `6ce46bfe113b64f48957d91d9d49d259ab85ce1dc2b5e1f224e16f2cd0e1d25c` selected by root for SDF. That preparation selected baseline1562 plus frozen Heightfields22, yielding1584 sources. The earlier private products are unavailable and this historical graph is not current portable evidence. A future profile owner must bind its actual source inventory and target-specific runtime anew. Copy the five original fixtures into separate support/public/test targets without modifying their oracle. Per-file and aggregate hashes record the exact graph; Native fixture behavior and each target's actual compiler/file list/runtime are separately owned proof. Preparation never launches a cold profile, decoder or compiler while the ordered resource leases are held.

## AF37 Fresh Native Preparation
Current execution authority is root's common producer from committed `f0325b053de62da95cabacbf48ad1efd3aa7cb78` (2124 sources) plus the seven frozen cohorts. The individual additive Heightfields registration candidate admits only Heightfields22 and its original Support3/Tests1/Public1: 2146 registered sources before other cohort registrations. It adds the DESIGN exclusion and target wiring; root alone applies its delta to the live manifest and owns the commit. Neither this candidate nor preparation establishes runtime qualification.

Freeze `.build/af38-heightfields/subject-source-freeze.json`, SHA-256 `6b04f7a9dc60e654a513dc2ad3b5eee01cb6e42b837e6f9345abd89fce9dfed3`, binds all original22 production and five fixture Swift files. Aggregates use sorted relative path, a space, SHA-256 and newline: production `1104637ac17c0a6bebac4cfaf6c6ad8e010bc5e0678dda4d9bec3300cf8bdec9`, fixtures `ce7209c194673d3520bd22c58fbbbb08b1b38b6064a29bdf639ba112bf438aec`. Source, equations, work charges, ray certificate, numerical tolerances and original assertions remain unchanged.

The thin consumer uses attached `-I<module-directory>`, original `-L/-lSwiftMechanics` and rpath, with no production target, object copies or provider rebuild. Actual Support/Public code generation remains macOS13, Testing/generated runner14; body-guarded APIs requiring macOS15 must retain that actual availability if encountered, rather than raising or weakening production contracts. Current fixtures contain no Mutex or such body guard. Build/test/public execute with pinned Swift6.4.0, effective jobs4 and process-group watchdogs (build/test120s, public60s). Consumer cumulative allocation cap1GiB and global free floor4GiB are sampled every2s; resource/deadline failure terminates the owned group and publishes no GREEN receipt. Matching common-producer source/object/module/library hashes must be checked before and after the one original8 Native tests and seven synchronous public cases; actual Task cancellation remains Native-only.

| Logical state | Native source | Ordinary WASM source | Embedded source | Qualification limit |
|---|---|---|---|---|
| Grid/identity/witness | Immutable Sendable owned values and CoW backing | Same declaration | Same declaration | Runtime profiles remain separate |
| Query workspace and CollisionWork | Exclusive local values / inout entry | Same entry | Same entry | No shared mutable cache or target isolation branch |
| Cancellation | Original CollisionWork Task check; awaited Native test | No inference from Native | No inference from Native | Actual target behavior required |
| Fixture composition | Optional support import only | No production state change | No production state change | No concurrency or portable promise from conditional import |

A focused original-source review traced actual admission, closest stationary/boundary minima and original KKT, full-face ray rejection, outward affine endpoint bounds, overlap radius/margin and original balance, immutable refit and cumulative failure work. Dynamic concavity, non-sphere overlap and signed-solid distance remain immediately marked typed refusals. No concrete contract defect was identified in this fixed path; no production source changed. Fresh matching Native8/public7 and source/object/link proof now pass on the common2270 producer described below. No source change was necessary.

## AF37 Fresh Native Behavioral Evidence
Root's immutable common producer is actual2270 (committed2124 plus eight selected subjects146), preserving Hydraulic13. Handoff `.build/af38-next-native/handoff.json`, SHA-256 `01e2ca4119bd0397a6f877d53f5a07955d3b4c00acdda4c94d33fbb752b097f1`, binds source freeze `0ebc4c519b31663a16411119c896a04ae6c38903fec713ecb0822a286df0d99b`, output inventory `2b597dd053454774a1f2568bbb79a713ac1cadf8b4f9ba0cfa020ffa3a1df14d` and producer-final receipt `2d44c7d4237b5ef30136ec5763c27af0731626989d0d1962a001ae0a25ce7b18`. Producer compilation alone was not reused as behavioral evidence.

Fresh thin execution `.build/af38-heightfields/native-qualification-receipt.json`, SHA-256 `a75c537784635fc2a3f08152ebc7f1fa67ed13cd40003786a02f4143a2d03802`, establishes original Native8 tests and seven synchronous public groups. Original22 production and fixture5 hashes match the subject freeze, matching compiled source and actual emitted object bindings. All2270 production source/object, three metadata files and dylib hashes were checked before and after. This consumer contains no production target, borrows original module/library directly and copies only fixture5. No source, equation, numerical tolerance, work charge, failure contract or oracle changed to obtain GREEN.

| Evidence | Actual result and limit |
|---|---|
| Fixture-only build | GREEN, 11.952 seconds; all emitted final drivers jobs4 |
| Original Native8 | GREEN, 1.969 seconds; seven synchronous groups plus actual awaited cancelled Task admission/query/refit paths |
| Original public7 | GREEN, 0.545 seconds; exact original seven success lines; no Task cancellation/portable inference |
| Repaired coplanar miss | Original `(-1,2,0)`, +X, maximum3 returns certified full-face miss; endpoint outward lower/upper barycentric rejection and original work assertions unchanged |
| Geometry/failure coverage | Original flat/sloping and transformed face/edge/vertex/seam witnesses, both diagonals, two-sided/coplanar/boundary/finite ray behavior, sphere margin/clearance/fidelity, immutable refit/source, typed admission/ambiguity/resource/refusal paths |
| Module / original dylib | SHA-256 `8988baac33d5a40334a0e5c8560f3c962e153fb494a1af9997d75ca314c117ae` / `8c349c725804d5f37ccb77c211d522615def9bbefd23dba2aacb79ad65b4da0d` |
| Fixture source/object/link | `.build/af38-heightfields/source-object-link-inspection.json`, SHA-256 `c3ec394c9df2563a638780477704497d9f4c603e915cbd53679a3554865535fc`; original5 emitted objects, actual driver argv and test/public external dylib links |
| Compiler / target | Pinned Swift6.4.0 release directory and MacOSX27.0.sdk; effective final Support/Public codegen13, Testing/generated runner and final links14; producer13. Current-host execution does not certify macOS13 runtime deployment |
| Resource / deadlines | Build/test120s, public60s, inspection30s; repository watchdog and owned process-tree termination; cumulative1GiB consumer cap/free4GiB floor sampled every2s. Observed maximum new allocation50892800 bytes/minimum free169484025856 bytes; samples are not an unsampled peak or old128MiB claim |
| Strict signatures | Public executable and producer library exit0. Generated test bundle and inner binary exit1: resource signature indicates resources that are absent. Logs retained; no resigning or physical test repetition |

The focused source review and one fresh runtime converge this unchanged snapshot with no concrete owned finding. Reader lease is released after completed pre/post binding and link inspection; no compiler/runtime or future producer-byte reader remains. Root owns the additive individual registration and commit. Native qualification is limited to the original selected8/7 cases, not all2270 behaviors, universal grazing/tangency, dynamic concave response, signed volume, non-sphere overlap, moving sweeps or ordinary/Embedded WASM. Existing incomplete markers remain genuine typed refusals.
