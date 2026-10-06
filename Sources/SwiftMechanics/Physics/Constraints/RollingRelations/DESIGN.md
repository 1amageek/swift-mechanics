# Rolling Relations

## Purpose and Scope
Parent: [Constraints](../DESIGN.md). AF33.7 owns CN-002's selected rigid, infinitesimal-thickness circular disk on a smooth rigid plane. No children. This source-first handoff is unqualified, excluded until root registration, and has no build, behavioral, platform or commit evidence.

## Responsibilities and Boundaries
Own disk contact geometry, original normal and two tangential velocity rows, differentiated acceleration terms, source-bound physical covectors and rank diagnostics. Consume compiled kinematics through its public admission/evaluation operations. Compiler admission, Runtime acceptance, dynamics, reaction allocation, contact activation, friction and collision discovery remain with their owners. The caller supplies an active contact and its physical source; detached/penetrating geometry outside the explicit contact tolerance fails.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Constraints](../DESIGN.md) | parent | Original residual and provenance authority | Query results only | No accepted dynamics registration |
| [Jacobians](../../../Modeling/Joints/Jacobians/DESIGN.md) | depends on | Point motion/Jacobian and geometric angular velocity | Actual material-point velocity/acceleration and virtual power | Point bias includes centripetal terms |
| [Trees](../../../Modeling/Joints/ArticulatedTrees/DESIGN.md) | depends on | Immutable snapshot/body frame/layout | Matching SI world-framed columns | Prescribed drift is separate from J*v |
| [CompilationRecords](../../../Modeling/Compiler/CompilationRecords/DESIGN.md) | depends on | Compiled model/state stamps and evaluate | Existing IM07 qualified model binding | No admission authority transfers |
| [CoordinateEquations](../CoordinateEquations/DESIGN.md) | coordinates with | Velocity rows, drift and acceleration bias convention | A*v+d and A*vdot+b | Its scalar-coordinate integrability flag cannot represent mixed normal/tangent rows and physical ports; use owned typed rows |

## Architecture
```text
compiled model + admitted state + immutable disk/plane/source binding
  -> public snapshot evaluation
  -> disk axis, plane normal, unique supporting rim point and contact trace rate
  -> public material-point velocities, accelerations and Jacobians
  -> original normal / forward / lateral rows + drift + differentiated bias
  -> physical covectors + residuals + scaled-row rank, or typed failure
```

## Contracts and Invariants
SI length, velocity and acceleration are m, m/s and m/s². World axes are right handed. Positive disk axis defines forward `a cross n`; positive plane normal points out of the supported half-space. Radius is strictly positive. Disk center/axis belong to the named wheel body frame; body-plane point/normal belong to its named body frame. Arbitrary anchor-frame bindings are unsupported. A prescribed plane has a distinct named frame, world reference, source ID, model stamp and exact sample time with complete geometric origin velocity/acceleration.

For unit axle a, plane normal n, `k=|n-a(a dot n)|`, the supporting rim offset is `r=-R(n-a(a dot n))/k`. `k` must exceed the caller chart threshold. Differentiate this expression using `adot=ww cross a` and `ndot=wp cross n` to obtain rdot. Contact trace is `x=c+r`, `xdot=vc+rdot`; its material-point wheel velocity is `uw=vc+ww cross r`. The plane material velocity at x is `up=vp+wp cross (x-p)`.

Rows are `A_i=e_i dot (Jw-Jp)`, drift `d_i=e_i dot (dw-dp)`, and original residual `e_i dot (uw-up)`, where e is n, normalized(a cross n), and n cross forward respectively. Only the normal row is integrable, with gap `n dot (x-p)`. The tangential rows impose velocity constraints and have no position residual or holonomic locking surrogate. Query success preserves nonzero physical residuals for the downstream solver; it checks decomposition consistency against caller-frozen dimensional absolute plus relative tolerances, rather than declaring the constraint satisfied.

The total derivative of material velocities sampled along the changing contact trace is
`Uw'=aw_material+ww cross (rdot-ww cross r)` and
`Up'=ap_material+wp cross (xdot-up)`.
The row acceleration residual is `edot dot (uw-up)+e dot (Uw'-Up')`. Substitute material-point acceleration biases for material accelerations to obtain b in `A*vdot+b`; transport and basis-rate terms remain unchanged. This includes explicit plane motion and configuration-dependent contact selection without duplicating fixed-point centripetal terms. The normal derivative equals the active support-gap second derivative; wheel contact is continuously reselected, not a permanently attached rim point.

Each row publishes wheel and plane covectors at x: ±e linear, zero couple. Pairing with geometric twist at x gives relative material velocity. A multiplier in newtons would give physical endpoint force, but no multiplier/reaction is solved or fabricated. Prescribed-plane columns are zero and its actual motion is retained in drift/bias and the negative plane power covector. A body plane uses its actual point columns and drift. Actual endpoint power includes prescribed motion; generalized-coordinate power covers A*v only.

Source/model stamp, source revision, reference time, radius, body/frame binding, axis, normal, contact point, tangent orientation and all three original rows are retained. The prescribed plane has its own source revision, independent of the relation revision. Both frame jets and endpoint material velocities are retained to reconstruct physical power. Rank uses caller velocity scales and two-pass Gram-Schmidt with relative tolerance; report mode returns independent/dependent row IDs, require-independent mode throws with the observed rank. A zero-coordinate layout is admitted only in report mode. No solver acceptance, velocity projection or trajectory integration is implied by a query.

