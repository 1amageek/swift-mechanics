# MechanicsJointsTests

## Purpose and Scope
Behavioral ownership of admitted joint manifolds, rooted planar/spatial trees, moving-frame derivatives and Jacobian/power operators (IM06). Parent: [MechanicsJoints](../../Sources/SwiftMechanics/Modeling/Joints/DESIGN.md).

## Responsibilities and Boundaries
Independent analytic fixtures, central configuration-direction derivatives and explicit domain failures. No loop solving, reaction solving or integrated dynamics claims.

## Related Designs
[KinematicAlgebra](../../Sources/SwiftMechanics/Modeling/Joints/KinematicAlgebra/DESIGN.md), [JointManifolds](../../Sources/SwiftMechanics/Modeling/Joints/JointManifolds/DESIGN.md), [ArticulatedTrees](../../Sources/SwiftMechanics/Modeling/Joints/ArticulatedTrees/DESIGN.md), [Jacobians](../../Sources/SwiftMechanics/Modeling/Joints/Jacobians/DESIGN.md).

## Architecture
```text
local independent fixture -> actual joint/tree operator -> analytic/differential/power oracle
```

## Contracts and Invariants
Tests use local immutable descriptors and explicit numerical/capacity policy. No shared filesystem/database/static fixtures. Tests verify body-origin versus world-origin wrench distinction, 7/6 quaternion mappings and supplied moving-anchor derivative behavior.

## Verification and Change Impact
Run timeout-wrapped swift test --build-path .build/joint-kernels --filter MechanicsJointsTests. Exact-profile Native/WASM/Embedded execution is root-owned; native behavioral evidence does not imply unrun platforms or complete mechanics integration.

AF23 PrescribedMotionTests owns analytic translation/fixed-axis rotation, exact pinned pose, original sample rejection, interval and metadata capacity. It does not qualify physical moving-base dynamics.

AF25 [PrescribedMotions](../../Sources/SwiftMechanics/Modeling/Joints/PrescribedMotions/DESIGN.md) owns the additive base-motion contract. `PrescribedBaseMotionTests` exercises the required sampler and sealed original acceptance on independent noncommuting spatial q/v/a/qdot and planar unwrapped-angle formulas. It covers chart/plane/frame/time/law refusal, changed real producer source, seeded supplier success/failure reset, known/unavailable failure prefixes, work/storage and late cancellation. The sole shared test cancellation state is Mutex<Bool> with the same storage/isolation across targets; test availability guards preserve the platform deployment contract. Root owns registered graph test execution and original profile probes. No mathematical test asserts COM dynamics, force, energy or Runtime replay completion.

| Logical state | Native | WASM | Embedded | Read / mutation / release |
|---|---|---|---|---|
| Test late-cancellation flag | Mutex<Bool> | Mutex<Bool> | Mutex<Bool> | cancelled()/supplier completion both withLock; callback mathematics outside lock; local immutable owner released at test end |
| Production base/rank evidence | immutable Sendable let fields | same | same | public reads; no mutation or shutdown |
| Work / scratch | exclusive operation locals | same | same | inout work and local arrays; no shared access |

### AF25 lower Native qualification

The frozen source executed 26 declarations in six suites, including all six PrescribedBaseMotion tests. Exact Swift 6.4.0 release/macOS 27 arm64, `.build/ar01-native`, `-j 4`, and a 240-second external timeout were used. Logs: `.build/af25-lower-native-tests.log` and the allocation-only `.build/af25-allocation-native-recheck.log`. Original production did not change during test-helper corrections. Source/profile composition is canonical in [FoundationVerification](../../Verification/FoundationVerification/DESIGN.md#af25-lower-integrated-qualification); full upper/root/loop domains remain separate.
