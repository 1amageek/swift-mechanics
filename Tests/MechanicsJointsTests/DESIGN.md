# MechanicsJointsTests

## Purpose and Scope
Behavioral ownership of admitted joint manifolds, rooted planar/spatial trees, moving-frame derivatives and Jacobian/power operators (IM06). Parent: [MechanicsJoints](../../Sources/SwiftMechanics/Modeling/Joints/DESIGN.md).

## Responsibilities and Boundaries
Independent analytic fixtures, central configuration-direction derivatives and explicit domain failures. No loop solving, reaction solving or integrated dynamics claims.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Joints](../../Sources/SwiftMechanics/Modeling/Joints/DESIGN.md) | parent | Mathematical component index | Source owner and test context | Root owns parent changes |
| [KinematicAlgebra](../../Sources/SwiftMechanics/Modeling/Joints/KinematicAlgebra/DESIGN.md) | depends on | FrameMotion and parent-axis composition | Moving-origin derivative meaning | Mathematical tests do not prove Dynamics |
| [JointManifolds](../../Sources/SwiftMechanics/Modeling/Joints/JointManifolds/DESIGN.md) | depends on | Original q/v chart operations | Chart/rate behavior | Preserve independent scalar oracles |
| [ArticulatedTrees](../../Sources/SwiftMechanics/Modeling/Joints/ArticulatedTrees/DESIGN.md) | depends on | Tree and prescribed-anchor sample contracts | Actual sample consumers | Full inventory is tree authority |
| [Jacobians](../../Sources/SwiftMechanics/Modeling/Joints/Jacobians/DESIGN.md) | depends on | Velocity and power mappings | Joint/tree operator evidence | No reaction allocation claim |
| [PrescribedMotions](../../Sources/SwiftMechanics/Modeling/Joints/PrescribedMotions/DESIGN.md#af26-additive-lower-trajectory-contract) | verifies | Immutable law, sampling and original acceptance | Trajectory behavioral owner | AF26 ports are design-only until implementation/qualification |

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

## AF26 Lower Trajectory Proof Plan
This is design-only. No AF26 test source, fixtures or runtime evidence exists yet. Mathematical law/domain/chart/work authority is defined once in [PrescribedMotions](../../Sources/SwiftMechanics/Modeling/Joints/PrescribedMotions/DESIGN.md#af26-additive-lower-trajectory-contract); this owner defines falsifiable evidence and does not duplicate its contract. Actual implementation registration, Native execution and original Native/WASM/Embedded composition belong to root after a frozen lower handoff.

```text
raw scalar harmonic/polynomial oracle + immutable finite law records
  -> actual builtin mathematical sample through nongeneric required ports
    -> original sealed acceptance and canonical chart output
      -> exact source/failure-prefix/bounds/knot witness
```

| Proposed dedicated suite | Actual path and independent oracle | Refusal / boundary evidence |
|---|---|---|
| HarmonicPrescribedMotionTests | Anchor program sampling against separately evaluated sine/cosine position, first and second derivatives, fixed parent-axis rotation, nonidentity pinned pose and repeated periods | Invalid frequency/axis/frame/time/products/domain, exact reference bits, identifier/metadata/work capacity |
| PiecewisePrescribedMotionTests | Distinct known scalar/vector quintic polynomials in adjoining intervals; compare samples against original polynomial coefficients and their direct derivatives, not the producer's Hermite basis | Exact endpoints, knot/right-side and final/left-side convention, adjacent sided derivative limits, non-C2 position/velocity/acceleration failure with exact seam and first broken derivative |
| PrescribedBaseTrajectoryTests | Actual planar and noncommuting spatial base sampler; independently compute unwrapped angle, raw quaternion components, body omega/alpha and quaternion derivatives; independently difference q and v | XY plane rejection from nonplanar amplitudes/jets, chart/frame/world/source mismatch, reference quaternion bits, no cycle/knot angle reset |
| PrescribedTrajectoryAcceptanceTests | Every new sealed anchor/base port delegates to the actual builtin producer; alternate real law/program values with the same IDs/time establish wrong-source counterexamples | Changed coefficients/phase/knots/domain/kind/metadata, reset on return and throw, known failure prefix, unavailable failure, late cancellation and exhausted arithmetic/iteration/storage; preserve terminal error and admitted seeds |
| PrescribedTrajectoryBoundaryTests | Actual earliest-knot query on complete multi-frame inventory and single base; compare to independently scanned declared source knot times | Before/on/after knot, strict-after skipping, inclusive limit, no harmonic knot, invalid/outside-domain query, changed real query source, reset/known/unknown/cancel/capacity |

Polynomial fixtures retain independently supplied original coefficients and analytically derived endpoint jets. Multiple segments differ in jerk or higher derivatives while matching their position/velocity/acceleration jets. A sampling test that merely compares the two producer paths is insufficient. Source-tag differences are checked even when two laws coincide at the requested time; full original metadata remains observable. The proposed non-C2 error must identify the lowest derivative order and actual seam, not a broad unsupported outcome.

Legacy PrescribedMotionTests and PrescribedBaseMotionTests remain exact compatibility evidence. Additive regression verifies unchanged old public getter types/field meanings, constructors, raw samples and old metadata/signatures. Where shared internal mathematical/chart phases are extracted, compare old sample fields and metadata to fixed original fixtures, including signed/nonidentity quaternion and planar principal/unwrapped branch. A new quadratic-tagged trajectory uses its new schema; it must not masquerade as an old program or return a fake old inventory.

All tests use operation-local immutable descriptors/programs/oracles and exclusive NumericalWork. Fault/cancellation evidence, if shared with a Sendable supplier, has the identical Mutex-backed owner and withLock entry points on Native/WASM/Embedded; actual mathematics and callbacks run outside that lock. No static fixture cache, filesystem sharing, fake force calculation or target-specific state is introduced. Failed opaque work cannot trigger an automatic retry. Pure mathematical test results do not qualify compiled geometry binding, physical effort/energy/work, stage integration order, Runtime publication or cold replay.

After lower qualification, root/upper test owners must independently exercise a real periodic cam and C2 piecewise moving-root/anchor mechanism, knot-clipped refinement, original q/v/a/full-force/power, exact endpoint/history, cold replay and rollback. Until real non-C2 event handling is supplied and executed, complete SPEC KI-006 remains open even when the lower selected trajectory tests pass.
