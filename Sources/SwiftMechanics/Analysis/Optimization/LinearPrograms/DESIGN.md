# General affine linear programs

## Purpose and Scope
Parent: [Optimization](../DESIGN.md). Own selected OP-004 general LP optimal/infeasible/unbounded terminal certificates for unrestricted finite variables, affine CSR equalities/inequalities and optional finite bounds. No children. Selected original-data behavioral and Native/ordinary/Embedded public qualification is complete; its evidence owner is linked below. Full OP004 family remains open.

## Responsibilities and Boundaries
Own phase-I/II simplex, original row mapping, degeneracy policy and independently recomputed terminal certificates. Consume qualified public CSR, OptimizationMetadata, SIReferenceQuantity and NumericalWork contracts. Existing bounded convex solver remains unchanged. No nonlinear/QP/status inference, finite-box substitution, regularization, hidden precision change or unqualified supplier.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [Optimization](../DESIGN.md) | parent | OP-004 ownership and registration | Full family remains open |
| [ProblemContracts](../ProblemContracts/DESIGN.md) | depends on | Immutable physical normalization metadata | Reuse metadata, not its finite-box status authority |
| [LinearAlgebra](../../../Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | Actual canonical CSR and cumulative work | Owned tableau arithmetic; no LU performance claim |
| [ConvexPrograms](../ConvexPrograms/DESIGN.md) | coordinates with | Original mathematical sign conventions | No internal helper or finite-box inference |

## Architecture
```text
original normalized c/E/A/bounds + source/SI references
 -> free x=xPlus-xMinus + every original equality/inequality/bound row
 -> signed RHS, signed slack, one artificial column per row
 -> phase-I Bland simplex -> original Farkas OR artificial removal
 -> phase-II Bland simplex -> original KKT/gap OR original recession ray
 -> immutable certificate/status OR typed nonconvergence/resource/cancellation
```

## Contracts and Invariants
Original problem is min constant+c*x, E*x=b, A*x<=d and each declared finite lower/upper bound. Missing bound means unrestricted on that side; no infinity or guessed clipping enters coefficient storage. All coefficients are dimensionless normalized physical data. Metadata owns positive SI variable/objective/row references, variable IDs, original source/revision and physical dimensional meaning. Dual physical values are objectiveReference/rowReference times normalized multipliers; bound rows use the variable reference. Returned physical point/ray and objective/slope use those same original references.

Each original row remains independently addressable. Equality and inequality/bound row IDs retain their kind/index, sign flip and RHS. Standard variables are xPlus/xMinus, signed inequality slack and artificial columns. Artificial basis starts at abs(original RHS). Tableau pivots update a full transformation from original signed rows; mapping original dual=-rowSign*(basisCost*rowTransform) retains equality signs and nonnegative <= multipliers. Redundant zero rows can be deactivated only after an artificial basic row has exact zero RHS and every non-artificial coefficient is exact zero. All original rows remain in final certificates. Rank near threshold and positive artificial remnants are numerical ambiguity, never infeasibility.

Phase I minimizes the actual sum of artificial variables. Phase II uses original split cost and objective constant. Bland chooses smallest improving nonbasic column; minimum nonnegative ratio leaves, with exact ratio ties broken by smallest basic column. Owned pivot and caller NumericalWork iteration limits bound degeneracy. Negative basic RHS, tiny positive pivot/ratio ambiguity and nonfinite arithmetic fail explicitly. No iteration limit, overflow or missing leaving row alone establishes unboundedness.

Optimal publication checks original equality/inequality/bound feasibility, multiplier signs, original c+E^T*nu+A^T*lambda-lower+upper stationarity, complementarity and primal/dual objective gap with caller dimensionless tolerances. LP uniqueness is not established.

Infeasible publication requires exact nonnegative inequality/bound weights, original combined normal within tolerance, original weighted RHS and strict separation. For a nonzero normal residual, its global lower bound must be computable from the ACTUAL declared lower/upper bounds in that sign; an unrestricted side cannot be bounded by a tolerance. The resulting lower bound minus weighted RHS must exceed the separation threshold. This retains Farkas proof meaning on unrestricted coordinates; numerical ambiguity refuses classification.

Unbounded publication requires an original feasible point and an original direction with exactly zero equality products, nonpositive inequality products, correct bound direction signs, and c*direction strictly negative beyond the caller separation threshold. Equality/inequality small positive residuals never certify an infinite-time recession path. All certificates are evaluated against retained original input rows after optimization, not tableau status. Arithmetic remains Float64; exact-zero requirements are strict numerical acceptance and may refuse an otherwise valid mathematical certificate.

## Runtime Flows
Preflight all dimensions/nonzeros/metadata/counts/work/storage; create original row map and full standard tableau; phase I; certify Farkas or remove zero artificial basis with bounded pivots; phase II; map candidate/dual/ray to original coordinates; re-evaluate original certificates; final cancellation; publish. No retries or partial terminal status. Failures retain phase, pivots, original source identity and cumulative known work.

## State, Ownership, and Lifecycle
Immutable Sendable input/result/certificates on all targets. Owned local tableau, transformation, RHS/basis/active flags and scalar reduced-cost scratch have exclusive lifetime in the synchronous call. No cache, unsafe pointer, target-conditioned storage/conformance or shared mutation. Conservative scalar reservation includes retained original CSR/rows, complete standard tableau, row transformation, scratch, output and metadata bytes: 8*tableauEntries+8*M^2+16*M*N+256*(M+N+1)+metadataBytes. Numeric work and pivots are cumulative in caller NumericalWork; no unreported external numerical solver is invoked.

## Failure, Concurrency, and Constraints
Caller bounds original variables/rows/nonzeros, tableau fill and total pivots plus NumericalBudget. Checked integer products precede allocation; zero-fill initialization is included in cumulative work. Work O((P+1)*M*(N+M)+N^2+metadata), storage O(M*(N+M)+M^2+N+metadata), where P is bounded cumulative pivots and N^2 admits unique original IDs. Per-row/column/pivot and metadata-byte cancellation checks apply. Typed invalid problem, resource, cancellation, nonfinite, numerical ambiguity and certificate rejection are distinct from terminal certified LP statuses. General exact-rational certificates or numerical refinement are not provided; uncertain Float64 certificates fail rather than silently changing arithmetic.

| Target | Mutable storage owner | Isolation | Read/mutation | Release |
|---|---|---|---|---|
| Native / WASM / Embedded | one call-local LinearSimplexTableau | exclusive local value + caller inout work | internal synchronous methods | scope exit |
| Native / WASM / Embedded | public problem/result/certificates | immutable Sendable | immutable properties | value lifetime |

## Verification and Change Impact
The selected qualification independently checks bounded/unrestricted/fixed optima and nonzero constants, dependent/zero equality rows, a degenerate Bland fixture, original KKT/gap and physical dual scales, unrestricted Farkas contradictions, equality-null and zero-row recession, and selected capacity/storage/work/pivot/cancellation/nonfinite/tiny-pivot failures. The public protocol passed selected Native/ordinary/Embedded execution, and the canonical Native composition passed the same six tests. The source-first handoff is frozen; root owns progressive registration and commit while unrelated implementations continue. These fixtures do not exhaust arbitrary dimensions/conditioning or close the full OP004 family. Changed original row, arithmetic, SI or failure premises invalidate their affected proof.

[LinearProgramsQualification](../../../../../Verification/LinearProgramsQualification/DESIGN.md) owns independent original-data behavioral fixtures and exact selected target evidence.
