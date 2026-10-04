# Analytic collision producer evidence

## Purpose and Scope
Parent: [MechanicsCollision](../../Sources/SwiftMechanics/Physics/Collision/DESIGN.md). Children: none. Owns initial analytic geometry, conservative discovery, value continuation and fixed-rotation translation CCD fixtures; full CL closure remains unimplemented.

## Responsibilities and Boundaries
Independent SI formulas establish sphere/box/plane distance and witness balances, support bounds, inside/edge/tie, rays, filtering, persistence and original TOI brackets. Physical contact/dynamics, generic convex/concave geometry, rotating CCD and accepted-time event scheduling remain outside evidence.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Shapes](../../Sources/SwiftMechanics/Physics/Collision/Shapes/DESIGN.md) | depends on | Proxy/domain identity | Explicit collision authority | Display independent |
| [Geometry](../../Sources/SwiftMechanics/Physics/Collision/Geometry/DESIGN.md) | depends on | Actual analytic queries | Geometric original residuals | Feature tolerance band |
| [Discovery](../../Sources/SwiftMechanics/Physics/Collision/Discovery/DESIGN.md) | depends on | Candidate/filter/query ordering | Exhaustive independent contacts | Conservative extras allowed |
| [Persistence](../../Sources/SwiftMechanics/Physics/Collision/Persistence/DESIGN.md) | depends on | Value-owned histories | Sliding and trigger deltas | Sampled geometry only |
| [Sweep](../../Sources/SwiftMechanics/Physics/Collision/Sweep/DESIGN.md) | depends on | Fixed orientation actual interpolation | Independent analytic TOI | No rotation claim |

## Architecture
```text
Frozen SI formulas/shape geometry -> public protocol production paths -> independent assertions
Invalid/stale/capacity/cancellation fixtures -> typed failure -> unchanged accepted values
```

## Contracts and Invariants
Meter-scale analytical fixtures freeze 1e-10 m absolute+1e-11 relative*1 m tolerances and 1e-8 s TOI width. Proxy refinement uses known sphere radius deviations .1 m and .01 m. Exhaustive sphere candidates use independent center-distance formulas; transformed support checks all eight box vertices. Tests share no mutable resources and suites have one-minute limits. User filter fixtures are immutable Sendable services with explicit work reports and typed failures.

## Verification and Change Impact
Run `python3 Scripts/run_with_timeout.py 180 swift test --build-path .build/collision-kernels --filter 'GeometryTests|DiscoveryTests|PersistenceTests|SweepTests'`. Root registers source/test targets and owns exact Native/WASM/Embedded composition including EmbeddedUnicode capability. Changed equations/feature conventions/lifecycle or motion assumptions invalidate corresponding fixtures. No source geometry, force/impulse, arbitrary CCD or complete CL claim follows from this subset.
