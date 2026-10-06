# Selected convex support-map qualification

## Purpose and Scope
Parent subject: [ConvexQueries](../../Sources/SwiftMechanics/Physics/Collision/ConvexQueries/DESIGN.md). Children: none. Own independent selected CL-001/004 public support, GJK separation and EPA penetration fixtures, shared synchronous execution and Native cancellation. Root owns registration, target leases, integration and Git.

## Responsibilities and Boundaries
Exercise the actual `ConvexCollisionQuerying` protocol with `SupportMappedConvexQueries`, supplied immutable mechanical proxies and qualified Core/Model/Collision inputs. Closed-form primitive support values and independently chosen distances/depths are fixture oracles. No substitute narrow-phase solver, unqualified geometry provider, CAD authority or contact dynamics is introduced. Moving a proxy means a new instantaneous rigid snapshot; this proof grants no sweep or continuous motion capability.

## Related Designs
| Design | Relationship | Contract Used | Caution |
|---|---|---|---|
| [ConvexQueries](../../Sources/SwiftMechanics/Physics/Collision/ConvexQueries/DESIGN.md) | subject | ConvexProxy, weighted support witness, GJK/EPA and typed failures | Source membership alone is not behavior |
| [Shapes](../../Sources/SwiftMechanics/Physics/Collision/Shapes/DESIGN.md) | depends on | CollisionProxy/Policy/Work | Original accounting and source identity |
| [Geometry](../../Sources/SwiftMechanics/Physics/Collision/Geometry/DESIGN.md) | depends on | Public sphere/box support adapter | No internal analytic dispatch access |
| [Core](../../Sources/SwiftMechanics/Mathematics/Core/DESIGN.md) | depends on | Vector3, UnitQuaternion, RigidTransform | Finite checked arithmetic propagates |

## Architecture
```text
independent primitive/hull scalar geometry + supplied identity/source/frame
 -> actual proxy admission -> public support / GJK / strict seed / EPA
 -> scalar support extrema and known separation/depth
 -> original weighted supports reconstruct both points and framed balance
 -> synchronous public cases + focused Native Testing + cancellation
frozen2363 depot -> individually verified private outputs -> narrow fixture compile/link
```

## Contracts and Invariants
Fix nine synchronous groups before execution: analytic/new primitive support extrema and ties; adapted sphere separation/margins/reversal; capsule/cylinder/cone/hull GJK separation; original box EPA depth; hull/cylinder/cone/capsule EPA depths; numerical touching and coincident boxes; rigid covariance and immutable moved snapshot; identity/source/quality/admission refusal; and operation/storage/record/iteration refusal. A tenth Native case cancels actual constructor, support and both witness overloads. Sphere separation is `3-1-0.5-0.1-0.2=1.2`. Capsule axial extent is `halfLength+radius`; cylinder and cone axial apex extent is `halfHeight`. Unit cube pairs displaced by `(1.5,0.125,0.25)` have unique depth0.5 along +X. Cylinder/cone of half-height1 versus a unit box at Z1.5 have depth0.5 along +Z. Capsule radius0.5/half-length1 versus a unit box at Z2 has depth0.5 along +Z. Coincident unit cubes have depth2 and nonunique directions; no arbitrary chosen normal is required.

Support values are derived from the supplied shapes: sphere `r*|d|`; box the sum of half-extents times absolute direction components; capsule that sphere value plus half-length times absolute Z; cylinder radial support plus cap support; cone the maximum of apex and base-disk support; hull the actual maximum over original retained vertices. Pose and margin contributions are independently included. Each returned weighted original support must attain its own closed-form support value; weights reconstruct both reported points, sum to one and remain nonnegative. Signed bounds must contain the independent expected value, have the admitted interval width, and agree with the original signed point balance. EPA success additionally requires negative separation and its reported support interval; an iteration flag or a failed query never satisfies a depth oracle.

