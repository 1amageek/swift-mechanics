# RigidEquations

## Purpose and Scope
Own identified spatial rigid-tree mass, inertial bias, applied force channel/power accounting and original body Newton/Euler products (DY001/004/007/008). Parent: [MechanicsDynamics](../DESIGN.md). No children. Initial closed domain follows [plan](../../../../../IMPLEMENTATION_PLAN.md); full DY family remains owned by IM15.

## Responsibilities and Boundaries
Own the equations and evidence below. Runtime evolution/checkpoints, unknown constraint/contact response, impact laws, model compilation and actuation constitutive laws remain consumers. No cached mutable state or accepted-state mutation.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Module](../DESIGN.md) | parent | Scope | Rigid initial producer | Full closure later |
| [Joints](../../../Modeling/Joints/ArticulatedTrees/DESIGN.md) | depends on | Snapshot geometric columns, actual velocity and accelerationBias | q/v layouts may differ | Explicit velocity must match |
| [Model](../../../Modeling/Model/Inertia/DESIGN.md) | depends on | Positive physical body COM tensor | Rotate about COM | No geometry inference |
| [Numerics](../../../Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | Cholesky, residual and cumulative budget | Selected numerical profile | Failed work unavailable |
| [Loads](../../Loads/ForcePorts/DESIGN.md) | depends on | Framed force/impulse distinction and affine gravity | Known external forces only | Bushing chart/cable/follower limits remain |
| [Sibling](../DenseDynamics/DESIGN.md) | coordinates with | Immutable equation/input and original inertia product | Solve and physical authority | No mechanical ABA claim |
| [Tests](../../../../../Tests/MechanicsDynamicsTests/DESIGN.md) | used by | Public protocols | Independent analytic proof | Native evidence is local |

## Architecture
```text
immutable identified snapshot + inertia + explicit loads
 -> caller admission + budget checks
 -> world COM / inertia / geometric columns
 -> mass / Newton-Euler bias / energy and force budget
 -> selected dense solve -> independently recomputed physical residual
```

## Contracts and Invariants
Input is an immutable Joints snapshot, explicit generalized velocity matching actual body velocities J*v+prescribedDrift within separate caller angular/linear tolerances, and one body-order/frame-matched complete MassProperties3D per body. Admit V>0 spatial tree, known external wrenches/generalized loads, no unknown contact/constraint reactions. Caller body/velocity/contribution capacities bound input traversal; NumericalWork bounds scalar storage and charged arithmetic; LoadWork separately bounds Loads supplier evaluations/cancellation. M=sum(Jomega^T Iworld Jomega+m Jcom^T Jcom), Iworld=R Ibody R^T, Jcom.linear=Jbody.linear+Jbody.angular cross R*COM. Inertial bias uses supplied accelerationBias, COM alphaBias cross offset and omega cross(omega cross offset), plus omega cross(Iworld*omega). Actual omega includes prescribed drift; snapshot.motion.acceleration is never substituted for bias. Uniform gravity uses the verified Loads point service at COM and retains its explicit potential time derivative. Nonzero spatial gradients are unsupported: a COM-only call would omit distributed second-moment gravitational torque/potential and must not be successful. Assembly accepts separate caller-owned inout LoadWork: supplier logical evaluations are cumulatively accounted in their own unit, never relabeled as scalar arithmetic. Both assembly ledgers are retained. Applied framed wrenches have torque about their explicit reference point; rotation/translation shift produces torque about world body origin. Four channels actuator/applied/constraint/contact mean supplied known loads, not inferred reactions. Arbitrary generalized-to-body wrench allocation is nonunique and unavailable. Original inertia products recompute body acceleration and Newton/Euler wrench from immutable input; they do not multiply assembled M. Queries return kinetic energy, frame-referenced linear/angular momentum, complete potential/dissipation when supplied and otherwise explicit unavailable/error. Kinetic rate pairs required COM force/torque with actual velocities; prescribed-work contribution remains separate.

## Runtime Flows
Check capacities/layout/frame/domain -> reserve simultaneously retained numerical storage -> charge before arithmetic/traversal -> evaluate physical equation -> solve selected numerical problem -> original physical residual check -> immutable evidence. Cancellation is checked at operation and body/column boundaries. No retries.

## State, Ownership, and Lifecycle
Inputs/results immutable Sendable. NumericalWork and the assembly LoadWork are caller-owned inout local state, arrays are exclusively operation-owned mutable workspaces, immutable snapshot backing retained by value. Fixed-size Core vectors/matrices remain values. Reuse column/output workspace across bodies; no per-inner-loop intermediate arrays. All public queries reserve the retained system scalarStorage footprint even when their result contains no arrays. Conservative scalar-storage accounting includes system arrays, local work and supplier-declared storage; borrowed caller inputs/snapshot/inertia backing are excluded. Consumers own aggregate previously retained result storage. No unsafe pointer, shared caches or target-dependent conformance.

## Failure, Concurrency, and Constraints
DynamicsError distinguishes domain/capacity/identity/shape/velocity mismatch/energy unavailable/nonfinite/physical residual/numerical/Core/Loads/Joint/cancellation failures. Numerical supplier failures explicitly mark unavailable partial work; caller inout ledger retains known outer work. Unsupported topology/physics is rejected, not approximated. All capacities, tolerances/scales and NumericalBudget are caller-selected. Checked products/sums precede allocation.

## Verification and Change Impact
Free rigid-body asymmetric Euler and rotated body axes, COM pendulum, two-link independent M/C/gravity, prescribed motion and nonzero supplied acceleration, physical energy/power/momentum, frame/missing-inertia/velocity mismatch and capacity failures. Changes to COM/frame/v convention, force authority, original residual, resources or scaling invalidate downstream constraints/contact/integration/observations and root platform probes. No dynamics trajectory or recursive scaling proof is claimed.

### AF24 additive planar physical source contract

The source trace established that Model and Compiler retain validated `MassProperties2D` and Joints evaluates original planar body motion, columns and acceleration bias. Current Dynamics admission and `RigidBodyInertia.properties: MassProperties3D` reject that physical domain. Removing the guard alone cannot qualify planar mechanics.

The additive contract retains the existing spatial inertia/input/system APIs. A new `PlanarRigidBodyInertia` retains identified original `MassProperties2D`; a planar input retains the full original snapshot, velocity, inertia inventory and explicit loads. `PhysicalRigidDynamicsInput` tags actual spatial versus planar source, and `PhysicalRigidDynamicsSystem` retains the complete admitted source plus equation, load, ledger and resource evidence. `PhysicalRigidEquationComputing` exposes non-generic protocol requirements for assembly, original inertia, body wrench and energy. The concrete kernel shares its physical algorithms with the existing spatial witnesses. A planar source never produces a legacy spatial system, empty substitute inertia inventory or fabricated 3D tensor. Exact record layout and phase implementation belong to this component's lower implementation design before source edits.

```text
original spatial input -> spatial source bridge --+
                                                  +-> shared physical equations -> original-body acceptance
original 2D inertia + actual planar input --------+
```

Planar admission requires one connected, dimension-consistent XY tree, positive mass and polar inertia, original body/frame/order/layout identity and plane-preserving motion and loads. Out-of-plane force/torque after original frame/reference transformation is an explicit typed failure; an unavailable plane support reaction is never reported as zero. COM transport uses original Rz*[cx,cy,0]. Inertia action on the admitted rotational tangent is Iz*omegaZ, without fictional transverse moments. Mass, bias, original Newton/Euler product, momentum and kinetic/prescribed work use those same original values. Uniform gravity remains the only admitted gravity distribution. Existing source/velocity checks, preallocation capacity, separate load/numerical work, supplier seed/reset/refusal/cancellation and unknown-work contracts remain applicable to both domains.

This owner and [DenseDynamics](../DenseDynamics/DESIGN.md#af24-additive-physical-solve-contract) are the first lower handoff, before planar constrained evolution. [MechanicsDynamicsTests](../../../../../Tests/MechanicsDynamicsTests/DESIGN.md) must independently check offset-COM free body/pendulum/two-link M/C/gravity, forward/inverse/mixed solves, original physical residual rejection, kinetic energy/momentum/power, dimension/frame/source/plane-load refusal and bounded/cancelled work. Root owns actual registration and original Native/WASM/Embedded composition at unchanged stack/profile settings. This is an implementation contract; planar behavioral qualification is pending.
