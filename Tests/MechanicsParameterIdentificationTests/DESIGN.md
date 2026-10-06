# Physical parameter identification verification

## Purpose and Scope
Test owner for [ParameterIdentification](../../Sources/SwiftMechanics/Analysis/Optimization/ParameterIdentification/DESIGN.md). Parent is its production contract; children: none. DESIGN preceded source. The selected 26 Native tests have passed in the authorized immutable-baseline private proof. Canonical and original WASM/Embedded composition qualification remains pending; the [Optimization parent](../../Sources/SwiftMechanics/Analysis/Optimization/DESIGN.md) owns its evidence.

## Responsibilities and Boundaries
Exercise actual fixed prismatic mechanics, real passive dashpot, exact mechanical parameter products, qualified bounded QP and independent fitted Newton-Euler/KKT acceptance. Fixtures obtain synthetic accelerations through actual RigidDynamicsSolving.forward; no regression matrix is supplied to the estimator. The tests prove the selected mass/damping/noise model, not arbitrary identification, unknown inertia shape or state reconstruction.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [ParameterIdentification](../../Sources/SwiftMechanics/Analysis/Optimization/ParameterIdentification/DESIGN.md) | depends on | Physical observations, estimate and typed failure | Subject under test | Exact kinematics and stated force-noise model |
| [Dynamics tests](../MechanicsDynamicsTests/DESIGN.md) | coordinates with | Actual Newton-Euler/forward fixture evidence | Physical supplier qualification | No duplication of unrelated mechanics proof |
| [Derivative tests](../MechanicsDerivativesTests/DESIGN.md) | coordinates with | Exact mass/force products and supplier ledger refusals | Derivative supplier qualification | Parameter mapping still needs this owner's proof |
| [Optimization tests](../MechanicsOptimizationTests/DESIGN.md) | coordinates with | Original convex certificates and failure work | Numerical supplier qualification | Optimizer result is independently assessed |

## Architecture
```text
known physical mass/dashpot + actual load/dynamics forward
 -> immutable observation states and measured efforts
 -> required physical estimator
 -> independent parameter/objective/nullspace/covariance/KKT oracle
 -> typed invalid/correlated/failed-work/cancel/capacity counterexamples
```

## Contracts and Invariants
Known physical parameters m=2 kg,d=0.5 kg/s. Two actual-forward samples with (v,a,f)=(1,1,2.5) and (2,-1,-1) recover that pair. Independent normalized design rows (1,1),(-1,2) give information [[2,-1],[-1,5]] and Gaussian reference covariance (1/9)*[[5,1],[1,2]] at unit force sigma and unit SI references. These scalar formulas are test oracles only; production must obtain its columns through actual mechanical direction products and independently recompute fitted mechanics.

Add a third sample (v,a,f)=(-1,0,-0.5). Perturb only its measured force by +0.1 N with unchanged exact supplied kinematics. Independent information [[2,-1],[-1,6]], inverse (1/11)*[[6,1],[1,2]], and estimator parameter shifts (-0.1/11,-0.2/11) verify a nonzero original physical misfit/objective. Noise sigma is a supplied observation assumption; it is not estimated from these residuals. Active bounds must retain original KKT signs and be identified in output; reference covariance must never be labeled covariance of the bounded estimator. Physical parameter/force reference changes preserve fitted SI mass/damping and original objective.

Correlated observations a=2*v and f=4.5*v must refuse identifiability despite zero objective and finite box: physical pairs (m,d)=(2,0.5) and (1.5,1.5) produce the same true mechanics, null direction (1,-2) independently annihilates the original unscaled design. Near-correlated positive pivots below caller threshold must report rank-indeterminate rather than a false rank/covariance. Different world axis rotations and nonzero fixed COM offsets preserve the generalized physical result. Wrong state revision/layout/body/frame, unsupported joint/base/anchors, nonfinite/missing acceleration/effort, nonpositive sigma, invalid bounds/reference dimensions/physical inertia and stroke/rate domains fail explicitly.

## State, Ownership, and Lifecycle
Each test owns local immutable source/observations and exclusive IdentificationWorkspace, NumericalWork, LoadWork and DerivativeSupplierWork. No shared file, global mutable fixture, hidden RNG or accepted-state mutation. Fault variants are immutable except the opaque linear-refusal invocation counter below. Its deployment availability is guarded inside the test body, not on the test declaration.

| Logical state | Storage on Native / WASM / Embedded | Isolation and access | Release |
|---|---|---|---|
| Shared cancellation flag | Same `let Mutex<Bool>` | isCancelled getter and cancel mutation both withLock; Sendable callback runs outside lock | Local test owner releases cancellation owner after assertions |
| Refusing linear supplier invocation count | Same `let Mutex<Int>` | Both dense and CSR requirement implementations mutate withLock; calls getter reads withLock; no callback or await in lock | Local test owner releases supplier after failure assertions |

## Failure, Concurrency, and Constraints
Actual failing numerical/derivative/load providers, reset/replaced supplier ledgers, altered returned source/metadata or falsely accepted optimizer certificates must not publish a physical estimate. Failure preserves underlying typed cause, known prefix, unavailable consumption and stop-once behavior. Finding-specific reconciliation tests run actual ExactMechanicalDifferentiator before simultaneous three-ledger reset on success and throw; all captured prefixes must survive. A changed LoadBudget cancellation closure must never replace caller authority, including after a successful estimate. Observation/storage/fill/operation/candidate/iteration/call budgets and cancellation are independent caller boundaries checked before prohibited work. All tests have timeout qualification; independent Native copy/build used root's assigned slot and stopped cache directly because disk is constrained. No copied generated caches or shared manifest changes are part of this preparation.

## Verification and Change Impact
One stable source/test snapshot receives an owned coherent review and focused behavioral execution; finding-only repairs receive targeted recheck. Root owns parent evidence, canonical registration, original Native/WASM/Embedded public probes, integration and commit. Existing supplier source/tests remain unchanged. Passing these tests qualifies only the stated fixed affine mechanical/noise domain.
