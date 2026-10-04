# MechanicsClosedLoopReactionTests

## AF25 Reduced Planar Evidence
The additive planar suites consume actual PhysicalConstrainedMechanismSolving and sealed physical allocation. The independent pi/2 fourbar uses original MassProperties2D(m=1, COM origin, Iz=1), physically identified crank torque one, zero originalDrive/velocity/gravity and original coincidence XYZ scale two. Actual joint-coordinate identity determines acceleration slots; all rows, rank two/nullity one and representative Z multiplier remain. Physical endpoint and cut/root balances distinguish physical wrench uniqueness from multiplier uniqueness. Reduced tests also own distance normalization, offset identified force/support moment/frame conversion, full original source/time/layout/motion/refusal, active duplicate/toggle ambiguity, opaque actual assembly source/inertia swap and success/failure ledger reset/merge cancellation/resource bounds. Existing spatial evidence remains unchanged. Root executes frozen tests and original profiles; this section does not claim new runtime success before execution.

```text
actual planar compiled fourbar/sliders -> sealed rows + actual physical constrained motion
 -> reduced recovery -> independent Fx/Fy/Mz, points, original rows/rank/source, failure prefixes
```

New helpers/results are immutable; NumericalWork/LoadWork/fixture arrays are operation locals. The existing availability-guarded LoopCancellationFlag retains common Mutex storage/access on all targets. Typed do blocks contain only matching typed public operations; untyped fixture construction occurs before those blocks. Test declarations have one-minute limits; root owns external timeout and graph execution.

The constraint Gram solver explicitly selects partialPivotLU. The original mass matrix is mirrored by its producer and keeps the required Cholesky dynamics capability. Original Gram entries come from independent inverse-mass products and independently ordered floating-point accumulations; mathematical symmetry does not establish the bitwise symmetry required by ReferenceLinearSolver's Cholesky branch. LU consumes the unchanged original Gram with unchanged pivot/residual tolerances; no symmetrization, tolerance relaxation or runtime fallback is used.

## Purpose and Scope
Owner: [ClosedLoopReactionPaths](../../Sources/SwiftMechanics/Physics/Mechanisms/ClosedLoopReactionPaths/DESIGN.md). No children. Own selected spatial and reduced planar continuous loop/body/tree/support behavioral oracles.

## Responsibilities and Boundaries
Use actual compiled models, sealed geometry, legacy constrained dynamics and original inertia/load services. Independent arithmetic identifies physical forces and moments. Root owns registration, build/test/profile execution and commits.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [ClosedLoopReactionPaths](../../Sources/SwiftMechanics/Physics/Mechanisms/ClosedLoopReactionPaths/DESIGN.md) | depends on | Public spatial and planar recovery protocols | Planar Fx/Fy/Mz only; no full bearing completion claim |

## Architecture
```text
actual compiled sliders -> original geometry/mass/constrained motion -> recovery
                         -> independent force/moment/source/failure oracles
```

## Contracts and Invariants
Mass 2/3, separation 2, distance scale 4, first identified force 10 imply common acceleration 2 and loop forces -6/+6, multiplier 48 J. Scale changes preserve force. Transverse applied forces at offset points imply independent guide/root support moments. Active redundant physical rows remain ambiguous; planar structural-zero rows retain nonunique multipliers while their physical wrenches are unique. Test work is operation-local; immutable fixtures have no shared resource.

## Verification and Change Impact
Root runs frozen focused Native with timeout and original Native/WASM/Embedded public profiles at unchanged stack. Tests refuse stale/time/geometry/row/input/drive/impulse/planar/support/capacity/cancel and supplier reset on success/failure from zero and precharged prefixes. No tests/builds are executed by this source owner. Changes to original source, covectors, rank or tree balance invalidate this evidence.

The cancellation fixture owns a common `Mutex<Bool>` on all targets, reads and writes exclusively through `withLock`, invokes no callback under the lock, and releases its owner at synchronous test scope exit. There is no conditional storage/isolation/conformance. Root's Native test execution proves that fixture path; production has no shared stored state.

The first registered focused Native run passed all 13 test declarations in three suites, including four parameterized ledger cases with two actual reset kinds each (`.build/af24-upper-native-tests.log`). Swift 6.4.0 release, macOS 27 arm64, `.build/ar01-native`, `-j 4` and a 240-second command bound were used. Original-profile public composition remains owned by IM.IM16.25.
