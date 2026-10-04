# ScalarCalculus

## Purpose and Scope
Initial admitted implementation domain; behavioral/profile qualification pending. Parent: [module](../DESIGN.md). Children: none. Own checked Float64 first directional calculus and derivative failure/resource semantics for OP-002. Full OP-001/002 remains open beyond the published smooth domains.

## Responsibilities and Boundaries
Own exact product/chain rules for addition, multiplication, division, positive square root, sine and cosine. No finite differences or substitution of a different primal backend. Supplier arithmetic is separately attributed; numerical work counts this component's arithmetic and metadata traversal.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Numerics](../../../Mathematics/Numerics/DESIGN.md) | depends on | NumericalWork | Caller cumulative budget | Failed nested consumption may be unavailable |
| [TreeTangents](../TreeTangents/DESIGN.md) | used by | Exact directional primitives | Spatial recurrence | No chart branch differentiation |
| [Tests](../../../../../Tests/MechanicsDerivativesTests/DESIGN.md) | used by | Behavioral evidence | Independent oracles | Qualification pending |

## Architecture
```text
finite scalar + direction -> checked exact rule -> finite value + direction
                              | budget/cancel/domain -> typed failure
```

## Contracts and Invariants
Directions are derivatives with respect to one dimensionless perturbation parameter; physical input units remain unchanged. Division rejects zero denominator, square root rejects nonpositive argument. Nonsmooth/unsupported operations return derivativeUnavailable. NumericalTolerance is caller-owned acceptance, not a differentiation rule. Every primitive charges a declared arithmetic upper bound before evaluation; fixed-size vector/matrix primitives have declared arithmetic counts and no heap intermediate arrays. UTF8 identity traversal is charged before equality; immutable String storage is borrowed. Core public arithmetic has fixed declared upper bounds (rotation/normalization: 200 scalar units, Matrix3 product: 45, vector cross: 9; elementary sine/cosine count as one unit each), and scalar constructors only validate finiteness.

## State, Ownership, and Lifecycle
Immutable Sendable values; operation-local arithmetic ledger. Exclusive inout work is retained even on failure. No shared mutable state or target-dependent storage. Output and workspace capacities are checked with overflow-safe products before allocation.

## Failure, Concurrency, and Constraints
Typed errors preserve Core, Numerical, Joint, Constraint and Dynamics failures. Supplier call ledger counts admitted public invocation attempts, not unknown supplier internal arithmetic; its caller maximum and cancellation are checked before invocation. Failed supplier work is explicitly unavailable where the supplier does not return it. No retry after failed supplier. Caller owns all limits and callbacks are Sendable.

## Verification and Change Impact
Scalar chain-rule/domain/budget tests and real mechanical products distinguish wrong derivatives. Changes affect all three sibling components and test owner.
