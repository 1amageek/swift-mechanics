# LinearQuadraticQualification

## Purpose and Scope
Parent: [Verification](../DESIGN.md). No children. Own independent selected qualification of existing [LinearQuadratic](../../Sources/SwiftMechanics/Execution/Control/LinearQuadratic/DESIGN.md) scalar/diagonal analytic DARE, actual IM17 mechanical bilinear preparation, bounded feedback and physical scalar-effort mapping. Source preparation is not behavioral evidence. Parent registration, all-platform execution and full CO-family qualification remain integration-owned.

## Responsibilities and Boundaries
Construct systems through public preparation requirements, design through `LinearQuadraticDesigning`, evaluate through `LinearQuadraticFeedbackEvaluating`. Obtain mechanical linearization from an actual compiled prismatic model, original static equilibrium, original inertia assembly and original IM17 realization. Obtain scalar feedback from the original observation/encoder and port adapter. No accepted Runtime state or actuator-law execution is fabricated. Invalid linear suppliers are negative dependency fixtures only; every positive numerical/physical witness uses the actual qualified original providers.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
| --- | --- | --- | --- | --- |
| [LinearQuadratic](../../Sources/SwiftMechanics/Execution/Control/LinearQuadratic/DESIGN.md) | verifies | Preparation/design/feedback requirements | Subject16 frozen sources | No production change absent concrete counterexample |
| [Linearization](../../Sources/SwiftMechanics/Analysis/Equilibrium/Linearization/DESIGN.md) | depends on | Actual IM17 point and reduction | Mechanical A/B authority | Fixed scalar spatial chart only |
| [Ports](../../Sources/SwiftMechanics/Execution/Control/Ports/DESIGN.md) | depends on | Actual encoder-to-scalar feedback | Time, model, frame, SI port | No control-session publication |
| [LinearAlgebra](../../Sources/SwiftMechanics/Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | Original IM03 solve and accounting | Actual DARE/Lyapunov solves | No jitter or hidden backend |

## Architecture
```text
analytic scalar/diagonal matrices -> actual preparation -> design -> feedback
physical compiled prismatic + original equilibrium/dynamics -> actual IM17
 -> explicitly calibrated bilinear map -> actual design -> actual encoder/port
 -> scalar effort -> original dynamics -> SI acceleration/power checks
                         |
independent Riccati roots / original equations / Schur poles / cost identity
```

## Contracts and Invariants
For one normalized state/input with nonzero b, the positive Riccati root solves `b^2 P^2 + [r(1-a^2)-q b^2]P - qr=0`; independently compute the positive quadratic root, `K=bPa/(r+b^2P)`, `F=a-bK` and `W=1/(1-F^2)`. The scalar pole must have magnitude below1 and the original DARE/gain/Lyapunov equations must hold. A diagonal two-input system has the two independent scalar roots with exactly zero cross gains; also verify the matrix equations with independent plain loops and the finite closed-loop cost plus terminal quadratic value. Fixed absolute1e-8 plus relative1e-8 numerical oracle tolerances apply; physical literal checks use absolute1e-9 plus relative1e-9. No expected root is obtained from the production algorithm.

The mechanical plant has mass2kg, stiffness8N/m, damping2Ns/m, and model force2N per dimensionless parameter unit. Original equilibrium at parameter2 is q0=.5m with nominal4N. A reduction basis.5m/unit gives reduced M=.5, K=2, D=.5, A=`[0,1;-4,-1]`, B=`[0;2]` per model parameter. Calibration is explicitly.5 parameter units/N, normalized input scale3N and state scales `[.2,.4]` in eta/etaDot units. At sample period.1s, normalized bilinear matrices are A=`[1.04,.2;-.2,.94]/1.06`, B=`[.075;.75]/1.06`. These are the declared bilinear approximation, not exact hold dynamics. Original dynamics at displaced q and nonzero rate checks actual Newton force, acceleration, kinetic power and original residual from the returned physical effort. No parameter-unit value is relabeled as newtons.

| Shared case | Independent invariant and failure |
| --- | --- |
| 1. Scalar roots | Two analytic DARE roots, gains, stable poles, W and original residual |
| 2. Diagonal matrix equations | Independent DARE/gain/Lyapunov and finite cost identity |
| 3. Mechanical realization | Actual compiled/equilibrium/IM17 source, calibrated bilinear entries, encoder effort and original dynamics/power |
| 4. Units and saturation | SI scaling, clipping, applied plant step and disclosed loss of linear certificate |
| 5. Mechanical/source refusals | Wrong identity/dimension/sample time, analytic scalar-effort source, invalid calibration |
| 6. Cost/stability failures | Indefinite/nonsymmetric/null-pivot cost, non-SPD R, unstable witness, Q=0 nonstabilizing fixed point, nonconvergence |
| 7. Work and supplier failures | Seeded exact/one-short limits; actual original solve followed by invalid output/budget or failure, retained known work/unavailable flag |
| 8. Cancellation | Initial unchanged prefix and final publication after completed supplier work |

Native adds one actual cancelled-Task witness. Immutable input, policy and seeded work are prepared before cancellation. Scalar and matrix cases retain their original models, oracle formulas and tolerances through causal compiler/fixture repairs.

## Runtime Flows
Build immutable inputs through published constructors; run actual operations with exclusive work; independently reconstruct residuals and physical outcomes; assert typed refusal on failures. Future Native direct-links one library from the immutable original2363 objects, compiles only fixture sources and validates source/object/module/link identities. All compiler/link/runtime work is held until root capacity/lease admission.

## State, Ownership, and Lifecycle
Production16 uses immutable Sendable records and operation-local scratch. Fixtures have one shared cancellation poll counter with the same Sendable owner, `Synchronization.Mutex<Int>`, `withLock` read/mutation and availability guard on Native/ordinary WASM/Embedded. No conditional raw state, unsafe isolation or C buffer is introduced. Work values belong to the calling scope. The Native Task owns its local state and completion.

| State | All three target source contracts | Owner and lifetime |
| --- | --- | --- |
| Poll counter | Same Mutex storage/read/mutation | Caller retains class, scope release |
| Numerical work and scratch | Exclusive local inout/arrays | Operation/case scope |

## Failure, Concurrency, and Constraints
The original frozen subject16 is used with original2363 lower APIs. Latest live AF31 wrappers are disclosed separately and not mixed into that closure. Maximum selected dimensions are2 states/2 inputs, fixed Riccati bound1000, bounded metadata and one explicit work budget. Lyapunov solves retain original n^2 coefficient coverage. Future narrow Native uses jobs4,128MiB cumulative additional allocation,768MiB free floor and process-group deadlines. No compilation or large object/cache copy occurs during this preparation stage. Invalid dependency fixtures never provide positive physics evidence.

## Verification and Change Impact
Selected success requires actual compile/link, nine Native tests and eight public cases, complete subject/lower/fixture/module/object/link bindings and original physical/numerical residuals. Preparation and structural scans alone do not meet that condition. Actual diagnostics or concrete contract counterexamples alone authorize causal fixture/subject corrections; a production change requires design first and matched affected-primary/module regeneration. Root owns Package, parent designs/indexes, PROGRESS and Git. Ordinary/Embedded and canonical current-source proofs remain separate.


## Strict cost boundary regression
An additional independent public case exercises the exact represented indefinite tiny and large principal minors, equal least-subnormal zero-diagonal coupling, and exact dyadic rank-one/neighbor matrices through the original designer with a zero stable analytic plant. Cost values, original tolerances and source authority remain unchanged. Admission work is derived from the documented metadata/symmetry/pair reservation and tested at exact and one-short budgets. Matching execution remains pending.


## Selected Native qualification
Pinned Swift6.4.0/macOS27 SDK execution against fresh immutable2387 producer passed the original nine Native functions/eight synchronous public groups plus an independent exact-cost boundary case (Native10/public9). Receipt `.build/af42-linearquadratic/native-receipt.json` SHA b39c83576e6c68bd2d7634ce72dd14f7d46b0007c3c779db4fabb175997bbdd2 and actual consumer source/object records bind the executed code. All producer source/object/module/dylib hashes match before/after. Original Riccati/Lyapunov/stability, physical equilibrium/bilinear/effort/dynamics, dimensions/saturation/source, failure/consumed-work and awaited cancellation oracles pass. Exact principal-minor refusal, rank-one/neighbor admission and one-short reservation pass through the public designer. A ten-vector Native helper probe also checks represented product extremes; it does not substitute for public behavior. Fixture stored child pose is corrected to the unchanged initial q=.5m; unavailable final-cancellation platform now refuses explicitly. Support/public compile for macOS13; actual Testing modules compile for14 and execution was on27. Same Mutex counter storage/read/mutation is retained; portable synchronization runtime and full portable qualification remain unverified. Original source16 gains one internal bounded comparison helper; no new public API or residual tolerance is introduced.
