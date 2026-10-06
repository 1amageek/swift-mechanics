# Discrete cables selected behavioral qualification

## Purpose and Scope
Parent: [Verification](../DESIGN.md). Children: none. Own shared synchronous cases and Native awaited cancellation for the existing [DiscreteCables](../../Sources/SwiftMechanics/Physics/Flexible/DiscreteCables/DESIGN.md) public services. The selected Native10/public9 proof is executed against a coherent frozen common2387 producer; original RED evidence is retained. No rope contact, director torsion, hanging/refinement convergence or general Runtime authority is added.

## Responsibilities and Boundaries
The production services generate all actual assemblies and evolution results through `any CableAssembling` and `any CableEvolving`. A separate scalar oracle evaluates the declared energy and analytic nodal force using ordinary local arrays; it never supplies force to production or replaces an evolution path. Fixtures own their immutable inputs and local work. The runner binds exact source bytes, all selected supplier bytes and matching producer module/objects before and after execution.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Verification](../DESIGN.md) | parent | Local invariant proof ownership | Selected test owner | Root owns registration and resource leases |
| [DiscreteCables](../../Sources/SwiftMechanics/Physics/Flexible/DiscreteCables/DESIGN.md) | depends on | CableAssembling/CableEvolving | Actual physical and transactional paths | Original selected domain only |
| [Core](../../Sources/SwiftMechanics/Mathematics/Core/DESIGN.md) | depends on | Vector3/Matrix3 | Checked finite input and public block reads | Oracle does not call producer derivative helpers |
| [Numerics](../../Sources/SwiftMechanics/Mathematics/Numerics/DESIGN.md) | depends on | NumericalWork/Budget/Error | Original consumption on success and failure | No work resets or ledger relaxation |

## Architecture
```text
fixed SI model/state/policy -> public production assembly/evolution -> original result
           |                                                       |
           +-> independent scalar energy/force/closed-form step -----+-> assertion
shared synchronous cases -> standalone public entry / Swift Testing
Native self-cancelled Task -> awaited typed cancellation assertion
```

## Contracts and Invariants
Use K=200/3 Pa and G=50 Pa, hence E=9KG/(3K+G)=120 Pa, A=0.5 m², rho=4 kg/m³ and selected EI=3 N m². Stretch at l0=1 m/l=1.2 m has U=1.2 J, physical endpoint forces +/-12 N and local Hessian diag(60,10,10) N/m. At l=0.8 m bilateral transverse Hessian is -15 N/m; unilateral slack has zero force/Hessian. The exact rest unilateral tangent is refused, including a non-axis-aligned rest edge.

For the non-collinear three-node state, compare every physical force coordinate to independent scalar energy central differences with delta=1e-6 m and fixed error 2e-7 N + 2e-7 relative. Compare every additive Hessian entry to the negative independent analytic-force central difference with delta=1e-5 m and fixed error 2e-7 N/m + 2e-7 relative. Direct analytic and exact-value comparisons use 1e-11 absolute + 1e-9 relative. No tolerance may be widened after an observed failure. Bending force uses derivatives of u·v, not CableJet or the returned tangent. Straight and antiparallel states, curved reference prestress, zero-bend isolation, Hessian symmetry and translation nullspace are explicit cases. Stress-free straight rigid-rotation directions are nullspace cases; prestressed rotations instead satisfy the differentiated force covariance relation.

Rigid covariance uses the exact proper rotation R(x,y,z)=(-y,z,-x), det(R)=+1, with translation (2,3,4). Forces map by R; full tangent maps by R K Rᵀ. Independent net force, torque and virtual power checks retain physical -gradient sign.

Reference edges of 1 m and 2 m have masses (1,3,2) kg and total 6 kg. Drag alpha=0.5 s⁻¹ is tested against explicit C, force and power. A freely translated straight chain with gravity (0,-2,0), initial y velocity 1 and h=0.01 has y velocity 0.98, y displacement 0.0098, external work -0.0392 J and energy residual -0.0004 J. A supported stretched chain with h=0.001 has free x velocity -0.012, x displacement -0.000012 and fixed support impulse -0.012 N s; angular balance is about the translated origin. Uniform alpha=2 drag at h=0.01 has work loss 0.0392 J and energy residual -0.0004 J. These one-step cases explicitly select 0.001 J (supported case 0.0001 J) absolute energy acceptance and zero relative energy tolerance, rather than asserting exact symplectic energy conservation.