Fixture numerical inputs are fixed: length/normal policy1.1e-8 and independent assertion band2.2e-8, with explicit reference length1meter. These inputs are not adjusted after failures. Sufficient reference work is explicitly supplied as50million scalar operations,200iterations,200000scalar slots and4096records. Selected geometry may expose a causal algorithm defect or a genuine typed unsupported numerical domain; retain the counterexample and seek root-coordinated matching outputs before re-execution. Concentric smooth-shape convergence and arbitrary hull rank/scale, tangency, rotation sweep and universal convex pairs are outside this fixed proof.

## Runtime Flows
Each case owns input proxies and cumulative exclusive work. Public snapshots retain original identities/poses/source/quality and supports after moved values are created. Exact typed failures are asserted; any other failure rejects the case. Preparation may proceed independently while two narrow Native resource slots are occupied. Compiler execution begins only after root releases the queue. Every retained object/module file and all17 subject Swift/five fixture bytes are verified before and after actual execution. A source repair requires a coherent fresh producer, never mixing an old module/object with new source.

## State, Ownership, and Lifecycle
Immutable Sendable inputs/results and local operation-exclusive arrays/work are shared unchanged across targets. Fixtures own no persistent handle, mutable static state, callback, unsafe buffer, I/O or stream. Native cancellation awaits its cancelled task. Test-only conditional support-module imports affect composition, not isolation. Original2363 producer remains read-only; private copies may deduplicate immutable bytes through hardlinks only after individual hashes agree.

## Failure, Concurrency, and Constraints
Source/collider/frame/quality/margin/rank admission failures, zero-direction support, unbounded half-space refusal and budget/iteration/cancellation failures retain exact typed meanings. Reference budgets bound the actual algorithm, not a guessed success count. Preparation has a256MiB private ceiling. Root's subsequent Native slot1 release additionally bounds cache growth by128MiB relative to the measured frozen prepared output/source copies and reserves576MiB global free space. All commands have watchdogs and actual effective jobs4. No cold full-source/profile compiler or LLVM decoder competes with ordered leases. Strict signatures, compiler/link behavior and geometry behavior are separate observations; never relabel a strict-signature failure.

## Verification and Change Impact
Root-released selected Native execution passed all ten Swift Testing cases and nine unchanged synchronous public groups on pinned Swift6.4.0/macOS arm64. No fixture compiler repair, production counterexample, tolerance/oracle change or production source edit occurred. Capsule/cylinder/cone/hull support and selected GJK/EPA paths attained the independent extrema, gaps and depths, with original weighted support reconstruction and signed primal/dual bounds. Cancellation and exact admission/work failures executed through the original public requirements. Before and after each step, every2363 retained object and three metadata files, all17 subject Swift files and five fixture copies/live files matched their frozen hashes. Actual fixture compiler jobs, argv, object/binary/load-path hashes, watchdogs and resource measurements are in the private [Native receipt](../../.build/af35-convex-queries-qualification/native-final-receipt.json).

The fresh library and public executable pass strict signature verification. The generated inner test binary reports the existing resource-signature mismatch; that inspection remains an explicit failure separate from actual Testing success. The original2363 depot's known unrelated AF31 source divergence does not become a claim that the current entire repository matches this old producer. Subject source/object binding is exact.

A single source review converged the fixed proof without causal implementation rechecks. Ordinary/Embedded profile execution and root integration remain separate. The selected runs do not exercise duplicate-support, unresolved-interior-seed or invalid-polytope error outcomes, arbitrary ill-conditioned hulls or universal smooth coincidence. Changes to support geometry, weighted witnesses, frame/source authority, numerical admission, seed/horizon/face selection or work invalidate affected receipts. Source preparation must preserve all existing suppliers and original fixture equations; target membership does not qualify behavior.

