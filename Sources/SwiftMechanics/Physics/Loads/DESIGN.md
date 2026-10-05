# Loads component

## Purpose and Scope
Parent: [responsibility owner](../DESIGN.md). Responsibility IM11: Framed passive force/work contributions, gravity and routed cable derivatives. Children: [ForcePorts](ForcePorts/DESIGN.md), [PassiveLaws](PassiveLaws/DESIGN.md), [CableRouting](CableRouting/DESIGN.md), [CustomLaws](CustomLaws/DESIGN.md). Component contracts are established before their source and indexed at handoff. The complete target remains governed by [SPEC](../../../../SPEC.md) and [plan](../../../../IMPLEMENTATION_PLAN.md).

## Responsibilities and Boundaries
Framed passive force/work contributions, gravity and routed cable derivatives. Rigid dynamics, actuation and equation composition consume published contracts and own subsequent state evolution/physics and integration. Component designs own exact domains, failure guarantees and verification; root alone owns target/manifest and module indexes.

## Related Designs
| Design | Relationship | Contract used | Summary | Cautions |
|---|---|---|---|---|
| [Responsibility owner](../DESIGN.md) | parent | Scope, owner and requirement DAG | Single-writer package composition | Full feature closure remains IM48 |
| [MechanicsCore](../../Mathematics/Core/DESIGN.md) | depends on | Units, geometric/spatial values and explicit frames | Verified producer handoff at f291f24 | Only documented operations/profiles are qualified |
| [MechanicsModel](../../Modeling/Model/DESIGN.md) | depends on | Body identity/inertia and provenance | Verified producer handoff at f291f24 | Only documented operations/profiles are qualified |
| [MechanicsJoints](../../Modeling/Joints/DESIGN.md) | depends on | Kinematic snapshots and Jacobian transpose/power products | Verified producer handoff at f291f24 | Only documented operations/profiles are qualified |

## Architecture
```mermaid
flowchart LR
  MechanicsCore --> Module[MechanicsLoads]
  MechanicsModel --> Module[MechanicsLoads]
  MechanicsJoints --> Module[MechanicsLoads]
  Module --> Consumers[Rigid dynamics, actuation and equation composition]
```

## Contracts and Invariants
Public service operations are protocol requirements. Accepted records/results satisfy the admitted original invariants, with explicit typed failures identifying unavailable/unsupported capability. Providers and consumers share immutable public values only. A feature declaration or registered callback does not prove its numerical implementation. Component contracts and behavioral tests establish concrete acceptance and failure paths before composition.

## State, Ownership, and Lifecycle
Immutable Sendable inputs/results and exclusively operation-owned mutable value workspace. Shared references require an identical Mutex/actor boundary on every declared target. No target-specific weaker storage/conformance or implicit current-caller isolation is admitted. Evolution/checkpoint acceptance remains IM08.

## Failure, Concurrency, and Constraints
Caller capacity/operation limits and tolerance/domain policy are explicit. Invalid input, incompatible references, cancellation, overflow, unsupported feature and exhausted policy propagate; no invented force or silent alternate law is returned. Native/ordinary WASM/Embedded evidence is separately qualified with the exact toolchain/SDK/link profile from FoundationVerification.

## Verification and Change Impact
Tests/MechanicsLoadsTests owns actual analytic/manufactured behavior and invalid/failure proofs for its components. Root owns exact-profile runtime composition, integration and local commits. Changed producer assumptions invalidate affected compiler/runtime/dynamics/exchange clients; static structures and successful compilation alone are not mechanical evidence.

### Verified initial producer handoff (2026-10-03)
Native Swift 6.4.0 release passed 12 tests in four suites through actual public requirement dispatch. Root reviewed the admitted evaluator/value paths once and independently executed selected scalar energy/dissipation, affine gravity, straight cable gradient/curvature/pull, custom-law admission, cancellation and articulated JT/power checks on Native, matching ordinary WASM and Embedded WASM. Each separately built/linked artifact exited 0; WASM used Node.js 24.19.0 WASI Preview 1, and Embedded used the matching SDK with --traits EmbeddedUnicode. This evidence qualifies those selected operations only. Full FL/RB-008 family closure remains IM11/IM48: pulley/wrapping branch changes, follower tangent, flexible field integration, lift/aero, finite-angle physical bushing wrenches and accepted evolution are not inferred. Child designs own each admitted equation and failure boundary.

### Consolidation contract
This directory is a component inside the SwiftMechanics module, not a separate SwiftPM target. Its existing public behavior and exact-profile evidence remain its contract authority. Cross-component access uses the documented contracts; internal visibility alone does not grant admission or publication authority. Source relocation requires integrated behavioral requalification.

## Side-task environmental loads

Five independent selected laws consume the qualified public core/load contracts. Their domain and proof owners are the following child designs:

- [SphereHydrostatics](SphereHydrostatics/DESIGN.md): FL-005; SL01.
- [DirectionalHydrodynamics](DirectionalHydrodynamics/DESIGN.md): FL-005; SL02.
- [AerodynamicPolars](AerodynamicPolars/DESIGN.md): FL-005; SL03.
- [FollowerPressure](FollowerPressure/DESIGN.md): FL-004; SL04.
- [HarmonicGravity](HarmonicGravity/DESIGN.md): FL-001;FL-008; SL05.

### Additional Dahl law
Child [Dahl](DahlFriction/DESIGN.md) owns its selected service contract and independent verification. Existing evolution and parent qualification are retained.
