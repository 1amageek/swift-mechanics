# InertialParametersQualification

## Purpose and Scope
Parent: [Verification](../DESIGN.md). No children. Own independent behavioral qualification of the existing [InertialParameters](../../Sources/SwiftMechanics/Analysis/Derivatives/InertialParameters/DESIGN.md) ten-coordinate spatial rigid parameter products. The selected operations are inverse required-effort products and forward acceleration products at fixed q/v/a/time. Fresh Native9 tests and8 public cases passed on committed1983+unchanged subject9, total1992. Canonical registration, ordinary/Embedded behavior and full OP-family qualification are separate integration obligations.

## Responsibilities and Boundaries
Build physical source records, bindings and parameter endpoint models through published constructors. Invoke `InertialParameterDifferentiating` requirements through the actual implementation. Compare results with literal body-origin pendulum laws and independent central differences of original kinematics, rigid equation assembly, inverse/forward solves and energy. No test supplier replaces dynamics, gravity, inertia or the mechanical differentiator. Fixture-only typed assertion failures distinguish an incorrect result from expected production refusal.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
| --- | --- | --- | --- | --- |
| [InertialParameters](../../Sources/SwiftMechanics/Analysis/Derivatives/InertialParameters/DESIGN.md) | verifies | `InertialParameterDifferentiating`, physical binding and source chart | Subject nine unchanged sources | Exact fresh1992 Native proof only |
| [MechanicalSensitivities](../../Sources/SwiftMechanics/Analysis/Derivatives/MechanicalSensitivities/DESIGN.md) | depends on | Actual fixed-state mechanical products | Qualified lower derivative path | No new lower supplier or callback surrogate |
| [RigidEquations](../../Sources/SwiftMechanics/Physics/Dynamics/RigidEquations/DESIGN.md) | depends on | Original assembly, energy and body equations | Independent primal oracle | Committed1983 lower source authority, not live AF31 overlays |
| [DenseDynamics](../../Sources/SwiftMechanics/Physics/Dynamics/DenseDynamics/DESIGN.md) | depends on | Inverse/forward solves with original residual | Independent primal oracle | No fallback or regularization |

## Architecture
```text
physical BodyRecord3D -> source-bound ten-coordinate binding -> signed direction
   |                                         |
   |                                         v
   |                            actual inverse/forward parameter product
   v                                         |
independent +/- parameter endpoint conversion |
 -> original tree snapshot -> equation kernel -> original solve/energy
   |                                         |
   +---------- literal / finite-difference / physical acceptance --------+
```

## Contracts and Invariants
The literal pendulum rotates about body-origin z with identity anchors and fixed root. Its coordinates are `(m,h,Io)` in SI, with `M=Iozz`, `bias=0`, `K=Iozz*v^2/2`. Uniform `g=(0,-10,0)` at q=0 gives `Q=-10*hx`, `Ug=10*hy`, load power `Q*v`, and required torque `Iozz*a-Q-Qapplied`. These identities distinguish mass, first moment, origin tensor and each off-diagonal coordinate; no factor of two is introduced for symmetric tensor coordinates. All ten child coordinate basis directions and a signed combination are checked against actual public operations. Static root inertia direction has no generalized effect in the selected fixed-root domain.

The independent endpoint oracle modifies only `(m,h,Io)` then computes `c=h/m` and the central tensor using explicit scalar parallel-axis entries. Actual `MassProperties3D` constructors admit both perturbed models. Central differences use fixed steps1e-5 and5e-6, absolute2e-7 plus relative2e-6; literal checks use absolute2e-10 plus relative2e-10. Neither oracle calls a differentiated operation to obtain its expected value. Source identifiers, time, q/v/a, gravity and supplied forces are identical at both endpoints. Nonidentity chain/root/anchor rotations, offset COM and complete off-diagonal tensors expose world transport, coupled M/bias, power and forward derivatives. The forward oracle holds drive fixed and obtains each primal acceleration from the original dense solver; the literal one-DOF forward law is `(drive+Q)/Iozz`.

