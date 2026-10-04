# Separate restitution prediction
## Purpose and Scope
Parent [module](../DESIGN.md). Owns scalar threshold restitution loss predictions only. Children: none.
## Responsibilities and Boundaries
No velocity update, impulse, integration, drop trajectory or accepted impact history. IM21/24 compose those algorithms later.
## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [MaterialPairs](../MaterialPairs/DESIGN.md) | depends on | explicit loss policy | Prevent normal-loss double count | Damping-only rejects impact prediction |
| [Inputs](../Inputs/DESIGN.md) | depends on | typed errors/budget | Scalar bounds | SI speed/energy |
## Architecture
```text
validated pair separateImpact policy + approach speed/normal kinetic energy
 -> threshold effective restitution -> rebound speed/retained/lost energy
```
## Contracts and Invariants
Approach speed>=0 m/s, incoming normal kinetic energy>=0 J. If speed<threshold, effective e=0, otherwise configured e applies (equality is active). Return rebound speed=e speed, retained energy=e² incoming energy, loss=(1-e²)incoming energy. Input speed and energy must both be zero or both positive, avoiding an inconsistent scalar state. They represent one pre-impact normal mode; no mass inference. Pair validation prevents additional selected normal damping. Damping-only is a complete domain rejection of this separate-impact operation.
## State, Ownership, and Lifecycle
Immutable Sendable stateless service/records; operation-local fixed workspace. No committed evolution or hidden history.
## Failure, Concurrency, and Constraints
Invalid speed/energy, incompatible policy, nonfinite arithmetic, budget/cancel fail explicitly. No callable declaration of a coupled impact step is provided.
## Verification and Change Impact
[ImpactTests](../../../../../Tests/MechanicsContactLawsTests/ImpactTests.swift) independently verifies speed regimes/equality/energy fractions and rejects double counting and incompatible zero/nonzero input. Actual drop-height/impact refinement remains an IM21/24 integration obligation.
