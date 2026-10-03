# CableRouting

## Purpose and Scope
Own straight waypoint route length, first differential and second directional differential, generalized tension forces and prescribed-route work (FL-006). Parent: [MechanicsLoads](../DESIGN.md). No children. This is an initial closed-domain producer handoff under [plan](../../../IMPLEMENTATION_PLAN.md); full flexible/spatial-field/follower/aero/wrapping domains remain attributed to IM11.

## Responsibilities and Boundaries
Own the published equations and failures below. Dynamics integration, accepted runtime state, arbitrary geometric inference, and rollback are consumer responsibilities. Caller owns resource limits, admissible domains and accuracy policy.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Module](../DESIGN.md) | parent | Producer scope | Loads composition | Initial domains only |
| [Core](../../MechanicsCore/DESIGN.md) | depends on | Finite geometry, SI dimensions and spatial duality | Checked vector arithmetic | Wrench origin is explicit |
| [Model](../../MechanicsModel/DESIGN.md) | depends on | Entity identity and supplied mass | Provenance stays caller owned | No geometry-derived mass inference |
| [Joints](../../MechanicsJoints/Jacobians/DESIGN.md) | depends on | Immutable framed Jacobian columns and prescribed drift | JT and virtual power | Fixed velocity layout and matching reference |
| [Tests](../../../Tests/MechanicsLoadsTests/DESIGN.md) | used by | Public operation requirements | Behavioral verification | Native evidence has local scope |

## Architecture
```text
immutable SI input + caller policy -> local work/resource checks -> admitted equation
                                      | failure                  -> immutable evidence
                                      v
                               typed LoadError
```

## Contracts and Invariants
Caller supplies ordered immutable points in one frame, their derivatives with respect to independent SI coordinates, and prescribed velocity. Every segment must exceed caller minimum length. Length=sum(norm(delta)); gradient=sum(unit dot deltaJ); directional Hessian=sum((norm(deltaJ*d)^2-(unit dot deltaJ*d)^2)/norm(delta)). Generalized loads=-tension*gradient; actual cable length rate includes prescribed drift, separated from virtual coordinate rate. Pull-only tension must be finite nonnegative. Pulley contact, wrapping and branch switching are explicit unsupported failures, never straight-line substitutions. Tangent is with respect to independently affine waypoint coordinates; nonlinear joint second derivatives are unavailable and not fabricated.

## Runtime Flows
Validate domain/identity -> reserve peak scalar capacity -> charge logical work before repeated operations -> evaluate checked finite equation -> return immutable evidence. Every charge checks cancellation. No retry, backend or law substitution. Unsupported callable branches have explicit incomplete markers and fail.

## State, Ownership, and Lifecycle
Public values are immutable Sendable; only caller-owned inout LoadWork and operation-local arrays mutate. Scalar capacity counts simultaneously owned numerical arrays allocated by the operation; borrowed immutable input arrays are excluded. Output-boundary arrays allocate once, not per inner arithmetic operation. Local buffers die with the call; returned arrays retain owned backing. No pointers, shared caches or target-specific storage.

## Failure, Concurrency, and Constraints
LoadError distinguishes invalid/nonfinite/domain/frame/unsupported/provider/resource/cancellation failures. Work is a declared logical accounting unit, not wall-clock latency. Caller sets maxWork/maxScalars and cancellation callback, never guessed limits. Overflow checked before capacity products and sums. Counters retain consumed work on failure. Custom callbacks cooperate with accounting and purity; external code cannot be sandboxed by these values.

## Verification and Change Impact
Central differences of length/gradient and directional second derivative; endpoint virtual force work; prescribed drift; coincident segment, unsupported branch and capacity failures. Changes to admitted equations, origin, layout, accounting or failure behavior invalidate Loads consumers IM14/15/16 and module platform probes. No integration/time evolution is claimed.
