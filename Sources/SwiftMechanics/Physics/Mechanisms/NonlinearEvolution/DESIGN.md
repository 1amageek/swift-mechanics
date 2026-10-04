# NonlinearEvolution

## Purpose and Scope
Parent: [Mechanisms](../DESIGN.md). No children. Own projected nonlinear holonomic evolution over actual compiled mechanical coordinates. This component owns both quadratic coordinate and actual body-frame geometric loop evolution. Independent transition/sleep and unsupported lower domains remain separate requirements.

## Responsibilities and Boundaries
Immutable equation binds compiled model, original quadratic geometric/time rows, physical drive, position and velocity layouts, tolerance and projection bounds. The evolution owner publishes projected endpoints through Runtime transactions and existing integration contributor history. It owns projection; the existing explicit integrator requires exact endpoint readback and cannot perform this projection.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Joints](../../../Modeling/Joints/DESIGN.md) | depends on | snapshot.coordinateRate, spherical/sixDOF body angular velocity | Actual qdot=N(q)v | Quaternion q has four entries, angular velocity three |
| [Constraints](../../Constraints/DESIGN.md) | depends on | QuadraticConstraintEvaluator, rank | Original residual/J and analytic Hessian bias | Coordinate rows need tangent conversion |
| [GeometricRelations](../../Constraints/GeometricRelations/DESIGN.md) | depends on | immutable metadata, configuration validator, original sample acceptance | Actual body/frame closure and velocity-tangent bias | No added Ndot term; full physical axes remain acceptance authority |
| [ManifoldProjection](../../Constraints/ManifoldProjection/DESIGN.md) | depends on | assemble, bounded tangent retraction | Local feasible position assembly | Path correction is bounded; no global closest-point claim |
| [Dynamics](../../Dynamics/DESIGN.md) | depends on | RigidEquationKernel | Actual physical mass, inertial bias | Spatial inertia required |
| [ConstrainedDynamics](../ConstrainedDynamics/DESIGN.md) | depends on | acceleration and reconcileVelocity | Original mass/reaction acceptance | Projection impulse is distinct from continuous reaction |
| [Integration](../../../Execution/Integration/DESIGN.md) | coordinates with | descriptor, contributor, history | RK4/Heun policy and continuation | Accepted history stores actual projected endpoint |
| [Runtime](../../../Execution/Runtime/DESIGN.md) | coordinates with | performTrial/reject/checkpoint/restart | Atomic publication and rollback | Failed opaque work stops without retry |

## Architecture
```text
accepted q/v + contributor
  -> bounded RK stage -> nonlinear position projection (original J/rank)
  -> actual compiled N(q), Ndot(q,v)v -> real mass -> velocity impulse
  -> constrained acceleration + original reaction equations
  -> endpoint projection -> Runtime accept + history / reject without publication
```

## Contracts and Invariants
q dimensions and v dimensions have independent layouts and policies. Nonquaternion coordinates use the lower coordinate-rate contract, spherical/sixDOF and spatial root use body angular quaternion rate. Tangent rows are Jq*diag(1/Sq)*N*diag(Sv); acceleration bias is the original Hessian/time bias plus T² Jq*diag(1/Sq)*Ndot*v. The kernel result must preserve the complete supplied public dynamics input (snapshot tree/layout/body/frame/pose/rate/columns, inertias, velocity, gravity and body/generalized loads). The zero-load ledger also retains its admitted zero limits/counters on success and failure. Each constrained motion must preserve that exact snapshot; returned snapshot rates never become derivative authority without this witness comparison. Bounded source-comparison work is admitted before comparison. Original rows are retained, including redundant rows, and acceptance checks every row independently. Quaternion unit-norm rows are added at position projection; they do not invent angular constraints. Initial accepted q/v is validated without correction. Stages may be projected; only endpoint q/v/a and matching continuation are published.

