# Planning

## Purpose and Scope
Parent: [Analysis](../DESIGN.md). Own selected physical planning queries and path time parameterization. Children: [TimeParameterization](TimeParameterization/DESIGN.md) and [PoseIK](PoseIK/DESIGN.md).

## Responsibilities and Boundaries
Planning consumes admitted models, supplied tasks and paths. Dynamics owns physical operators and Runtime owns accepted simulation state. Planning cannot commit a simulation step.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [PoseIK](PoseIK/DESIGN.md) | child | Bounded source-bound point/orientation/pose inverse kinematics | Selected Native8/public7 at frozen2124 | Fixed-root spatial Euclidean chart and acute-angle branch; collision and wider domains fail explicitly |
| [Analysis](../DESIGN.md) | parent | Query composition | Index authority | Preserve query/state boundary |
| [TimeParameterization](TimeParameterization/DESIGN.md) | child | Certified physical prismatic retiming | Owns selected physics, limits and replay | Native qualified; portable profiles and broader trajectory domains remain open |

## Architecture
```text
admitted physical path + model + bounded limits
    -> child retiming contract
    -> original continuous physical acceptance
    -> immutable retimed path or typed failure
```

## Contracts and Invariants
Preserve units, frames, model/source revision and original physical acceptance. No partial or unsupported result is successful. Child contracts own their specific assumptions and guarantees.

## State, Ownership, and Lifecycle
Inputs/results are immutable Sendable values. Each synchronous operation exclusively owns its workspace. Planning cannot mutate accepted simulation state.

## Failure, Concurrency, and Constraints
Invalid or stale identity, unsupported domains, physical infeasibility, work/storage exhaustion and cancellation propagate typed failures. Caller policy bounds operation work and allocation.

## Verification and Change Impact
Child-local physical success/failure tests and public replay own behavior. Native registration uses the full1872-source composition and original eight tests/seven public cases. Fixed WASM/Embedded qualification remains open. Recheck affected child evidence when consumed contracts change; entire210 remains open.
