# Wheeled Assemblies Qualification

## Purpose and Scope
Parent: [SwiftMechanics](../../DESIGN.md). No children. Own independent selected behavioral evidence for [WheeledAssemblies](../../Sources/SwiftMechanics/Physics/Vehicles/WheeledAssemblies/DESIGN.md) IM.AF35.27. The current AF38 phase qualifies original fixtures against committed lower suppliers through fresh Native execution. The historical Native evidence below is context, not a current module binding or portable/full vehicle qualification. Root owns the Native slot and shared graph.

## Responsibilities and Boundaries
Use the actual public ReferenceMechanicalCompiler to compile six physical bodies and five scalar joints. Consume WheeledAssemblyEvaluating with original equations, dense solver, load laws, servo and transmission. Independently derive acceleration, body wrench, momentum and energy from Newton/Euler equations. No production mass matrix or candidate residual supplies the analytical oracle. Road wrenches are explicitly supplied inputs; tests never claim solved contact, load transfer, traction or closed-loop driving.

## Related Designs
| Design | Relationship | Contract used | Cautions |
|---|---|---|---|
| [WheeledAssemblies](../../Sources/SwiftMechanics/Physics/Vehicles/WheeledAssemblies/DESIGN.md) | verifies | initialize/query/step, immutable state and original work | Selected single-track floating six-body tree |
| [Compiler](../../Sources/SwiftMechanics/Modeling/Compiler/DESIGN.md) | depends on | compile, makeState, evaluate, canonical public layout | No fabricated sealed compiled state |
| [Dynamics](../../Sources/SwiftMechanics/Physics/Dynamics/DESIGN.md) | depends on | Original RigidEquationKernel/DenseRigidDynamics, force/wrench/energy | Current committed d30b585 suppliers; historical2353H2 is not reused |
| [Loads](../../Sources/SwiftMechanics/Physics/Loads/DESIGN.md) | depends on | PolynomialSpringDamper and ScalarLoadEvaluator | Explicit synthetic analytical coefficients |
| [Actuation](../../Sources/SwiftMechanics/Physics/Actuation/DESIGN.md) | depends on | Real servo response/affine power-conjugate torques | Preserve source-work and clipping receipt |

## Architecture
```text
public six-body descriptor + fixed anchors + original compiled model
    -> admitted assembly/configuration/state + explicit driver/road
    -> original supplier force/acceleration/body/energy path
    -> independent analytical witnesses and exact original failure checks
seven synchronous public cases -> Native runner and Swift Testing
separate owned Native Task cancellation -> original failure, awaited task
```

## Contracts and Invariants
All values use SI. Synthetic exact masses are chassis10, rear carrier2/wheel1, front carrier1/knuckle1/wheel1: total16kg. Chassis COM inertia is10 times identity; other COM tensors are identity. All COMs are zero. Suspension anchors are at world/body x=-1 and +1, spins local+Y, steering+Z, springs k=100N/m and dampers d=5Ns/m. Shaft maximum26Nm, rear/front brake maxima4Nm; steering position gain20Nm/rad, zero integral/damping/filter/deadbands, effort cap100Nm. These chosen inputs are analytical fixtures, not physical calibration measurements.

Canonical public joint layout supplies all q/v slots. Root uses world translation and body angular velocity. Every expected acceleration vector starts with zero in eleven coordinates and inserts independently derived active terms by canonical IDs. Independent wrench/momentum checks use actual published body acceleration but known synthetic physical coefficients; no matrix inversion oracle.