Admitted domains: arbitrary quadratic holonomic loops in actual coordinate charts, time-dependent quadratic rows, fixed/planar/spatial roots with dynamic state authority, ordered-axis joints, spherical/sixDOF joints. All bodies require actual spatial inertias. Prescribed anchor motion is rejected because the equation has no prescribed-sample provider. The geometric facade admits the lower builtin point coincidence, distance and regular two-row axis alignment relations with their explicit analytic time targets on connected spatial trees. Prescribed-frame, planar/mixed-body and literal disconnected domains remain lower typed rejections; arbitrary callback laws are not claimed.

## Runtime Flows
RK4 uses projected stage states; Heun/Euler error uses original SI coordinate scales before endpoint projection. Rejection changes no physical or contributor state. Successful endpoints are re-evaluated for position, velocity, acceleration and physical reaction, then published with original accepted prefix and monotonically increasing history. Deterministic checkpoints retain projected physical state and continuation.

## State, Ownership, and Lifecycle
Equation is immutable Sendable. All mutable arrays and ledgers are caller-exclusive. No cache, global mutable storage or target-dependent synchronization is introduced. Runtime owns cancellation and accepted state. Operation-local failed-work capture uses the same Mutex storage and Sendable contract on Native, WASM and Embedded. Numerical work is a failed-work prefix even when transaction publication is rolled back.

## Failure, Concurrency, and Constraints
Constructor validates bounded counts and signature byte capacity before materialization. Every operation reserves a conservative scalar envelope including tree snapshots before arrays and charges callback admission to the caller before execution. Numerical suppliers receive remaining independent ledgers with a nonzero seed; success and failure both validate budget/counter preservation before absorption. Unknown supplier failure carries failedSupplierWorkUnavailable and stops, including adaptive stepping. Projection iteration and correction limits are explicit caller policy. Rank/feasibility/domain/cancellation/capacity failures are typed RuntimeFailure; no failed opaque operation is retried.

## Verification and Change Impact
[Test owner](../../../../../Tests/MechanicsNonlinearMechanismTests/DESIGN.md). Independent physical oracles cover a Cartesian constrained pendulum, redundant nonlinear circle/closed-loop rows, original acceleration/reaction and energy, fourth-order refinement and long-run drift, quaternion q/v dimension separation, inconsistent initial state, cancellation/reset on success/failure, and Runtime no-publication/restart replay. Native scratch execution qualifies only its actual profile; root owns frozen Native/WASM/Embedded public qualification. Any chart, supplier, original-row or publication contract change requires affected evidence to be renewed.

### Qualified supplier algorithm choice
The mass-weighted solver forms its inverse-mass Gram entries independently. Actual quaternion stages can produce roundoff-level non-symmetric entries; the lower reference Cholesky contract rejects exact non-symmetry. The quaternion fixture therefore explicitly chooses the publicly available partialPivotLU constraint capability, while retaining Cholesky for actual rigid mass and the symmetric position projection Gram. The evolution owner never silently changes the caller capability or symmetrizes the lower result. A caller choosing Cholesky receives the original typed failure and unavailable supplier-work status where applicable.

The public integration contributor endpoint overload validates acceptedTime/point/nextStep/acceptedSteps/normalizedError using its original owner. Raw IntegrationHistory, reporting constructors and Integration internal captures are not consumed. This component owns its own result/failure/work records and Mutex capture.

### Native execution evidence
The isolated copied Mathematics/Modeling/Physics/Execution slice used exact Swift 6.4.0 release, arm64 macOS, and the real Runtime/rigid dynamics paths. All 11 dedicated tests passed in 14.377 seconds (compile 7.14 seconds) under a 150-second process timeout. Evidence: `/tmp/nonlinear-final-tests.log`. The twenty-second circle test retains both nonlinear rows, kinetic-speed tolerance 2e-6, position norm tolerance 1e-10 and checkpoint replay equality. The gravity pendulum, moving time-dependent rows and nonzero quaternion Ndot fixture passed independent original equations. This evidence qualifies Native only; root owns registered frozen source and public Native/WASM/Embedded execution.

