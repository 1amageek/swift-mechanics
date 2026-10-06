# Attachments Qualification

## Purpose and Scope
Behavior owner for the selected point-translation attachment contract. Parent: [Verification](../DESIGN.md); no children. The production authority is [Attachments](../../Sources/SwiftMechanics/Physics/Flexible/Attachments/DESIGN.md). This fixture qualifies actual public Tet4 material interpolation, rigid tree evaluation, constraint rows and reciprocal loads. It does not qualify coupled evolution, material rotation or runtime synchronization.

## Responsibilities and Boundaries
All producer calls use qualified public Mesh, MaterialGeometry, ArticulatedTrees and Jacobians contracts through `RigidMaterialAttachmentComputing`. Independent scalar/vector formulas own the expected values. No FieldOutputs, Hydroelastic, reduction or CAD supplier is consumed. The fixture owns only local inputs and its cancellation counter. Root owns the manifest, source producer and Native execution lease.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Attachments](../../Sources/SwiftMechanics/Physics/Flexible/Attachments/DESIGN.md) | depends on | Owner-issued rigid/material sources, query and force proposal | Actual physical execution | Modified source requires matching newly emitted objects and module |
| [Mesh](../../Sources/SwiftMechanics/Physics/Flexible/Mesh/DESIGN.md) | depends on | ValidatedTetrahedralMesh | Original Tet4 physical data | No internal helpers |
| [MaterialGeometry](../../Sources/SwiftMechanics/Physics/DeformingContact/MaterialGeometry/DESIGN.md) | depends on | DeformingSurfaceUpdating | Original boundary interpolation | Exact owner and epoch |

## Architecture
```text
real validated Tet4 -> real material surface -> affine current snapshot -> site
actual tree + state -> source evaluator -> snapshot + exact v
                             |                    |
independent analytic oracle <- public query -> public force proposal
                             |
same synchronous cases -> standalone caller / Swift Testing
```

## Contracts and Invariants
The reference cell is OXYZ, current nodes are (2.35,-.6,0), (3.35,-.6,0), (2.85,1.4,0), (2.35,-.6,.5). The selected face opposite node 3 has outward original order [0,2,1] and barycentric weights [.2,.3,.5], independently giving point (3,0,0). Load multipliers [2,-3,4] give original nodal forces [.2F,.5F,.3F,0] with F=(2,-3,4). Rigid force is -F and body-origin moment at offset (1,0,0) is (0,4,3). The independent world moment uses the original nodal positions and the body-origin wrench, not the producer's residual values.

| Case | Independent oracle / refusal |
|---|---|
| Floating tangent velocity | qdot7 versus v6; J=[I, angular axes cross offset], efforts [-2,3,-4,0,4,3], rigid power9, nodal power-9, bias[9,0,0] |
| Spherical tangent velocity | qdot4 versus v3; efforts[0,4,3], rigid power9, nodal power-9, bias[9,0,0] |
| Prescribed derivative | Prismatic q2/v5, moving anchor linear4X/angular3Z and acceleration6X: point velocity(9,9,0), bias(-21,30,0), rows prescribed[-4,-9,0], effort-2, rigid power9=generalized -10+prescribed19 |
| Original virtual work | Independently chosen rigid tangent and nodal virtual velocities: row transpose work equals generalized plus nodal work; per-interface force, world moment and physical power also vanish |
| Identity and physical refusals | Reissued rigid owner, different surface, epoch, boundary/revision/frame/time, rank/overconstraint, unsupported material rotation, nonfinite multipliers; shifted partial constraint must reject its free couple |
| Resources and cancellation | Exact observed operation/storage limits, count/layout limits, initial and final cancellation; supplier cancellation remains the original typed surface cause with ledger |

The repaired source constructor must retain the exact original state and policy, preserve actual evaluator revision/count/derivative failures, and never pair an arbitrary raw snapshot with a supplied v. Tests assert the published coordinate derivative remains different in count; they do not change its meaning. Physical tolerances are 1e-8 or tighter, units SI, all world/frame/source/body/material/node revisions are asserted from retained public values. Per-interface checks are repeated for selected loads; no global residual alone proves them.