Uniform drag over duration 0.1 s with unchanged 0.001 J acceptance rejects h=0.1,0.05,0.025 and accepts eight h=0.0125 local steps. Their accumulated original energy residual exceeds the same final gate, so the whole call must return the original state with `acceptanceFailed` and 11 charged attempts. An attempt-limited variant and numerical iteration/storage/operation limits refuse without publishing a partial state. Original frame/revision/node order/source retention, degenerate geometry, axial domain, torsion refusal, metadata capacity and public/Task cancellation remain separate assertions.

## Runtime Flows
Each shared case constructs fresh immutable inputs and NumericalWork, invokes real services, and checks both physical values and work/result semantics. The standalone loops the fixed synchronous cases. The Native cancellation test cancels its own Task before service entry and awaits its result. AF42 executes a private thin-consumer runner only after a matched producer and root reader lease.

## State, Ownership, and Lifecycle
All fixture services and records are Sendable. Every oracle array and work ledger is operation-exclusive. There is no shared mutable test state, target-specific isolation branch, unsafe pointer or hidden physics callback. Cancellation closures are Sendable and do not modify active production state.

## Failure, Concurrency, and Constraints
Typed fixture failures retain CableError/CoreError/ModelError/MaterialError/NumericalError. Test cases use at most three nodes, at most 9x9 dense oracle entries, fixed perturbation counts and caller work budgets. Swift Testing has a one-minute suite time limit; process commands have watchdogs and root resource admission. No producer rebuild or stale-module/object borrowing is allowed; only final fixture execution under the root reader lease is admitted. No whole-domain or portable qualification follows from fixture declarations.

## Verification and Change Impact
| Case | Fixed invariant | Production path |
|---|---|---|
| stretchAndUnilateral | Original energy/physical sign/full block and nonsmooth refusal | ObjectiveCableAssembler |
| independentDerivatives | Every energy-gradient and force-tangent differential | ObjectiveCableAssembler/CableJet |
| bendAndPrestress | Straight/antiparallel/prestressed original bending | ObjectiveCableAssembler |
| rigidCovariance | Full force/tangent covariance, force/torque/power | ObjectiveCableAssembler |
| massAndDrag | Reference masses and stationary environmental drag | ObjectiveCableAssembler |
| gravityAndSupport | Independent motion, work, P/L and support impulse | BoundedCableEvolution |
| dragAndTransactionalRollback | Dissipated actual work/local vs final energy gate | BoundedCableEvolution |
| resourceAndIdentityRefusals | Original cause/state/charged work and bounded admission | Both services |
| cancellation | Callback cancellation retaining original inputs | Both services |
| awaitedTaskCancellation (Native) | Real Task cancellation reaches public service | Both services |

Source admission records must distinguish current bytes from original2363 supplier bytes and live AF31 differences. Any physical source repair requires a matching fresh producer; old module/object proof cannot qualify new bytes. Selected Native execution is complete below; ordinary WASM and Embedded execution remain unperformed. A single source review and causal fixture corrections precede handoff; failures during later execution must remain frozen and must not trigger tolerance changes.

### AF42 final execution contract
The source18, causally calibrated fixture8 and22 consumed lower contract records are frozen in the private [source admission](../../.build/af42-cables/source-freeze.json). The authoritative lower producer baseline is committed `d30b585fdb0cd8fb1ab1104d861b03fbf55ecb26` selection2270; live lower WIP cannot replace those bytes. The common producer owner supplies a coherent full source/object/metadata/dylib handoff after actual compile/link. The thin consumer compiles only the same six support files, one Tests file and one standalone file. Package/support/public macOS13 and actual SwiftPM Tests14 are distinct recorded targets; no Suite availability annotation or macOS15 counter workaround is needed for the exclusively owned fixture state.

Pinned release6.4.0, explicit Native jobs4, joined module include, exact direct library/rpath, command deadlines (tests at most300s) and2s process-group capacity watcher govern execution. Additional owned cache must remain at most1GiB and free space at least4GiB. Original10 Swift Testing tests, including awaited actual Task cancellation, and the same9 synchronous public cases execute once. Full producer sources/per-source objects/three metadata/dylib and owned source/fixture hashes are verified before and after, with strict signing results separately reported. Actual Native results are recorded below; no portable or full FX-domain success is inferred from this selected proof.

