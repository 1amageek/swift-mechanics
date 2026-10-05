# Nine additional service verification

## Purpose and Scope
Parent [package](../../DESIGN.md); children none. Nine independent public protocol suites; immutable per-test laws/inputs and exclusive LoadWork.

## Responsibilities and Boundaries
Own original analytic, derivative, potential/power and explicit failure evidence for the nine new selected service contracts. Whole Runtime, full requirement family, portable profiles and performance are separate owners.

## Related Designs
The source component DESIGN.md documents point here; this target imports only public SwiftMechanics. Source child indexes are [Loads](../../Sources/SwiftMechanics/Physics/Loads/DESIGN.md) and [Materials](../../Sources/SwiftMechanics/Physics/Materials/DESIGN.md).

## Architecture
```text
nine independent physical fixtures -> nine public protocol witnesses
 -> analytic/finite-difference/work-energy checks + typed failure checks
```

## Contracts and Invariants
Tests must distinguish force sign, original potential/power, tensor shear convention, knot branches and overflow/domain/budget/cancellation failures. Suites may execute concurrently: no static mutable fixtures, file/DB/runtime sessions or shared work buffers.

## Verification and Change Impact
Swift 6.4.0 release Native focused product build/link then bounded public suite execution. Record exact result after running. Identical immutable source ownership on WASM/Embedded does not constitute target execution evidence.

### Selected Native qualification (2026-10-05)
Pinned Swift 6.4.0 release on arm64 macOS27.0.1, canonical SwiftMechanics module and MechanicsNineAdditionalTests product compiled/linked. Final 50 public tests in nine concurrent suites passed, including near-zero signed table calibration regression. Forty-one source/test hashes match the frozen inventory. Build and test commands use Scripts/run_with_timeout.py (300s/60s); logs and frozen hashes live in `.build/nine-evidence`. Supplier Swift files are unchanged in the parent working snapshot. Native evidence applies to these selected constitutive services; whole Runtime/element acceptance, minimum macOS13, WASM/Embedded, performance and complete210 closure remain unqualified.

| Profile | Storage/isolation | Read/mutation/release | Evidence |
|---|---|---|---|
| Native | Immutable Sendable laws/results; caller-exclusive LoadWork value | Public protocol witnesses; only local workspace/value counters mutate; value/COW release by caller | Selected compile/link and behavioral runtime passed |
| WASM | Same source storage, Sendable and work isolation | Same requirements and value ownership; math adapters depend on WASILibc | Not compiled/executed by this task |
| Embedded | Same source storage, Sendable and work isolation | Same requirements and value ownership; no omitted lock/reference owner | Not compiled/executed by this task |

Exact commands:
```sh
python3 Scripts/run_with_timeout.py 300 <swift-6.4.0-RELEASE>/usr/bin/swift build --build-path .build/six-native --product MechanicsNineAdditionalTests -j 2
python3 Scripts/run_with_timeout.py 60 <swift-6.4.0-RELEASE>/usr/bin/swift test --build-path .build/six-native --skip-build --test-product MechanicsNineAdditionalTests --disable-xctest --enable-swift-testing -j 2
```
Compilation initially rejected test-only missing nested `try`; corrected. One bounded review found the original negative near-zero table effort cancellation; both evaluators now interpolate outward from the endpoint nearest zero. The finding-only recheck and final 50 tests pass. No further source changes or target capability claims follow this evidence.
