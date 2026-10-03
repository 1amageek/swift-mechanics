# TreeTangents

## Purpose and Scope
Parent: [module](../DESIGN.md). Children: none. Own first directional products through the actual spatial rigid tree motion and geometric Jacobian. Initial implementation admission; profile qualification pending.

## Responsibilities and Boundaries
Differentiate fixed and spatial floating roots, ordered revolute/prismatic/screw factors, universal/cylindrical/planar/custom ordered factors, and spherical/six-DOF charts. Own pose, quaternion-storage coordinate-rate direction, actual velocity/acceleration, geometric columns, prescribed drift and zero-generalized-acceleration bias directions. Root reference pose and fixed anchor poses are immutable for this initial domain. Prescribed anchor samples require explicit pose/velocity/acceleration directional input; no missing derivative is replaced with zero. No evolution, topology sensitivity, rank transition or quaternion logarithm derivative.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Joints](../../MechanicsJoints/DESIGN.md) | depends on | TreeKinematicsComputing, JointMotionEvaluating | Executes and validates primal | Supplier work is public-call ledger only |
| [ScalarCalculus](../ScalarCalculus/DESIGN.md) | depends on | Checked directional arithmetic | Product rules | Float64 only |
| [MechanicalSensitivities](../MechanicalSensitivities/DESIGN.md) | used by | Body/column tangent | COM Newton-Euler derivatives | Must preserve actual angular convention |
| [Tests](../../../Tests/MechanicsDerivativesTests/DESIGN.md) | used by | Tree oracle | Nontrivial serial and floating trees | No FD production |

## Architecture
```text
verified tree + state + local chart direction
 -> primal tree supplier -> ordered frame/column tangent recurrence
 -> immutable body directions + flat geometric column directions
```

## Contracts and Invariants
Configuration direction has velocity-layout length, not quaternion-storage length. Quaternion orientation direction is right body tangent: dR=R[eta]x; floating translation direction is parent/world linear displacement. Scalar factor directions use physical coordinate units (radian or metre). Actual velocity and acceleration are independent directional inputs. Quaternion storage-rate product differentiates qdot=0.5*q*(0,omegaBody), with dq=0.5*q*(0,etaBody); sign follows the current normalized quaternion representative. dBias=d(actual acceleration)-dJ*a-J*da; nonzero supplied a never disappears. Ordered screws use prefix spatial adjoint then endpoint conversion; geometric columns are world angular/linear velocity at each body origin. A body's COM point derivative uses transported offset. Snapshot primal is generated from the same tree/state, not supplied mismatched metadata. Prescribed sample directions are ordered exactly as immutable state samples and time perturbation requires supplied full motion derivative; missing data fails. This instantaneous contract does not infer jerk or a time law.

## Runtime Flows
Check capacities and all finite directions; prescribed sample count cannot exceed two anchors per joint; precharge all supplied tree/sample identity bytes before the primal call; invoke primal supplier once; recursively compose differentiated frames; append columns without per-inner-loop arrays; verify reconstructed primal frame/columns against supplier with caller tolerance; publish after final cancellation check. A failed supplier stops once.

## State, Ownership, and Lifecycle
Caller-exclusive workspace retains body frames/column records. Fixed-size local factors have at most six columns; reused scratch. Immutable output owns copies at publication; both workspace and output initialized scalar slots are charged. The admission bound is 400*B+48*B*N+1440 scalar slots: supplier body/frame/joint snapshots and coordinate rates, both directional frame/column owners, body result/bias records, and six-factor scratch. Previously retained initialized workspace records are added to preflight storage before mutation/allocation. This is a conservative logical scalar bound, not allocator byte capacity/rounding or retained unused Array capacity. No view escapes a borrow, no unsafe storage.

## Failure, Concurrency, and Constraints
Planar body domain, unsupported chart/domain, stale revision, shape/metadata/nonfinite/cancellation/resource and primal mismatch fail typed. The tree constructor owns topology validity. Numerical and supplier-invocation budgets are separate; no claim about unreported supplier arithmetic.

## Verification and Change Impact
Independent central pose/velocity differences only in tests; exact two-link Jacobian and nonzero-a bias, quaternion body/world convention, screw products, prescribed drift, rejection/budget evidence. Changes recheck MechanicalSensitivities and module composition.
