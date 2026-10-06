# Discrete state-space and linear quadratic control

## Purpose and Scope
Parent: [Control](../DESIGN.md). Children: none. Owns CO-003 finite-dimensional binary64 reference discrete design and bounded state feedback, plus CO-001 dimension/sample-period admission. Source implemented; behavioral and target qualification is deferred.

## Responsibilities and Boundaries
Own normalized discrete matrices, explicit physical coordinate scales, provenance, symmetric PSD Q and SPD R admission, stabilizability witness checks, Riccati iteration, original-equation acceptance and feedback evaluation. An analytic system is explicitly caller-supplied; an equilibrium realization consumes the actual immutable IM17 result. The explicit bilinear discretization is an approximation contract, not a zero-order-hold realization. Caller owns operating envelope and any physical input-to-dimensionless-parameter calibration. No estimator, nonlinear plant, Runtime publication or accepted-state ownership is supplied here.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Control](../DESIGN.md) | parent | Dimensioned bounded feedback | Dispatch ownership | No new controller continuation authority |
| [Ports](../Ports/DESIGN.md) | coordinates with | ScalarControlPort identity and dimensions | Effort result binding | Parameter units do not imply newtons |
| [Linearization](../../../Analysis/Equilibrium/Linearization/DESIGN.md) | depends on | Actual EquilibriumLinearization | Mechanical provenance | Preserve source point, chart and reduction; no invented derivatives |
| [LinearAlgebra](../../../Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | IM03 LU/Cholesky, original residual and work ledger | All numerical solves | Failed supplier work is unavailable and explicitly recorded |

## Architecture
```text
caller analytic discrete matrices OR actual IM17 A/B + explicit bilinear map
  -> normalized dimensioned DiscreteControlSystem
  -> Q/R admission + supplied stabilizing gain witness
  -> bounded DARE iteration -> original DARE/gain residual + Lyapunov SPD certificate
  -> immutable LinearQuadraticDesign -> normalized u=-K*x -> explicit physical bounds
  -> dimension/identity checked scalar effort port (when requested)
```

## Contracts and Invariants
Coordinates carry SI dimensions and positive SI-per-normalized-unit scales. Matrices operate on normalized coordinates; Q, R and per-step cost are dimensionless. Dynamics are x[k+1]=A*x[k]+B*u[k]. DARE is P=Q+A^T*P*A-A^T*P*B*(R+B^T*P*B)^-1*B^T*P*A; gain obeys (R+B^T*P*B)*K=B^T*P*A. Q admission rejects negative pivots and requires exact zero null-pivot rows; computed P permits the explicit semidefinite roundoff tolerance. R and gain denominator are strictly SPD at the caller pivot threshold. A caller-supplied gain is admitted only when its actual closed loop has a Lyapunov SPD certificate; witness rejection does not prove mathematical unstabilizability. Publication requires fresh original DARE and unprojected gain residuals, symmetry evidence and an independent closed-loop certificate, not iteration change alone.

For F=A-B*K, solve W-F^T*W*F=I using IM03 LU, validate the original matrix equation and positive definiteness of symmetrized W using IM03 Cholesky. A positive W and positive actual W-F^T*W*F establish strict Schur stability. The actual decrement must pass SPD admission as well as residual checks; this avoids turning a loose residual tolerance into a stability claim. Q=0 may therefore reject a nonstabilizing Riccati fixed point even for a stabilizable system. Saturation is disclosed per component; it invalidates any claim that the applied command follows the unsaturated linear stability certificate.

## Runtime Flows
Check dimensions, products, metadata/work/storage -> admit provenance and scales -> check costs/witness -> iterate DARE from Q using actual SPD solves -> re-evaluate original equations -> certify final F -> cancellation gate -> return immutable design. Feedback checks source identity, state dimensions/finiteness, computes normalized feedback, converts to SI and clips only to explicit caller bounds.

## State, Ownership, and Lifecycle
Public records and services are immutable Sendable. Only operation-local scratch and caller-owned NumericalWork mutate. Arrays own their storage; no caches, pointers, unchecked isolation, conditional synchronization or implicit state updates. Port evaluation does not publish a Runtime state. No shutdown resource is owned.

## Failure, Concurrency, and Constraints
Caller policy bounds states, inputs, metadata, Riccati steps and all numerical storage/operations/iterations before allocation. Lyapunov certification has an n^2 by n^2 dense coefficient matrix, so O(n^4) storage and O(n^6) LU work; this cost is explicit and budget-limited. The component's conservative retained scratch reserve is combined with supplier workspace. Supplier diagnostics are checked against the exact remaining budget and recomputed original residuals. Numerical failures preserve known caller work and flag unreported failed supplier work. Invalid input, incompatible port, failed witness, rejected original evidence, nonconvergence, nonfinite arithmetic, cancellation and exhausted budgets never return a partial accepted design. Precision/backend/algorithm do not silently change.

## Verification and Change Impact
The independent selected fixture owner is [LinearQuadraticQualification](../../../../../Verification/LinearQuadraticQualification/DESIGN.md). Its eight synchronous cases and ninth Native cancelled-Task witness are prepared against the unchanged original2363 source/object authority; compilation, linking and runtime execution remain pending. This preparation does not establish behavioral, canonical or portable qualification.

Root owns deferred behavioral qualification, tests and profile integration. Required oracles: analytic scalar DARE root and poles; multistate original DARE/gain/Lyapunov equations; actual IM17 mechanical point and declared bilinear matrices; unstable uncontrollable witness rejection; indefinite/nonsymmetric Q/R; Q=0 nonstabilizing fixed point; false supplier result/ledger; cancellation at final supplier/publication; work/storage exhaustion; physical dimensions, identity, bounds and saturation. An admitted witness or source implementation is not qualification. Changes to IM17 source assumptions or IM03 solver/failure accounting require rechecking this child and its parent.


## Exact represented state-cost boundary
The original strict Q gate has a concrete false admission: Q=[leastNonzeroMagnitude,5e-162;5e-162,4] has a negative exact binary64 principal minor, but its pivoted Schur residual rounds to zero. Equal least-subnormal off-diagonal entries also disappear under halving. Preserve already equal symmetric entries verbatim. Before strict caller-Q Schur elimination, check every original two-coordinate principal minor using bounded exact 53-bit significand products in two UInt64 words and signed exponents; zero diagonals require zero coupling. This necessary gate rejects underflow/overflow-induced false principal-minor acceptance without changing Q or caller tolerances. General higher-dimensional PSD remains the documented pivoted numerical Schur contract; pairwise minors alone are not a sufficient general PSD certificate. Computed P retains its explicit roundoff contract. The fixed per-pair 128-operation reservation is checked before this bounded no-allocation comparison; failures retain the actual cumulative prefix. The new internal helper owns only represented-product comparison and exposes no new public API. Qualification must execute the original public designer on indefinite tiny/large and exact dyadic rank-one/neighbor costs, preserve original Riccati/stability/physical cases, and verify one-short admission work. Source implementation is not matching runtime evidence.


## Selected Native qualification
Pinned Swift6.4.0/macOS27 SDK execution against fresh immutable2387 producer passed the original nine Native functions/eight synchronous public groups plus an independent exact-cost boundary case (Native10/public9). Receipt `.build/af42-linearquadratic/native-receipt.json` SHA b39c83576e6c68bd2d7634ce72dd14f7d46b0007c3c779db4fabb175997bbdd2 and actual consumer source/object records bind the executed code. All producer source/object/module/dylib hashes match before/after. Original Riccati/Lyapunov/stability, physical equilibrium/bilinear/effort/dynamics, dimensions/saturation/source, failure/consumed-work and awaited cancellation oracles pass. Exact principal-minor refusal, rank-one/neighbor admission and one-short reservation pass through the public designer. A ten-vector Native helper probe also checks represented product extremes; it does not substitute for public behavior. Fixture stored child pose is corrected to the unchanged initial q=.5m; unavailable final-cancellation platform now refuses explicitly. Support/public compile for macOS13; actual Testing modules compile for14 and execution was on27. Same Mutex counter storage/read/mutation is retained; portable synchronization runtime and full portable qualification remain unverified. Original source16 gains one internal bounded comparison helper; no new public API or residual tolerance is introduced.
