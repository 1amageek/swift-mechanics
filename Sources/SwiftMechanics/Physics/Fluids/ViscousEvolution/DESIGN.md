# ViscousEvolution

## Purpose and Scope
Initial admitted implementation domain; behavioral/profile qualification pending. Parent [Fluids](../DESIGN.md); no children. Own actual steady and backward Euler evolution of the admitted finite-volume channel, not arbitrary ODE state.

## Responsibilities and Boundaries
Assemble and solve physical momentum using injected required LinearSolving<Double>, explicitly float64/referenceCPU/Cholesky. Recompute original face stresses, momentum and energy from solved u before success; supplier convergence alone has no physical authority. No stability/accuracy for other PDEs or wall motions is inferred.

## Related Designs
| Design | Relationship | Contract used | Cautions |
|---|---|---|---|
| [Channel](../ChannelDiscretization/DESIGN.md) | depends on | immutable physical/state fields | Fixed uniform grid |
| [Numerics](../../../Mathematics/Numerics/DESIGN.md) | depends on | dense matrix, solver, diagnostics, budget | Failed supplier work unavailable |
| [Continuation](../Continuation/DESIGN.md) | used by | actual step result | Accepted time owned by Runtime |

## Architecture
```text
old field + dt + held wall/source -> SPD momentum matrix -> real Cholesky
 -> original face-flux momentum + discrete energy -> accepted candidate or typed failure
```

## Contracts and Invariants
m=rho*A*h; g=mu*A/h. Interior shear tau=mu*(uR-uL)/h; walls use half-cell distance. Original cell equation m*(uNew-uOld)/dt=A*(tauRight-tauLeft)+A*h*(-dpdx+rho*gx). Steady omits inertia. Diagonal K is 2g interior, 3g boundary, 4g for one cell; offdiagonal -g; wall RHS 2g*U. BE requires representable positive m/dt and adds m/dt diagonal and m*uOld/dt RHS. Physical force residual is checked using caller absolute [N] and relative tolerances against actual original terms, never scaled numerical matrix only. Hydrostatic field is recalculated from the new boundary sample.

K=0.5*m*sum(u²); viscous D=sum(g*du²)+2g*(uFirst-Ulo)²+2g*(Uhi-uLast)² [W]. Boundary power=A*(tauUpper*Uhi-tauLower*Ulo); source power=A*h*f*sum(uNew). BE identity is deltaK+dt*D+0.5*m*sum((uNew-uOld)²)=dt*(boundaryPower+sourcePower). Last term is numerical dissipation, distinct from physical viscosity. Steady power input=D. Return original max force residual, pressure-gradient residual, kinetic energy, physical dissipation and numerical loss. Steady has an optional power defect [W] and no energy defect; BE has an optional energy defect [J] and no steady power defect. Their absolute/relative tolerances are separate caller policies, preserving dimensional meaning. BE's unforced stationary-wall energy monotonicity follows from this actual discrete identity for any admitted positive dt; accuracy requires refinement. Caller maxStep is a domain/accuracy envelope, not an invented CFL guarantee. Changing wall/source samples does external work as stated, no instantaneous fluid reset.

## State, Ownership, and Lifecycle
Input state is unchanged; result candidate advances time/sequence exactly once. Steady result retains time/sequence. Dense matrix, RHS, face stresses and supplier workspace are bounded call-local owners; loops reuse buffers and do not allocate per cell. Input/output immutable arrays are counted as live storage. Scalar algebra is finite checked; fail before publication on overflow/underflow, counter overflow, or time not strictly advancing.

## Failure, Concurrency, and Constraints
Policy fixes caller tolerances, budgets, max dimension and cancellation. Local NumericalWork absorbs actual successful solver diagnostics with live storage reservation. Nested failure carries typed NumericalError and unavailable failedSupplierWork; no guessed arithmetic count. Cancellation is checked before/after solve, rows, and final publication. All operation requirements are protocol witnesses; no target-dependent conformance/storage.

## Verification and Change Impact
[Tests](../../../../../Tests/MechanicsFluidsTests/DESIGN.md) compare Couette and Poiseuille with independent continuum solutions and mesh refinement, transient sine decay with time/mesh refinement, original cell momentum/energy, stationary-wall dissipation, injected real-solver cancellation, premature/invalid numerical results, budgets/domain errors. Lower contract changes require all original-residual and Runtime composition checks.
