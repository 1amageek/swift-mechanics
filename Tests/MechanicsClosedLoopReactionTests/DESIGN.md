# MechanicsClosedLoopReactionTests

## Purpose and Scope
Owner: [ClosedLoopReactionPaths](../../Sources/SwiftMechanics/Physics/Mechanisms/ClosedLoopReactionPaths/DESIGN.md). No children. Own selected spatial continuous loop/body/tree/support behavioral oracles.

## Responsibilities and Boundaries
Use actual compiled models, sealed geometry, legacy constrained dynamics and original inertia/load services. Independent arithmetic identifies physical forces and moments. Root owns registration, build/test/profile execution and commits.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [ClosedLoopReactionPaths](../../Sources/SwiftMechanics/Physics/Mechanisms/ClosedLoopReactionPaths/DESIGN.md) | depends on | Public recovery protocol | No planar or full bearing completion claim |

## Architecture
```text
actual compiled sliders -> original geometry/mass/constrained motion -> recovery
                         -> independent force/moment/source/failure oracles
```

## Contracts and Invariants
Mass 2/3, separation 2, distance scale 4, first identified force 10 imply common acceleration 2 and loop forces -6/+6, multiplier 48 J. Scale changes preserve force. Transverse applied forces at offset points imply independent guide/root support moments. Original redundant rows remain ambiguous. Test work is operation-local; immutable fixtures have no shared resource.

## Verification and Change Impact
Root runs frozen focused Native with timeout and original Native/WASM/Embedded public profiles at unchanged stack. Tests refuse stale/time/geometry/row/input/drive/impulse/planar/support/capacity/cancel and supplier reset on success/failure from zero and precharged prefixes. No tests/builds are executed by this source owner. Changes to original source, covectors, rank or tree balance invalidate this evidence.

The cancellation fixture owns a common `Mutex<Bool>` on all targets, reads and writes exclusively through `withLock`, invokes no callback under the lock, and releases its owner at synchronous test scope exit. There is no conditional storage/isolation/conformance. Root's Native test execution proves that fixture path; production has no shared stored state.

The first registered focused Native run passed all 13 test declarations in three suites, including four parameterized ledger cases with two actual reset kinds each (`.build/af24-upper-native-tests.log`). Swift 6.4.0 release, macOS 27 arm64, `.build/ar01-native`, `-j 4` and a 240-second command bound were used. Original-profile public composition remains owned by IM.IM16.25.
