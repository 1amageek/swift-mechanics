# Gear binding tests

## Purpose and Scope
Parent [SwiftMechanicsCAD tests](../DESIGN.md); no children. Verify [GearBindings](../../../Sources/SwiftMechanicsCAD/GearBindings/DESIGN.md) using pinned original public CAD/compiled mechanics/transmission/physical equation paths.

## Responsibilities and Boundaries
Own independent geometry-to-motion/load and refusal oracles. Caller fixture explicitly supplies mechanical inertias; it does not claim CAD-derived moments or use internal/raw producer construction. Root owns external public callers and canonical integration. Existing AF28 geometry tests remain valid for unchanged contracts.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [GearBindings](../../../Sources/SwiftMechanicsCAD/GearBindings/DESIGN.md) | depends on | Source/shaft/fidelity/phase binding | Selected new behavior | No resolved-contact or CAD inertia claim |
| [Parent](../DESIGN.md) | parent | Public fixture and work isolation | Test target composition | Root owns registration/index |

## Architecture
```text
real CAD gears + caller compiled rotor model -> actual gear binding/network
 -> original tree q/v + original physical constraint solve -> TR torque diagnostics
 -> independent ratio/acceleration/reaction/power and refusal checks
```

## Contracts and Invariants
Two source gears use teeth20/40 and equal module with original admitted spur geometry. Independent rotor inertia I1=2,I2=3, drive[1,0], and original row20*q1+40*q2=0 imply velocity ratio-1/2, acceleration[4/11,-2/11], shaft reaction[-3/11,-6/11], and zero ideal reaction power. With speeds[2,-1], drive power and kinetic-energy derivative both equal2. Actual original force solver/diagnostics, not supplied multiplier guesses, must produce these values. Separate nonidentity frame/mounting fixtures preserve these local physics and global torque transforms.

Test all new boundaries through public APIs: original parameter resolution/SI, source identity and stable geometry signature, actual model/body/frame/joint/range authority, explicit phase/fidelity, compatible geometry, repeated occurrence distinction, work/cancel failure prefixes and explicit fresh initialization after source edit. Missing moments continue to refuse.

## State, Ownership, and Lifecycle
Each test owns its source, compiled model, binding and work ledgers. Immutable fixtures share no mutable cache or resource. Any test-only mutable cancellation counter uses the existing synchronized owner. Tests use no @testable imports or public raw snapshot authority.

## Failure, Concurrency, and Constraints
Setup/build/link timeout1200 seconds/four jobs; behavior timeout240 seconds. Root-controlled stopped original Native cache is reused without changing old private sources/logs/digests. Actual checkout/path/object evidence must prove remote295a and immutable3fe26e1, not another mutable owner. No adapter WASM/Embedded claim.

## Verification and Change Impact
The confirmed handoff now has eight public GearBindingTests methods. One scoped source review precedes the immutable-copy original-pinned Native owner proof; only concrete compile/behavior findings are repaired before final source freeze. Root separately integrates the public original callers. Failure of a lower supplier is reported as a concrete prerequisite, not patched here.


## AF29 executed owner evidence
The isolated mechanics source is committed `3fe26e17608e2519faade8beddc9428a21deb0dc`, extracted to `.build/af29-independent-cad/swift-mechanics`. Only owned GearBindings production/tests and additive GeometryAdmission query files are overlaid. Copy-only package exclusions register these components. The shared manifest and original suppliers are unchanged.

The stopped absolute AF28 Native scratch is reused. Actual `workspace-state.json` associates the file-system mechanics dependency with the new immutable private root and remote CAD with exact `295a724cdf0219c904007c2735f2b99ef08200ca`; the CAD checkout is clean. This is normal remote resolution, not a local CAD override. The fixed toolchain is `/Users/1amageek/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swift`, Native arm64/macOS.

Build/link is bounded by `python3 Scripts/run_with_timeout.py 1200 <swift> build --package-path .build/af29-independent-cad/swift-mechanics/Adapters/SwiftMechanicsCAD --build-path <stopped-native-scratch> --configuration release --build-tests --jobs 4`. New logs are `.build/af29-independent-cad/native-build-01.log`. The initial build exposed only owned typed-closure declarations; explicit closure error types and typed Core call wrapping repaired them. Release build02 succeeded in9.78seconds; after fixture-only repairs, build03 succeeded in6.86seconds and build04 in7.00seconds. Original supplier sources were not changed.

| Evidence | Actual result | Validity after final repair |
|---|---|---|
| native-tests-01.log, whole17 | All9 unchanged GeometryAdmissionTests passed, suite1.266seconds;7 new gear fixtures refused original overlapping fillets | Existing geometry source/tests remained unchanged |
| native-tests-02.log, filterGearBindingTests | Seven new tests passed; load helper refused original inertia ordering; suite6.951seconds | The later helper repair is called only by the load test |
| native-tests-03.log, filteractualMotionAndIndependentMassWeightedLoadOracle | One test passed in2.415seconds, exit0; both identity and nonidentity root/anchors | Final actual load, transformed torque, phase, power and motion oracle |

Seventeen distinct behaviors are green across these causal focused runs; this is not a claim that one final17-test invocation passed. The source fixture fillet is .00064*(pitchRadius/.032), yielding .0004/.0008 for20/40; actual pinned CAD admission accepts both. The original physical kernel consumes inertia records in actual snapshot.bodies order; the repaired helper follows that order and looks up the supplied original body by ID.

Final13 owned Swift files are byte-equal to the immutable-copy overlays. AggregateSHA256 `b2bfbf76ff91c6a83cac7ea8be39c8c39b0348eef3c1e7baf0c3abb2c118d961` hashes each sorted relative path UTF8, NUL and raw fileSHA256. The file inventory is `.build/af29-independent-cad/owned-swift-sha256.txt`; aggregate/provenance and original CAD, new binder and original compiled-model object evidence are adjacent. Actual object debug strings identify new private mechanics/adapter paths and the original remote CAD checkout. Swift production/tests are frozen; root owns public integration/commit. No broader source review or repeat build is required by this handoff.
