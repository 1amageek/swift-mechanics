# Tooth contact tests

## Purpose and Scope
Parent [tests](../DESIGN.md); children none. Own actual ToothContacts selected TR-012 proof.

## Responsibilities and Boundaries
Independent public two-shaft tree/inertias and externally specified tooth patch geometries prove actual driven state, force/torque/load/slip/separation and refinement. No ideal transmission relation is instantiated. Root owns original-profile composition; all existing test/source producers read-only.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [ToothContacts](../../Sources/SwiftMechanics/Physics/Transmissions/ToothContacts/DESIGN.md) | depends on | original physical evolution | Test subject | Explicit proxy fidelity |
| [Collision tests](../MechanicsCollisionTests/DESIGN.md) | coordinates with | original proxy witnesses | Read-only regressions | No new producer authority |
| [Dynamics tests](../MechanicsDynamicsTests/DESIGN.md) | coordinates with | original M/C/K/force | Read-only regressions | Full source bound |

## Architecture
```text
external analytic test tooth-patch definition -> real proxies/material/tree
 -> protocol initial/step/advance -> independent scalar sin/cos force/torque/K/work
 -> nonuniform mesh and actual time refinement -> failures/immutable history replay
```

## Contracts and Invariants
Tooth count alone is not a mesh oracle. Nonuniform patches sample a smooth independently defined flank/load distribution with declared quadrature stiffness and externally bounded source deviation; limiting torque is independently integrated at fine resolution. Real driven q/v/K and separation/slip respond to contact and load with no hidden ratio. Coarse/fine time runs and energy defects converge. Actual original issued histories advance once; saved original state stays unchanged on refusal, fresh owner exact replay succeeds and changed source fails.

## State, Ownership, and Lifecycle
Independent local fixtures, COW source/state and exclusive work. No global mutable test state. Fault wrappers delegate to real suppliers before wrong-source/reset/failed-prefix/cancel counterexamples.

## Failure, Concurrency, and Constraints
Count/storage/work/cancel, source/revision/frame, proxy geometry error, unsupported shape/law and finite-step energy limits are checked behaviorally. Exact Swift6.4.0 owner Native copy baseline209ef09; setup1200seconds four jobs, actual tests240seconds. Private registrations retain exact affected existing targets; production/executable flags/dependencies unchanged.

## Verification and Change Impact
One owned comprehensive review and finding-only corrections precede stable overlay. Actual log/counts/source digest and copy equality are reported to root. Native is not evidence for unexecuted WASM/Embedded; full IM47 remains open outside selected domain.


Initial owner physical proof completed: exact Swift6.4.0 release setup exit0, separate240second skip-build behavior exit0. New11 test declarations/14 parameter cases in2 suites; original69 declarations/17 suites, all passing. `ToothOracle` independently computes scalar sin/cos geometry, force/torque/slip, distributed torque integral and high-resolution RK4; no consumer diagnostics feed those oracles. `ToothLawFault` has one immutable Mutex owner across all targets, with callback execution outside its lock; Native executes reset, failed known prefix, late cancellation success/throw and Task cancellation. Production has only immutable retained reference state and exclusive local work. Logs and remaining qualification boundary are recorded in the source design.


Known-seed regression owner `ToothSeedLedgerTests` uses the owned component-internal phases through testable import. Actual RED5 declarations/6 cases identify seed loss on reset and partial numerical/collision/assembly initialization. Corrected focused GREEN includes all17 owned declarations/22 cases in3 suites, with reset unavailable-work authority retained and valid success/throw exact-budget prefixes charged once. It reexecutes physical torque/mesh/time/work/replay and failure/cancellation evidence because the changed helpers are on those paths. Original lower-target behavior is unchanged and its previous independent proof is retained. The source design records exact bounded log paths and the remaining root-profile boundary.


