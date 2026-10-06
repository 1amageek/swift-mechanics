# NonlinearKKT

## Purpose and Scope
Parent [Optimization](../DESIGN.md); no children. Own an initial fixed-active-set, twice continuously differentiable, normalized finite-box nonlinear optimization domain. Selected independent Native behavior qualified; canonical integration and original WASM/Embedded qualification remain parent owned and pending. Full IM32 / OP-004 remains open.

## Responsibilities and Boundaries
Required caller original objective/constraint values, first derivatives and weighted Lagrangian second derivatives; actual square nonlinear KKT solve; independently recomputed original KKT, LICQ and positive reduced curvature. Publish strict LOCAL minimum only. No active-set discovery, global nonlinear result, inferred mechanical Hessian, identification or unbounded problem.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [Nonlinear](../../../Mathematics/Nonlinear/NonlinearSolve/DESIGN.md) | depends on | NonlinearSolving, original residual, failure work | Root solving alone establishes no optimality; generic scalar equation conformer preserves Embedded witness specialization |
| [Numerics](../../../Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | NumericalWork, explicit Cholesky | Failed linear consumption unavailable; no retry |
| [ProblemContracts](../ProblemContracts/DESIGN.md) | depends on | Immutable OptimizationMetadata / SI references | No change to frozen convex status authority |
| [Tests](../../../../../Tests/MechanicsNonlinearOptimizationTests/DESIGN.md) | used by | Original analytic equations and typed failures | Root owns shared graph and platform composition |

## Architecture
```text
immutable layout + required smooth callbacks + fixed active rows + initial x/multipliers
 -> generic scalar KKT equation -> actual NonlinearSolving
 -> ORIGINAL values/first derivatives -> KKT feasibility/sign/complementarity
 -> LICQ RREF / independent C*Z residual -> actual weighted Hessian -> Z^T*H*Z Cholesky
 -> strict LOCAL certificate or typed refusal
```

## Contracts and Invariants
Original normalized objective f(x), e(x)=0, g(x)<=0 and finite lower<=x<=upper; active indices refer to user inequalities then interleaved lower (-x+lower) / upper (x-upper) rows. Caller supplies initial equality/active multipliers. KKT residual consists of grad(f)+Je^T*lambda+Jactive^T*mu and equality/active row values. Exact Jacobian uses supplied H_L=H_f+sum(lambda*H_e)+sum(mu*H_g), including nonlinear constraint curvature. Fixed CSR patterns are immutable layout authority; callback outputs must preserve lengths and fully overwrite poisoned buffers. Original values/derivatives are independently invoked at publication; callback C2/exact derivative provenance remains an explicit supplier assumption, not proved globally by a directional probe.
All active inequalities/bounds require strictly positive multipliers above caller admission margin; all inactive rows require strictly negative slack beyond caller margin. Weak-active critical-cone curvature is unavailable: min -x^2, x<=0 at x=0,mu=0 must fail even with full rank and zero-dimensional tangent. Positive projected curvature on the active nullspace is sufficient only under this strict-complementarity admission. LICQ full row rank required; positive but small rank pivot is indeterminate, exact zero/dependent rows fail. RREF constructs nonorthonormal Z with each free coordinate equal to one in its own column; independently recheck C*Z before curvature. Cholesky certifies positive Z^T*H_L*Z; no smallest-eigenvalue estimate. Zero-dimensional tangent is explicitly vacuous after LICQ/strict-complementarity gates.
Original primal/dual/stationarity/complementarity each have independent caller absolute/relative scaling; acceptance tolerances describe approximate numerical certificates, not exact roots or a global optimum. SI physical point/objective conversion uses the existing metadata normalization; mathematical multipliers are not dynamic reactions.

## Runtime Flows
Admit layout/patterns/metadata/bounds/capacities; reserve conservative live slots; construct actual KKT adapter; invoke nonlinear once; absorb successful or exposed failed work; original re-evaluation; rank/nullspace; Hessian/projected curvature; final cancellation; immutable publication. No retry or accepted-state mutation.

## State, Ownership, and Lifecycle
Immutable Sendable layout owner, problem/provider and result. All work and phase arrays operation-local; no shared mutable cache, unsafe memory or target-conditioned storage/conformance. The existing nonlinear protocol cannot supply external reusable callback workspace: each callback owns bounded point/value/multiplier/Hessian buffers, charged before allocation and retained only for that invocation; no per-inner-loop row arrays. Conservative owner reservation includes these buffers and caller maximum provider scratch. Provider receives a separate remaining-operation/iteration ledger with its scratch storage limit; its invocation is primed with one operation, budget/counters are checked before absorption, including on throw. Invalid/replaced ledger makes consumption unavailable and stops. Numerical counts represent declared arithmetic/initialization/copies and callback invocation units; logical live slots are not allocator-rounded OS bytes.

## Failure, Concurrency, and Constraints
Caller controls dimensions/nonzeros/dense fill, scratch, NumericalBudget (nested nonlinear budget is the componentwise minimum of its template cap and remaining outer budget), nonlinear strategy/capability, rank/nullspace/certificate/strictness margins and Cholesky capability/tolerance. Checked sizes before allocation. Callback failures preserve typed NonlinearCause; reserved EquationError code Int.min denotes invalid callback ledger only. Successful nonlinear/linear work is absorbed before output checks. Nonlinear failure exposes known work, retained underlying failure and unavailable nested-work flag; opaque failed linear work is unavailable. Original disagreement, saddle/nonpositive curvature, rank, weak active/inactive margin, callback metadata/shape, budget and cancellation never become success. Caller callback cancellation is checked before/after every callback and before publication; nested solver blocks remain caller-budget bounded.

## Verification and Change Impact
Actual analytic curved-equality optimum, active nonlinear inequality, bound optimum, C2 constraint stress term, saddle/weak-active counterexamples, rank and false internal residual, original infeasibility/dual signs, exact supplier failures and work gates, sparse patterns, metadata, budget and cancellation. Independent Native baseline copy follows AF27; exact profile composition/root commits remain parent owned. Existing supplier and convex source remains read-only.

## Selected Independent Native Evidence
Committed baseline `1bf65c3ed00f95f58edcf7fa0ff6b7acbe9c3b8b` plus only this child/test overlay was compiled and linked with `/Users/1amageek/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swift`, four jobs and setup timeout1200. [Setup log](../../../../../.build/af27-independent-nonlinear-optimization/setup.log) reports completion in 27.63 seconds, exit0. [Behavior log](../../../../../.build/af27-independent-nonlinear-optimization/tests.log) records 15 owned tests, 23 frozen convex tests and 11 frozen nonlinear tests, all passing, with execution timeout240 and exit0. Copy-only registration retained the unchanged production/executable graph and flags. Existing baseline verification warnings were not changed. This evidence applies to the executed Native domain, not original WASM/Embedded, canonical registration, full OP-004 or performance/allocation measurement.