| Mutable logical state | Native / WASM / Embedded storage | Isolation | Read | Mutation | Release |
|---|---|---|---|---|---|
| Failed-work attempt capture | identical Mutex<NonlinearMechanismAttempt> | withLock | read() | store() | operation-local owner destruction |
| Physical state/contributor | existing Runtime accepted owner | Runtime transaction contract | snapshot / trial read | accepted performTrial | Runtime shutdown |
| Stage arrays / NumericalWork | caller-exclusive values | same Sendable operation closure | local access | local access | attempt scope |

### Physical source binding review repair
The identified source mismatch gap is closed by exact comparisons of the public original dynamics input and snapshot witness, including public geometric column slices. Injected wrappers build and return genuine lower-produced systems with different pose, inertia or generalized loads, and a genuine constrained acceleration with a different quaternion snapshot at the same time/velocity. All four counterexamples fail before publication, with the original Runtime prefix preserved. Two targeted regression tests passed in 0.012 seconds; the positive twenty-second circle/replay and quaternion evolution paths passed in 13.762 seconds under the same exact Native toolchain and 120-second process timeouts. Logs: `/tmp/nonlinear-source-binding-tests.log`, `/tmp/nonlinear-source-binding-positive-tests.log`. No lower producer implementation or visibility was changed.

### Embedded stack lifetime repair contract
Root's actual original 128 KiB Embedded profile found a live nested stack chain exceeding its fixed platform boundary. The evolution owner will retain rich accepted/model/policy inputs in immutable Sendable attempt/run contexts, keep stage arrays and numerical counters in one bounded caller-exclusive workspace, and split preparation, stages, assessment and publication into non-inlined phase functions. Dynamics and constraint rich temporaries are retained only in immutable operation contexts consumed by the physical solve phase; construction/evaluation/acceptance phases finish before the next supplier call. The fixed numerical method, original source/row/reaction acceptance, callback admission charges, authoritative supplier ledger validation on success/failure, and exact Runtime publication/history remain unchanged. New immutable context records are accounted in the existing conservative scalar reservation. No platform conditional, target limit, lower producer or synchronization contract is changed. Root owns actual Embedded stack measurement/runtime proof; Native 13-case behavior verifies this owner preserves numerics/failure/publication before refreezing.

The phase/lifetime repair's Native behavioral recheck passed all 13 dedicated tests in 20.709 seconds (compile 11.53 seconds, process timeout 150 seconds). Evidence: `/tmp/nonlinear-phase-tests.log`. Public API and algorithms are unchanged. Actual Embedded frame and original-profile runtime verification remain root-owned; Native success is not evidence of the Embedded stack boundary.

