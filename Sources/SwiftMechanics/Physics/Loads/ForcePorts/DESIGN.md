# ForcePorts

## Purpose and Scope
Own framed point/wrench loads, impulse mapping, work partition and operation-local resource accounting (FL-008/RB-008). Parent: [MechanicsLoads](../DESIGN.md). No children. This is an initial closed-domain producer handoff under [plan](../../../../../IMPLEMENTATION_PLAN.md); full flexible/spatial-field/follower/aero/wrapping domains remain attributed to IM11.

## Responsibilities and Boundaries
Own the published equations and failures below. Dynamics integration, accepted runtime state, arbitrary geometric inference, and rollback are consumer responsibilities. Caller owns resource limits, admissible domains and accuracy policy.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Module](../DESIGN.md) | parent | Producer scope | Loads composition | Initial domains only |
| [Core](../../../Mathematics/Core/DESIGN.md) | depends on | Finite geometry, SI dimensions and spatial duality | Checked vector arithmetic | Wrench origin is explicit |
| [Model](../../../Modeling/Model/DESIGN.md) | depends on | Entity identity and supplied mass | Provenance stays caller owned | No geometry-derived mass inference |
| [Joints](../../../Modeling/Joints/Jacobians/DESIGN.md) | depends on | Immutable framed Jacobian columns and prescribed drift | JT and virtual power | Fixed velocity layout and matching reference |
| [Tests](../../../../../Tests/MechanicsLoadsTests/DESIGN.md) | used by | Public operation requirements | Behavioral verification | Native evidence has local scope |

## Architecture
```text
immutable SI input + caller policy -> local work/resource checks -> admitted equation
                                      | failure                  -> immutable evidence
                                      v
                               typed LoadError
```

## Contracts and Invariants
Inputs use SI: point m, force N, torque Nm, force impulse Ns, torque impulse Nms, energy J, power W. Frame identity and reference point must match Jacobian exactly. Point force and wrench transpose mapping use immutable Joints columns; virtual power uses J*v while prescribed drift contributes separately to actual power. Impulse mapping never updates momentum and never reports power. Explicit frame transformation rotates force and transforms its application point; equivalent wrench torque is cross(point-reference,force).

## Runtime Flows
Validate domain/identity -> reserve peak scalar capacity -> charge logical work before repeated operations -> evaluate checked finite equation -> return immutable evidence. Every charge checks cancellation. No retry, backend or law substitution. Unsupported callable branches have explicit incomplete markers and fail.

## State, Ownership, and Lifecycle
Public values are immutable Sendable; only caller-owned inout LoadWork and operation-local arrays mutate. Scalar capacity counts simultaneously owned numerical arrays allocated by the operation; borrowed immutable input arrays are excluded. Output-boundary arrays allocate once, not per inner arithmetic operation. Local buffers die with the call; returned arrays retain owned backing. No pointers, shared caches or target-specific storage.

## Failure, Concurrency, and Constraints
LoadError distinguishes invalid/nonfinite/domain/frame/unsupported/provider/resource/cancellation failures. Work is a declared logical accounting unit, not wall-clock latency. Caller sets maxWork/maxScalars and cancellation callback, never guessed limits. Overflow checked before capacity products and sums. Counters retain consumed work on failure. Custom callbacks cooperate with accounting and purity; external code cannot be sandboxed by these values.

## Verification and Change Impact
Analytic off-center moment; rotated/transformed frame; actual versus virtual prescribed power; point and geometric/spatial JT equality; invalid identity and capacity/work/cancellation boundaries. Changes to admitted equations, origin, layout, accounting or failure behavior invalidate Loads consumers IM14/15/16 and module platform probes. No integration/time evolution is claimed.

### Logical accounting and admitted evidence
| Operation | Work units | Simultaneous allocated numerical storage |
|---|---|---|
| Point mapping | one per column plus one power evaluation | V scalars |
| Wrench/impulse transpose | one per column | V scalars |
| Scalar polynomial | one per equation evaluation | no numerical arrays |
| Bushing | one per Gram row; tangent one per Gram row | 12 response scalars or 36 tangent scalars |
| Gravity/traction/fluid | one per supplied sample/evaluation | no numerical arrays |
| Straight route | one per segment, one per segment-coordinate column, one per coordinate rate | V+3P scalars |
| Custom | one per callback plus provider-declared charged work | provider reserves any workspace; evaluator has no numerical arrays |
Input validation and fixed-size geometry arithmetic are part of these logical evaluation units, not individual scalar instruction counts. Cooperative callbacks must account for their own repeated work/storage. Capacity is a peak per public operation and excludes immutable borrowed input/previously returned arrays; consumers composing retained results must budget their aggregate ownership separately.

Native handoff: exact Swift 6.4.0 release, 12 tests in four suites, `python3 Scripts/run_with_timeout.py 180 swift test --build-path .build/load-kernels --filter 'ForcePortsTests|PassiveLawsTests|CableRoutingTests|CustomLawsTests'`, log `.build/load-kernels-focused.log`. This establishes equations/failures for the stated initial domains, not full FL or dynamics completion. Root owns WASM/Embedded/composite qualification.
