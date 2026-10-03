# CustomLaws

## Purpose and Scope
Own immutable scalar custom-law snapshot evaluation and independent finite-difference derivative/energy verification (FL-007/008). Parent: [MechanicsLoads](../DESIGN.md). No children. This is an initial closed-domain producer handoff under [plan](../../../IMPLEMENTATION_PLAN.md); full flexible/spatial-field/follower/aero/wrapping domains remain attributed to IM11.

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
Provider is Sendable and all operations are requirements. Caller supplies immutable state snapshot and scalar coordinate/rate; provider may not mutate accepted state or external state and must charge its executed logical work through operation-local counters. Responses are immutable, so there is no mutable output buffer/metadata bypass. Provider identity, coordinate kind, budget limits and monotone accounting must remain equal/valid before/after every callback. The owner checks its captured cancellation closure after callbacks, even if a provider replaces its inout work value. Three force components are conservative/dissipative/active, with independent derivative requirements. Conservative classification is verified only at the evaluated point and its caller-sized probes, not for the whole law. Any nonzero conservative component among the five probes requires energy values, centered finite-difference -dE/dq agrees with center force, and conservative force/energy are locally independent of rate. If all conservative components are zero and energy was not requested, nil energy is explicitly unavailable; dissipative component must have force*rate<=caller roundoff tolerance. Total derivative is independently probed in q and rate using caller steps/tolerances, and callback failure propagates. This is a cooperative provider contract, not CPU-time sandboxing; runtime checkpoint/reentry ownership remains IM08.

## Runtime Flows
Validate domain/identity -> reserve peak scalar capacity -> charge logical work before repeated operations -> evaluate checked finite equation -> return immutable evidence. Every charge checks cancellation. No retry, backend or law substitution. Unsupported callable branches have explicit incomplete markers and fail.

## State, Ownership, and Lifecycle
Public values are immutable Sendable; only caller-owned inout LoadWork and operation-local arrays mutate. Scalar capacity counts simultaneously owned numerical arrays allocated by the operation; borrowed immutable input arrays are excluded. Output-boundary arrays allocate once, not per inner arithmetic operation. Local buffers die with the call; returned arrays retain owned backing. No pointers, shared caches or target-specific storage.

## Failure, Concurrency, and Constraints
LoadError distinguishes invalid/nonfinite/domain/frame/unsupported/provider/resource/cancellation failures. Work is a declared logical accounting unit, not wall-clock latency. Caller sets maxWork/maxScalars and cancellation callback, never guessed limits. Overflow checked before capacity products and sums. Counters retain consumed work on failure. Custom callbacks cooperate with accounting and purity; external code cannot be sandboxed by these values.

## Verification and Change Impact
Manufactured cubic custom law derivative and potential; thrown provider failure; forged derivative/energy; mutation of identity via synchronized negative fixture; invalid output; work and storage boundaries. Changes to admitted equations, origin, layout, accounting or failure behavior invalidate Loads consumers IM14/15/16 and module platform probes. No integration/time evolution is claimed.
