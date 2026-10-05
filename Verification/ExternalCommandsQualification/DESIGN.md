# ExternalCommandsQualification

## Purpose and Scope
Parent: [system](../../DESIGN.md). Children: none. Own the existing AF35.6 public behavioral qualification gap for scalar delayed external commands. Selected Native and fixed ordinary/Embedded profiles are independent evidence; source preparation is not qualification.

## Responsibilities and Boundaries
Exercise original `ExternalCommandScheduling` and real `DriveEvaluating` through public contracts with an actually compiled scalar tree. Independently check original timestamps, declared SI conversions, interpolation weights, sequence/source binding, immutable checkpoint replay/pruning and physical actuator power/work. Plant integration, Runtime acceptance, networking and vector commands remain other owners.

## Related Designs
| Design | Relationship | Contract used | Cautions |
|---|---|---|---|
| [ExternalCommands](../../Sources/SwiftMechanics/Execution/Control/ExternalCommands/DESIGN.md) | depends on | bind/append/select/restore/prune/drive and original work | Selected source unqualified until actual proofs |
| [DriveLaws](../../Sources/SwiftMechanics/Physics/Actuation/DriveLaws/DESIGN.md) | depends on | Actual scalar servo response and energy | No plant trajectory claim |

## Architecture
```text
original scalar compiled model + admitted binding
 -> original timed packets + explicit degree/kN units
 -> scheduler selection/checkpoint
 -> actual servo response -> independent time/force/power/work oracle
```

## Contracts and Invariants
One shared synchronous case owner serves Swift Testing and standalone public execution. Source fixtures declare synthetic analytic inputs, not empirical calibration. Literal independent expected weights/times/forces/energy and original metadata must match. Typed failure categories and consumed work remain observable; failed queries do not mutate prior checkpoints. Unseen future packets, stale/late inputs, mismatched units and clock refusal must not yield successful commands.

## State, Ownership, and Lifecycle
| Target | Storage | Isolation | Reads/mutations | Release |
|---|---|---|---|---|
| Native/WASM/Embedded | Immutable Sendable fixture/model/checkpoint; local inout work | Operation-local exclusive state | Same public requirements | Lexical owners |
No shared mutable static fixture, target-dependent Sendable, pointer, external callback or shutdown owner. Native actual Task cancellation is awaited separately and is not generalized to unexecuted targets.

Compiler policy records the actual selected target: Native CPU, ordinary WASI Preview 1, or Embedded WASI Preview 1. This conditional changes only admitted compiler capability metadata; fixture state, isolation, inputs, physical equations and public case expectations remain identical. Preparing this metadata path changes the fixture source and requires a new Native fixture receipt; prior execution remains attributed to its original SHA.

## Failure, Concurrency, and Constraints
Selected policies bound metadata, packets, allocation and arithmetic; exact exhaustion/overflow and retained known work are checked. Every external execution has a watchdog. Pinned Swift6.4.0 and matching SDKs; original 131072-byte full-decoded stack-write guard before unchanged raw WASI. No profile gate or oracle is weakened to obtain success.

## Verification and Change Impact
Delay/linear/exact/hold, original SI conversion, replay/restore/pruning, arrival availability, age/gap/late/order/unit/time/source refusal, actual servo force/power/energy/sequence and capacity/cancellation are selected proof obligations. Source/fixture/SDK/driver changes invalidate only affected receipts.

### Selected Native execution
Pinned Swift 6.4.0 on arm64 macOS executed seven Swift Testing cases in one suite and the same six synchronous public cases. Fixture-only build/link took 23.411 seconds; the test process took 4.633 seconds (framework cases 0.013 seconds), and public execution took 0.450 seconds. Setup/test/public watchdogs were respectively 900/60/120 seconds. Six actual compiler/link driver calls retained effective jobs four.

The consumer copied all 2,363 producer objects and three matching module metadata files before execution and reverified their SHA-256 and byte counts afterward. The actual linked public executable and test product both depend on that copied `libSwiftMechanics.dylib`; original eleven ExternalCommands production files match the frozen producer. This producer is the earlier frozen source compilation snapshot, including its original rigid dynamics supplier, not the later uncommitted AF31 witness repair or six-model side merge. No producer was recompiled or substituted. The original receipt is preserved under `.build/af35-external-commands-qualification/native-first-proof`, SHA-256 `e2bfe57a3c7eabf07df390fdc955633334aa8a6e62d8a84299dccffc481036d6`.