## AF29 Material Proof Ownership
The source [material contract](../../Sources/SwiftMechanics/Physics/Transmissions/ToothContacts/DESIGN.md#af29-material-evolution-contract) owns new APIs, selected domains and the lower current-port prerequisite. AF29 source and dedicated material tests now implement this contract; isolated Native proof is recorded in the source design. Lower Response tests are owned by the root-assigned prerequisite owner; this target must consume qualified current and trial ports without reflection, fabricated histories or zero-duration trials.

Independent tests use actual two-shaft dynamics and externally declared proxies. Scalar sin/cos/Rodrigues body kinematics derive the original witness normal/points plus the physical common traction point. Equal/opposite force and common point must give zero pair net force and net moment; full original body-point force/couple power is compared independently. Arbitrary admitted initial slip has real virgin history and instantaneous current force, with sequence/time unchanged. A loaded frictional run must develop actual bristles/traction, drive/load torque and slip without an ideal ratio. Independent ellipse/traction work and stored-energy difference prove stick/slip/release and the exact discrete dissipation increment. Anisotropic material axes advect from original collider/body pose; singular projected axes refuse. Damped linear clipping and Hertz/HC forces, original curves/derivatives/continuous losses and full K/Kdot/work are checked with independent physical scalars. Frictional and nonlinear time refinement compare actual q/v/history and energy-defect convergence; normal and resistance continuous losses and exact discrete tangent loss are kept distinct. Reversible cohesive potential is included in the complete stored energy.

Current initialization/end validation must not advance history. Only one real endpoint trial advances sequence/time once; saved accepted history is unchanged on reset/cancellation/resource/energy/source refusal, and an advance preserves its successful prefix. Fresh model/service replay compares exact full physical/history state; same-revision law/material direction/inertia edits refuse. Fault wrappers delegate to the real qualified lower current/trial/geometry/dynamics suppliers before producing wrong source/ledger outputs. Known seed absorption remains exact on initialization failure, reset, ordinary success/throw and late caller/Task cancellation. Existing normal-only public APIs and the qualified original proof are regression obligations, not assumed from types. Immutable baseline48ec4df with qualified lower Sampling, bounded1200second setup/fourjobs and240second behavior is the owner execution plan after stable source review; root owns cumulative canonical/profile proof.


The selected AF29 proof includes reversible cohesion and rolling/spinning resistance. Independent scalar Fc/Uc at compression, within the opening range and after full opening must reproduce conservative opening work T*L/2 in actual K/drive/potential balance without adding it to dissipation. Independent nonidentity framed angular velocities derive both rolling components, spinning couple, compressive-load caps and nonnegative Dr; actual body force/couple application must preserve pair net force/moment and full Kdot. Loaded combined-law evolution must refine q/v/full energy and reproduce exact accepted-history replay. A wrong couple, negative-potential value or omitted resistance power must be rejected by builtin original acceptance. Lower constitutive tests cannot substitute for these upper dynamics oracles. The source [fixed oracle table](../../Sources/SwiftMechanics/Physics/Transmissions/ToothContacts/DESIGN.md#fixed-full-material-oracle-contract) owns the complete proof contract. Current-port spelling and typed error authority follow [Sampling](../../Sources/SwiftMechanics/Physics/ContactLaws/Sampling/DESIGN.md); the lower source is immutable after root qualification48ec4df.


Legacy compatibility cases construct each richer law in the expanded model and invoke the old operation requirements on both the old initializer and the new explicit-current initializer. They require exact `.unsupportedDomain` before any current/trial/history callback or physical publication, including an advance requested at its current accepted time. Delegated counting suppliers prove that injected current capability does not widen legacy operations. Actual admitted AF28 normal-only calls on both compositions reproduce original force locations, physical/history results and original budget/failure behavior. Material operations on a legacy-only composition refuse missing current capability explicitly. These checks close the start-trial double-advance counterexample without changing the old initializer or fabricated lower results.


AF29 owner Native evidence:12 new declarations/25 cases in2 suites pass the final240second run; unchanged17 Tooth declarations and82 affected lower declarations passed the initial full six-target run. Only the new oracle/caller fixture changed after that run: exact public body-ID mapping and an independently verified sliding branch. Production/tolerances and original tests remain unchanged. Source design records setup/behavior logs and the split proof boundary. Scoped review and actual tests establish one immutable production storage contract, with call-local mutable work and shared fault state protected by the same Mutex on all targets. Root retains canonical cumulative/profile/131072byte qualification.
