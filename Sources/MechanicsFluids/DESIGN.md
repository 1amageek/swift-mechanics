# MechanicsFluids

## Purpose and Scope
Parent [system/package](../../DESIGN.md). Own IM44 fluid evolution and EX-005 under [SPEC](../../SPEC.md). This is source dispatch only; no registered capability or behavior qualification. Child links follow actual lower contracts.

## Responsibilities and Boundaries
material_kernels owns new child directories and Tests/MechanicsFluidsTests. Root owns this index, Package.swift, shared scripts/probes, PROGRESS, producer edits and commits. Frozen Beams/StructuralAnalysis remain read-only. Select identified physical equations, discretization, boundary data and bounded time evolution. Coupling, vehicle control and acceleration remain separate owners.

## Related Designs
[Implementation plan](../../IMPLEMENTATION_PLAN.md) owns IM03/08/09 prerequisites. [Numerics](../MechanicsNumerics/DESIGN.md), [Runtime](../MechanicsRuntime/DESIGN.md) and [Integration](../MechanicsIntegration/DESIGN.md) are read-only public producers. Child contracts must establish the actual consumed operations and producer limitations.

## Architecture
```text
identified fluid + discretization + boundary/time data
 -> bounded physical evolution -> original conservation/residual acceptance
 -> accepted state or explicit failure preserving accepted prefix
```

## Contracts and Invariants
Declare SI quantities, frame/source/revision, formulation and boundary assumptions. Actual hydrostatic/viscous-flow and refinement oracles exercise the selected implementation. Stability restrictions and convergence status must remain visible. No fabricated samples or silent fallback certify fluid behavior.

## State, Ownership, and Lifecycle
Child contracts own state/workspace lifetime and accepted/rejected publication. Shared mutation uses identical isolation and Sendable contracts across Native/WASM/Embedded; no conditionally removed locks.

## Failure, Concurrency, and Constraints
Typed admission, unsupported domain, stability, solver, resource and cancellation failures; checked caller budgets precede allocation. Failed supplier work is unavailable where not reported, and stops computation.

## Verification and Change Impact
Source-first independent physical/failure tests precede root registration and actual execution. Producer gaps require root coordination before edits. Full EX-005 and whole-target IM48 remain incomplete until applicable behavior evidence exists.