## Runtime Flows
Prepare immutable real sources, call public material-site admission, query rows, independently compare row columns/g/rate/bias, map force multipliers and check independent loads/work. Failure cases require the exact typed cause. Cancellation counting first observes a successful operation's actual check count, then cancels at its final check; no guessed scheduling interval. Native actual Task cancellation uses a cancelled task and awaits its result with an untyped Task adapter preserving the typed synchronous entry.

## State, Ownership, and Lifecycle
Canonical macOS13 registration is supported for the fixture declarations. The pinned Swift6.4.0 Native `Synchronization.swiftinterface` declares Mutex and withLock available on macOS15 (lines1025 onward). Only the cancellation counter, its sole resources/cancellation implementation and corresponding Test require macOS15. The general runner dispatch checks actual API availability and returns a typed `mutexUnavailable` refusal on earlier macOS; it never removes Mutex or reports a skipped resource case as success. Other five synchronous cases and the actual Task cancellation entry do not require this fixture Mutex API. On WASM/Embedded the same unconditional Synchronization import/storage/withLock remains; no state isolation branch is introduced. Native macOS13 raw typechecking and macOS15-target actual execution qualify this availability adjustment, not macOS13 runtime behavior.

Inputs and fixtures are immutable Sendable; producer scratch is operation local. The only shared mutable value is a per-case cancellation count in common `Synchronization.Mutex<Int>` on Native/WASM/Embedded, with identical storage and read/mutation entries, no callback or I/O under lock. Only the counter/resources case and its Test require macOS15; final fixture registration and production retain macOS13. Earlier Native consumer evidence used a macOS15 private target. Counter lifetime is retained by the immutable closure and ends after the case; no global cache, pointer, shutdown or escaped borrow is owned.

## Failure, Concurrency, and Constraints
Typed fixture error preserves AttachmentError, CoreError, JointError, ModelError, FlexibleError, MaterialError, NumericalError and DeformingContactError. Unexpected untyped construction failures are explicit fixture failures. No retry, casts to force compilation, successful fallback or partial result. Parallel cases share no mutable data or files. Narrow matching-module consumer uses jobs4, compiler watchdog, test timeout and strict codesign recording, with additional cache budget128MiB. Native execution waits for root's lease; old immutable2363 objects/module remain untouched. No whole source rebuild or SDK restoration occurs here.

## Verification and Change Impact
Portable preparation uses the exact committed4d16dfd graph1562 plus only the repaired Attachments13, retaining all original exclusions and adding only the owned DESIGN exclusion. Every1562 baseline Swift path was compared with the matched2363 immutable source snapshot; exactly one difference is the uncalled `Modeling/Machines/MachineDefinitionContext.swift` structural additions. The selected fixture directly constructs validated Tet4 and KinematicTree, and its traced Mesh/MaterialGeometry/Joints/Model/Core/Numerics supplier path has no MachineDefinitionContext reference. No unqualified structural factory/comment source is added. The final availability8 fixture bytes are copied; only six synchronous public cases are executed in portable products, with the Native awaited Task test left in its test target. A root-issued canonical final Native receipt binding is required before profile execution; earlier Native receipts prove only their retained old fixture bytes.

The prepared runner preserves the old131072 guard and full original LLVM all-`global.set` audit, requires every stack-pointer write to have an inserted guard, and runs guard before unchanged raw. Actual source lists, driver jobs4, WMO and frontend threads4 are captured, not inferred from CLI. Each profile build watchdog1200s, full decoder600s, instrumentation120s and each runtime240s use a storage watcher with2560MiB admission,2048MiB local envelope,512MiB recovery reserve and256MiB reaction margin. This envelope is not a measured temporary peak. Root owns the exclusive heavy compiler/decode lease and SDK restoration; preparation executes none of them. On WASI the macOS availability wildcard selects the same resources method and the same Mutex storage; no target-specific synchronization substitute exists.

The first matching Native fixture compilation rejected identity comparison on the value-type `DeformingSurfaceSnapshot` and typed-throws inference through a short-circuit expression. A second fixture compilation identified that its NodalState has no Equatable conformance. The causal fixture repair compares the actual retained MaterialSurface owner plus every published nodal frame/revision/identifier/position/velocity and snapshot time/epoch, and evaluates expected policy before the Boolean expression. Independent physics/oracle values and production source remain unchanged. Both failure source copies, freezes, logs and receipts remain retained; the incremental consumer uses a separate pass receipt and updated fixture freeze.

