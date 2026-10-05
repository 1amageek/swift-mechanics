# Derivatives component

## Purpose and Scope
Parent: [responsibility owner](../DESIGN.md). IM30 owns smooth mechanical derivatives under [SPEC](../../../../SPEC.md). Frozen exact-product source handed to root for registration and behavioral qualification; full IM30 remains open.

## Responsibilities and Boundaries
The original child/test source snapshot is frozen. Root now owns review regression corrections and qualification; linear_kernels owns separate Granular source. Root exclusively owns this module index, Package.swift, shared probes/scripts, PROGRESS and commits. Dependencies are read-only: Core, Model, Joints, Constraints, Dynamics, Numerics, Loads. Producer changes require root coordination and an explicit reassignment before editing.

## Related Designs
[Canonical implementation plan](../../../../IMPLEMENTATION_PLAN.md) owns prerequisite IDs; [root](../../../../DESIGN.md) owns composition. Only verified public producer contracts may be consumed. Child designs own exact selected operations, assumptions and evidence, without duplicating supplier internals.

## Architecture
```text
identified producer inputs -> bounded owned computation -> original acceptance evidence
 -> immutable qualified result or typed failure with preserved accepted prefix
```

## Contracts and Invariants
Actual tree tangent recurrences, constraint products, mass/bias/force sensitivities and implicit acceleration products. Scalar AD alone does not prove derivatives through the existing Double mechanics path.
Units, frames, revision, chart, fidelity, parameter provenance and temporal meaning must remain explicit. Numerical status alone cannot establish physical acceptance. The full assigned requirements persist where an initial admitted domain does not cover them. Callable incomplete branches have markers and explicit failure; no silent substitute qualifies a requirement.

## State, Ownership, and Lifecycle
Child designs establish operation state, persistent contributor state, source/borrow lifetime and accepted/rejected publication before declarations. Shared state has identical Mutex/actor storage, isolation and Sendable contracts on Native/WASM/Embedded. Callbacks and resource release occur outside control locks.

## Failure, Concurrency, and Constraints
Public typed errors expose stale binding, unsupported domain, nonfinite inputs, cancellation, capacity and known/unknown supplier work. Each child declares caller-owned budgets before allocation. There is no build/profile qualification during source dispatch.

## Verification and Change Impact
The assigned owner traces producer implementations and fixes each required physical oracle before source. Native tests exercise actual physics and failed paths, not declarations. Root registers stable production targets and qualifies selected public operations on exact profiles after source freeze. Direct/transitive consumers must recheck changed assumptions. Full IM48 remains incomplete.

| Child | Owned public contract |
|---|---|
| [GeometryParameters](GeometryParameters/DESIGN.md) | Selected analytic placement/root/axis products; full1983 Native9/public8 qualified, portable and broader derivative domains remain open |
| [ScalarCalculus](ScalarCalculus/DESIGN.md) | Checked exact directional scalar algebra and failure/work policies |
| [TreeTangents](TreeTangents/DESIGN.md) | Actual spatial motion/Jacobian/chart products |
| [ConstraintProducts](ConstraintProducts/DESIGN.md) | Scaled physical quadratic-constraint products |
| [MechanicalSensitivities](MechanicalSensitivities/DESIGN.md) | Mass/bias/force and implicit acceleration products |
| [ContactProducts](ContactProducts/DESIGN.md) | AF27 selected constitutive/impact fixed-branch products and refusal boundaries; selected canonical Native/WASM/Embedded qualification passed; [evidence](../../../../Verification/FoundationVerification/DESIGN.md#af27-integrated-selected-qualification) |

Root reviewed actual primal tree/dynamics, differentiated physical products, original equation acceptance and failure budgets. Twenty-two Native tests pass after rejecting callback ledger reset and correcting independent fixture expectations for stationary hinge origins and cumulative nested solver iterations. Required public pendulum mass/gravity/implicit product and complete drive Jacobian plus unavailable scalar domain compiled, linked and exited 0 on original Native/ordinary-WASM/Embedded WASM profiles. All production state is immutable or exclusive call-local; no target-conditioned synchronization or conformance. These selected paths do not qualify missing planar/geometric-parameter/rank-transition/contact derivative domains.

### Consolidation contract
This directory is a component inside the SwiftMechanics module, not a separate SwiftPM target. Its existing public behavior and exact-profile evidence remain its contract authority. Cross-component access uses the documented contracts; internal visibility alone does not grant admission or publication authority. Source relocation requires integrated behavioral requalification.

## AF27 contact derivative dispatch

nonlinear_mechanisms exclusively owns the new ContactProducts child and Tests/MechanicsContactDerivativeTests. Read qualified contact/impact primal paths before defining selected derivative semantics; fixed-active validity and nonsmooth refusal are part of the contract. Existing children and all producers remain read-only. Root owns this index, registration, public composition and commits. See [AF27 dispatch](../../../../IMPLEMENTATION_PLAN.md#af27-independent-source-and-verification-dispatch).
