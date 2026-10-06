# Discrete linear state estimation

## Purpose and Scope
Parent: [Control](../DESIGN.md). Children: none. Own the selected CO-006 discrete, time-invariant, fully observable, nondimensionalized Double Kalman filter. Source implementation is intentionally handed off without build, runtime or platform qualification under the current source-first instruction. Nonlinear EKF/UKF, smoothing and delayed measurement assimilation are not admitted domains.

## Responsibilities and Boundaries
Own immutable model admission, initial estimate admission, pure prediction, observation assimilation and owned binary continuation. The caller supplies A, B, H, Q, R, coordinate normalization, frame/chart and source revision. Runtime alone publishes accepted state; a returned estimate or contributor record is tentative. No sensor, controller, LQR or mechanical state is implicitly read or changed.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Control](../DESIGN.md) | parent | Requirement and integration ownership | Root maintains child index | Source is unqualified |
| [Linear algebra](../../../Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | DenseMatrix, actual Cholesky solve and original residual, NumericalWork | Qualified IM03 supplier | Solver failures do not expose work; conservative bounds are reserved before callbacks |
| [Runtime transactions](../../Runtime/Transactions/DESIGN.md) | coordinates with | Exclusive local trial and atomic acceptance | Qualified IM08 owner | No new registration or commit authority |
| [Runtime state records](../../Runtime/StateRecords/DESIGN.md) | depends on | Owned contributor schema and bytes | Pure checkpoint boundary | Caller must register, associate and commit through Runtime |
| [Linear estimation qualification](../../../../../Verification/LinearEstimationQualification/DESIGN.md) | used by | Original public model/state/filter/codec and typed failure ledger | Independent owner-local analytic cases | Prepared source does not qualify runtime or portable behavior |

## Architecture
```text
revision + clock + coordinate scales + A/B/H/Q/R -> bounded admission -> immutable model
immutable prefix + explicit held input -> A*x+B*u, A*P*A^T+Q -> tentative prediction
prediction + current identified reading -> innovation -> actual SPD solve -> Joseph covariance
tentative estimate -> owned contributor bytes -> caller-owned Runtime trial -> accept/reject
```

## Contracts and Invariants
All matrices and estimate/measurement values are normalized dimensionless coordinates. Each coordinate retains its original PhysicalDimension and positive SI scale, identity and frame; the caller converts once at the external boundary. A maps state to state, B maps input to state, H maps state to measurement. Covariance entries are products of normalized coordinates. Shapes and checked products precede allocations. Q and P are symmetric positive semidefinite under the caller's declared covariance tolerance; R and S are strictly positive definite under the supplied pivot threshold. Exact input symmetry is required. Output roundoff symmetry is restored only after the caller's absolute symmetry tolerance passes, then covariance is checked again. A bounded elimination of stacked H, H*A, ..., H*A^(n-1) establishes threshold-qualified full observability; deficient rank is an explicit setup failure.

Prediction uses the supplied held normalized input for exactly one configured sample period. Update computes z-H*x, S=H*P*H^T+R and solves S*K^T=(P*H^T)^T with the original IM03 Cholesky implementation; there is no inverse or singular fallback. P+=(I-KH)*P*(I-KH)^T+K*R*K^T. Every public operation returns a new immutable estimate only after all checks and cancellation safe points pass. Failure retains the exact original estimate prefix and cumulative caller ledger; no partial estimate is accepted.

## Runtime Flows
Initialize binds tick zero to the epoch. Prediction advances exactly one tick using checked UInt64 arithmetic and the explicit epoch+tick*period time. Observation must have matching source/model revision, filter revision, measurement layout, exact sample time and delivery time equal to the predicted tick time. Delayed, future, duplicate and out-of-order samples fail explicitly. Missing observations use the explicit caller policy: fail or retain this prediction without assimilation. No old reading is reused. Each tick resolves one observed or explicitly missing slot before another prediction. Continuation records preserve clock tick, sample resolution, last measurement sequence/time, mean and covariance plus bit-exact complete model/configuration prefix.

## State, Ownership, and Lifecycle
Models, input/measurement snapshots and estimates own immutable Sendable COW values. Only call-local arrays and the caller's exclusive inout NumericalWork mutate. Independent calls share no mutable storage. No pointer, actor, conditional storage, unchecked conformance or external accepted-state mirror exists. Caller snapshot lifetime lasts through synchronous evaluation; returned records retain all arrays. A fixed immutable final failure reference retains the original prefix and ledger, never a partially modified candidate; the typed-throws carrier does not inline the full model/state payload into every temporary. Its allocation is reserved by the fixed conservative operation storage envelope, and it releases backing owners with its last reference. Decode recreates a tentative value; registration and restored-state/physical-clock cross-validation belong to Runtime composition.

## Failure, Concurrency, and Constraints
Caller limits state/input/measurement cardinality, metadata bytes, continuation bytes, finite coefficient magnitude, numerical work/storage/iterations, rank threshold, covariance tolerance and solve residual/pivot thresholds. Cubic admission/matrix work and scalar storage are checked with overflow-safe NumericalWork arithmetic. Each inner arithmetic charge polls Task cancellation and the explicit Sendable cancellation callback. Nested Cholesky calls use a conservative pre-reserved operation/iteration bound and exact supplier storage envelope; the ledger reports admitted reservations, not measured executed flops. Successful calls separately expose the supplier's actual work diagnostics. A failed supplier call carries `failedSupplierWorkUnavailable` and the original numerical cause; unknown executed work is never reported as zero. Failure can therefore retain exact reservation prefix even when the supplier throws without work evidence. No cancellation or exhausted-budget failure changes caller input state. Nonlinear dynamics, heterogeneous unnormalized equations, non-observable setup, unsupported time semantics, invalid covariance, failed innovation solve and corrupt continuation are explicit typed failures.

## Verification and Change Impact
Prepared [owner-local qualification](../../../../../Verification/LinearEstimationQualification/DESIGN.md) fixes seven independent synchronous scalar/coupled-state/coupled-measurement, covariance/observability, clock/missing/source, continuation, budget/callback and actual supplier-overflow cases. A separate eighth Native case cancels its own Task. All16 production Swift sources match the original immutable2363 source/object binding; no physical or numerical algorithm changes accompany fixture preparation. Cases retain original normalized equations, Joseph covariance, failure causes, exact original prefix and admitted work; no production tolerance or fallback changes. The initial source-only preparation had no runtime evidence. The fresh AF36 selected Native proof below now executes those original cases; ordinary WASM and Embedded WASM remain unverified. Root must bind fresh matching source/module/objects and execute these cases, then test Runtime reject/accept and full contributor/physical clock association before CO-007/008 integration claims. Changes to these contracts require Control/Runtime composition review; numerical supplier contracts remain unchanged.

## AF36 Native Reconstruction Impact

The [qualification owner](../../../../../Verification/LinearEstimationQualification/DESIGN.md#AF36-Fresh-Native-Reconstruction) now prepares a fresh committed-HEAD lower composition plus these16 subject sources after old depot/evidence loss. Historical source/object associations are not reused as executed proof. Production equations, public protocol requirements, tentative-state authority,447-byte scalar continuation fixture, normalized Joseph covariance and failure/work contracts remain unchanged. New matching module/dylib and original behavioral cases must be executed before Native qualification; no source-only capability or portable claim is added.

### AF36 Selected Native Closure

The [qualification record](../../../../../Verification/LinearEstimationQualification/DESIGN.md#AF36-Exact-Native-Evidence) binds exact HEAD1983 plus these16 sources and six unchanged fixture files to a fresh Native producer/module/dylib. Eight original tests and public seven synchronous groups plus actual Task cancellation passed with the original covariance,447-byte codec, clock/work prefix and failed-supplier overflow oracles. No production or fixture Swift change was made. Collector-only summary wording was repaired without repeated producer/test execution; the first reporting failure remains preserved. This evidence does not qualify ordinary/Embedded behavior or Runtime accepted-state association. Root owns registration and integration.


## Final Native Composition
The immutable2124-source producer and these unchanged fixtures passed original8 tests and seven synchronous public groups plus awaited Task cancellation. Final receipt `.build/af36-linear-final-consumer/native13-continuation-receipt.json`, SHA5036d1a3c214c36cb0ecc0c01123e72b897763a14620f951da1224be8dfbe68e, records actual Support/Public macOS13 and Testing/generated-runner macOS14 targets. All source/object/module/library bindings agree before and after; no producer rebuild or copied objects occurred. The historical macOS14 consumer proof remains separate. Actual macOS13 runtime, portable targets and accepted Runtime association are not established by this current-host execution.
