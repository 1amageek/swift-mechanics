# ConvexPrograms

## Purpose and Scope
Parent [module](../DESIGN.md); no children. Own complete caller-bounded active-basis enumeration and independently checked original LP/QP certificates. Selected initial convex domain qualified; execution evidence and its platform scope are owned by the [parent evidence record](../DESIGN.md#selected-af18-qualification).

## Responsibilities and Boundaries
Finite box, full-row-rank equality admission, LP or symmetric SPD QP. Constant cost/gradient and CSR affine derivatives. No general simplex/interior point, general PSD/indefinite optimization, nonlinear Hessian or mechanical identifiability claim. No retry after a failed linear supplier.

## Related Designs
[ProblemContracts](../ProblemContracts/DESIGN.md) owns input/status/certificate meaning. [Numerics](../../../Mathematics/Numerics/DESIGN.md) supplies actual LinearSolving<Double> dense partial-pivot LU and Cholesky operations. [Tests](../../../../../Tests/MechanicsOptimizationTests/DESIGN.md) owns analytic/failure evidence. Full OP ownership belongs module.

## Architecture
```text
admit + SPD proof -> enumerate independent active rows -> actual KKT LU
 -> original primal/dual/stationarity/complementarity -> complete original basis processing
 -> optimal certificate OR phase-I LP -> ORIGINAL Farkas certificate OR typed failure
```

## Contracts and Invariants
LP candidates use n-r active rows (vertices); QP candidates use 0..n-r active rows. All box rows participate. Equality and candidate row rank is screened by owned bounded elimination before supplier LU. Zero residual pivot may mark a dependent candidate basis; positive pivot below caller rank threshold is indeterminate and terminates. Rank screening is numerical admission, not global exact rank proof. Actual KKT residual and original certificate are separately recomputed; false rank screening cannot establish infeasibility.
KKT=[H C^T; C 0], rhs=[-c; active rhs], where H=0 for LP. SPD is validated through actual Cholesky with zero rhs before QP enumeration; non-SPD fails explicitly. Candidate multipliers are mapped into ORIGINAL row and lower/upper arrays, no fabricated force. Every admitted original basis is visited, and best accepted convex certificate retained; candidate cap exhaustion is nonconverged, numerical iteration exhaustion is resource failure.
If no original feasible candidate exists after complete enumeration, solve bounded phase-I LP min t, original x box unchanged, 0<=t<=worst violation at the box midpoint, +/- equality and inequality residuals <=t. Its original KKT certificate plus t>0 yields original Farkas weights (equality signed combination, nonnegative inequality/bound weights), with combined normal zero and weighted rhs strictly negative. Independently validate the ORIGINAL Farkas equations before infeasible. Phase-I exhaustion/no certificate cannot produce infeasible.

## Runtime Flows
Preflight shapes/IDs/metadata/storage; gather dense original affine rows; equality rank admission; QP SPD invocation; bounded enumeration; independent original candidate assessment; optional phase-I enumeration and Farkas assessment; final cancellation; publish immutable result. Failure preserves accepted caller state and stops once; its isPhaseOne flag identifies the problem whose last assessed feasibility residual was measured. Supplier successful work is absorbed with remaining budget/reserved live storage; failed consumption is unavailable and retained underlying NumericalError. Invalid returned budget/counters marks unavailable work and fails before continuation. A valid-budget returned supplier ledger is absorbed before output shape/rank/residual checks, so successful work remains recorded even when output validation fails.

## State, Ownership, and Lifecycle
Owned local dense row/Hessian/KKT/rank/rhs/active-index/candidate buffers. No per-inner-loop materialized row arrays; reuse array capacity under exclusive workspace. Candidate result arrays are output-boundary copies to retain best solution across next buffer mutation. Logical storage preflight includes retained initialized/capacity buffers and live successful supplier result; allocator rounding is not measured OS memory. No unsafe or shared-state adapter.

## Failure, Concurrency, and Constraints
Caller NumericalBudget, policy maximum variables/rows/nonzeros/factor entries/candidate bases, pivot/rank/certificate tolerances and cancellation function. Checked overflow for all products/sums. Linear capability is explicit Float64/referenceCPU LU plus explicit Cholesky qualification; no precision/backend substitution. Unsupported domains carry callable markers and typed failure. Same Sendable/workspace/isolation all targets. Caller cancellation is observed at every owned charge/rank/candidate checkpoint and immediately before publication; a synchronous nested supplier call is an admitted caller-bounded block, with its own Task cancellation checks and budget. No continuous caller callback polling inside that supplier is claimed.

## Verification and Change Impact
Independent LP (0,1), SPD QP (1,0), tied objective, row/bound Farkas cancellation, duplicate/near rank, immutable accepted inputs, numerical/candidate/fill/cancel limits and actual failed supplier work. Selected qualification is recorded in the [parent evidence authority](../DESIGN.md#selected-af18-qualification); it applies only to the actually executed cases and public paths. Full OP-004/009 remains open.