Selected Native semantics are proven within that source scope. The later exact-profile and canonical evidence below extends this selected service; coupled plant evolution and full CO-008 remain open.

### Target-admission fixture refresh
The target metadata fixture was recompiled in the actual private consumer, with all five private source hashes checked against the current working fixture freeze. The refreshed build took 7.118 seconds, seven tests passed in a 1.631-second process, and the same six public cases passed in 0.521 seconds. Five actual compiler drivers retained jobs four. Output file maps, source lists, produced object hashes and both executable link lists bind the executed fixture source to each linked consumer; copied production objects and matching module metadata were reverified unchanged. The refreshed receipt is `.build/af35-external-commands-qualification/native-qualification-receipt.json`, SHA-256 `2be9ef98dd3ab56af203939b890473346a77b66aa84fd91a857ca741eb12cf52`.

An earlier refresh attempt executed the stale private fixture copy. Its logs remain under `target-refresh-copy-mismatch`, with an explicit evidence invalidation receipt. That attempt is not evidence for the changed fixture; the original Native proof retains its original scope. The separately recorded exact-profile runs below execute the current frozen fixture.

### Exact-profile execution and canonical registration
The same six current synchronous public cases pass on the exact Swift 6.4.0 release ordinary and Embedded WASI Preview 1 SDKs. Both graphs contain 1,612 selected production source files, with the committed qualified baseline and unchanged eleven service sources. Ordinary compile/link took 30.548 seconds and full LLVM decoding 18.207 seconds; Embedded took 32.027 and 1.521 seconds. Actual compiler argv ends in jobs four, and Embedded WMO code generation uses four threads. The original 131072-byte reservation is unchanged: full decoded ordinary 38607 stack writes and Embedded 1989 writes exactly equal inserted guards. Every guarded case passed before executing the identical raw artifact, which also completed all six cases.

| Evidence | SHA-256 |
|---|---|
| Ordinary receipt | 05d8e5a0c367876cd84603b186d93deed7983c0549d56ede6abccfb9869ec9b4 |
| Ordinary raw artifact | 7081afc29cd034081d670eae4f9c1dc8c53de5839af10b35780f76bf6696feeb |
| Embedded receipt | 6e8248db3e297b5db4f7f491496f4b9ff3a9df2e161d1e1c05e5a18ab1e7d8c1 |
| Embedded raw artifact | a5655b953eabf46dad7aea290334c9d62ddd7628a9a6fdb5cd875032c43b1a82 |
| Canonical Native receipt | 5563d0329ce9352dd2a6a13fe1879b57012d6b78fa8a6127f7f71a9c191a29b9 |
| Actual canonical source/object/test-link binding | 80d3e8e342a4e248b5e8bc076c0215114273d532d7f9cf2b62a870387cb79ed9 |

Receipts live under `.build/af35-external-commands-qualification`, with exact profile receipts under `profiles`. Each source/fixture/private-manifest hash is checked before and after execution. The bounded profile watcher admits 2560MiB, refuses local allocation at 1792MiB or global free at 768MiB, samples every two seconds and preserves failure evidence. These are operational bounds with an explicitly unmeasured temporary peak; sampled allocation is not an allocator-peak guarantee. No physical inputs, equations, tolerances, work, target identity or guard were weakened.

The original 1693-source canonical cache was restored at its exact original path from the fully verified current1693 archive, retaining each file SHA/size/type/mode/mtime. Only eleven production sources and the five current service fixture files were added. The 1704-source incremental build took 7.587 seconds and the test process 1.404 seconds. Twenty-three cases in three suites passed: seven ExternalCommands and eight each of retained JointStops and MJCF. Actual source lists equal the frozen 1704-source selection; all 1704 production objects and four co-located fixture/test objects bind to the executed package-test link file list. Maximum observed additional canonical cache/temp storage was 6,467,584 bytes within its 128MiB gate. Full-target integration, minimum-platform qualification and undeclared coupled/vector/transport domains are not inferred.
