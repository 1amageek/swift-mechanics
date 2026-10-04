# Coordinates

## Purpose and Scope
Own base q/v layout records and round-trip conversion for fixed, planar floating and spatial floating roots (RB-006 record contract). Parent: [MechanicsModel](../DESIGN.md). No children.

## Responsibilities and Boundaries
Declare q/v counts and storage order, validate supplied coordinate arrays, and convert base state to/from immutable Core transforms. Joint layouts, model compilation and evolving simulation states belong downstream.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Model](../DESIGN.md) | parent | Composition | Registers records | Base layout only |
| [Core Geometry](../../../Mathematics/Core/Geometry/DESIGN.md) | depends on | UnitQuaternion | Distinct orientation and angular velocity | Input normalization requires acceptance policy |
| [Bodies](../Bodies/DESIGN.md) | depends on | PlanarPose | Planar chart | +z angle convention |

## Architecture
```text
BaseState -> BaseLayout.encode -> q/v arrays -> BaseLayout.decode -> BaseState
```

## Contracts and Invariants
Fixed q/v counts are 0/0; fixed state has no base coordinates and its fixed placement belongs to the body descriptor. Planar q is [x,y,angle] and v is [vx,vy,omegaZ] in world axes. Spatial q is [x,y,z,qw,qx,qy,qz] and v is [vx,vy,vz,omegaBodyX,omegaBodyY,omegaBodyZ], with translation/world COM velocity and body angular velocity. Counts are 7/6 and never inferred equal. Positions are meters, linear speeds m/s, angles radians, angular speeds rad/s. Spatial input quaternion norm must be accepted by the caller's dimensionless NumericalTolerance, then canonical UnitQuaternion normalization is explicit; zero quaternion always fails. Arrays must match exactly, contain finite values and match state dimension. No absent state is replaced with a default. Values own storage; no mutable registry or borrowed lifetime.

## Verification and Change Impact
Test owner: [MechanicsModelTests](../../../../../Tests/MechanicsModelTests/DESIGN.md).

CoordinateTests proves fixed/planar/spatial counts, transform and velocity round-trip, quaternion rejection and count/dimension/nonfinite failure. Joint compiler and runtime consumers recheck count/order/frame convention changes.