### Causal fixture calibration correction
The first actual Native run compiled and linked successfully, then six tests passed and four failed: segment energy, independent energy, antiparallel bending energy and supported free-node velocity. The original fixture supplied K=320/3 Pa and G=40 Pa while claiming E=120 Pa. The authoritative isotropic relation E=9KG/(3K+G) instead gives E=320/3 Pa; its axial and bending rigidities differ from the independently fixed EA=60 N and EI=3 N m². Production uses the correct relation.

Correct only the shared fixture material input to K=200/3 Pa and G=50 Pa. Independent substitution gives E=120 Pa (Poisson ratio 0.2), preserving all intended exact forces, energies, tangent entries, supported motion, perturbations, tolerances, work and acceptance gates. No production or oracle Swift changes are needed. Original fixture bytes, source freeze, actual RED receipt and log remain under the private calibration-red snapshot. The stable corrected fixture is rebound to the unchanged coherent common2387 producer; all original10 tests and9 shared public cases passed before the selected qualification was recorded.

### Actual Native result and retained evidence
| Authority | Actual binding |
|---|---|
| [Corrected Native receipt](../../.build/af42-cables/calibration-green-native-receipt.json) | SHA256 `fb99c04c35b6333440c10ac1baa2f618d933def70deaffdf06cd8a719a9ff358`; qualified selected Native10/public9 |
| [Final source/fixture freeze](../../.build/af42-cables/source-freeze.json) | SHA256 `a3eaebad30c54c236d57e023b28b5fd6a293b2db5c53e1080b036ff1adc1eac7`; production18 unchanged, fixture8 with one material-input calibration |
| [Original RED preservation](../../.build/af42-cables/calibration-red/inventory.json) | SHA256 `9df952a10e88efc2496de0cf0fa361be14442979b9ec2878cc3867f88703d016`; original fixture, source freeze, runner, receipt and log retained |
| [Coherent producer reader binding](../../.build/af42-cables/reader-binding.json) | SHA256 `965f393926626f3aff5ea5719815dedfa9f50ee6c0a7ab630cefbe911bce3c6d`; all2387 sources/objects, metadata3 and library checked before/after |
| [Actual consumer outputs](../../.build/af42-cables/consumer-output-inventory.json) | SHA256 `a06b93955b545e839580a5691fda29a365e9b784563eb6e93edcb91a1685a8a0`; fixture-only module/object records |

The formal attempt-2 producer handoff SHA256 is `f6c4959f204ce51cb07259224891546bd4d18847d397d9a6731d68095ae77941`; failed attempt-1 outputs are not used. Source inventory SHA256 `aedeef1968768ae44559478c4e7c4b8ed442d6329e2fcfc912a4c3faa44505a4`, output inventory SHA256 `03866d4d5dfe671e2a20912a97a05a98e8bbd37c2dc7235128a1103b138fb41f` and final producer receipt SHA256 `c2d1dde5e5be2903b4ac44f6012c3f63aed4fe4e99fb73cf348b30e70152c43a` define the actual fresh compilation closure. The direct module SHA256 is `505a0ea9980788c6e6a3a2dcf14ec5c87ed805857db621844294429ea7391893`; the direct library SHA256 is `c1016d2bfb18800d7ec0a242d0d606ff5f06b3b9afbef23e190b8f0fda990ad5`.

Actual original10 Swift Testing tests passed after0.004s runtime, including self-cancelled and awaited Task cancellation; all9 public cases passed. The corrected command watchdog measurements are tests2.027s, public build4.164s and public execution2.122s. Release6.4.0 and explicit Native jobs4 are recorded in actual argv; Support/Public targetmacOS13 and Tests/generated runner targetmacOS14. No actual producer frontend is invoked by the consumer. Fixed analytic9x9 derivatives, force signs, covariance/nullspaces, original energy/work, supported momentum/angular impulse and full rollback assertions pass without widened tolerance or altered oracle.

Library/public strict codesign exit0. Test bundle strict codesign exit1 reports a resource-envelope discrepancy; its actual log is retained and no test-bundle signing success is claimed. All source/fixture/producer bindings are equal before/after. Total additional private allocation64,049,152B stays below1GiB; minimum sampled free165,433,147,392B stays above4GiB. Every command remains under its deadline and2s watchdog. Native reader/runtime lease is released. This proof does not establish portable synchronization/runtime, hanging/refinement convergence, rope contact, director torsion or general FX-domain closure.
