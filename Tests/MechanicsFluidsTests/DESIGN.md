# MechanicsFluidsTests

## Purpose and Scope
Own behavioral evidence for [Fluids](../../Sources/MechanicsFluids/DESIGN.md), initial channel formulation. Qualification pending actual execution; no whole EX-005 claim.

## Responsibilities and Boundaries
Independent continuum hydrostatics/Couette/Poiseuille and transient sine oracles, original discrete momentum and physical/numerical energy, actual Runtime accepted/rejected/checkpoint paths. Tests use real Numerical and Compiler/Runtime implementations; no numerical mock success.

## Related Designs
[Channel](../../Sources/MechanicsFluids/ChannelDiscretization/DESIGN.md), [Evolution](../../Sources/MechanicsFluids/ViscousEvolution/DESIGN.md), [Continuation](../../Sources/MechanicsFluids/Continuation/DESIGN.md) own production authority. Existing producer tests remain read-only.

## Architecture
```text
independent physical oracle -> actual discretization/solver -> residual and refinement
real compiled fixed carrier -> real Runtime -> accept/reject/restart comparison
```

## Contracts and Invariants
Deterministic local fixtures and immutable contexts. Counter/rollback tests exercise actual contributor and physical time. Injected cancellation delegates to real solver, then synchronized flag; no fabricated numeric result. Comparison tolerances declared per physical oracle; successful diagnostics alone are insufficient.

## State, Ownership, and Lifecycle
All fixture state call-owned. Cancellation owner uses identical Synchronization.Mutex<Bool> and availability on all targets; read/write entries withLock, no I/O under lock, owner retained through solve.

## Failure, Concurrency, and Constraints
Focused timeout execution root-owned after source registration. Typed failure cases must reject invalid geometry/material/domain, stale payload/time, insufficient work/storage, numerical nonconvergence/residual, cancellation and deferred migration. No shared static mutable fixtures.

## Verification and Change Impact
Mesh/time refinement, closed-form physical balance and real Runtime replay establish only selected channel domain and executed profile. Broader fluid/FSI/compressibility remains unqualified. Change to physical or wire contract rechecks associated fixture paths.

| Profile | Shared state | Isolation | Read | Mutation | Release |
|---|---|---|---|---|---|
| Native / WASM / Embedded | cancellation Bool in Mutex<Bool> | same withLock | owner.read | owner.cancel | owner reference retained by solver/policy, then released |

No conditional storage, unchecked Sendable or unsafe pointer path exists. Allocator capacity is not claimed zero-copy measured; immutable COW arrays and reused call-local buffers avoid cell-loop intermediate arrays.

Root regression calls the actual channel solve inside Runtime with an exhausted solver iteration budget, after real matrix/RHS assembly. The FluidError-to-RuntimeFailure bridge must preserve unknown failed supplier work, last accepted complete prefix and known outer charges.

AF16 actual root qualification: seventeen Native tests passed, including mesh/time refinement and real Runtime solver-failure unknown-work regression, within the final 391-test/27-module run. Original Native/ordinary-WASM/Embedded public hydrostatic/Couette/BE balance and Runtime reject/accept/checkpoint replay and failed-prefix probes exited 0. No PlanarProjection/FSI/free-surface/compressibility or acceleration evidence is included.