## Portability Preparation Premises
Root selects exact committed export `4d16dfdeed329eb425f8f54dc171793903bc55e5` with baseline inventory `6ce46bfe113b64f48957d91d9d49d259ab85ce1dc2b5e1f224e16f2cd0e1d25c`. Preserve original exclusions and all1562 included baseline Swift providers; add only exact17 Native-green ConvexQueries Swift files, yielding1579 production sources, plus the same five fixture files. `Modeling/Machines/MachineDefinitionContext.swift` is present, included and byte-identical to the baseline inventory. Its real definition/lowering callers remain included; no supplier is removed to avoid target diagnostics. Membership does not establish that all baseline paths are portable. Ordinary/Embedded execute the same nine synchronous cases; the awaited cancellation case is Native-only and is not generalized to WASI.

Prepare scripts from root's ExternalCommands profile pipeline, adapting only source count, subject paths and Native-green receipt/oracle bindings. Pin release6.4.0 and matching ordinary/Embedded WASI SDK IDs, jobs4 and compiler threads4, with Embedded WMO required by actual compiler argv. Before/after every phase, verify original source/fixture copies and the manifest; the actual compiler source list must equal all1579 included paths. Full decoded original global writes must exactly equal the inserted stack guards, all at stack-pointer global0, with reservation131072bytes. The guarded nine-case executable must pass before raw execution; compare the same Native public witness lines. Never weaken guard count, reservation, original EPA/support oracles, failure semantics or supplier membership.

The unchanged bounded watcher admits a build only with2560MiB global free, bounds profile local nonreserve allocation by2048MiB and retains512MiB recovery reserve plus256MiB reaction margin. It samples at most every two seconds, refuses slow/unreliable observations and terminates the child process group before crossing reaction boundaries. Prepared deadlines are build1200seconds, complete decoder600, instrumentation120 and each guarded/raw run240. Measured adjacent profiles informed root's resource policy; no temporary peak or compiler/decoder/runtime success is claimed by preparation. Compiler, LLVM decoder, runtime and archive remain gated on root's ordered queue release. Scripts, helpers, source inventory and execution policy are frozen in the private profiles preparation receipt.

### Registered Exact-Source Profile Proof

Root registered the selected17 production Swift files and four co-located fixture/test Swift files after pinned Swift6.4.0 release execution. The fixed1579-source ordinary and Embedded WASI graphs preserve all1562 baseline suppliers and the same nine synchronous public witnesses. Complete LLVM decoding observed38424 ordinary and938 Embedded stack-pointer writes; each count equals inserted original131072-byte guards. All nine guarded witnesses passed before the unchanged raw artifacts ran successfully. Native cancellation remains a separate Native-only proof.

| Evidence | SHA-256 |
|---|---|
| [Ordinary receipt](../../.build/af35-convex-queries-qualification/profiles/wasm-receipt.json) | `2b613710957ef61addf2bd196f03892d47729cdf620ecd7657a3b516e0b69519` |
| [Embedded receipt](../../.build/af35-convex-queries-qualification/profiles/embedded-receipt.json) | `cd2de60405996581dab6f5fc581ac696fce69990af72d864882d0168adfe6ce5` |
| [Canonical Native receipt](../../.build/af35-convex-queries-qualification/canonical-native-receipt.json) | `755ba0b33aae5d7ecd9ceac26ca05b96ab4222eebff3df56ed6a21f480e4eeb1` |
| [Canonical source/object/link bindings](../../.build/af35-convex-queries-qualification/canonical-source-object-link-bindings.json) | `420b67bf395d514f4aa99ae02c3e9d944e2cdde62c9fefa5bde7a821674f7b8f` |

The existing warm canonical Native composition now contains1747 included production sources. Its actual ten convex cases plus39 retained URDF/Affine/ExternalCommands/JointStops/MJCF cases passed in six suites, with exact1751 production and convex fixture source/object entries in the executed test link. macOS13 remains the package minimum. The geometric query path contains immutable Sendable values and exclusive local work on every target; no shared mutable state or target-dependent synchronization is introduced. Full CL closure, universal ill-conditioned/smooth-coincident geometry, discovery, sweep, persistence and contact dynamics remain outside this selected registration.
