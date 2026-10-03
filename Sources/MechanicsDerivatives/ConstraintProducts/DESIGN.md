# ConstraintProducts

## Purpose and Scope
Parent: [module](../DESIGN.md). Children: none. Own exact smooth quadratic coordinate-equation products, including explicit time and identified coefficient directions. Initial implementation domain; qualification pending.

## Responsibilities and Boundaries
Compute dg, dJ, dg_t and acceleration-bias directional products from the verified IM12 polynomial system in its declared SI scaling. No inferred physical reaction or fixed-rank assembly multiplier sensitivity; those are unavailable in this initial domain.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Constraints](../../MechanicsConstraints/DESIGN.md) | depends on | ConstraintEvaluating | Actual primal domain validation | Same fixed layout revision/scales |
| [ScalarCalculus](../ScalarCalculus/DESIGN.md) | depends on | Exact arithmetic/budgets | Own derivative work | Nested actual work retained |
| [Tests](../../../Tests/MechanicsDerivativesTests/DESIGN.md) | used by | Polynomial oracle | Time/scaling/coefficient evidence | No reaction claim |

## Architecture
```text
SI q/v/t + immutable polynomial -> IM12 primal evaluation
    + coefficient and SI directions -> exact polynomial product -> immutable evidence
```

## Contracts and Invariants
x=q/S, u=v*T/S, tau=t/T. Scales and identity are fixed; dg=J dx+g_tau dTau plus coefficient perturbations. dJ=H dx+e dTau plus coefficient terms. Physical Jacobian Gq=J/S; its product uses the same scaling. Coefficient Hessian directions must be symmetric; row IDs/order/revision must match. Directions are finite, with exactly captured dimensions. No finite differences, rank selection or discontinuous coefficient/topology change.

## State, Ownership, and Lifecycle
Immutable inputs/results, local checked output arrays allocated once. One supplier evaluation; cumulative work absorbs actual successful supplier accounting with derivative-owned live storage reserved. No mutable accepted state.

## Failure, Concurrency, and Constraints
Typed underlying constraint failure and conservative unavailable failed supplier work; no retry. Shape/revision/nonfinite/asymmetric derivative/limit/cancel fail. Caller owns capacities, work and tolerances. Same Sendable contract across targets.

## Verification and Change Impact
Independent polynomial directional products, distinct coordinate/time scales, coefficient perturbations and bad derivative/domain/resource tests. Changes affect any consumer differentiating constraints.
