# PassiveLaws

## Purpose and Scope
Own bounded SI scalar spring/damper laws, Gram-factor passive six-axis chart bushing, affine gravity, fixed independent mass/traction quadrature and lumped isotropic drag/buoyancy (FL-001..005). Parent: [MechanicsLoads](../DESIGN.md). No children. This is an initial closed-domain producer handoff under [plan](../../../../../IMPLEMENTATION_PLAN.md); full flexible/spatial-field/follower/aero/wrapping domains remain attributed to IM11.

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
Scalar translation or rotation coordinates have an explicit rest coordinate and finite closed displacement/velocity domains. Nonnegative quadratic/quartic elastic coefficients and linear/cubic damping produce exact potential and nonnegative dissipation. Six-axis deformation coordinates carry an explicit reference-frame identity and are caller-supplied independent local chart coordinates [rotation rad,translation m]; chart velocities are their derivatives, not arbitrary finite-rotation angular velocity. K=B^T B and C=D^T D from finite supplied six-column factors certify PSD without tolerating negative eigenvalues. Coupled entries carry corresponding mixed SI units. Gravity is symmetric affine g=a+G*x in the declared frame at a declared instant, with uniform explicit time derivative; force=m*g, potential=-m(a dot x+x dot G*x/2). Independent mass/area samples own geometry provenance; summation is exact for those samples only. Fixed traction/pressure quadrature has no follower tangent. Drag uses medium-relative velocity, coefficient bounded speed and F=-c1*v-c2*abs(v)*v; dissipation is relative-medium power, moving-medium work is prescribed. Buoyancy uses supplied displaced volume and center, F=-rho*V*g. No missing geometry is manufactured.

## Runtime Flows
Validate domain/identity -> reserve peak scalar capacity -> charge logical work before repeated operations -> evaluate checked finite equation -> return immutable evidence. Every charge checks cancellation. No retry, backend or law substitution. Unsupported callable branches have explicit incomplete markers and fail.

## State, Ownership, and Lifecycle
Public values are immutable Sendable; only caller-owned inout LoadWork and operation-local arrays mutate. Scalar capacity counts simultaneously owned numerical arrays allocated by the operation; borrowed immutable input arrays are excluded. Output-boundary arrays allocate once, not per inner arithmetic operation. Local buffers die with the call; returned arrays retain owned backing. No pointers, shared caches or target-specific storage.

## Failure, Concurrency, and Constraints
LoadError distinguishes invalid/nonfinite/domain/frame/unsupported/provider/resource/cancellation failures. Work is a declared logical accounting unit, not wall-clock latency. Caller sets maxWork/maxScalars and cancellation callback, never guessed limits. Overflow checked before capacity products and sums. Counters retain consumed work on failure. Custom callbacks cooperate with accounting and purity; external code cannot be sandboxed by these values.

## Verification and Change Impact
Independent energy finite differences; damper/drag power; coupled bushing gradients; affine gravity sampled resultants; pressure area/moment; submerged-volume force; domain and coefficient/finite rejection. Changes to admitted equations, origin, layout, accounting or failure behavior invalidate Loads consumers IM14/15/16 and module platform probes. No integration/time evolution is claimed.
