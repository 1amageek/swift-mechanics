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