One source review and targeted causal recheck precede freeze. Same synchronous public cases run via standalone caller and Swift Testing; a Native-only awaited Task test adds cancellation evidence. Matching Native execution passed seven tests and all six identical public cases, including exact spherical/floating coordinate derivative versus tangent velocity and original prescribed power. The authoritative receipt and source identities are recorded in the production [Attachments](../../Sources/SwiftMechanics/Physics/Flexible/Attachments/DESIGN.md) evidence paragraph. All producer object/source/module metadata and selected live source hashes matched before and after; no production compiler was launched by this consumer. Original preparation/failed fixture source copies and both failed compilation receipts remain retained. Strict public/dylib signature verification passed; generated test bundle strict verification failed with its original missing-resource signature diagnostic, retained without re-signing. Source edits invalidate object/module matching, so root coordinates a separate producer before another fixture build. Native does not imply macOS13 runtime or WASM/Embedded proof; profile execution remains separately scheduled.

## Registered Repaired Point-Interface Proof

Root registered all13 repaired production Swift files after final availability-adjusted8 fixture bytes passed actual canonical Native seven tests and six shared public cases using all1760 canonical production objects. The initial public compiler command lacked its SDK and failed to import Darwin; the retained compiler diagnostic was corrected by supplying exactly the SDK already emitted by the successful canonical build. No source, oracle, tolerance or Native test was changed or re-executed for this command correction.

The fixed1575-source graphs keep every1562 baseline supplier, adding only13 exact repaired Attachment sources. Complete ordinary LLVM observed38591 global0 stack writes and Embedded observed1869, exactly equal to inserted original131072-byte guards. All six guarded public cases passed before unchanged raw execution. Pinned Swift6.4.0 release, matching WASI SDKs and Node24.19.0 were used; actual driver jobs4 and Embedded WMO/frontend threads4 are recorded.

| Evidence | SHA-256 |
|---|---|
| [Canonical Native receipt](../../.build/af35-attachments-qualification/canonical-native-receipt.json) | `7766ffd5b3cee7d63a42b6b22b1cffe40910b8b784d6616d62a6084fb8df70fa` |
| [Canonical source/object/link bindings](../../.build/af35-attachments-qualification/canonical-source-object-link-bindings.json) | `7afe956129f099e6bb3c71cd5e4f9c5ad0e6ed54057a8992b0ca005cacb863b4` |
| [Ordinary receipt](../../.build/af35-attachments-qualification/profiles/wasm-receipt.json) | `55f515014e1d9038eabdf2a3e8df93941eaff0a88c6a4b1d5b6e4a93971cf365` |
| [Embedded receipt](../../.build/af35-attachments-qualification/profiles/embedded-receipt.json) | `8010adac046ba4fe641482418e9d5e977b259af26ad8b89dace77ab6da021a76` |

The constructor evaluates and retains the exact original `KinematicState`; query tangent columns and effort/power contract against `state.v`. Floating seven quaternion coordinates/six tangent velocities and spherical four quaternion coordinates/three tangent velocities remain different domains. `snapshot.coordinateRate` preserves coordinate derivatives and is never reinterpreted as generalized velocity.

| Owner | Native / ordinary WASM / Embedded | Access and lifetime |
|---|---|---|
| Rigid source | Same immutable Sendable tree-evaluated snapshot and retained state | Source constructor owns evaluation; proposals retain the exact owner; no raw/unsafe substitute |
| Query/workspace | Same operation-local arrays and exclusive `inout NumericalWork` | Failure returns no proposal; no callback or I/O enters shared state |
| Test cancellation counter | Same `Mutex<Int>` storage and Sendable counter | `check` mutation and `count` read both use `withLock`; no callback/I/O under lock; retained closure owns lifetime |

macOS13 declaration/build admission is proved; the actual Native runtime is newer macOS, and the Mutex case refuses earlier systems explicitly. Native Task cancellation is not a WASI parallelism proof. Material orientation still fails with its immediate incomplete marker, and coupled flexible evolution, Runtime synchronization and full FX-008 remain open.
