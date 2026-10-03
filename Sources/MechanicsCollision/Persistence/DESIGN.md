# Geometric manifold and trigger continuation

## Purpose and Scope
Parent: [MechanicsCollision](../DESIGN.md). Owns immutable revision-aware contact feature continuation and sampled geometric trigger enter/exit deltas. Children: none. Multi-point box patches/mesh seam manifold generation and accepted-time runtime events remain deferred.

## Responsibilities and Boundaries
Manifold update consumes current authoritative witnesses; points beyond caller breaking distance are pruned. Candidate duplicates merge by equal features or witness-point distance within caller merge tolerance, retaining the deepest witness. Previous contacts match equal features or merge proximity; ties select smallest prior ID. Stable IDs monotonically increase, are value-owned and never reused. Missing current candidates prune previous contacts. Trigger update refines actual trigger candidate pairs, records overlap at separation<=0 and returns entered/exited pair deltas; it has no force/impulse API.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Module](../DESIGN.md) | parent | Qualified lifecycle subset | Composition | Sampling owner external |
| [Shapes](../Shapes/DESIGN.md) | depends on | Exact pose-independent identity | Stale-state protection | Geometry/frame/source edits require reset |
| [Geometry](../Geometry/DESIGN.md) | depends on | Original current witnesses | Feature continuation | Single deepest box-plane witness |
| [Discovery](../Discovery/DESIGN.md) | depends on | Filtered pairs/current scene | Trigger intersection | Unsupported pair propagates |

## Architecture
```text
current witnesses + optional accepted manifold -> merge/prune -> candidate manifold
current snapshot + optional accepted trigger state + next sample index
 -> actual overlap pair set -> sorted enter/exit deltas + candidate state
caller accepts result -> next call; rejected call leaves previous values unchanged
```

## Contracts and Invariants
Manifold exact pair identities include both collider/frame/source/shape/margin/resolution records; pose changes are admitted while geometry edits fail stale use. Current candidates must belong to that pair and satisfy original witness residual. All merges/pruning use caller SI tolerances; capacities and O(m²+mp) work are explicit. Trigger initial sample index is zero, each continuation increments by exactly one with checked overflow. Prior pair identities must still exist unchanged in the snapshot; deletion or geometry edits fail lifecycle validation and require explicit caller reset. Output order is collider pair lexical order, independent of input order. No unsampled transit event or accepted-time event guarantee is inferred.

## State, Ownership, and Lifecycle
Manifold/trigger histories are immutable Sendable values with internal result construction. Updates use operation-owned arrays, no shared storage mutation or task ownership. Failure/cancellation cannot commit partial events or modify accepted history.

## Failure, Concurrency, and Constraints
Stale geometry, invalid sequence/reference/candidate, contact ID overflow, exhausted output/storage/work/iteration and unsupported trigger geometry are typed failures. Enter/exit records describe sampled geometry only; mechanics and runtime acceptance are separate contracts.

## Verification and Change Impact
[PersistenceTests](../../../Tests/MechanicsCollisionTests/PersistenceTests.swift) slides a box on a plane preserving feature contact identity, merges/prunes current witnesses, rejects source edits/capacity, and samples sphere trigger pass-through with ordered enter/exit and unchanged rejected history. Changes recheck future IM21/24/26 consumers.
