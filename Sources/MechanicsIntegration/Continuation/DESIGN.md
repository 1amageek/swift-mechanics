# Accepted Integration Continuation

## Purpose and Scope
Own an exact bounded integrator contributor schema and payload binding equation/model/chart, method/options, accepted time/point, next step and accepted integration sequence. Parent: [MechanicsIntegration](../DESIGN.md). No children.

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
The v1 payload begins with the exact configured descriptor/policy signature and model revision; signatures use byte identity intentionally. It stores accepted time/coordinate point, next step, sequence and optional normalized error. No rejected stage/history is checkpointed. The Runtime contributor callback sees only record/model and certifies its bounded payload and model binding. `associatedHistory` certifies physical time/point at integration entry, including no-op; step admission compares payload association against actual trial chart values/time before any stage. Runtime checkpoint admission alone is not an integration association certificate. Changed options/chart/model/layout require a newly initialized state; migration is explicitly unsupported until the equation provider certifies the changed physical continuation. Parsing validates exact length, finite values, next-step bounds, optional flags and configured signature before success.

## Runtime Flows
Initial physical state plus explicit equation read mapping -> associated initial payload. Runtime admission validates bounded signature/history/model. Integration entry invokes associatedHistory and each trial repeats physical association validation before stages. Accepted publication replaces payload; rejected trials retain the prior payload.

## State, Ownership, and Lifecycle
Immutable Sendable provider/history/signature. Decode owns an n-scalar point buffer and retains input bytes through COW headers; no shared mutable state. Serialization explicitly materializes bounded output bytes, including the signature copy on append.

## Failure, Concurrency, and Constraints
Signature byte estimate is identity UTF8 lengths +136+32n, checked before reserve; this includes eight dimension exponents, absolute/relative scales, n accepted point values and the maximum optional error payload. Validation charges encoded byte count and n*8 scratch bytes. Model/options/chart mismatch, truncation/nonfinite/trailing data or stale physical association fail explicitly. Migration remains marked incomplete and fails; no preserved-history guess.

## Verification and Change Impact
[Test owner](../../../Tests/MechanicsIntegrationTests/DESIGN.md) proves actual checkpoint/restart continuation, corrupt options/signature, missing history and accepted physical association mismatch. Root-selected profiles exercise public required contributor witnesses. Payload or chart association changes invalidate restart and downstream evolution evidence.
