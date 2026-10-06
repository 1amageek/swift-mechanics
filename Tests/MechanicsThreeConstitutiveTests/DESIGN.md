# Three constitutive public verification

## Purpose and Scope
Parent [package](../../DESIGN.md); children none. Own public Native proof for three new [Materials children](../../Sources/SwiftMechanics/Physics/Materials/DESIGN.md).

## Responsibilities and Boundaries
Independent analytic stress/strain, exact work-energy, history split/reversal and finite-deformation tangent/objectivity evidence. Whole Runtime, element pairing and full FX scope remain separate.

## Related Designs
Source child DESIGN.md files link here. Public SwiftMechanics import only; immutable fixture inputs and per-test accepted states.

## Architecture
```text
three independent physical fixtures -> public protocol requirements
 -> original analytic/conservation/derivative checks + typed failure paths
```

## Contracts and Invariants
No shared mutable globals, files, sessions or work buffers; Swift Testing suites run concurrently. Tolerances are explicit absolute+relative and reflect original constitutive outputs, not solver status alone. Near-zero energy and transformed tensors must be exercised on actual production paths.

## Verification and Change Impact
Pinned Swift 6.4.0 Native focused product compile/link and bounded parallel suite execution; record actual results after running. WASM/Embedded/minimum macOS13 and performance remain unqualified.

### Selected Native qualification (2026-10-06)
Swift 6.4.0 release on arm64 macOS27.0.1. Canonical SwiftMechanics plus MechanicsThreeConstitutiveTests compiled/linked; final 16 public tests in three concurrent suites passed. Final build8.16s, test execution0.001s. Twenty exact source/test hashes match `.build/constitutive-evidence/source-freeze.json`. The public Burgers long-unloading case first failed with a zeroed finite tail, then passed after stable exponential endpoint evaluation. One source review and finding-only recheck completed; no unrelated implementation or broader test claim follows.

| Profile | Storage/isolation | Read/mutation/release | Qualification |
|---|---|---|---|
| Native | Immutable Sendable laws, history and responses; immutable injected Sendable supplier witness for SLS | Required public witnesses; only bounded local arithmetic/series variables mutate; caller retains history/provider | Selected compile/link/behavior passed |
| WASM | Identical stored types, conformance and witness contracts | Same value ownership; matching math ABI still requires qualification | Not built/executed in this task |
| Embedded | Identical stored types, conformance and witness contracts | Same value ownership and isolation; no lock/reference owner was removed | Not built/executed in this task |

Element/Runtime integration, minimum macOS13, performance, portable profiles and complete210 scope remain unqualified. Exact commands:

```sh
python3 Scripts/run_with_timeout.py 300 <swift-6.4.0-RELEASE>/usr/bin/swift build --build-path .build/six-native --product MechanicsThreeConstitutiveTests -j 2
python3 Scripts/run_with_timeout.py 60 <swift-6.4.0-RELEASE>/usr/bin/swift test --build-path .build/six-native --skip-build --test-product MechanicsThreeConstitutiveTests --disable-xctest --enable-swift-testing -j 2
```
The red test used the same public product and filter longUnloadingPreservesTheFiniteExponentialTail. Final full product evidence includes all unchanged SLS/Neo-Hookean paths and the corrected Burgers component. Test constants/physical envelopes remain unchanged during the correction; no tolerance relaxation, tail clipping or stack adjustment was used.
