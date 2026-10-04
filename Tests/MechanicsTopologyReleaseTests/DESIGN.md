# MechanicsTopologyReleaseTests

## Purpose and Scope
Behavioral verification of [SubtreeTransitions](../../Sources/SwiftMechanics/Physics/Mechanisms/SubtreeTransitions/DESIGN.md) and [TopologyContinuation](../../Sources/SwiftMechanics/Physics/Mechanisms/TopologyContinuation/DESIGN.md). Root owns graph registration and exact profile execution.

## Responsibilities and Boundaries
Use actual compiler/Joints/Dynamics/Runtime/Actuation producers. Independently sum body linear/angular momentum and kinetic energy, check all world motions and raw coordinate mappings, independently inspect original target force equations, and exercise persisted contributor bytes through fresh checkpoint owners. No copied private source or type-only proof.

## Related Designs
Lower owner designs above define contract and change impact. Legacy AcceptedTransitions tests remain separate.

## Architecture
```text
moving chain fixture -> cut subtree -> independent body oracle -> actual target forward force solve
 -> complete catalog/history/actuator migration -> atomic owner replacement -> second cut/replay/restart
```

## Contracts and Invariants
Each fixture owns immutable models/providers and local ledgers. Failure cases check exact accepted checkpoint and RNG. Callbacks use local mutable work, with no shared mutable test resources.

## Verification and Change Impact
Root runs timeout-bound Native focused tests after registration, then selected original Native/WASM/Embedded paths. Full tests are not run by this worker before root provides a slot. Unsupported v1 import, loop/prescribed runtime and bearing-wrench trigger coverage remain explicit.
