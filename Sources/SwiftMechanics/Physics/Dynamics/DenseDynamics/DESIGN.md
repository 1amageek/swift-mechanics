# DenseDynamics

## Purpose and Scope
Own initial Float64 referenceCPU Cholesky forward/inverse/inverse-mass/mixed dynamics and original physical residual acceptance (DY001..004). Parent: [MechanicsDynamics](../DESIGN.md). No children. Initial closed domain follows [plan](../../../../../IMPLEMENTATION_PLAN.md); full DY family remains owned by IM15.

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
| [Sibling](../RigidEquations/DESIGN.md) | coordinates with | Immutable equation/input and original inertia product | Solve and physical authority | No mechanical ABA claim |
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
Caller selects Float64/referenceCPU/Cholesky explicitly; no precision/backend/factorization/regularization substitution. Caller coordinate scales S, energy scale E and time scale T nondimensionalize Aij=Si*Mij*Sj/(E*T^2), rhs_i=Si*f_i/E, physical acceleration_j=Sj*y_j/T^2. Symmetric entries are computed once and mirrored, preserving Cholesky admission. Residual acceptance uses independent original body Newton/Euler products scaled by Si/E and caller dimensionless absolute/relative tolerances. Inverse computes original required generalized force minus known load channels. Mixed partitions provide exactly one known acceleration or known drive force per coordinate; unknown acceleration uses the principal block M_UU and known acceleration coupling; unknown force is independently reconstructed. No prescribed acceleration is overwritten. Mass-inverse products use original body inertia action without velocity bias. NumericalWork remainingBudget/absorb composes all successful nested solver work and conservative simultaneously retained scalar storage. Failed numerical supplier work is unavailable by the frozen producer contract; failure immediately stops, retains known outer counters and underlying NumericalError, and never retries. Dense mechanics is O(B*V^2+(W+G)*V)+O(V^3), where W/G count supplied body/generalized contributions, not ABA, recursive or sparse constrained dynamics. DY005 remains unqualified initial-domain responsibility.

## Runtime Flows
Check capacities/layout/frame/domain -> reserve simultaneously retained numerical storage -> charge before arithmetic/traversal -> evaluate physical equation -> solve selected numerical problem -> original physical residual check -> immutable evidence. Cancellation is checked at operation and body/column boundaries. No retries.

## State, Ownership, and Lifecycle
Inputs/results immutable Sendable. NumericalWork and the assembly LoadWork are caller-owned inout local state, arrays are exclusively operation-owned mutable workspaces, immutable snapshot backing retained by value. Fixed-size Core vectors/matrices remain values. Reuse column/output workspace across bodies; no per-inner-loop intermediate arrays. Conservative scalar-storage accounting includes system arrays, local work and supplier-declared storage; borrowed caller inputs/snapshot/inertia backing are excluded. Consumers own aggregate previously retained result storage. No unsafe pointer, shared caches or target-dependent conformance.

## Failure, Concurrency, and Constraints
DynamicsError distinguishes domain/capacity/identity/shape/velocity mismatch/energy unavailable/nonfinite/physical residual/numerical/Core/Loads/Joint/cancellation failures. Numerical supplier failures explicitly mark unavailable partial work; caller inout ledger retains known outer work. Unsupported topology/physics is rejected, not approximated. All capacities, tolerances/scales and NumericalBudget are caller-selected. Checked products/sums precede allocation.

## Verification and Change Impact
Forward/inverse/mixed analytic comparisons, asymmetric Euler, independent original physical residual, scaled coordinates, capability/solver pivot/work/storage/iteration/cancellation boundaries. Changes to COM/frame/v convention, force authority, original residual, resources or scaling invalidate downstream constraints/contact/integration/observations and root platform probes. No dynamics trajectory or recursive scaling proof is claimed.

### AF24 additive physical solve contract

Consume the complete source-tagged physical system defined by [RigidEquations](../RigidEquations/DESIGN.md#af24-additive-planar-physical-source-contract). An additive `PhysicalRigidDynamicsSolving` port provides non-generic physical-system solve requirements while preserving original spatial `RigidDynamicsSolving` calls and result meaning. Numerical solve and original-body residual algorithms must be shared; a planar source cannot be converted into fabricated spatial inertia or accepted solely from assembled M. Actual source, velocity, acceleration/force temporal meaning, scales, known work and unavailable supplier failure remain associated through every phase. The test owner and root qualification boundary are linked by RigidEquations; implementation-specific lower design and actual behavioral evidence must precede upper handoff.

#### AF24 shared solve records and lifecycle

`PhysicalRigidDynamicsSolving` requires forward, inverse, inverseMassProduct and mixed operations on `PhysicalRigidDynamicsSystem`, returning an immutable `PhysicalDynamicsSolution` with its full original system, acceleration, drive, residual, linear diagnostics and known work. `DenseRigidDynamics` implements both this port and the existing spatial port. Existing `init(equations:linearSolver:)` keeps the supplied legacy witness and its original behavior. New `init(physicalEquations:linearSolver:)` explicitly selects the physical witness. A legacy-only witness cannot act on planar source and throws `unsupportedDomain`; no dynamic cast, default-kernel substitution or fabricated spatial conversion is permitted. Physical witnesses can accept spatial input through the actual source bridge. Every existential operation is a non-generic requirement.

One private algorithm handles each solve mode, scaling, numerical callback and independent original-body residual for both ports. Internal immutable reference contexts carry the admitted system and original-force witness dispatch; phases prepare matrix/RHS, call the bounded numerical supplier, then reconstruct physical acceleration, verify original force and publish. Only completed immutable source contexts cross phases, and future rich result/source publication is not retained over deepest callbacks. The public legacy result remains DynamicsSolution. The physical result retains the exact admitted system and wraps the same computed values without another mechanical solve.

Numerical supplier admission reserves a known operation before the opaque callback on the physical path, derives remaining capacity from the actual caller ledger and retained simultaneous arrays, and absorbs successful diagnostics. Failed supplier work unavailable in the frozen LinearSolving contract is propagated with the known admission prefix and no retry. Original equation callbacks on the physical path receive a seeded operation-local remaining ledger, whose budget/counters are validated and absorbed on success and failure; reset yields typed supplierLedgerReplaced with unavailable work, and unknown work remains terminal. Legacy-constructor spatial supplier invocation/work meaning is preserved. The new physical constructor uses guarded original-equation callbacks even when called through the old spatial method signature. Caller capabilities remain explicit Float64/referenceCPU/Cholesky; no backend/algorithm fallback. Shared mutable state is absent on all profiles.