| Synchronous case | Independent mechanics witness |
|---|---|
| Gravity/uniform motion | At z3, v=(2,0,1), g=-10Z: root az=-10, relative accelerations0, K40, stored520, p=(32,0,16), L=(0,96,0), Kdot=-160, chassis force=-100Z |
| Held supplied force and evolution | Rear/front forces8X each: ax=1, K32 at vx2, road power32. dt=.01 gives x=.02/vx2.01, exact impulse.16 and trapezoidal work.3208; sequence/servo issuance advance once |
| Spring and supplied normal load | s=(.1,-.1) at rest: F=(-10,10), U1, pitch alpha=20/13.06 from I13 + horizontal mass arm contribution6*.1²; chassis az0, rear/front absolute az=(-10/3,10/3), relative accelerations subtract root geometric terms. Separate zero-spring normal inputs3Z/6Z yield unsprung az1/2 and chassis az0, preserving supplied loads |
| Damping and momentum | s=0, rates(.2,-.1): F=(-1,.5), chassis az=.05, pitch alpha=1.5/13, K=.075, pZ=.3, LY=.9, loss.25 and Kdot=-.25 |
| Shaft/internal reaction | Rear-only affine gradient1, throttle.5 =>13Nm at rear spin2: chassis alphaY=-1, rear relative alpha14, front relative alpha1, suspension accelerations(1,-1), K2/Kdot26. I13 chassis-side reaction balances rear wheel absolute alpha13 |
| Steering/brakes | Steering target.1 =>2Nm, chassis yaw=-2/19, relative steering alpha21/19. Separate wheel spins(2,-3), brake commands(.5,.25) =>torques(-2,1), chassis pitch1/13, relative spin accelerations(-27/13,12/13), K6.5 and loss7 |
| Refusal/immutability/work | Zero/crossing brakes, stale road and unsupported port; positive spring-step energy defect must reject without publishing state; work caps/callback cancellation; explicitly injected original unavailable dynamics failure makes workspace terminal, without any successful fake dynamics value |

Numerical assertions use fixed1e-8 relative to max(1, magnitude). Producer admission retains its own1e-10 force/velocity/power bands and1e-9 energy/momentum bands. No residual projection or tolerance increase is allowed to make an oracle pass. Unknown road potential remains nil in original MechanicalEnergy; separately reported stored energy is checked analytically.

## Runtime Flows
Each case compiles a fresh immutable model, applies initial q/v using public model.makeState, and initializes a real assembly. Cases query actual body acceleration/wrench/energy or execute one positive bounded step. Refusal helpers accept explicit typed WheeledAssemblyFailure closures. Deliberately injected failure supplier has no success branch and serves only terminal error ownership; it never supplies a physical success result. Native Task cancellation is owned by a local stream gate; cancel before releasing, await value and finish the gate on every exit.

## State, Ownership, and Lifecycle
All production/fixture owners are immutable Sendable values; each query/step owns exclusive inout work. Every case owns fresh arrays, models and ledgers. No global mutable counter, shared state, Mutex or actor is introduced. Native async cancellation is a separate source. Native/WASM/Embedded synchronous code keeps identical storage/Sendable contracts; awaited cancellation is not a portable synchronous promise.

| Logical state | Native | WASM | Embedded |
|---|---|---|---|
| Model/state/fixture | Immutable Sendable | Same source | Same source |
| Work | Exclusive local inout | Same | Same |
| Async cancellation | Locally owned/awaited Task and gate | Excluded from shared sync owner | Excluded from shared sync owner |

## Failure, Concurrency, and Constraints
Cases contain at most six bodies/eleven velocities and bounded local loops. Work caps are explicit; failures retain charges and unchanged input state. MacOS13 shared registration requires no Mutex API availability extension because no shared mutable storage exists. Fresh execution must validate subject14 sourceSHA and all actual common-producer source/object/three metadata/dylib hashes before and after. A direct read-only module/dylib and fixture-only targets avoid production rebuilding or object/source copies. Additional consumer capacity1GiB/globalfree4GiB is sampled every2s. Pinned Swift6.4.0 and final driver jobs4 apply; overall sequence300s and internal build/test120s/public60s watchdogs bound owned process groups. Root slot/resource lease precedes any Native process; no depot mutations, cold producer builds or unrelated source substitutions.

## Verification and Change Impact
Read complete assembly initialize/actuate/mechanics/evolve/refusal paths and actual compiler.makeState/evaluate. Read original floating body dynamics, floating tree Jacobian, scalar servo/transmission and spring-law tests cited in production DESIGN. Structural skeleton parse signals for typed throws are navigation only, not compiler defects. Native compiler/source evidence alone is not this behavioral proof. Source counterexamples require production child DESIGN first and coordinated matching producer objects/module; no oracle weakening. Ordinary/Embedded profiles, individual registration, performance, terrain/contact closure and general vehicle configurations remain outside this selected evidence.


