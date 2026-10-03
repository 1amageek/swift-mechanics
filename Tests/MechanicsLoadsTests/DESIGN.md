# MechanicsLoadsTests

## Purpose and Scope
Test owner for initial IM11 ForcePorts, PassiveLaws, CableRouting and CustomLaws. Parent [package](../../DESIGN.md). No children.

## Responsibilities and Boundaries
Own Native behavioral proof of admitted force/energy/derivative/resource contracts. Root owns cross-target runtime composition and dynamics evolution.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [ForcePorts](../../Sources/MechanicsLoads/ForcePorts/DESIGN.md) | depends on | Framed load and impulse mapping | Original virtual/actual power | Correct torque reference |
| [PassiveLaws](../../Sources/MechanicsLoads/PassiveLaws/DESIGN.md) | depends on | Admitted analytic laws | Energy/dissipation/geometry | Chart domain explicit |
| [CableRouting](../../Sources/MechanicsLoads/CableRouting/DESIGN.md) | depends on | Straight route differential | Independent finite differences | No wrap behavior claimed |
| [CustomLaws](../../Sources/MechanicsLoads/CustomLaws/DESIGN.md) | depends on | Cooperative immutable callback | Derivative and failure | No runtime rollback claimed |

## Architecture
```text
manufactured immutable fixtures -> public services -> independent equation or finite difference
                                 -> invalid/resource/provider failure assertions
```

## Contracts and Invariants
Tests exercise public requirement dispatch and actual admitted equations. Expected power and potential derivatives are calculated independently. Inputs remain unchanged.

## Failure, Concurrency, and Constraints
No shared mutable fixtures. Each test owns workspace and budget. Timeout wrapper 180 seconds and private .build/load-kernels.

## Verification and Change Impact
Analytic spring/gravity/bushing/pressure/medium tests, routing finite differences, Joints JT and prescribed drift, custom failure and all budget boundaries. New physics domains require new owner tests; these do not close all FL requirements.
