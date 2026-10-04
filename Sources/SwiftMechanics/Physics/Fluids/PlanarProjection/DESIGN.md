# PlanarProjection

## Purpose and Scope
Initial admitted implementation domain; behavioral/profile qualification pending. Parent [Fluids](../DESIGN.md); no children. Own real two-dimensional periodic incompressible Newtonian MAC discretization and explicit donor-cell/viscous evolution followed by pressure projection. Full EX-005 ownership remains beyond this domain.

## Responsibilities and Boundaries
Own staggered layout, periodic pressure/velocity boundary law, conservative dual-volume advection, viscous diffusion, original pressure/momentum/divergence and kinetic-work acceptance. Pure reference operation advances exclusively owned state, without changing the frozen Channel/Runtime contributor. Fixed inertial frame x/y axes, domain [0,Lx)×[0,Ly), uniform thickness z; constant positive rho [kg/m³] and mu [Pa s]. No free surface, compressibility, moving geometry, turbulence or coupled structure is qualified. Periodic pressure cannot represent a nonperiodic hydrostatic gradient; frozen Channel owns wall/hydrostatic behavior.

## Related Designs
| Design | Relationship | Contract used | Cautions |
|---|---|---|---|
| [Fluids](../DESIGN.md) | parent | IM44 boundaries | Independent new domain |
| [Core](../../../Mathematics/Core/DESIGN.md) | depends on | EntityID frame | Caller supplies fixed inertial frame, no inferred transform |
| [Model](../../../Modeling/Model/DESIGN.md) | depends on | SourceProvenance | Grid identity/revision/physical provenance retained |
| [Numerics](../../../Mathematics/Numerics/DESIGN.md) | depends on | LinearSolving<Double>, dense Cholesky, NumericalWork | Reduced Laplacian is SPD but not strict-DD; no CSR CG fallback |
| [Tests](../../../../../Tests/MechanicsFluidsProjectionTests/DESIGN.md) | verified by | independent physical oracles | Execution qualification pending |

## Architecture
```text
bounded periodic MAC field -> conservative donor/viscous predictor
 -> gauge-pinned actual pressure solve -> face gradient correction
 -> ALL original cell equations + divergence + kinetic/work -> new state or typed failure
```

## Contracts and Invariants
nx,ny>=3; N=nx*ny checked against caller maximumCells before traversal/allocation. Unique periodic faces: u[i,j] at (i*dx,(j+1/2)*dy), v[i,j] at ((i+1/2)*dx,j*dy), p[i,j] at ((i+1/2)*dx,(j+1/2)*dy), flattened j*nx+i. Neighbors wrap, no duplicate endpoint. D(u,v)=(uRight-uLeft)/dx+(vTop-vBottom)/dy [1/s]; G is the matching face pressure gradient [Pa/m]; G=-D^T in the uniform face/cell inner product. Pressure gauge p[0]=0 exactly. Original full periodic equation -DGp=-(rho/dt)D(predictedVelocity) [Pa/m²] is checked in ALL N cells, including the removed gauge row. Solve only the N-1 principal SPD submatrix through explicitly float64/referenceCPU/Cholesky. Original corrected D, per-face correction momentum [N], global momentum [N] and projection energy [J] are checked separately; numerical residual alone never publishes success.

For u dual volumes, advecting x-face speed is average adjacent u and y-face speed is average the two adjacent v; v uses the transposed construction. Transported component is donor selected by advecting speed sign. Conservative flux differences [m/s²] and central nu Laplacian (nu=mu/rho [m²/s]) form R=-div(a*donorVelocity)+nu*lapVelocity+uniform acceleration. Explicit predictor w*=w+dt*R. Pressure correction wNew=w*-(dt/rho)Gp. Step entry requires original cell divergence within caller tolerance; project-only entry admits finite tentative divergence and leaves time/sequence unchanged. Step advances time and sequence once; retained source sample records the held uniform acceleration.

For each dual volume, outgoing advective factor is dt*(max(aRight,0)-min(aLeft,0))/dx + dt*(max(bTop,0)-min(bBottom,0))/dy. Add 2*nu*dt*(dx^-2+dy^-2). Every u/v row must be <=caller courantLimit, with 0<courantLimit<=1; report its maximum plus separate advective and viscous maxima. This admits a positive explicit donor/diffusion update for an exactly divergence-free advecting field, not an unconditional Navier–Stokes stability claim. Original divergence tolerance creates a measured transport leakage, accounted below. Caller maxStep and speed/pressure/acceleration envelopes are independent physical/resource authority. Invalid dt/CFL/domain fails before numerical solve.

