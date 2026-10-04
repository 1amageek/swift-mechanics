# MechanicsConstraintsTests

## Purpose and Scope
Parent [package](../../DESIGN.md); no children. Own actual Native behavioral evidence for [CoordinateEquations](../../Sources/SwiftMechanics/Physics/Constraints/CoordinateEquations/DESIGN.md), [AssemblyProjection](../../Sources/SwiftMechanics/Physics/Constraints/AssemblyProjection/DESIGN.md), [ScalarJointPorts](../../Sources/SwiftMechanics/Physics/Constraints/ScalarJointPorts/DESIGN.md).

## Responsibilities and Boundaries
Analytic independent expected equations, derivatives, weighted corrections/energy and real supplier failure boundaries; root owns integration/platform probes.

## Related Designs
The linked production children own equation, algorithm, unit, resource and failure authority. Tests consume public protocol requirements.

## Architecture
```text
analytic geometry / time / joint fixtures -> public services -> physical expectations and typed failures
```

## Contracts and Invariants
Multiple-root circle intersection uses different explicit initial branches; duplicate rows remain present, contradictory rows fail. Knife-edge velocity/acceleration are independently differentiated. Energy results are checked against supplied physical diagonal metric.

## State, Ownership, and Lifecycle
Independent local fixtures/work; no shared mutable state.

## Failure, Concurrency, and Constraints
Timeout180, private .build/constraint-kernels after root target registration. No platform evidence inferred from Native tests.

## Verification and Change Impact
Focus the closed published algorithms, original residual, rank and resources; rerun affected contracts after causal changes.
`RankAnalysisTests` exercises the required standalone protocol on retained independent/dependent/zero rows, explicit independence policy, nonzero drift, stale and malformed samples, finite admission, cancellation and bounded workspace/work. Rank evidence never certifies force or feasibility. Existing assembly/projection tests cover the shared sample-validation path changed for the additive operation.

AF25 `ActiveCoordinateRankTests` consumes the additive AssemblyProjection requirement with full original layouts and rows, independent/dependent restricted tangents, ordered indices, empty D and zero original rows. It verifies exact retained sample/policy fields, inactive nonfinite rejection, stale binding, index/capacity/storage/work/cancellation failures and unchanged legacy zero-row refusal. No shared state or supplier callback is present in rank execution. Root owns focused registered Native and original three-profile proof; restricted rank never claims full physical reaction authority.

### AF25 lower Native qualification

The frozen source executed 24 declarations in six suites, including all five ActiveCoordinateRank tests. Exact Swift 6.4.0 release/macOS 27 arm64, `.build/ar01-native`, `-j 4`, and a 240-second external timeout were used. Logs: `.build/af25-lower-native-tests.log` and the allocation-only `.build/af25-allocation-native-recheck.log`. Original production did not change during test-helper corrections. Source/profile composition is canonical in [FoundationVerification](../../Verification/FoundationVerification/DESIGN.md#af25-lower-integrated-qualification); full upper/root/loop domains remain separate.
