# SwiftMechanicsCAD tests

## Purpose and Scope
Parent [companion package](../../DESIGN.md). Verify the selected [GeometryAdmission](../../Sources/SwiftMechanicsCAD/GeometryAdmission/DESIGN.md) public responsibility; child [GearBindings verification](GearBindings/DESIGN.md) owns the distinct source-to-shaft motion/load proof.

## Responsibilities and Boundaries
Use original public CAD constructors/evaluator and independent primitive/placement oracles. Do not import adapter or CAD internals, fabricate admission tokens, or infer inertia from missing geometric moments. Tests own no shared resources or cache.

## Related Designs
| Design | Relationship | Contract used | Summary | Caution |
|---|---|---|---|---|
| [GeometryAdmission](../../Sources/SwiftMechanicsCAD/GeometryAdmission/DESIGN.md) | verifies | Sealed source/query authority | Owned success and refusal proof | Full IM38 remains open |
| [GearBindings verification](GearBindings/DESIGN.md) | child | Public original gear-to-shaft association and physical motion/load | Independent AF29 owner proof | Source pin and supplied inertia stay explicit |
| [Package](../../DESIGN.md) | parent | Exact remote pin and isolated Native graph | Actual package qualification | No profile generalization |

## Architecture
```text
public CAD source -> real adapter admission -> original geometry queries
                           ^                       |
                  forged/stale/limited inputs     v
                        typed refusal <- independent geometry/frame oracle
```

## Contracts and Invariants
Cover successful primitive/gear evaluation, distinct repeated occurrences and SI conversion; strict pin/document/revision/fingerprint/units/tolerance association; missing, deleted and cross-body anchors; density, duplicate mapping, unsupported source, capacity, cancellation and explicit exact-moment refusal. Fresh owners query equivalent source without reusing an admitted snapshot. No scalar existence or type-only assertion qualifies the path.

## Verification and Change Impact
Freeze production/tests, overlay only this companion package into a clean committed209ef09 mechanics baseline, use exact Swift 6.4.0, setup1200 seconds/four jobs and behavior240 seconds. Root owns manifest and canonical external caller proof. Record executed source digest, command and behavioral results here after actual qualification.

| Public test | Invariant and independent witness |
|---|---|
| exactBoxAndRepeatedOccurrenceFrames | CAD volume24 and box face/edge frames; translated Rz occurrence |
| displayUnitsDoNotScaleExactGeometryTwiceAndFreshOwnerMatches | SI volume24e-9, actual cylinder2pi, fresh exact anchors, moments refusal |
| eachSourceIdentityFieldGatesQueryBeforeSelection | Each declared source identity field refuses before missing selection |
| sameIDShapeEditOriginalResolverAcceptsButAdapterRefuses | Genuine original resolver counterexample; stale source and same-kind changed full signature refusal under current identity |
| crossBodyMissingAndForgedAnchorsRefuse | Actual two-body ownership, deleted ID, forged full signature |
| invalidSourceAndOccurrenceMappingNeverPublish | Invalid dimension/density, duplicate body/frame/occurrence, unsupported source |
| ownedLimitsAndCancellationRefuseWithoutAdmission | Source/depth/metadata/topology/work/output ceilings and zero-prefix cancellation |
| cancellationAfterPositiveWorkAndAfterActualQueryReturnsNoValue | Positive owned work and post-original-query cancellation refusal |
| genuineGearSourceUsesOriginalProfileAndSweep | Actual 32-tooth source reaches exact original profile/sweep and height.01 |

### Executed AF28 Native evidence
The initial qualified 17 Swift files (14 production, 3 test) matched that executed snapshot byte-for-byte. Its aggregate SHA-256 over sorted relative Swift file paths and individual SHA-256 lines is `246e6234fd3848414ad44b469cf1853d15c9509aaf8e611d2481c6f7b03609ba`. All 2003 regular files in the immutable mechanics `209ef09a0c8c4460dfe41ba09d82dfdb1b8484f8` archive remained unchanged. Actual CAD checkout is clean at `295a724cdf0219c904007c2735f2b99ef08200ca`; no package override was used.

Executed from `/Users/1amageek/Desktop/3D/swift-mechanics/.build/af28-independent-cad-adapter/swift-mechanics/Adapters/SwiftMechanicsCAD`, using Apple Swift 6.4 release target arm64 on actual macOS 27.0.1. The nested mechanics directory preserves SwiftPM's required local dependency identity. The initial unnested layout failed before resolution; it was corrected without changing the manifest.