Mass per dual volume m=rho*dx*dy*depth [kg]. Total periodic mass rho*Lx*Ly*depth is unchanged; face momentum sum m*u and m*v change only by m*N*dt*acceleration (flux/gradient sums telescope). K=0.5*m*sum(u²+v²) [J]. Viscous loss power Dmu=m*nu*sum(edge deltaVelocity²/directionSpacing²) [W]. Donor numerical loss power Dup=0.5*m*sum(face |advectingSpeed|*deltaTransportedVelocity²/directionSpacing) [W]. Advecting-dual divergence leakage power Qdiv=-0.5*m*sum(componentVelocity²*dualDivergence) [W]. Source power Qsrc=m*sum(componentVelocity*acceleration) at OLD velocity [W]. Original predictor identity: K*-Kold=dt*(Qsrc-Dmu-Dup+Qdiv)+0.5*m*dt²*sum(R²). Last term is explicit time injection [J], distinct from physical loss. Projection loss Lp=0.5*m*sum((wNew-w*)²) [J]. Pressure residual work Wp=dt*m/rho*sum(p*D(wNew)) [J]; exact projection identity Knew-K*+Lp-Wp=0. Whole-step energy defect [J] checks this combined original identity. Advective/viscous dot-work identities are independently checked, not inferred from final total. With zero source, reject unexplained K increase beyond caller energy allowance plus measured divergence/pressure leakage. No convergence status implies physical stability outside this discrete domain.

## Runtime Flows
Pure operation only: input owner retains immutable arrays; call-local bounded buffers hold predictor/R, dense reduced pressure matrix/RHS, corrected field. NumericalWork reserves all simultaneously live logical scalar buffers before allocations, charges conservative floating-arithmetic row ceilings for physical assembly/check loops (comparisons/indexing/metadata are separately bounded by admitted layout), and absorbs real successful supplier diagnostics. Failed supplier work is explicitly unavailable and computation stops. No unreported guessed solver caps. Repeated cell loops reuse arrays; no per-cell intermediate arrays. One completed step returns new immutable state; any failure/cancellation leaves input unchanged. General Runtime participant composition belongs a later qualified handoff, not fabricated by this pure solver.

## State, Ownership, and Lifecycle
Grid, source, state and evidence immutable Sendable; NumericalWork is an exclusive inout caller value. No shared production mutation, hidden cache, unsafe pointer or profile conditional. Identical storage/Sendable requirements across Native/WASM/Embedded. Metadata bounded byte traversal precedes identity comparison. Snapshot pressure and source are retained; original bindings cannot silently change. Phase helpers separate assembly/projection/work to bound Embedded debug frames.

## Failure, Concurrency, and Constraints
Typed invalidInput/domain/staleBinding/stability/originalResidual/nonfinite/capacity/cancelled/numerical failures. Grid maxCells/maxMetadataBytes and finite envelopes admitted before traversal; checked count products before buffers. Policy fixes force [N], pressure-equation [Pa/m²], divergence [1/s], energy [J] tolerances, Courant and required linear tolerance. Cancellation hook immutable Sendable, checked by row, before/after actual solve and final publication. No solver/backend fallback. Absent general-fluid APIs are not fabricated; full EX-005 remains open.

## Verification and Change Impact
Tests construct independent potential and solenoidal fields, recover gauge/gradient correction, verify removed gauge row, divergence and momentum, real 2D Taylor–Green viscous/advection evolution with mesh/time refinement, discrete shear amplification, original global mass/work and unforced dissipation. Reject invalid grid/material/pressure gauge, CFL/viscous limits, stale field counts, budgets/iteration limits, real-solver wrong-equation output and cancellation after actual solve. Layout/flux/projection changes invalidate all original-equation and refinement tests. Root owns build/registration/profile execution; source-only checks do not qualify behavior.

Taylor–Green mesh refinement uses the asymptotic n=8,12,16 fixture range; the [test contract](../../../../../Tests/MechanicsFluidsProjectionTests/DESIGN.md#contracts-and-invariants) owns the independent Fourier/modal-rate justification and the n=4 Nyquist aliasing/cancellation counterexample. The discrete formulation admits n=4, but does not guarantee monotonic continuum error from that coarse grid. Original residual, energy, CFL, threshold and caller-budget checks remain unchanged.

### Selected AF17 execution evidence

Ten Native actual original-equation/refinement/failure tests passed. Original Native/WASM/Embedded public pressure/gauge/divergence projection, uniform-acceleration momentum/work and typed rejected-step execute. General CFD/planar Runtime/FSI remains open. Exact profile identity and root logs are indexed by the [parent design](../DESIGN.md); the corresponding test owner retains the independent physical oracles. Private stack diagnostics are not qualification.