| Shared case | Independent invariant and failure witness |
| --- | --- |
| 1. Ten-coordinate origin laws | All ten basis directions, literal M/bias/K/required torque and physical original residual |
| 2. Uniform gravity and fixed loads | Literal force, potential, work/power and primal inverse/energy with load derivative zero |
| 3. Rotated coupled finite differences | All M/bias/Q/K/U/power/required products for complete off-diagonal physical tensors |
| 4. Forward acceleration | Literal implicit derivative, independent endpoint forward solves and original inverse/forward roundtrip |
| 5. Source and mapping refusals | Revision, provenance, body/frame order, duplicate scalar IDs, shape, topology and unavailable force derivative |
| 6. Physical and rank domain | Invalid endpoint mass/inertia, nonzero physicality tolerance, nonuniform/wrong-frame gravity and actual pivot-threshold refusal |
| 7. Cumulative work | Seeded ledgers, exact successful replay bounds and one-short numerical/supplier limits; no reset on failure |
| 8. Cancellation | Initial caller/admission cancellation and final publication poll after actual supplier work, with accounting retained |

Native adds one actual cancelled-Task case, constructing immutable inputs and seeded ledgers before cancellation. This avoids cancelling fixture construction instead of the public operation. Expected errors are matched by their typed cases, not by success-shaped placeholders.

## Runtime Flows
Prepare input and immutable policy; create local caller-owned numerical, load and supplier ledgers; invoke the public product; run independently constructed primal oracles; check original residual and energy/power; publish only fixture assertions. AF36 Native reconstructed committed HEAD's 1983 included SwiftMechanics sources from git archive and that commit's actual target exclusions, then added only the current nine InertialParameters sources. The resulting fresh 1992-source dynamic producer is independent of live uncommitted lower AF31 files. The unchanged seven fixture sources form a separate SwiftPM consumer linked by explicit module/library paths and rpath to this fresh producer. Pre/post source, module, object and library hashes bind actual completed execution. The removed original2363 producer/receipts were not borrowed or claimed as new evidence. Root granted the cold lease, and the completed producer was reused for consumer execution without a repeated compile.

## State, Ownership, and Lifecycle
Fixtures and result records are immutable Sendable values. Numerical/load/call ledgers are exclusive local inout values. The cancellation poll counter is the sole shared mutable state and uses the same `Synchronization.Mutex<Int>` storage, `withLock` read/mutation and Sendable owner on Native/WASM/Embedded. Its macOS15/iOS18 availability is explicit; package and producer/public macOS13 remain unchanged. No target branch substitutes raw state or a no-op lock. The Native Task owns its inputs and completion; no asynchronous state enters a critical section.

| Logical state | Native / ordinary WASM / Embedded source contract | Read | Mutation | Release |
| --- | --- | --- | --- | --- |
| Cancellation polls | Same Sendable owner with `Mutex<Int>` | `count` through `withLock` | `poll` through `withLock` | Caller releases immutable class reference |
| Numerical/load/call ledger | Exclusive local value, same inout API | Owning call scope | Published ledger operations | Scope end |

The source review matrix applies to all targets. Actual Native publication/caller and awaited Task cancellation cases passed; no ordinary/Embedded runtime synchronization claim is made.

## Failure, Concurrency, and Constraints
The earlier original2363 comparison describes historical source preparation; its private artifacts have been removed and are not available to verify or reuse. AF36 uses only the committed full HEAD source selection plus the unchanged owned nine sources. Fresh producer uses pinned Swift6.4.0, macOS13, dynamic library, enable-testing, WMO, four compiler threads and SwiftPM jobs4. The separate consumer uses macOS15 for the unchanged Mutex cancellation fixture and jobs4. One cumulative baseline covers at most8GiB additional private allocation and a4GiB free-space floor, with process-group deadlines and active capacity monitoring; root owns the cold resource lease. Disk below admission blocks execution, not source preparation. Finite-difference models have at most3 bodies and2 velocities, bounded fields and fixed steps. No broader chart, topology or gravity law is added to production.

