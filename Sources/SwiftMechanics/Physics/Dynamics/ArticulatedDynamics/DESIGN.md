# ArticulatedDynamics

## Purpose and Scope
Parent: [Dynamics](../DESIGN.md). No children. IM.AF35.3 owns a real scalar-joint spatial articulated-body forward/inverse-mass recursion for DY-005. Source is excluded/unqualified until later behavioral and target qualification. No sparse constrained formulation or complete joint-family claim is made.

## Responsibilities and Boundaries
Derive acceleration through per-body Featherstone articulated inertia elimination and recovery. Original Joints owns tree order, fixed-anchor transforms, joint subspaces and geometric acceleration bias. Original Dynamics owns Newton/Euler and energy acceptance. Original Loads owns gravity evaluation and its separate ledger. Dense mass assembly is an independent acceptance oracle after the recursive candidate, never the source of the candidate. There is no dense solve, generic numerical tree elimination, Runtime mutation or contact-force allocation.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Dynamics](../DESIGN.md) | parent | DY-005 responsibility | Additive child | Source-only status |
| [Trees](../../../Modeling/Joints/ArticulatedTrees/DESIGN.md) | depends on | Public body/joint order, bodyIndex, snapshots and ranges | Parent-before-child topology | Never use private parent arrays as authority |
| [JointManifolds](../../../Modeling/Joints/JointManifolds/DESIGN.md) | depends on | Published relative motion/subspace | Scalar S in original q/v chart | Larger joint families are refused |
| [RigidEquations](../RigidEquations/DESIGN.md) | depends on | Spatial inertia input, original residual and energy | Independent acceptance | Assembly remains quadratic |
| [Loads](../../Loads/PassiveLaws/DESIGN.md) | depends on | Framed uniform gravity point response | Actual body load | LoadWork is not numerical arithmetic |
| [LinearAlgebra](../../../Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | Checked caller work/budget | Bounded scalar elimination | No injected solve or hidden regularization |

## Architecture
```text
actual spatial snapshot + COM inertia + known loads + original-v drive
    -> public topology/subspace and frame admission
    -> body-origin world I, velocity wrench b and acceleration transport c
    -> reverse tree: U=IA*S, d=S^T*U, u=tau-S^T*pA
    -> IAbar=IA-U*U^T/d, pbar=pA+IAbar*c+U*u/d
    -> parent += X^T*IAbar*X, X^T*pbar
    -> forward tree: a=X*aParent+c; qdd=(u-U^T*a)/d; a+=S*qdd
    -> independent original Newton/Euler and energy/load acceptance
    -> immutable tentative query result
```

## Contracts and Invariants
Selected input is a connected spatial tree with fixed root, fixed anchors, V>0 and only fixed/revolute/prismatic/screw scalar joints. Root inertia remains in the complete original source. Other joint families, planar/floating/prescribed sources, unknown constraint/contact loads, nonuniform gravity and V0 queries have marked typed refusal. Body/source/frame/order identity, exact velocity layout, finite drive and source velocity agreement are admitted before recursion. Original snapshot acceleration is not substituted for bias.

Six-vectors order angular then linear and are expressed in world axes about each current body origin. X maps parent origin motion/acceleration to child origin: angular unchanged and linear += angular cross (childPosition-parentPosition). Torque-force dual transport is X^T. S comes from the actual published relative joint subspace rotated by the world parent-anchor rotation and shifted from the child anchor to body origin, following the original TreeKinematicsEvaluator. q/v mapping follows the original scalar velocity range; generalized torque Nm or force N pairs with rad/s or m/s. Screw coordinate is rad with its actual meters/radian pitch.

Physical body inertia is built from the original world-rotated COM tensor and COM offset using I*[alpha;a] = [Icom*alpha+c cross m*(a+alpha cross c); m*(a+alpha cross c)]. Its velocity wrench is [omega cross Icom*omega + c cross m*(omega cross (omega cross c)); m*(omega cross (omega cross c))]. Acceleration transport bias is c_i=originalBias_i-X_i*originalBias_parent. These are geometric origin accelerations; no origin-spatial-velocity convention is silently substituted. Known physical wrenches are rotated/shifted from the declared body/world frame to body origin; uniform gravity is evaluated at the actual COM through GravityEvaluator. Generalized loads are added in original velocity order. Mass-only operation uses zero c, zero velocity/load wrench and only its right-hand side, while retaining the full original source for acceptance.

Scalar d is accepted only when finite and positive above a caller pivot threshold after original q/energy/time normalization. No damping, row dropping, pseudoinverse or fallback exists. Fixed joints pass full articulated inertia and bias to the parent without elimination. Parent ordering, joint/layout association and exactly one owner of each active velocity coordinate are checked. Mutable numerical storage is exclusively local and identical across Native/WASM/Embedded.

After the recursive candidate exists, the original RigidEquationKernel assembles the actual source with the same caller NumericalWork and separate LoadWork. Original body Newton/Euler force is recomputed independently with bias for forward or without bias for inverse-mass. Original equation residual uses caller coordinate/energy scaling and caller residual tolerance. Original energy is also queried: its virtual power must agree with the independently recomputed full original inertial-force pairing, and kinetic rate must equal original virtual plus prescribed power. Forward additionally checks drive plus known-load virtual power. Mass-only energy describes the actual retained source with the queried acceleration and is not a physical force-balance/evolution claim. Complete energy is caller-required or explicitly unavailable through the original API.

## Runtime Flows
Capacity/cancellation/storage -> source and topology admission -> body preparation and explicit loads -> reverse elimination -> forward recovery -> release workspace -> independent original assembly/force/energy checks -> final cancellation -> result. No retries. LoadWork includes both recursive gravity evaluations and original oracle evaluations; neither is hidden or relabeled.

## State, Ownership, and Lifecycle
Public request/result and source owners are immutable Sendable. Per-body arrays and small 6/36 scalar scratch belong to one synchronous call. NumericalWork/LoadWork are caller-owned inout state; no Mutex is needed for this exclusive scope. No unsafe pointer or target-conditional conformance/storage exists. The result retains the actual original physical system and immutable energy/residual evidence. Call boundaries isolate source preparation, recursion and rich result publication; stack usage remains unmeasured.

## Failure, Concurrency, and Constraints
Small frame/source vector preparation and load transforms use declared conservative fixed upper-bound charges; matrix/recursive arithmetic is charged at each actual loop. These ledger counts are accounting bounds, not measured operation counts or timing.

Typed failures distinguish unsupported domain, capacity/topology/layout/frame/source mismatch, finite/shape/velocity errors, singular scalar pivot, original force/power rejection, Core/Loads/Dynamics/numerical failure and cancellation. Checked scalar-storage sizes precede allocation. Caller body/velocity/load capacities and arithmetic/iteration/storage budgets bound work. Every body traversal, elimination and recovery checks cancellation. Concrete suppliers expose known inout prefixes on failure; original Dynamics unavailable-work status remains terminal. No candidate is returned on any failure.

## Verification and Change Impact
Selected Native compile/link/runtime evidence is owned by [ArticulatedDynamicsQualification](../../../../../Verification/ArticulatedDynamicsQualification/DESIGN.md), including complete registered Native1924 composition with the original14 producer files and six original fixture Swift files unchanged. Actual eight Native tests and eight public calls passed with source/object/module/link bindings and awaited cancellation. This evidence is limited to the fixed original cases and target; it does not close the arbitrary supported-tree numerical domain or scaling. Independent evidence requirements include offset-COM pendulum, noncommuting rotated spatial inertia, two-link and branched trees, fixed intermediate joints, prismatic/screw and framed loads, nonzero actual velocity and supplied snapshot acceleration, gravity, mass-only product, independent dense forward oracle and original energy/power, singular/scaled pivots, topology/layout/source/domain/refusal, all budgets and cancellation. Original Swift6.4.0 ordinary/Embedded WASM compile/link/runtime and actual stack/performance behavior remain pending. The selected Native evidence is linked above; the canonical source freeze and object/link receipts remain its authority. Selected supplier evidence is [FoundationVerification](../../../../../Verification/FoundationVerification/DESIGN.md) PG03/IM15/AF24; it does not qualify this new recursion. Recursion and its scalar storage are structurally linear in body count for fixed workload structure, but source input contains existing full Jacobians and mandatory original assembly/acceptance is quadratic or worse in generalized dimension. Total operation speed/scaling must be measured separately; no performance improvement is claimed.