## Runtime Flows
Validate policy, source identities and state stamp; check cancellation; reserve bounded storage/work before supplier evaluation; evaluate one public compiled snapshot; select contact; query public material-point motion/Jacobians; construct original rows; check all finite values and rank; check cancellation before publishing one immutable result. Typed failure publishes no partial result. A prescribed sample is instantaneous caller-provided derivative data, not a qualified time law or extrapolated trajectory.

## State, Ownership, and Lifecycle
Descriptors, model/state references and results are immutable Sendable values. Output arrays own their backing. Mutation is exclusive to local arrays and the caller's inout NumericalWork; no shared cache, borrowed escaping pointer, actor, conditional synchronization or retained callback exists. Snapshot and query temporary storage end with the operation; results retain provenance and physical values, not admission/publication authority.

## Failure, Concurrency, and Constraints
Typed failures distinguish invalid input/chart, stale source/sample, undefined contact, unsupported domain, rank deficiency, cancellation, numerical budget exhaustion, supplier compilation failure and nonfinite arithmetic. Thresholds and coordinate scales belong to the caller, are positive and finite, and must be frozen for later qualification. Policy bounds bodies, coordinates, metadata bytes, scalar storage and operations. Checked Int arithmetic precedes allocations. A conservative reservation covers snapshot dense columns, point-query arrays, rows and rank workspace; an operation charge bounds the inspected kinematic and row paths rather than claiming instruction-level measurements. Failed work remains charged; immutable inputs remain unchanged. Cancellation is observed at bounded phase/column/row boundaries; the synchronous existing compiled evaluator has no internal cancellation port.

Finite-width/deformable wheels, spheres, nonsmooth/multiple contacts, axis parallel to plane normal, arbitrary body-attached anchors, contact activation, dynamics/force allocation and trajectory evolution remain unsupported. The callable evaluator carries an INCOMPLETE_IMPLEMENTATION marker for this broader domain and explicit failure paths; source-only inspection cannot remove that marker.

## Verification and Change Impact
Later root qualification must independently verify straight disk rolling on a stationary plane; nonzero slip and acceleration residual preservation; changing contact point under spin; camber and moving/rotating plane explicit-time terms; body-plane versus prescribed-plane column/power differences; finite-difference residual derivatives along the exact chart; A*vdot+b equals original acceleration; covector/generalized virtual power; source mismatch, separated/penetrating contact, degenerate axis, rank refusal, resource exhaustion and cancellation. The original source-first phase authorized no new tests; the separately assigned behavioral qualification phase is recorded below. Supplier point/bias, q-v layout, compiled binding or transport changes invalidate the corresponding equations and require targeted behavioral qualification before an implementation claim.

### Limited Native behavioral qualification
The [local qualification owner](../../../../../Verification/RollingRelationsQualification/DESIGN.md) now records eight focused Native tests and seven shared standalone public cases against the unchanged original17 Swift sources and immutable Native2363 objects/module. Fixed SI witnesses cover supporting camber projection, continuously reselected material rim, retained slip, original rows and acceleration bias, body/prescribed translating-yawing plane differences, rotating-normal first derivatives, endpoint/generalized power, source/contact/chart/rank refusals, exact work reservations and cancellation. The independent rotating-normal normal acceleration is0.68m/s^2 and bias0.48m/s^2; full actual residual derivatives use the unchanged1e-6s authored chart perturbation and2e-7 tolerance. No production source repair or broader-domain qualification follows. The existing incomplete marker remains for the unsupported physical domains.

### Current composed Native registration scope
The [qualification owner](../../../../../Verification/RollingRelationsQualification/DESIGN.md) now binds the unchanged original17 source to the complete current1858-source Native composition (committed Tire1841 plus Rolling17). Its initial successful production compile is preserved separately from the subsequent missing-fixture-target failure. After root corrected that manifest registration, the fixture-only continuation passed the original eight tests and seven public cases without production recompile or module reemission. Actual complete1858 object/test/public links and post-runtime source/object/three-module-metadata hashes are recorded by the qualification owner. Original numerical law, source APIs, SI oracles, tolerances and earlier2363 evidence remain unchanged. Qualification is Native only for the existing row/rim/rank/physical-work domain; no velocity projection, solver acceptance, state evolution or portable runtime is claimed.

### Portable execution preparation after Native registration
The unchanged committed4d16dfd baseline1562 plus original Rolling17 remains a separate1579-source ordinary/Embedded graph; full1858 Native registration in commit d4e4afc is its source/fixture predecessor binding, not a portable graph substitution. [Prepared profile contract](../../../../../.build/af35-rolling-relations-qualification/profiles/DESIGN.md) owns actual-emitted-job metadata-only Make dependency omission, official index disable, full LLVM all-write/131072 guard-before-raw gates and the root-selected1536MiB admission/640MiB additional cap/768MiB floor. Original17 production source, five fixture Swift files, seven physical cases and tolerances remain unchanged. Preparation starts no compiler, runtime, decoder or archive; explicit root Heavy grant is required.

### Selected portable qualification
The unchanged original1579 graph passed ordinary and Embedded compile/link plus all-write131072-byte guarded execution before raw for the same seven physical public cases. All38,426 ordinary and2,133 Embedded original writes matched guards; source and SI oracles were unchanged. This is limited to the existing rim/row/first-derivative/rank/power domain; Native Task cancellation remains separate. [Qualification evidence](../../../../../Verification/RollingRelationsQualification/DESIGN.md) records actual scope and resource boundaries. No general solver, velocity-projection, reaction or evolution claim is introduced.