## Verification and Change Impact
The [actual Native receipt](../../.build/af36-inertial-native/pass-5-native-receipt.json), SHA256 `84be673c06ad747d651f2ab7b264f8a41118e2c87b8da7e67016da5479796c29`, records nine unchanged Swift Testing tests and eight shared public cases passing. Source9 ledger is `6dccf0ecb94a41b4b85a2da3457830763492753d03c2ae57745c3685073e0189`; fixture7 ledger is `ec7a0194f56b90c0fecb79149f077448afbb992ec9c11637b61c4dec8e3c8e3f`; full1992 source ledger is `2e24e74ad36ae72e9e84567be7e51c637848f38ff794f10ec0abe37a0afb483f`. Actual explicit-Native producer exited0 in35.995s with WMO4/j4/mac13/enable-testing and matching source list; consumer tests exited0 in6.506s (physical test runtime0.011s) and public exited0 with all eight original messages. Producer/output/source/fixture pre/post hashes matched. Library/public strict codesign returned0; test-bundle returned1 (`code has no resources but signature indicates they must be present`), retained separately and not represented as signing success. One original cumulative allocation baseline includes retained failed runner attempts; final growth1,768,288,256B was below8GiB and free186,586,144,768B exceeded4GiB.

Earlier version-spelling, wrong-default-engine and artifact/argv-selection failures remain unqualified receipts/logs. The wrong-engine attempt cost115.75s and emitted-j14 before failing a dependency file; it is neither a physical source defect nor accepted proof. Causal runner repairs selected explicit Native and compiled argv, excluded dSYM lookalikes, and did not change any fixture or production Swift/oracle/tolerance. No physical subject counterexample was observed. Only concrete future diagnostics or physical counterexamples may cause owned fixture/source repair; a production change requires its design first and a matching regenerated producer before behavior execution. Source/provider changes invalidate dependent evidence; root owns shared registration, Package, parent indexes, PROGRESS and Git. Ordinary/Embedded and full OP-family qualification remain pending.

### Root registration availability adaptation
The minimal shared registration preserves the package macOS13 platform. The final-publication cancellation fixture requires its existing macOS15/iOS18/tvOS18/watchOS11 `Mutex` counter. Before performing that fixture body, runtime availability is admitted explicitly; an older platform throws `InertialParametersQualificationError.unsupportedPlatform` instead of silently omitting the final-poll oracle. Suite/Test declarations remain unannotated because Swift Testing macros reject those availability annotations. The original counter, helper, physical products, numerical oracles and work bounds are unchanged. The final fixture differs from the historical Native1992 receipt only by this explicit capability failure and its error case; the final registered-union execution below qualifies those exact final bytes. The historical receipt remains proof of its exact prior fixture, not a final-union claim.

### Final2124 Native consumer execution
The [final receipt](../../.build/af36-inertial-final-consumer/native-receipt.json), SHA256 `361489606bc9902979809ce2d448ef3b62326d235981e4aa64543a4b6d17dd68`, records Native9 tests and public8 passing with final fixture ledger `7326be28ab87c654a88fd2df02196d779ea75dc02d0c315a15d7216c33171372` and unchanged source9 ledger `6dccf0ecb94a41b4b85a2da3457830763492753d03c2ae57745c3685073e0189`. The original physical oracle, finite-difference tolerances, power/work/refusal witnesses and awaited Task cancellation remained fixed. The final body guard was exercised on an available runtime and retained the actual final-poll counter/checks. No older-platform unsupported branch execution is claimed.

The thin consumer read the root-frozen2124 producer directly: public module `c6415b7a03dfb9c307b311e60167f0752f56507d6390abc44a058134edba41eb`, dynamic library `c74e83936bdbb98d744e4f5f6756e2c9fb31d7a9c59dcd4ab2ac2d8910e217e9`, full output inventory `12661799a67c417d3551f94f510c501a930610a5dcc5c95fdbb2c038d4fd25d9`. Full source2124/object2124/module3/library bindings and owned fixture/source hashes were verified before/after without copying or rebuilding the producer. Consumer package/support/public retain macOS13; SwiftPM's actual test and generated-runner targets are macOS14. Explicit Native jobs4, atomic joined module include argument and actual dynamic-library link/rpath are preserved in the receipt. Tests completed in8.041s (Testing runtime0.011s), public build2.025s and public execution2.022s; all returned0. Strict library/public verification returned0 and test-bundle1 retained the same resource-signature discrepancy. Additional owned allocation69,206,016B remained below1GiB, final free181,028,073,472B exceeded4GiB, and all consumer processes exited. The root reader/execution lease was released immediately; ordinary/Embedded and broader derivative domains remain unqualified.
