# Three independent model verification

## Purpose and Scope
Parent [package](../../DESIGN.md); children none. Behavioral evidence for thermal elasticity, sphere added inertia and Dahl friction through public service protocols.

## Responsibilities and Boundaries
Test original analytic equations, derivatives, success/failure and ownership. No full coupled mechanism, heat solver or CFD completion claim.

## Related Designs
Own tests for Sources/SwiftMechanics/Physics/Materials/Thermoelasticity, Physics/Fluids/SphereAddedInertia and Physics/Loads/DahlFriction; each source DESIGN.md owns its domain.

## Architecture
```text
three independent concurrent suites -> actual SwiftMechanics public service -> original physical oracle
```

## Contracts and Invariants
Each suite holds immutable services and local state/work. No shared mutable fixture or external resource. Fixed Swift 6.4 release Native build/link/runtime; preserve prior evidence where public suppliers are unchanged.

## Verification and Change Impact
Build and tests have external deadlines. Focused runtime selects only this test product with supported --test-product option; no unrelated product startup. Source hashes and exact Native qualification recorded after success. WASM/Embedded remain unverified.

### Execution evidence (2026-10-05)
Pinned compiler: /Users/1amageek/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swift; host arm64 macOS 27.0.1. Final canonical build command `swift build --build-path .build/six-native --product MechanicsThreeAdditionalTests -j 2`, with 300 s external bound, exited 0 in 22.65 s after the thermal lower-bound error correction. Actual public product runtime `swift test --build-path .build/six-native --skip-build --test-product MechanicsThreeAdditionalTests --disable-xctest --enable-swift-testing -j 2`, with 60 s bound, exited 0: 12 tests in three concurrent suites passed in 0.004 s. This execution time excludes SwiftPM startup. All 17 Swift hashes match `.build/three-evidence/source-freeze.json`. Logs: native-boundary-build.log and native-boundary-tests.log.

Initial broad build regenerated unrelated test products and was deliberately stopped after roughly six minutes; final work selects only this product. `--product` and `--build-tests` are mutually exclusive. The first focused compile rejected one omitted required tensor zz test argument, which was corrected; the next run passed 12 tests. Final thermal boundary repair and original physical oracle rerun above own completion evidence. No unrelated source or test was changed to fix these diagnostics.
