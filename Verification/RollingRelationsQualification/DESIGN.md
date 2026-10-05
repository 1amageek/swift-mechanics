# Rolling relations qualification

## Purpose and Scope
Parent: [Verification](../DESIGN.md). No children. Own behavioral qualification of [RollingRelations](../../Sources/SwiftMechanics/Physics/Constraints/RollingRelations/DESIGN.md), the original active thin rigid disk on a smooth rigid plane. Geometric projection selects the supporting rim; this component does not own velocity projection, reaction solution, vehicle dynamics or accepted-state evolution. Original normal/forward/lateral rows, contact-trace first derivative and physical work are the proof target.

## Responsibilities and Boundaries
Own independent SI geometry, contact velocities, row coefficients, acceleration bias and work oracles. Use the actual public compiled descriptor admission, makeState/evaluate, point motion/Jacobian and RollingConstraintEvaluating requirement. Caller supplies source/model identities and an active contact; explicit plane jets are tested at their exact sample time without declaring a production time-law provider. Root owns registration, shared indexes, PROGRESS and Git. Frozen original supplier objects/module remain immutable; production repairs require a concrete local counterexample and distinct matched frontend/module/object composition.

## Related Designs
| Design | Relationship | Contract used | Cautions |
|---|---|---|---|
| [Verification](../DESIGN.md) | parent | Local evidence and snapshot ownership | Root integration remains separate |
| [RollingRelations](../../Sources/SwiftMechanics/Physics/Constraints/RollingRelations/DESIGN.md) | depends on | Original rows, contact geometry, bias and covectors | Query preserves slip; no solver acceptance |
| [CompilationRecords](../../Sources/SwiftMechanics/Modeling/Compiler/CompilationRecords/DESIGN.md) | depends on | Admitted model/state/snapshot | Actual stored poses agree with initial tree configuration |
| [Jacobians](../../Sources/SwiftMechanics/Modeling/Joints/Jacobians/DESIGN.md) | depends on | Point material motion and columns | Reselected-contact transport must not duplicate fixed-point centripetal terms |
| [ArticulatedTrees](../../Sources/SwiftMechanics/Modeling/Joints/ArticulatedTrees/DESIGN.md) | depends on | Fixed-root spatial prismatic/revolute charts | Actual coordinate indices are read by joint identity |
| [LinearAlgebra](../../Sources/SwiftMechanics/Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | NumericalWork ledger | Logical reservations do not establish allocator performance |

## Architecture
```text
independent bodies/anchors and initial pose -> original compiler -> admitted model/state
explicit thin disk and body/prescribed plane -> public rolling evaluator
    -> supporting projection/contact + physical material velocities
    -> original three SI rows + transport/basis first derivative + rank/covectors
    -> closed-form physical residuals, exact-chart perturbation and typed refusals
same seven sync cases -> focused Native tests and standalone entry
awaited cancelled Native Task -> original query refusal with zero new work
```

## Contracts and Invariants
Radius R=0.5 m. Independent wheel translations X,Y,Z precede rotation about local Y. On normal Z, positive forward is X and lateral Y. Wheel material contact velocity is (Vx-R*omega,Vy,Vz); its contact trace translates at center velocity while a different material rim point is selected under spin. The original rows in actual coordinate layout are normal Z, forward X-R*spin and lateral Y. Acceleration residual is (Az,Ax-R*alpha,Ay) in row order; fixed-point spin centripetal terms cancel through the contact transport. Tangential slip remains observable and is never silently projected to zero.

A fixed camber rotation with cos(phi)=0.6 and sin(phi)=0.8 gives axle (0,0.6,0.8), contact-chart sine0.6, supporting offset (0,0.4,-0.3) m and contact height zero when the wheel center is at0.3 m. Forward spin coefficient remains -R, rather than -R*cos(phi). The projection is checked by these independently derived values.

For a translating/yawing body plane at origin(P,0,0), velocity(U,0,0) and angular velocity Omega*Z, its material contact velocity is (U-Omega*y,Omega*(x-P),0). Its trace derivative is (Aplane-alphaPlane*y-Omega*Vy,alphaPlane*(x-P)+Omega*(Vx-U),0). Body-plane columns retain coordinate contributions; an identical prescribed jet has zero plane columns and moves those original terms into drift/bias. Covector endpoint power equals original relative material velocity; generalized power covers A*v, with prescribed power retained separately. A test multiplier is only an independent work pairing, not a solved reaction.

For a prescribed plane rotating about Y at constant Omega, at time zero the normal is Z and its derivative Omega*X. Independent differentiation of gap n(t) dot c(t)-R gives normal acceleration Az+2*Omega*Vx-R*Omega^2. With R0.5, Omega0.4, Vx0.7 and Az0.2, that value is0.68 m/s^2 and normal bias0.48 m/s^2. This oracle distinguishes material centripetal terms, trace transport and moving-row basis. Actual residual differences at +/-1e-6 s along the explicitly authored q/v/acceleration and plane rotation laws supplement the analytical first derivative; absolute derivative tolerance is2e-7. Other independent SI comparisons use1e-10 absolute plus relative tolerance. Production query agreement envelopes remain explicitly1e-10 and are never widened after observation.

| Case | Required observation |
|---|---|
| Straight disk | Original SI rows/slip/acceleration, continuously reselected rim, metadata |
| Camber | Exact support projection/chart, contact and unchanged spin coefficient |
| Body/prescribed plane | Original moving-plane columns/drift/bias and physical/generalized power |
| First derivative | Rotating-normal transport/basis, original acceleration and exact-chart perturbations |
| Source/contact refusals | Stale state/sample, frames, detached/penetrating gap, invalid chart/binding |
| Rank/budgets | Full/zero rank and refusal, exact reservation ledgers, metadata/body/coordinate bounds |
| Policy/cancel | Constructor failures, callback refusal before work |
| Native cancel | Pre-admitted immutable input; await cancelled Task and observe original RollingError.cancelled |

## Runtime Flows
Read actual frozen sources and qualified suppliers; freeze all17 source/object bindings and five fixture Swift files; reuse one read-only Native2363 producer module/object set in a single owned dylib. Root released narrow slot B for this exact snapshot. The later fixture-only Native flow has link120s/setup900s/test60s/public120s watchdogs and jobs four. Source or physical findings preserve their first counterexample before a local causal repair; no full producer cold build is introduced. Portable producers/decoders wait for separate root leases.

## State, Ownership, and Lifecycle
All fixtures, models, states and results are immutable Sendable values. Each query owns exclusive local arrays and NumericalWork. The Task-cancellation witness constructs/admit inputs before cancellation and awaits the child. Conditional CompilerTarget selection is a platform adapter only; storage, Sendable and isolation do not vary. No shared mutable fixture, unsafe pointer or actor state is introduced. Borrowed original artifacts outlive execution and remain read-only.

## Failure, Concurrency, and Constraints
Native additional private allocation is bounded128MiB with global640MiB free-space stop floor (root selected admission envelope); a half-second watcher stops the process group on resource or watchdog breach. Every Swift Testing case has a one-minute limit. Explicit typed RollingError and supplier failures are retained. For the independent four-coordinate/five-body wheel chart, the declared scalar reservation is7296 and operation reservation139264; already-consumed work remains on failure. The zero-coordinate report query is admitted and require-independent mode must report rank deficiency. This proves bounded logical accounting, not physical allocator/copy profiling.

## Verification and Change Impact
The selected Native matrix is green: eight focused Swift Testing cases and the same seven synchronous standalone public cases executed against original17 sources through the immutable Native2363 producer. Original source and all2363 objects plus three module metadata hashes were verified before and after execution. Changes to geometry/chart, contact selection, original compiled/point supplier, row/bias convention, provenance, rank or work invalidate the affected witnesses. Native evidence will not qualify portable runtime, general rolling vehicles, friction/contact activation, velocity projection or reaction solution.

### Limited Native evidence
Swift6.4.0-RELEASE, matching MacOSX27.0 SDK and arm64-apple-macos13.0 fixture frontend target. Actual compiler driver jobs end in -j4; fixture command uses -j4/-Xswiftc-j4, original --build-system native deprecation warning remains. One private dylib linked the entire immutable2363 object set without producer copies or edits. Dylib link0.371s; affected fixture build3.072s; focused test command1.125s; public command0.309s. Eight tests and seven public cases passed. First fixture compiler failure (18 inferred untyped expectation closures) is retained; explicit typed closure signatures were the only corrective edit. Numerical oracle, tolerance, admitted model, original source and supplier contracts were unchanged.

Peak private allocated96,522,240bytes, with original initial610,304bytes; monitored global free minimum1,516,445,696bytes, above the640MiB stop floor. Execution watcher retained its original128MiB additional envelope across the correction rather than resetting at retry. The record is [.build/af35-rolling-relations-qualification/native-receipt-2.json](../../.build/af35-rolling-relations-qualification/native-receipt-2.json), with [original source/object/link proof](../../.build/af35-rolling-relations-qualification/native-source-object-link-proof.json). No physical counterexample or production repair was needed. This evidence does not qualify general vehicle/contact dynamics, velocity projection, reaction solutions, allocation profiling, ordinary WASM or Embedded runtime.

### Current composed Native registration evidence
The complete committed Tire1841 baseline01384c29d1820684fdc771add12def69b4afdd4e plus unchanged Rolling17 forms1858 production sources. The first actual1858 production build emitted the complete module, original added17 primaries and all1858 objects; a root private-manifest omission then prevented fixture registration, so that attempt has no test/public success claim. Its byte-exact source/object/module/compiler evidence and explicit partial-failure receipt remain preserved. Root added the exact missing MechanicsRollingRelationsTests target; the continuation compiled only the four fixture sources and required test-entry modules, with no production codegen or module reemission.

Eight focused tests and the same seven public cases then passed. All1858 production objects and four fresh fixture objects were bound to the actual test link; the unchanged four-source standalone public caller linked the same1858 objects and produced byte-identical original public output. Source, all1858 object and three module-metadata hashes remained unchanged after execution. Actual bounded continuation commands took4.265s for fixture build,1.478s for tests,0.841s for public link and0.547s for public execution; jobs remained4. The final composed evidence is [fixture-continuation-native-receipt.json](../../.build/af35-rolling-relations-qualification/registration/fixture-continuation-native-receipt.json), SHA256 a350fbb6811d9cec427db8f8bfb0a49fbb6562cf886e3afad9baaee0ac801da7, bound through immutable continuation inputs to [the original1858 inventory](../../.build/af35-rolling-relations-qualification/registration/attempt-1-production-partial/canonical-production-object-inventory.json), SHA256 34dad500e9cb9000562cf430a1928214c51d23c584cf90ba7ec3ac482d2d37c0.

This is the current Native registration proof for the selected Rolling row construction, supporting-rim geometry, first derivative, rank and physical power scope. Original2363 producer evidence remains valid for its earlier graph; the current composition supplements it. Original production Swift bytes, SI oracles and tolerances were unchanged. At that Native registration checkpoint, ordinary/Embedded preparation had not executed. The later selected portable evidence below adds no velocity-projection, solver-acceptance or evolution qualification. Root owns final shared registration and Git.

### Portable execution preparation after Native registration
The unchanged committed4d16dfd baseline1562 plus original Rolling17 remains a separate1579-source ordinary/Embedded graph; full1858 Native registration in commit d4e4afc is its source/fixture predecessor binding, not a portable graph substitution. [Prepared profile contract](../../.build/af35-rolling-relations-qualification/profiles/DESIGN.md) owns actual-emitted-job metadata-only Make dependency omission, official index disable, full LLVM all-write/131072 guard-before-raw gates and the root-selected1536MiB admission/640MiB additional cap/768MiB floor. Original17 production source, five fixture Swift files, seven physical cases and tolerances remain unchanged. Preparation starts no compiler, runtime, decoder or archive; explicit root Heavy grant is required.

### Limited ordinary and Embedded behavior evidence
The unchanged original1579 portable graph (committed4d16dfd1562 plus Rolling17) and the same five fixture Swift files executed with Swift6.4.0-RELEASE, matching ordinary and Embedded SDKs and wasm32-unknown-wasip1. The separate full1858 Native registration predecessor remains bound to commit d4e4afc; portable proof does not replace that graph or qualify later root graphs. Actual emitted SwiftPM drivers/codegen retained jobs4, WMO and threads4. Official --disable-index-store and only Make dependency output omission reduced metadata cost; original and adapted argv/maps remain in receipts. Each actual link included all1579 production objects and four fixture objects plus three module wrappers.

Ordinary compile/link52.713s, full LLVM13.718s, guarded0.721s and raw0.709s passed; all401,283,943 decoded bytes were hashed through EOF, with38,426 original global writes equal to38,426 guards. Embedded compile/link82.991s, full LLVM2.169s, guarded0.788s and raw0.782s passed; all21,662,678 decoded bytes were hashed through EOF, with2,133 original global writes equal to2,133 guards. Both preserved131072-byte reservation and emitted the original seven physical PASS records plus footer in guarded execution before raw. The same source, object and artifact hashes were checked after runtime. Awaited Task cancellation remains Native-only. No general rolling solver, velocity projection, reaction solution, vehicle evolution, full-format or external-engine equivalence is qualified.

One fixed allocation baseline11,722,752bytes covered both profiles: measured peak additional503,398,400bytes, minimum global free1,504,415,744bytes and maximum sample0.198s over119 samples. This stayed within the root-selected640MiB additional cap/512MiB early stop and768MiB global floor/896MiB early stop; unobserved between-sample peaks remain unmeasured. All original SI oracles and tolerances were unchanged, with no production repair or failed compiler/physical attempt. Planning-only SwiftPM missing-output exit status is retained separately from successful actual emitted compile/link acceptance. Heavy lease has been released.

Final portable evidence: [portable-behavioral-handoff.json](../../.build/af35-rolling-relations-qualification/profiles/portable-behavioral-handoff.json). Original raw/guard artifacts and compile/link/coverage/runtime receipts remain preserved.
