# MechanicsConstraintsTests

## Purpose and Scope
Parent [package](../../DESIGN.md); no children. Own actual Native behavioral evidence for [CoordinateEquations](../../Sources/MechanicsConstraints/CoordinateEquations/DESIGN.md), [AssemblyProjection](../../Sources/MechanicsConstraints/AssemblyProjection/DESIGN.md), [ScalarJointPorts](../../Sources/MechanicsConstraints/ScalarJointPorts/DESIGN.md).

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