```sh
python3 /Users/1amageek/Desktop/3D/swift-mechanics/.build/af28-independent-cad-adapter/swift-mechanics/Scripts/run_with_timeout.py 1200 /Users/1amageek/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swift build --build-tests -c release --build-path .build/native -j 4
python3 /Users/1amageek/Desktop/3D/swift-mechanics/.build/af28-independent-cad-adapter/swift-mechanics/Scripts/run_with_timeout.py 240 /Users/1amageek/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swift test --skip-build -c release --build-path .build/native -j 4
```

Actual compilation exposed the two CAD/mechanics MaterialError name collisions; both now explicitly preserve CADCore.MaterialError. The next release build compiled/linked successfully in 7.83 seconds. First behavior executed 9 tests: 8 passed, one gear fixture correctly failed because parameter 0 lies outside some original trim ranges. The repaired fixture obtains original public resolved startParameter and compares actual original endpoint coordinates; production was unchanged. Final incremental release compile/link exited 0 in 6.20 seconds. Final whole companion behavior exited 0: 9 tests/1 suite passed in 1.151 seconds. No timeout/hang occurred.

Evidence in that private package: `.build-native-setup-layout-corrected.log` preserves the actual initial compiler finding; `.build-native-setup-owned-repair.log` the qualified compile; `.build-native-behavior.log` the red trim-range finding; `.build-native-setup-test-repair.log` the final compile; `.build-native-behavior-final.log` the final 9-test success. Final behavior log SHA-256 is `1cb19176a8f36fe01810e85ad98d4a224eb010ade64f871b6a6993b6abb09230`; `.build-native-evidence.json` contains all file/log hashes. Existing missing excluded-observation file warnings belong to the committed mechanics archive and did not affect selected compilation. Root owns independent external public composition and commit; no WASM/Embedded or complete inertia qualification follows from this Native evidence.

The test-only cancellation counter has immutable Mutex<Int> storage and read/mutation inside withLock, with no callback in the critical section. Each test owns a separate counter; its macOS 15 availability guard is inside the test. Production admission is immutable; source/work counters are exclusive inout local state. No target conditionals, unchecked concurrency or raw pointer owner were added.

### Scoped review signature witness
Root's single scoped source/test review found no production defect and identified one precise evidence gap. Only sameIDShapeEditOriginalResolverAcceptsButAdapterRefuses changed: it selects an actual face whose full geometry signature changed, preserves the original direct same-ID resolver and stale-source assertions, then publicly rewraps the old face stableReference/topology under second.identity with the same occurrence. Actual surfaceAnchor using second.identity returns wrongAnchor. Both references are real faces; this proves geometry equality independently of a vertex-versus-face kind mismatch or stale identity guard.

Production and the other eight tests remain unchanged. In the same private release copy, the incremental build-tests command above exited 0 in 7.53 seconds; the focused command below exited 0 with 1 test/1 suite passing in 0.007 seconds. The existing full 9-test qualification remains valid for the unchanged paths; no broad rerun was performed.

```sh
python3 /Users/1amageek/Desktop/3D/swift-mechanics/.build/af28-independent-cad-adapter/swift-mechanics/Scripts/run_with_timeout.py 240 /Users/1amageek/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swift test --skip-build -c release --build-path .build/native -j 4 --filter sameIDShapeEditOriginalResolverAcceptsButAdapterRefuses
```

Final 17 Swift files match the executed private source byte-for-byte and are frozen. Final aggregate SHA-256 using the same path/file-hash algorithm is `314c5a45ebfe94a847439362d7d9170719f17be149babc536eacfe44aa4fd3b6`. `.build-native-setup-signature-review.log` records final compile/link; `.build-native-behavior-signature-review.log` records the targeted success, SHA-256 `f91c711867a1d55d243141a6471b455396dfa6e784af4658ad1150478de09396`. `.build-native-evidence-signature-review.json` retains final file/log hashes. No source, provider, manifest or unrelated test was changed by this scoped correction.

## AF30 child ownership

[GearReinitialization](GearReinitialization/DESIGN.md) owns the new explicit edited-gear restart and complete checkpoint/refusal proof. Its source remains excluded until the frozen Native handoff; actual execution evidence must precede a success claim. Root owns this parent index, package registration and cumulative optional integration.
