# Mechanics Island Dynamics Tests

## Purpose and Scope

Dedicated SwiftPM test owner for [StationaryIslandDynamics](../../Sources/SwiftMechanics/Physics/Mechanisms/StationaryIslandDynamics/DESIGN.md). Parent: [Package](../../DESIGN.md). No children. It proves lower actual physical and mapping authority, not accepted sleep/contact evolution.

## Responsibilities and Boundaries

Own independently compiled fixtures and physical/source/work falsification. Production compiler, Dynamics, Constraints and mechanism solvers remain qualified public suppliers; no test manufactures their internal handles or lowers physical tolerances.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Package](../../DESIGN.md) | parent | Registered test ownership | Root owns manifest/profiles | No local target registration |
| [Stationary Islands](../../Sources/SwiftMechanics/Physics/Mechanisms/StationaryIslandDynamics/DESIGN.md) | depends on | prepare/motion/rest evidence | Sole proof subject | No sleep metadata success substitutes for physical evidence |
| [Island Sleep Tests](../MechanicsIslandSleepTests/DESIGN.md) | coordinates with | Lower fixture assumptions | Upper separately proves omission | No shared mutable fixtures |

## Architecture

```text
independent original compiler fixture -> public island preparation
whole original Dynamics oracle <-> mapped actual island Dynamics
changed physical/source/work inputs -> explicit failure + retained known work
```

## Contracts and Invariants

Use fixed static root, two mass2 Z rotors with Izz2 and actual 1:1 transmission row [1,1,0], plus independent mass2 Y-prismatic striker. Descriptor body order differs from actual tree order. Source q=[0,0,0.5], v=[0,0,-1], drive=[0,0,0], M=diag(2,2,2). Real A/B island rest evidence is valid although whole v is nonzero; real C forward motion has v=-1,a=0 and K=1. Awake gear velocities [-2/3,2/3] remain tangent and its genuine constrained acceleration is zero. Compare actual whole source mass/bias/poses/columns and original force residuals with mapped actual compiled island outputs, not hardcoded returned handles.

Preserve exact IDs/normalized scales/units/row order and all original force authority. A separately compiled same-stamp changed inertia, drive, anchor, policy or row must not consume the original program/evidence. A descendant moving branch, uncovered/duplicate coordinate, fake empty row, rank ambiguity or unsupported semantic obligation must be explicitly refused. Capacity before compilation/supplier execution records zero invocations. Inject reset/failure/cancel into each exercised public compiler/equation/dynamics/evaluator/rank/solver boundary; compare exact known numerical/load/compiler receipts and unavailable classification on success/failure. Original typed causes remain inspectable.

## State, Ownership, and Lifecycle

Each case owns its compiler/model/program/work/cancellation. Test counters and fault suppliers use common Mutex and Sendable contracts on all configured targets; no cross-suite global mutation. Evidence may outlive temporary producer operations through its immutable owners; fresh construction cannot depend on another test's cache.

## Failure, Concurrency, and Constraints

All test runs use root-assigned watchdog/resource slots and exact Swift6.4.0 profile. Fixtures have explicit finite compiler/physical/signature/work capacities. No generated-cache copy or supplier source change is part of this target. Simultaneous/reentrant usage checks operation-local evidence independence and exactly known work without mutable current source.

## Verification and Change Impact

The component owner runs the assigned immutable-copy Native proof; root owns registration and original Native/WASM/Embedded plus 128 KiB integration. This design declares required behavioral evidence, not obtained results. Failed physical/source/work oracles block upper composition. Lower source changes renew affected tests once stable; upper omission/event/history/RNG tests belong to their own owner.
