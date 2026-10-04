# Gear reinitialization tests

## Purpose and Scope
Parent [SwiftMechanicsCAD tests](../DESIGN.md); no children. Own the selected [GearReinitialization](../../../Sources/SwiftMechanicsCAD/GearReinitialization/DESIGN.md) CA-009 actual edited-source rebuild, physical reinitialization, atomic publication and fresh restart evidence.

## Responsibilities and Boundaries
Exercise only public original CAD evaluation, compiler, gear binding, constrained physical admission, integration records and Runtime operations. Each fixture owns new CAD documents, supplied rotor inertias and original numerical work. No @testable imports, raw evaluated snapshot, fake step control, retained old model disguised as a cold recipe or fabricated accepted value is permitted. Root owns package registration, public callers, integration and commits.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Production](../../../Sources/SwiftMechanicsCAD/GearReinitialization/DESIGN.md) | depends on | Edited-source preparation and original Runtime publication | Owned invariants | Reinitialization only; exact moments unavailable |
| [Parent](../DESIGN.md) | parent | Native public test target | Registration and test isolation | Root owns shared graph |
| [Gear tests](../GearBindings/DESIGN.md) | coordinates with | Existing original CAD/shaft/load evidence | Unchanged lower proof | Do not repeat all AF29 assertions |

## Architecture
```text
actual source CAD -> actual source compiled context -> real RuntimeSession
edited CAD + explicit new placements/inertias/q/v/a
 -> original fresh compilation/binding/cold force admission
 -> prepared reinitialize -> real atomic replacement
 -> exact saved bytes -> entirely fresh final context/session -> restart
negative source/force/catalog/choice/cancel/bounds -> unchanged accepted bytes/RNG
```

## Contracts and Invariants
A genuine parameter edit changes admitted source fingerprint/revision and at least one original gear dimension. Prefer resizing the shared module and shifting the second shaft center so the original new pitch-radius sum is exercised, with explicit fresh placement/anchor recipe. Source20:40 teeth remain a declared ideal domain; supplied inertias I1=2,I2=3 and drive[1,0] give the independent original row acceleration [4/11,-2/11], reactions[-3/11,-6/11], and zero ideal reaction power. A target supplied inertia change must use its independently recomputed original mass-weighted oracle, not silently reuse the old a. The tests must observe actual new geometry, compiled descriptor/anchor position and source-bound physical chart, not only a new stamp.

Source may advance before edit using actual original projected evolution, including actual RNG draws in a published trial. Target reinitialization explicitly chooses q/v at the accepted time and correct physical a; publication preserves RNG and advances global sequence by one. Both CAD and integration records must differ when their original associations change. The numerical integrator reset uses the declared classicalRK4 initial step with a global sequence tied to Runtime, never an unassociated sequence-zero record at later publication.

Fresh restart reconstructs CAD document, original source admission, descriptor compilation, gear binding, equation, contributors, handler and RuntimeSession as new owners from the final recipe. Decode saved bytes through the original native codec and restart; compare complete final checkpoint, exact bytes and RNG, then advance both original and cold owners through the same actual projected evolution and compare the next checkpoint. No retained previous physical/model owner supplies the cold recipe.

Negative cases exercise actual publication or strict admission: old expected CAD identity or same-ID edited anchor; unchanged/stale mechanics revision; wrong new spacing/placement; incompatible reset q/v or forged a; same-revision changed mass; altered CAD record and omitted/duplicate/extra contributor; forged integration global sequence/time/point; old revision saved bytes on final owner; preserveCompatibleState; source accepted checkpoint changed after preparation; cancellation and bounded-capacity failure. Every failing live operation must retain the complete accepted checkpoint and RNG, with original supplier failures remaining typed. Test cancellation/ledger prefixes only where the owned contract can observe them; no opaque CAD-work claim is invented.

## State, Ownership, and Lifecycle
Each test owns independent immutable recipes and exclusive work, plus original session lifecycle. Any cancellation counter shared by a Sendable callback uses Mutex. No shared file or process state is created. Suite/Test declarations remain unannotated; each test guards macOS15 Runtime availability before calling those APIs. Private nonmacro helpers may carry availability annotations.

## Failure, Concurrency, and Constraints
No builds start before production/test source freeze and the assigned proof slot. Exact Swift6.4.0 release, Native four jobs, setup1200 seconds and behavior240 seconds are bounded externally. Reuse only the root-approved stopped CAD cache against immutable48cf8df and owned overlays; never copy generated caches or build the mutable shared source. Actual workspace-state/provider pin and compiled source evidence must identify the tested graph. The currently small disk budget is a scheduling constraint, not a new public physics policy.

## Verification and Change Impact
One scoped production/test review followed by causal repairs and focused Native behavior closes this owner. The existing17 optional-package behaviors remain regression evidence for unchanged prerequisites; broader canonical optional-package integration belongs to root. Source/pin/model/equation admission contracts changing later invalidate only their dependent proofs. This design records proof obligations, not completed execution.
