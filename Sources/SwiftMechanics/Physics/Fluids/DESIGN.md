# Fluids component

## Purpose and Scope
Parent [system/package](../../../../DESIGN.md). Own IM44 fluid evolution and EX-005 under [SPEC](../../../../SPEC.md). The frozen channel formulation is registered and qualified on selected exact profiles; the frozen independent multidimensional expansion is registered for qualification under its lower contract.

## Responsibilities and Boundaries
material_kernels owns new child directories and Tests/MechanicsFluidsTests. Root owns this index, Package.swift, shared scripts/probes, PROGRESS, producer edits and commits. Frozen Beams/StructuralAnalysis remain read-only. Select identified physical equations, discretization, boundary data and bounded time evolution. Coupling, vehicle control and acceleration remain separate owners.

## Related Designs
[Implementation plan](../../../../IMPLEMENTATION_PLAN.md) owns IM03/08/09 prerequisites. [Numerics](../../Mathematics/Numerics/DESIGN.md), [Runtime](../../Execution/Runtime/DESIGN.md) and [Integration](../../Execution/Integration/DESIGN.md) are read-only public producers. Child contracts must establish the actual consumed operations and producer limitations.

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

## Source Handoff and Independent Expansion
The ChannelDiscretization, ViscousEvolution and Continuation source/test snapshot is frozen for root review and qualification. Its actual public APIs remain read-only during registration. material_kernels next owns only a new `PlanarProjection/` child and dedicated `Tests/MechanicsFluidsProjectionTests/`. This is an independent multidimensional incompressible Newtonian fluid expansion under IM44, using read-only Core/Model/Numerics contracts; it does not require changing the frozen channel Runtime contributor. Lower actual grid/pressure/velocity boundary, stability, numerical work and conservation contracts precede source. Root owns this index and later shared target registration. General free surface/compressibility/FSI/particle claims remain open.

| Child | Responsibility | Qualification |
|---|---|---|
| [ChannelDiscretization](ChannelDiscretization/DESIGN.md) | Identified channel field and boundary data | Native and selected profile qualified |
| [ViscousEvolution](ViscousEvolution/DESIGN.md) | Steady and backward-Euler channel physical balance | Native and selected profile qualified |
| [Continuation](Continuation/DESIGN.md) | Accepted/rejected channel and Runtime contributor | Native and selected profile qualified |
| [PlanarProjection](PlanarProjection/DESIGN.md) | Independent multidimensional velocity/pressure evolution | Selected AF17 profiles qualified |
| [PlanarContinuation](PlanarContinuation/DESIGN.md) | Exact field checkpoint and required Runtime association | Selected AF21 profiles qualified |

Root reviewed the complete channel solve/original residual/time/codec/Runtime paths and preserved numerical unknown-work evidence in the Runtime bridge. Seventeen channel/continuation Native tests pass, including that real exhausted-solver regression. Public hydrostatic/Couette/backward-Euler, accept/reject/checkpoint replay and failed supplier prefix paths compiled, linked and exited 0 on original Native/ordinary-WASM/Embedded WASM with swift-6.4.0-RELEASE/matching SDKs. Embedded required direct Joints imports for physical carrier properties; this visibility correction does not change physics/isolation. At the AF16 channel handoff, PlanarProjection was excluded from registration. Root now registers its frozen AF17 source for qualification; no multidimensional/FSI/free-surface/compressibility qualification is inferred from registration.

## Selected AF17 Qualification

Root registered the fixed source graph after lower review and exercised actual implementations. All 436 Native behavioral tests in 30 registered modules passed in `.build/af17-integrated-native.log`. Selected public compositions compiled/linked and exited 0 on original Native arm64 macOS27, swift-6.4.0-RELEASE_wasm and its matching Embedded SDK with EmbeddedUnicode, Node24.19.0 WASI Preview1; `.build/af17-{native,wasm,embedded}-run.log` owns execution output. Original stack reservation and unmodified produced artifacts were used. This is selected-path evidence, not all Native test paths on WASM, target-wide performance, actual WASI parallelism or full requirement closure.

Planar Native: ten actual pressure/gauge/original divergence/momentum/work/refinement/failed-supplier/cancellation cases; existing seventeen channel cases remain qualified. Public profiles: required periodic pressure projection, mean momentum/acceleration work and typed rejected step. The selected asymptotic Taylor–Green meshes n8/12/16 pass existing thresholds/budgets; the n4 Nyquist/cancellation counterexample and independent explanation are recorded by its test owner. General CFD, planar Runtime and FSI remain open.

## AF18 Independent Planar Continuation Dispatch

Child contract: [PlanarContinuation](PlanarContinuation/DESIGN.md). It owns exact field wire, static carrier binding and whole-checkpoint time/sequence admission. [Runtime tests](../../../../Tests/MechanicsFluidsRuntimeTests/DESIGN.md) own its behavioral evidence; qualification is pending.

material_kernels owns only new `PlanarContinuation/` and `Tests/MechanicsFluidsRuntimeTests/`, with lower DESIGN before source. This child is explicitly excluded from the registered target until freeze. Frozen channel and PlanarProjection source/tests remain read-only. Root owns index/graph/probes/progress/producer changes/commits. The child consumes qualified public PlanarFlowOperating/PlanarState/Grid/Source plus actual Runtime contributor/trial/checkpoint contracts, Core/Model/Joints/Compiler/Numerics. Own exact bounded u/v/pressure/source/time/sequence continuation bound to an immutable grid and Runtime model; actual accepted/rejected/checkpoint/restart semantics with preserved RNG and whole accepted prefix. Wire restoration reconstructs and validates actual state; no out-of-process registry handle masquerades as checkpoint data. General model/grid migration, coupling/FSI and scheduling remain unavailable unless separately admitted. Child contract must fix byte/work/storage limits, failure/unknown supplier-work propagation, ownership/codec signature and original physical acceptance before declarations. Required oracles use actual MAC pressure evolution and a real compiled static-root Runtime carrier, exact reject/accept/restart continuation, untrusted bytes/stale context/budget/cancel/failed actual solver. No child reads channel/projection internal implementation or changes those owners.

### Consolidation contract
This directory is a component inside the SwiftMechanics module, not a separate SwiftPM target. Its existing public behavior and exact-profile evidence remain its contract authority. Cross-component access uses the documented contracts; internal visibility alone does not grant admission or publication authority. Source relocation requires integrated behavioral requalification.

## AF21 Registration Scope

Root registers the frozen PlanarContinuation child and MechanicsFluidsRuntimeTests after one original-path review. The confirmed missing supplier-ledger guard is repaired against the child contract before qualification. [Foundation verification](../../../../Verification/FoundationVerification/DESIGN.md#af21-planar-runtime-qualification-contract) owns selected-profile evidence. Existing channel and projection contracts are unchanged; full EX-005 remains open.

[AF21 selected qualification](../../../../Verification/FoundationVerification/DESIGN.md#af21-selected-original-profile-qualification) closes this static-carrier continuation handoff. Full EX-005 and IM44 remain open.

### Additional AddedInertia law
Child [AddedInertia](SphereAddedInertia/DESIGN.md) owns its selected service contract and independent verification. Existing evolution and parent qualification are retained.
