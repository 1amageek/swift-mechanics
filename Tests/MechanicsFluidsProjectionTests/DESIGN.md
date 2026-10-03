# MechanicsFluidsProjectionTests

## Purpose and Scope
Own behavioral proof for [PlanarProjection](../../Sources/MechanicsFluids/PlanarProjection/DESIGN.md), an initial periodic 2D physical domain. Tests and exact-profile execution are pending; no whole EX-005 claim.

## Responsibilities and Boundaries
Use actual Numerics solver and independent discrete/continuum oracles, not mock numeric answers. Verify pressure gauge and all removed/retained original rows, nonlinear advection/viscosity, conservation/work, time/mesh refinement and explicit typed failures.

## Related Designs
[Fluids](../../Sources/MechanicsFluids/DESIGN.md) is parent requirement owner; [PlanarProjection](../../Sources/MechanicsFluids/PlanarProjection/DESIGN.md) owns equations/layout; [Numerics](../../Sources/MechanicsNumerics/DESIGN.md) supplies real bounded solves. Frozen Channel tests are separate.

## Architecture
```text
independent potential/streamfunction/Taylor–Green/shear
 -> actual MAC operations -> physical residual, conserved mean/work, refinement
```

## Contracts and Invariants
Source/field fixtures immutable and local. Pressure fixtures include nonzero discarded-row forcing so omitting that original row is detectable. Wrong-RHS wrapper delegates to a real solver for a different equation, and final original checks must reject it. Cancellation delegates to actual successful solve then sets the same Mutex-protected owner. No physically fabricated solver result.

Taylor–Green continuum mesh refinement uses n=8,12,16 at nu=0.1 m²/s, T=0.05 s and ten equal steps, with exact amplitude exp(-2*nu*T). This is a selected asymptotic fixture range, not a guarantee of monotonic error for every admitted grid. At n=4 the nonlinear double wavenumber lies at Nyquist and many staggered velocity samples vanish; coarse donor sampling and central-diffusion under-decay cancel part of the continuum error. An independent initial modal-rate calculation, -<w,R>/<w,w>, gives viscous plus donor decay rates [1/s] of 0.1621138938+0.2250790790 at n=4 and 0.1899282407+0.2383989343 at n=8, compared with continuum 0.2. Thus the initial truncation error is already smaller at n=4; expecting monotonic n=4→8 error is invalid. The donor dot-work identity balances to roundoff in this calculation.

Independent separable Fourier Helmholtz projection uses the original periodic pressure-pencil eigenvalues 4*(sin²(pi*kx/n)+sin²(pi*ky/n))/h², without the production pressure assembly or numerical solver. Its ten-step continuum RMS errors are n=4:0.00457306012950, n=8:0.00584995649165, n=12:0.00457432902095, n=16:0.00363494210585, with all-step discrete divergence below 4.5e-16 [1/s]. This reproduces the coarse-grid counterexample and establishes the n=8,12,16 oracle choice; it does not replace actual solver execution. The actual test retains strict decreasing error, final error <0.02 m/s, every original residual/energy/CFL check and existing budgets. The largest mesh is 256 cells, within the existing caller limit. Native/profile requalification remains root-owned.

## State, Ownership, and Lifecycle
Fixture state call-owned. Test cancellation Bool lives in identical Synchronization.Mutex<Bool> across profiles, read and write via withLock, owner retained until operation completion. Availability is inside test bodies, not SwiftTesting suite/test annotation. Production has no shared mutable state.

## Failure, Concurrency, and Constraints
Root executes focused timeout tests after stable registration. Test budgets explicit; no independent builds while source evolves. Bounded deterministic n and time-step counts exercise real nonlinear terms. Native/profile evidence remains local to actually executed paths.

## Verification and Change Impact
Independent conservation, projection, diffusion and continuum convergence tests own this contract. Changes to grid/flux/stability/gauge require corresponding oracles. General BC/free-surface/compressibility/FSI and Runtime continuation are not covered by these tests.

| Profile | Shared storage | Isolation | Read | Write | Owner release |
|---|---|---|---|---|---|
| Native / ordinary WASM / Embedded | Mutex<Bool> | same withLock | read | cancel after actual solve | policy/solver retain owner until call returns |

No target-dependent state/conformance, unsafe pointer, unchecked Sendable or hidden cache path is present. Logical live storage is admitted; allocator capacity/copy count is not claimed measured.

Root AF17 qualification: Ten actual Native cases pass in `.build/af17-integrated-native.log`. Public profile execution belongs to FoundationVerification and covers its selected operations, not this whole test target on WASM. Full requirement gaps remain with the parent module.