### AF20 selected public profile evidence
Root executed the final unmodified Native, ordinary-WASM and Embedded-WASM compositions with all path completion witnesses and exit zero. [Exact profile evidence](../../../../../Verification/FoundationVerification/DESIGN.md#af20-selected-original-profile-qualification) owns toolchain, stack, runtime and test-snapshot qualification. This extends only the selected public paths documented there; the remaining domain and concurrency limitations above persist.

### IM16.10 common physical and geometric evolution contract
`ProjectedMechanismEquations` refines the existing smooth ODE contract with model, strict initial acceptance, stage consistency, and caller-ledger endpoint publication requirements. Every existential operation is a protocol requirement. The new `ProjectedMechanismEvolving` refinement owns the general facade advance witness; the original `NonlinearMechanismEvolving` protocol retains its original requirements for existing conformers. The existing quadratic facade, initializer, descriptor construction and `constraints` property remain compatible. `GeometricMechanismEquation` owns an actual `GeometricConstraintSystem`, never a manufactured quadratic payload. Both delegate rigid assembly, exact physical source comparison, velocity impulse, acceleration, all original tangent rows and original mass/J-transpose reaction acceptance to one immutable `NonlinearPhysicalEngine`; both use the existing single projected RK/Runtime algorithm.

```text
quadratic facade -> original polynomial/J -> q projection + N/Ndot conversion --+
geometric facade -> strict chart / bounded stage normalization               |
                 -> actual manifold assembly -> sealed original g/J/bias ----+
                                       common physical engine -> mass/impulse/reaction
                                       common projected evolution -> exact endpoint/history
```

External accepted initial quaternions are checked by the lower strict configuration validator without correction. A raw RK stage has an explicit caller-bounded quaternion normalization step before manifold assembly. Its Euclidean quaternion correction and lower tangent path correction are reported separately, and neither becomes an unbounded fallback. Geometric tangent acceleration bias already includes actual tree centripetal acceleration; the geometric facade never adds a separate Ndot term. Final position and every full physical axis cross component, original velocity and original acceleration rows are independently accepted. Full physical axis rate and second derivative are also recomputed from public frame poses, world body angular velocity, acceleration bias and original geometric columns; the regular two-row chart does not replace these physical derivative checks. Snapshot coordinateRate is derivative authority only after exact source checks. Rank is lower original-row rank with retained redundancy/ambiguity; the known per-row normalization limitation is not changed.

The geometric descriptor binds complete lower geometry metadata, tangent correction policy metadata, actual compiler quaternion/chart policy, position dimensions, stage chart correction bound, drive, spatial mass properties, dynamics and reaction tolerances/scales/capabilities. Equivalent identity strings cannot hide different sources or laws. Construction bounds metadata bytes and callback storage before allocation.

`writeAccepted` performs geometric endpoint checks against the projected evolution caller's NumericalWork and RuntimeStepControl, then publishes unchanged q/v/a/time. The ordinary SmoothODE `write` entry has no work parameter; its facade owns a separately caller-configured finite publication NumericalBudget and performs the same sealed builtin checks with a local ledger. That local budget is not reported as integration caller work. The projected path never uses this local-budget entry and charges its actual checks to the aggregate caller ledger. Both entries reject an inconsistent endpoint and compare derivative q with actual snapshot.coordinateRate; neither trusts an earlier cache or injected diagnostics.

Geometric assembly and evaluator suppliers receive seeded remaining ledgers only after irreversible caller admission. Success and failure both check ledger budget and monotone counters before absorption; lower failure records' unavailable-work flag is preserved. Cancellation before/after suppliers prevents publication. Position retraction can change physical kinetic energy; the geometric result reports this change separately from the velocity impulse's lower kineticEnergyChange. New chart/position-energy evidence is optional in the shared result: the existing quadratic facade retains nil for unmeasured evidence. It is a numerical correction, not external torque work. Physical kinetic energy is independently computed from actual mass at accepted q/v. Fixed drive work can be checked by independent torque times displacement oracles. Existing phase lifetime boundaries remain in force for the original Embedded stack limit.

Completion evidence belongs to the registered dedicated test target: torqued non-polynomial revolute fourbar g/v/a, independent rod kinetic energy and torque work under refinement/long runs; mixed sixDOF/spherical q/v and original full-axis acceptance; strict initial rejection, bounded stage correction, stale source/reset/cancel, exact endpoint contributor association and deterministic checkpoint replay. Root owns actual Native and original WASM/Embedded execution and registration after source/test freeze.

The geometric stage position, velocity preparation and acceleration preparation retain rich lower samples/systems in immutable Sendable reference contexts. Preparation ends before each MassWeighted supplier call; final rich public result construction occurs in a separate non-inlined publication phase. These contexts are included in the conservative combined scalar envelope. They add no mutable shared state or platform branch.

### AF22 qualified execution
The actual registered dedicated target passed all 24 Native cases, including the eleven geometric physical/failure cases and thirteen inherited quadratic cases. [Integrated execution authority](../../../../../Verification/FoundationVerification/DESIGN.md#af22-integrated-mechanism-qualification) owns exact registered test and final original-profile evidence. Its torque-driven four-bar public path ran on Native/WASM/Embedded through required existential operations with original geometry/energy/work/replay acceptance. Mixed moving-axis quaternion evolution, long-run/refinement and the broader local failure matrix are Native-local; unsupported domains above remain explicit gaps.
