# Smooth Equation and Chart Contracts

## Purpose and Scope
Own an explicit smooth Euclidean Float64 coordinate equation, dimensional per-coordinate error scales and pure required chart/equation callbacks. The provider binds model stamp, published chart identity, coordinate dimensions and complete physical q/v mapping. Parent: [MechanicsIntegration](../DESIGN.md). No children.

## Responsibilities and Boundaries
This component owns the preceding responsibility and its immutable public artifacts. Runtime owns physical state/checkpoint/lifecycle; providers own equation and chart semantics. Full TI requirement-family closure remains IM09 after this initial domain.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Integration](../DESIGN.md) | parent | IM09 boundary | Root composition | Full eventual domain retained |
| [Runtime](../../MechanicsRuntime/DESIGN.md) | depends on | Required trial/contributor/snapshot methods | Verified producer 6ae2742 | Nonqueuing admission; macOS 15 baseline |
| [Numerics](../../MechanicsNumerics/LinearAlgebra/DESIGN.md) | depends on | NumericalWork/budget | Supplier declared arithmetic ledger | Failure never authorizes blind retry |
| [Tests](../../../Tests/MechanicsIntegrationTests/DESIGN.md) | verified by | Manufactured equations | Behavioral proof | Exact selected profiles root-owned |

## Architecture
```text
model/chart + immutable equation/policy -> explicit owned stages
 -> dimensional acceptance -> Runtime accept + required continuation
 -> reject/failure -> unchanged accepted prefix
```

## Contracts and Invariants
A coordinate value has its declared SI dimension; its derivative has that dimension per second. Providers implement read/write mappings explicitly, validate the actual model/chart, and preserve descriptor identity. No array-count inference of qdot=v or quaternion chart is permitted. Callbacks only mutate supplied outputs/trial/contributors and charge NumericalWork before execution. Every derivative output is NaN-poisoned, and shape/finiteness checks reject incomplete writes. All continuation-dependent custom subsystem updates must live in declared Runtime contributor state; external side effects are outside this admitted pure domain.

## Runtime Flows
Integrator calls validate(model), reads actual trial coordinates, invokes prepare on declared contributor/RNG state, computes derivatives and writes the accepted chart endpoint. prepare preserves physical chart/time; the integrator checks that preservation and endpoint readback. Callback purity permits retries without external side effects.

## State, Ownership, and Lifecycle
Providers/descriptors/scales are immutable Sendable. Callbacks may mutate only supplied work/output/trial, with lifetime bounded by the call. External mutable simulation history must be declared as required Runtime contributors. Shared state is not created by this component.

## Failure, Concurrency, and Constraints
Descriptor construction uses explicit caller identity-byte and coordinate-count limits. Derivative output lengths/finite values and descriptor identity are checked at each call. Supplier NumericalWork budgets and control quantum are owned by [Stepping](../Stepping/DESIGN.md); providers charge before their own arithmetic, preserve the ledger/budget, and poll each declared quantum. Pure read/write mappings must have an explicit bounded coordinate traversal; arbitrary side effects or hidden iteration are outside this contract.

## Verification and Change Impact
[Test owner](../../../Tests/MechanicsIntegrationTests/DESIGN.md) supplies an actual fixed-root one-hinge Euclidean mapping q'=v and v'=coefficient*q, independently known oscillator/decay solutions, malformed derivative and prepared subsystem rollback. No universal q/v relationship or unproved manifold mapping is inferred. New chart/domain providers need their own behavioral proof.