## Historical Selected Frozen Native Evidence
The historical Native2353H2 graph executed all seven synchronous public cases and the separate actual Native Task cancellation case. Swift Testing reported eight actual tests passed. Original fourteen production Swift files plus their DESIGN remain unchanged with inventory `e502135a3a7734a52c25d8a045c3e3d917379e141dc1b4ccf1d0a0cd789ebc7f`. All2353 direct read-only object files and three matching module metadata files were individually checked before and after execution; public module SHA is `6b7e8debc3a38573b23505795c439f5c9d0b6338c413679ac5cdd04bbfa553e2`. This is the original frozen supplier body/property path, not current changed AF31 source qualification.

The only actual preparation defect was a missing explicit ReferenceActuationTransmitter mapper argument. The original public API and TransmissionTests require `LoadMapper()` injection; the selected affine implementation does not call that mapper. The grouped fixture repair changed this constructor alone, leaving analytical models, coefficients, oracles and tolerances unchanged. No producer counterexample or producer source repair occurred.

Actual toolchain was Swift6.4.0 RELEASE, MacOSX27.0 SDK, fixture/producer target arm64-apple-macos13.0. All six actual fixture drivers retained final jobs4; production frontend inputs were empty. Link/build/public/test watchdogs were120/900/60/120 seconds, with no timeout/resource refusal. Additional allocated blocks were below128MiB and observed free space above576MiB. Original public runtime and Signing are separate evidence: standalone and dylib strict verification exited0; the generated test runner exited1 with `code has no resources but signature indicates they must be present`, retained without resigning.

The earlier private Native receipt `99a6f7d02c9762d70fc67eb15a207f68ee9080dad7c477291ca0106191d01e5f` and related `.build` artifacts were lost. Its historical claims are not current executable evidence, and no old module or object is reused. This appendix follows that executed fixture snapshot; no Swift source changed afterward. Ordinary/Embedded WASM, general suspension/driver settings, contact/load-transfer/traction closure, full vehicle stability/performance and individual registration remain unqualified.

## AF38 Fresh Qualification Boundary
Source freeze `.build/af42-wheeled/subject-source-freeze.json`, SHA-256 `1e6c2658f5967037ebbd1f5f120586cab620eee5b7e1fc519c8b8daf830d82b6`, binds original14 production and fixture7. Sorted repository path, space, SHA-256 and newline UTF8 gives production aggregate `8a15422f6193b946fcdc7592f82416ecc5a4053685f66dcc925ff4665022cc5c` and fixture aggregate `fc762c928fef9c7ac954439b6532eb0155adb45aa9e19f7cf804893ba4e4bd8d`. All equations, SI calibration inputs, numerical oracles, tolerances, failure checks and cancellation cases are unchanged.

The qualified lower authority is committed `d30b585fdb0cd8fb1ab1104d861b03fbf55ecb26`, actual2270 registered sources. Private `.build/af42-wheeled/lower-public-route-binding.json`, SHA-256 `5d6fad72de13f8910c485ad0650211834b1fea6127c6109f19142fe249d9c658`, records committed hashes of the immediate original model, tree/quaternion, spring/load, servo/affine, rigid equation/physical bridge and dense solver routes. Live PhysicalRigidDynamicsSystem/RigidEquationComputing differs from committed bytes; the matching common producer uses committed lower bytes and must not interpret current WIP as qualified supplier substitution. The full transitive source/object closure belongs to the common producer inventory.

```text
committed lower suppliers + original assembly14 + original fixture7
    -> matching common module/dylib -> Support5 / Tests1 / Public1
    -> original Native8 + seven public witnesses + awaited Native cancellation
    -> full producer and subject hashes before/after + actual fixture object/library link
```

