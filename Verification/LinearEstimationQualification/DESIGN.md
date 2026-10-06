# Linear Estimation Qualification

## Purpose and Scope
Parent: [SwiftMechanics](../../DESIGN.md). Own independent behavioral qualification of [LinearEstimation](../../Sources/SwiftMechanics/Execution/Control/LinearEstimation/DESIGN.md)'s selected normalized discrete time-invariant Kalman filter and contributor codec. Root owns target registration and execution leases. The original AF35 preparation used the historical Native2363 inventory ba99ba4e21c6af7c6bb6394d58a4b9808ca7dd5e17fe0eba5718bca8bb0f6441; its deleted objects are not inputs to the AF36 Native proof below. No portable qualification follows from a source match.

## Responsibilities and Boundaries
Fixtures supply explicit synthetic normalized matrices and coordinate scales through original public constructors. Cases consume only public LinearEstimating and LinearEstimatorContinuationCoding requirements and public matrix coefficient access, retaining original typed failures and ledgers. They own independent numerical assertions, not sensor calibration, mechanical model evolution, Runtime acceptance, nonlinear estimation, delayed assimilation or shared Numerics changes.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [LinearEstimation](../../Sources/SwiftMechanics/Execution/Control/LinearEstimation/DESIGN.md) | subject | admit/initialize/predict/update; schema/record/restore | Original public implementation | Returned state is tentative |
| [Linear algebra](../../Sources/SwiftMechanics/Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | DenseMatrix coefficient access, NumericalWork/Budget, original Cholesky diagnostics | Qualified immutable original supplier | NonlinearMatrix is outside these fixture paths |
| [State records](../../Sources/SwiftMechanics/Execution/Runtime/StateRecords/DESIGN.md) | depends on | RuntimeContributorState/Schema construction | Owned codec bytes | No transaction acceptance authority |

## Architecture
```text
explicit normalized matrices + original clock/source/layout + local NumericalWork
    -> any LinearEstimating / original ReferenceLinearEstimator
    -> admitted model -> initial state -> prediction -> innovation/Joseph update
    -> independent literal scalar / fixed two-state assertions
same original state -> any LinearEstimatorContinuationCoding
    -> original contributor record -> restore -> bit-exact state/record checks
```
The same seven synchronous public cases are called by Testing and the public runner. A separate Native-only eighth case cancels its own child Task; it is not part of portable synchronous evidence.

## Contracts and Invariants
| Case | Independent oracle / counterexample |
|---|---|
| Scalar predict and assimilation | A=2, B=3, H=1, Q=1, R=4, x=1, P=2, u=2, z=10: prediction x=8/P=9; innovation2/S13/K9/13; posterior x122/13/P36/13 |
| Coupled states and Joseph | A=[[1,1],[0,1]], B=[1/2,1], H=[1,0], Q=diag(1/4,1/2), R=2, x=[1,2], P=[[4,1],[1,3]], u=2, z=9: prediction x=[4,4], P=[[37/4,4],[4,7/2]]; K=[37/45,16/45], posterior x=[73/9,52/9], P=[[74/45,32/45],[32/45,187/90]], determinant131/45 |
| Admission/covariance | Full and deficient observability; PSD zero pivots, nonzero coupling at zero pivot, asymmetric/indefinite covariance, positive R pivot and explicit capacity/metadata limits |
| Clock/missing/source | One resolved slot per tick; fail versus retainPrediction; exact tick/sample/delivery; stale/future/order/layout/revision refusal; no reuse of old observations |
| Codec | Literal little-endian words and fixed payload length, negative-zero mean bit preservation, byte-exact record replay, next-step equivalence, corruption/configuration/source refusal |
| Work/callback cancellation | Caller ledger seeded with nonzero work; scalar storage319 versus original scalar envelope320; operations limit5 and supplier iteration/storage failure; no state publication, exact failure admittedWork==caller prefix |
| Actual supplier overflow | A=B=1, H=1e-309, Q=0, R=1e-320, P=1e308, rank threshold1e-310/pivot0. S approximately1e-310 and P*H approximately0.1 require gain approximately1e309, beyond finite Double. Original Cholesky must fail with unavailable executed supplier work, preserving the admitted reservation and original state |

Assertions use absolute1e-11 and relative1e-11 for finite analytic numerical values, exact equality for associations/clock/flags/ledgers and bit patterns for codec/replay. Tolerances are independent assertion bounds and never alter subject acceptance policy. No oracle calls internal matrix arithmetic, covariance validation, codec prefix helpers or production diagnostics to compute expected values. Diagnostic residual acceptance and actual solve work are separately checked as original supplier evidence.

## Runtime Flows
Each case creates a new immutable public model and exclusive local ledger. Failure checks retain the original prefix and caller ledger, then independently reuse the untouched prefix. Codec restore remains tentative and cannot claim Runtime association or accepted physical time. Common cases contain no awaited cancellation; Native Task cancellation is explicitly separate.

## State, Ownership, and Lifecycle
No static mutable state, Mutex, observer, callback counter, process, stream or shared file is used by fixture code. All state, arrays, records and models are immutable or operation-local; NumericalWork mutates only through local inout ownership. The Native Task captures immutable Sendable state and owns its own ledger. Native/WASM/Embedded storage and Sendable contracts are not weakened; portable execution is still pending.

## Failure, Concurrency, and Constraints
Expected errors are compared to original LinearEstimatorFailure.cause; its original state prefix and admittedWork are checked independently. Actual supplier failures retain failedSupplierWorkUnavailable rather than inventing zero executed work. No error is converted to a success or alternate algorithm. Tests use one-minute limits. Historical thin Native128MiB accounting is not authority for the fresh AF36 producer; the root-granted cold contract below owns its deadlines, jobs and disk limits. Only the released cold slot executed the new compiler.

## Verification and Change Impact
Original subject/Cholesky/codec paths have been read, including shape/observability admission, exact timing and observation order, Joseph PSD/symmetry, conservative reservation and binary schema/state checks. Seven shared synchronous cases plus the separate Native Task case were initially prepared without execution. The AF36 proof below binds a fresh matching1999-source module/dylib and fixture objects; no original2363 module/object is reused. A concrete counterexample requires DESIGN-first owned source repair and a fresh matching producer; no old module/new object combination is evidence. Shared Numerics, Runtime registration, ordinary/Embedded profiles and root integration are outside this source-only completion claim.

## AF36 Fresh Native Reconstruction

The former2363 object/depot authority is historical and is not an input to this run. Root assigns a fresh private producer consisting of exact committed HEAD1983 admitted production files plus the current16 LinearEstimation files, for1999 total. Obtain lower bytes using `git archive` of the fixed commit and its original production exclusion list; no live uncommitted lower provider and no Terrain18 overlay is admitted. Subject and the existing six fixture Swift files are hashed before copying and before/after every execution. No numerical, timing, codec447-byte, work-prefix or cancellation oracle changes accompany reconstruction.

```text
fixed HEAD archive + original HEAD exclusions + subject16
    -> macOS13 dynamic SwiftMechanics / pinned Swift6.4.0 WMO / threads4 / enable-testing
    -> fresh module + dylib paths supplied through -I/-L/-l and rpath
    -> private SwiftPM support/test/public consumer with same six fixtures
    -> eight original Testing cases + seven original synchronous public groups + original Task case
```

This is a cold producer composition, distinct from earlier128MiB thin-consumer accounting. Root operational authority allows at most8GiB additional allocated bytes across this private directory, from one immutable initial baseline, and requires4GiB global free space before launch and throughout execution. Sample every2seconds, refuse observations longer than5seconds, and terminate the process group with preserved logs/receipt on resource or deadline failure. Producer setup uses a900second watchdog; each test/public operation has its own timeout. Only root-granted cold slots may start compilers; preparation launches none. SwiftPM and driver jobs are4, producer WMO requests frontend threads4, and actual emitted arguments are recorded rather than inferred.

Source pre/post identity, the complete actual compiled production list, fresh module/dylib hashes, consumer compile/link arguments and runtime loaded dylib establish this run's provenance. Successful compilation alone does not qualify filters, covariance, codec, failure prefix or cancellation. Actual Native8/public7 plus Task1 results must be returned separately before root registration/commit; ordinary/Embedded and Runtime transaction acceptance are separate pending obligations.

## AF36 Exact Native Evidence

The fresh1999-source producer and six unchanged fixture files executed under root's released cold slot on pinned Swift6.4.0/macOS arm64 with macOS13 deployment, WMO and actual thread/job4 flags. All eight original Swift Testing cases and the original public seven synchronous groups plus separate awaited Task cancellation passed. Original scalar and coupled rational Joseph values, covariance/observability refusal, exact447-byte continuation, clock/source/missing semantics, admitted work prefixes and tiny-innovation overflow assertions are unchanged. No production or fixture Swift edit was needed.

| Evidence | SHA-256 | Scope |
|---|---|---|
| [Fresh source freeze](../../.build/af36-linear-estimation-native/source-freeze.json) | `7da74598a95539e468073a2b3fa015ac8314e7b5812af70432924ec3455da9e4` | HEAD1983 plus subject16 and fixture6, both manifests |
| [Final Native receipt](../../.build/af36-linear-estimation-native/native-continuation-receipt.json) | `efc201305a123293ca6963e1499ac4a144592581e2f62481d3beadce0b4856f1` | Native8/public7+Task1, source pre/post and fresh source/object/link records |
| [Reporting-only failure](../../.build/af36-linear-estimation-native/native-receipt.json) | `3de36e1ab41a4f3f20a17001963a0bc8dcdbd50a8f442e1c11e7aeea87f06615` | Original8 actually passed; collector expected the older test summary wording |

The single-token `-I<absolute module path>` consumer admission prevents a known generated discovery-runner orphan flag. The collector was corrected to recognize the actual `8 tests in 1 suite passed` summary without rebuilding the producer or rerunning tests. Continuation preserved the original cold baseline and first reporting failure. Producer120.491seconds, consumer20.037seconds, test operation2.738seconds and direct public0.425seconds are process durations. Maximum additional allocation994,181,120bytes and minimum observed global free196,965,462,016bytes stayed within8GiB/4GiB limits. These measurements are not physics or stack guarantees.

The actual production list contains exactly1999 frozen sources, and fresh object/module/dylib hashes plus all fixture target source/object lists are retained. Direct public dyld output establishes loading the new `libSwiftMechanics.dylib` with SHA-256 `14ff14c7edbb5f454e6d54b776ffc185fd8963df2f4bf371574b256e28eca5bf`. SwiftPM's test helper emitted no dyld trace; that trace is explicitly unavailable, while its executed test binary's original dependency and exact fresh library rpath are retained. No runtime load trace is invented for that helper.

This closes selected owner-local Native behavior only. Ordinary/Embedded profiles, Runtime contributor registration/acceptance and full CO-007/008 integration remain pending. Root owns the resulting individual commit and canonical registration; neither deleted historical object reuse nor success on other feature graphs is claimed.


## Final Native Composition
The immutable2124-source producer and these unchanged fixtures passed original8 tests and seven synchronous public groups plus awaited Task cancellation. Final receipt `.build/af36-linear-final-consumer/native13-continuation-receipt.json`, SHA5036d1a3c214c36cb0ecc0c01123e72b897763a14620f951da1224be8dfbe68e, records actual Support/Public macOS13 and Testing/generated-runner macOS14 targets. All source/object/module/library bindings agree before and after; no producer rebuild or copied objects occurred. The historical macOS14 consumer proof remains separate. Actual macOS13 runtime, portable targets and accepted Runtime association are not established by this current-host execution.
