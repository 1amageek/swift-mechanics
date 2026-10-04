# Fixed-orientation translation CCD

## Purpose and Scope
Parent: [MechanicsCollision](../DESIGN.md). Owns sphere-sphere and sphere-half-space time-of-impact bracketing under independently linearly translated endpoints with fixed orientations. Children: none. Rotating blades, sphere-box sweeps, general convex motion and deforming geometry remain explicitly unsupported/deferred.

## Responsibilities and Boundaries
Pose translation is start+(end-start)*t for normalized t in [0,1]; both shapes may translate, including the plane. Shape/source/frame/margin identity must match endpoints. Rotations must be exactly equivalent quaternions up to sign. Result times use caller duration seconds. CCD refers to explicit proxy geometry; approximation metadata does not establish source-geometry TOI accuracy.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Module](../DESIGN.md) | parent | CL-006 initial subset | Composition | No rotation coverage claim |
| [Shapes](../Shapes/DESIGN.md) | depends on | Immutable endpoints/identity/budgets | Motion authority | Exact fixed orientation |
| [Geometry](../Geometry/DESIGN.md) | depends on | Original signed separation/witness | Geometric acceptance | Same margin convention |
| [Discovery](../Discovery/DESIGN.md) | coordinates with | Translation-swept AABB candidate bound | Broadphase | Does not establish TOI |

## Architecture
```text
endpoint identities/fixed rotations -> actual linear relative motion
closest sphere-sphere time / monotone plane endpoint -> separating/contact bracket
bounded bisection on original geometric separation -> checked TOI interval + upper witness
```

## Contracts and Invariants
Initial separation<=0 returns [0,0]. Otherwise sphere-sphere minimum occurs at clamped -d0·v/(v·v), while sphere-plane separation is linear with minimum at an endpoint. A strictly positive minimum above spatial tolerance certifies no-hit; a positive minimum within tolerance is unresolved and fails rather than declaring no-hit. An actual nonpositive minimum supplies an upper contact endpoint. Bisection maintains original separation(lower)>0 and separation(upper)<=0; accepted time width<=caller maximumTimeWidthSeconds and witness balance are checked. When the minimum separation is zero, the minimum-time upper endpoint is retained: an earlier midpoint whose separation rounds to nonpositive is unresolved and fails, rather than moving the upper endpoint before the true tangent time. Thus tangency is admitted only when the requested time width is resolved before this rounding ambiguity. Midpoint stagnation or exhausted explicit iteration budget fails. No closed-form translation formula is generalized to rotation.

## State, Ownership, and Lifecycle
Sweep services and endpoint/result records are immutable Sendable; O(1) local workspace is operation-owned. No interpolation callback, hidden motion cache, shared mutation or accepted-step state exists.

## Failure, Concurrency, and Constraints
Unsupported pair/rotation, changed endpoint geometry/frame/source, invalid duration/time tolerance, arithmetic failure, unresolved minimum, nonconvergence, capacity/work/storage/cancel fail explicitly. Failed trials return no partial TOI.

## Verification and Change Impact
[SweepTests](../../../../../Tests/MechanicsCollisionTests/SweepTests.swift) independently derives high-speed sphere-plane crossing and sphere-sphere TOI, includes moving plane, initial overlap/no hit/tangent, verifies both original bracket signs and width, and rejects rotating sweep/budget/source edits. Frozen spatial tolerance 1e-10 m+1e-11 relative*1 m; ordinary requested time width 1e-8 s. A 1e-12 s tangent request rejects an early rounded-zero separation that otherwise produces a bracket excluding the independently known contact time 0.5 s. Changes recheck future continuous-contact/runtime consumers; physical dynamics remain unverified.