The minimal individual additive shared candidate is based on committed d30b585:2270 + assembly14 =2284 sources. It adds only Wheeled DESIGN exclusion, product and Support5/Tests1/Public1 targets. Root owns applying this delta to the latest live manifest while preserving other WIP, parent indexes and the individual commit. The private consumer has no production target, attached joined-I import, original external dylib link and rpath; Support/Public codegen13 and actual generated Testing14 are recorded separately, not minimum-OS runtime certification. No fixture Mutex, shared global state or target-conditioned storage/Sendable exists; the separate Native Task gate has local owner, awaited completion and continuation.finish via defer.

A focused original source review traced the actual six-body admission, original compiled kinematics, original suspension/servo/shaft/brake efforts, mass/bias/force equation, chassis/body acceleration and original momentum/energy, supplied support loads, held explicit candidate, quadrature/source work, rejection/no-publication and terminal failed supplier work. No concrete new defect was found; no production source was changed. Current Native runtime completed with no owned causal repair. Portable profiles, full vehicles, contact/traction closure and broader integration remain open.


## AF38 Executed Fresh Native Evidence
Root-issued immutable attempt2 handoff `.build/af42-next-native/attempt-2/handoff.json`, SHA-256 `f6c4959f204ce51cb07259224891546bd4d18847d397d9a6731d68095ae77941`, binds actual2387 sources and objects plus three module metadata files and the linked dylib. Source inventory SHA-256 is `aedeef1968768ae44559478c4e7c4b8ed442d6329e2fcfc912a4c3faa44505a4`, object inventory `03866d4d5dfe671e2a20912a97a05a98e8bbd37c2dc7235128a1103b138fb41f`, and producer final receipt `c2d1dde5e5be2903b4ac44f6012c3f63aed4fe4e99fb73cf348b30e70152c43a`. The failed first attempt is excluded. The common graph includes committed2270 lower sources and frozen cohorts; qualification of this child is limited to the original assembly route, not all2387 behaviors.

Private `.build/af42-wheeled/native-qualification-receipt.json`, SHA-256 `41345b0816a1e81eeeac5996e46b0d7ea7f231ef14cbeb65bcbe1023ea8129f4`, records eight actual Swift Testing tests passed and seven public synchronous cases plus the existing awaited Native cancellation completed. Thin fixture build took30.209s, tests2.444s and public runtime0.503s. Actual source/object/link inspection `.build/af42-wheeled/source-object-link-inspection.json`, SHA-256 `92a7559694493fa2f998db7393c3ecf28c091c288b748751d3ce0564ba35c943`, binds all seven original fixtures to their emitted objects. Every common source/object/metadata/library and original21 subject Swift files matched before and after; no production frontend input or production target was rebuilt.

| Artifact | SHA-256 |
|---|---|
| Public SwiftMechanics module | `505a0ea9980788c6e6a3a2dcf14ec5c87ed805857db621844294429ea7391893` |
| External original dylib | `c1016d2bfb18800d7ec0a242d0d606ff5f06b3b9afbef23e190b8f0fda990ad5` |
| Original public executable | `e554fa6db300cef851233a2810db6af94b57271ac79a9f2e51de39f7cb4f31fb` |

Pinned Swift6.4.0 RELEASE, actual MacOSX27.0 SDK and final jobs4 were retained. Actual Support/Public drivers end at arm64-apple-macosx13.0; Testing and its generated runner end at14.0. Native execution on this host does not certify minimum-OS runtime. Public and test binaries link the exact original external dylib; public LC_RPATH names its immutable library directory. Joined-I importing passes through generated Swift Testing code. All source/oracle/tolerance/cancellation values remain unchanged.

The once-created capacity baseline and2s monitor measured maximum new allocation54,444,032bytes and minimum global free165,439,582,208bytes, within additional1GiB/free4GiB. No timeout or resource refusal occurred. Public executable and dylib strict codesign verification exited0. Generated test bundle and inner executable strict verification exited1 with the retained resource-signature discrepancy; signing is separate from successful behavioral execution and nothing was resigned. The reader lease was released after execution and object/link inspection. Ordinary/Embedded, full vehicles, contact/load-transfer/traction closure and final shared registration remain separate; Root owns the additive manifest and commit.
