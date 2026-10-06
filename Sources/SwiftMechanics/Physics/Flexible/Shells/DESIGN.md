# Flat Mindlin shells

## Purpose and Scope
Parent: [Flexible](../DESIGN.md). Own the AF32 source-first FX-003/007 rectangular flat plate discretization. Children: none. The selected rectangular infinitesimal Native operator has independent behavioral qualification; cloth, drape and finite-motion support remain outside this contract.

## Responsibilities and Boundaries
Own an identified, uniformly subdivided rectangular midsurface embedded in a caller-identified 3D frame, five local DOFs per node, MITC4 transverse shear interpolation, membrane/bending/shear energy, conjugate internal force, consistent tangent, consistent or row-sum lumped translational/rotary mass, and nonnegative Rayleigh damping. Curved reference geometry, drilling rotations, finite rotations, nonlinear material/history, rigid-body attachment, external loads, solves, accepted-time publication and CAD geometry are outside this contract. The final-use path is `any ShellAssembling = RectangularMindlinShellAssembler()` followed by `assemble(plate,state:admission:work:)`.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Flexible](../DESIGN.md) | parent | Flexible energy, layout and admission ownership | Composition owner | Selected Native qualification is owned by the fixture child |
| [Core Geometry](../../../Mathematics/Core/Geometry/DESIGN.md) | depends on | Checked finite Vector3 operations | Local orthonormal basis and 3D reference embedding | Local DOFs are never spatial body coordinates |
| [Model](../../../Modeling/Model/DESIGN.md) | depends on | EntityID and SourceProvenance | Frame, source, revision identity | Source identity is mechanical provenance, not CAD authority |
| [Numerics](../../../Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | Exclusive NumericalWork and checked dimensions | Bounded dense matrix assembly | No numerical solve is supplied |
| [Elasticity](../../Materials/Elasticity/DESIGN.md) | depends on | IsotropicElasticity and LinearElasticResponding tangent | Infinitesimal plane-stress condensation | No other material is admitted |

## Architecture
```text
identified rectangular reference plate + local generalized displacement/velocity
    -> identity/domain/capacity validation
    -> structured Q4 cells + 2x2 Gauss + MITC4 edge tying
    -> plane-stress membrane/bending and transverse-shear stiffness
    -> Kq, 1/2 q^T Kq, M, C=alpha M+beta K, Cv, v^T Cv
    -> immutable ShellAssembly or typed ShellError
```

## Contracts and Invariants
Nodes are row-major, `node = row*(elementsX+1)+column`, identified by the UInt64 node ordinal. Cells are counterclockwise `(bottomLeft,bottomRight,topRight,topLeft)` in the published orthonormal local basis. `ShellBasis` explicitly constructs e1 by normalizing the first supplied tangent, n by normalizing their cross product, and e2=n cross e1. Positive width/height and checked positive representable cell areas determine orientation. No coordinate/frame conversion is implicit.

Each node owns `[u,v,w,betaX,betaY]`: translations in metres and director tangent components in radians. The through-thickness displacement is `(u+z betaX,v+z betaY,w)`, so engineering strains are `em=(u,x,v,y,u,y+v,x)`, `k=(betaX,x,betaY,y,betaX,y+betaY,x)`, and `g=(w,x+betaX,w,y+betaY)`. Plane stress eliminates `ezz=-lambda/(lambda+2mu)*(exx+eyy)` using the supplied elastic law. Membrane, bending and shear scales are h, h^3/12 and kappa*mu*h; kappa is caller-selected finite (0,1]. Energy is the positive-semidefinite discrete quadratic, internal force is its positive gradient (physical restoring force is its negative), and tangent is the same K. No geometric stiffness is claimed.

All terms use 2x2 Gauss with weight cellArea/4. MITC4 ties gx at `(xi=0,eta=+-1)` and interpolates linearly in eta; gy at `(xi=+-1,eta=0)` interpolates linearly in xi. This replaces raw shear interpolation to address rectangular Q4 shear locking, without reduced integration. Distorted/curved elements and drape convergence remain unqualified. The rectangular constant-curvature nodal field has zero tied shear. Energy and Rayleigh power are integrated as positive constitutive squares, algebraically equivalent to `q^T Kq/2` and `v^T Cv`, preserving nonnegativity near rigid modes under rounding.

State must match identity, plate revision, frame, source provenance and exactly `5*nodeCount` coordinates/velocities. Four corner checks per cell bound the bilinear raw displacement gradients and rotations. All translation gradients and director components must remain within the caller's maximum kinematic magnitude, limited to <=0.1. Raw transverse shear and surface in-plane engineering strains at z=+-h/2 must remain within the caller's maximum linear strain, limited to <=0.05. These are restricted infinitesimal assumptions. The in-plane deformation Jacobian must remain positive. Thickness, dimensions, density, condensed modulus, quadrature, derivative-squared stiffness and mass scales must be positive and finite; lost positive scales fail.

Consistent mass integrates `rho*h*N_i*N_j` for u/v/w and `rho*h^3/12*N_i*N_j` for betaX/betaY. Row-sum lumping acts separately on each DOF and preserves constant-field translational mass and rotary inertia. No drilling zero is introduced. Damping coefficients have units 1/s and s and are nonnegative. Outputs disclose the chosen mass form and formulation through their immutable plate. The stiffness has infinitesimal rigid modes; mass is positive definite on the five-DOF space. The selected Native witnesses are recorded by ShellsQualification; broader geometry and target claims remain separate.

## Runtime Flows
Bounded metadata scan and state identity -> checked node/cell/dense sizes and peak storage -> allocate outputs -> per cell corner admissibility -> build full-quadrature K/M -> optional row-sum M -> C and force/energy/power -> cancellation check -> publish owned result. No partially assembled successful result escapes. A failed call may advance the exclusive work ledger, but does not mutate input state or any accepted state.

## State, Ownership, and Lifecycle
Plate, basis, state, policies, assembler and result are immutable Sendable values. State owns COW arrays. Each call exclusively owns work, dense arrays, fixed twenty-column interpolation buffers and local temporaries. No global cache, actor, task creation, shared mutable property, unsafe pointer, Foundation dependency or target-dependent Sendable/isolation exists. Native/WASM/Embedded use the identical source contract.

## Failure, Concurrency, and Constraints
ShellError distinguishes invalid parameters/layout, stale source, frame mismatch, degenerate or inverted geometry, unsupported formulation, outside small-deformation envelope, capacity exhaustion, nonfinite arithmetic, Core/Material/Numerical supplier failures and cancellation. Only `.infinitesimalMITC4` succeeds; `.finiteRotation` fails before assembly. Caller limits bound cells, nodes and metadata bytes; NumericalWork bounds dense output/local/input scalar storage and conservative arithmetic charges before kernels. Metadata equality is charged after a bounded byte scan, and cancellation checks occur during scanning, corner/quadrature traversal and each matrix row. Dense work is O(cells*20^2+DOFs^2), storage O(DOFs^2). No fallback, altered material, fabricated spatial body or placeholder matrix is returned.

## Verification and Change Impact
Original broad regression owner: [Tests/MechanicsFlexibleTests](../../../../../Tests/MechanicsFlexibleTests/DESIGN.md). The original source-first phase ran no tests/build/probes. Current selected Native evidence is owned by [ShellsQualification](../../../../../Verification/ShellsQualification/DESIGN.md) as recorded below. Required oracles: plane-stress membrane patch, constant-curvature bending, shear, six infinitesimal rigid modes, directional energy/force/tangent, constant-field consistent/lumped mass and rotary inertia, Rayleigh dissipation, rectangular refinement/thin-plate behavior and each typed rejection including late cancellation/resource exhaustion. Exact-target qualification remains integration-owned. Frame/DOF/strain/mass changes require Flexible and future structural/contact/coupling consumer review; this handoff connects no new consumer.

### Assigned independent qualification preparation
[ShellsQualification](../../../../../Verification/ShellsQualification/DESIGN.md) owns original physical membrane/bending/MITC4 shear, mass/damping, rigid/reference-basis power and typed work/cancellation oracles. The historical original eleven-source preparation was separately frozen for a planned Native2363 consumer; no behavioral success follows from source inspection. The original pre-marker finiteRotation enum/guard lacked the required immediate incomplete comment; the marker correction below preserves the actual typed refusal. That marker-contract gap is reported independently from numerical behavior; changed source requires an attributable matching producer or approved comment-only binding before current-source closure. Root owns lease, shared registration and broader integration.

### Incomplete-marker contract correction
The assigned closure requires immediate English incomplete markers at the finiteRotation declaration and its actual assembler refusal. The existing branch already returns ShellError.unsupportedFormulation; this correction changes comments only, with no formula, public API, state, ownership or failure semantics change. Preserve the original11 source bytes and their historical2363 binding before editing. The new two per-source hashes and exact comment delta are separately recorded; current-source proof waits a freshly matching producer. The original unsupported fixture is retained as the refusal witness, with no additional review or execution implied by this comment correction.

### AF42 fresh Native qualification boundary
The selected physical operator remains unchanged. [ShellsQualification](../../../../../Verification/ShellsQualification/DESIGN.md) now consumes a fresh common Native producer from committed `d30b585` lower suppliers plus the exact eleven shell sources. Historical deleted object/cache records are not current evidence. Support/Public compile at macOS13 and Testing at macOS14; operation-owned Mutex fixture helpers retain macOS15 availability with checked entry bodies and typed refusal below that runtime boundary. Root owns the producer lease and additive registration. Original forces, tolerances, physical oracles, work, cancellation and unsupported finite rotation remain fixed; actual behavioral closure is recorded by the matching seven Native tests and six public cases in the qualification child design.

### AF42 selected Native behavioral evidence
The fresh common producer binds exact2387 sources with committed `d30b585` lower suppliers and these unchanged eleven shell sources. Seven Native tests and the same six public physical cases passed once; this includes original work/storage/refusal paths, operation-local early/late cancellation and awaited native Task cancellation. [ShellsQualification](../../../../../Verification/ShellsQualification/DESIGN.md) owns the precise source/object/module/library/consumer receipt. This is selected rectangular infinitesimal MITC4 Native evidence, without portable, finite-rotation, drape, curved-cell or accepted runtime evolution claims.
