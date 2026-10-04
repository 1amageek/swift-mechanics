# Contact derivative tests

## Purpose and Scope
Test target MechanicsContactDerivativeTests owns selected ContactProducts OP-003 proof. Parent [tests](../DESIGN.md); children none.

## Responsibilities and Boundaries
Independent scalar physical equations and actual public pairing/primal services establish products, source and failures. No coupled impulse/response or full OP-003 completion claim.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [ContactProducts](../../Sources/SwiftMechanics/Analysis/Derivatives/ContactProducts/DESIGN.md) | depends on | fixed-active products | Production authority | Neighborhood and fixed source |
| [Contact laws tests](../MechanicsContactLawsTests/DESIGN.md) | coordinates with | unchanged primal regression | Read-only producer proof | No shared mutable fixtures |

## Architecture
```text
actual pairing/history/input -> protocol derivative -> independent analytic scalar/vector oracle
 -> actual primal perturbation refinement -> source/failure/budget boundaries
```

## Contracts and Invariants
Linear/Hertz/HC normal products include elastic U, clipped dissipation and mechanical P. Rotated normal validates frame projection. Impact retained+lost direction equals original energy direction, independently varies speed and energy. Strict threshold/domain neighborhoods are checked. Delegated actual supplier wrappers create wrong-source and valid failed-prefix/reset/cancel counterexamples, without fabricated primal values.

## State, Ownership, and Lifecycle
Local fixtures and ledgers; any cancellation observer uses identical Mutex Sendable storage. No shared test files/state. Immutable accepted history is replayed and unchanged after refusal.

## Failure, Concurrency, and Constraints
Typed catches retain exact cases. Setup is bounded1200seconds and behavioral execution240seconds, exact Swift6.4.0 and four jobs in exclusive baseline copy. Private manifest registers this target and retains affected original contact/derivative targets; production graph/flags unchanged. Root canonical integration and profiles follow source freeze.

## Verification and Change Impact
Owner runs independent Native tests after one scoped comprehensive review; concrete findings receive limited correction/recheck. Logs and source digest are reported to root. Native evidence is not generalized to WASM/Embedded. Changes to branch/source/work contracts require affected owned oracle recheck and parent consumer composition.

### AF27 isolated Native evidence
The frozen owned implementation was overlaid onto committed baseline `1bf65c3` in `.build/af27-independent-contact-derivatives`. The private manifest registers only MechanicsContactDerivativeTests and exact existing MechanicsContactLawsTests, MechanicsContactResponseTests, MechanicsHybridTests and MechanicsDerivativesTests; all production/executable targets, dependencies and compiler flags remain unchanged.

Exact Swift6.4.0 setup `swift build --build-tests --build-path .build/native -j 4` used a1200second timeout. First setup exposed one owned test Task catch inference error, corrected with an explicit typed do; the incremental setup exited zero. Separate240second `swift test --skip-build --build-path .build/native -j 4` exited zero: new14 declarations/25 parameter cases in3suites, existing67 declarations in13suites; total81declarations/16suites. The actual logs are private copy `.build/af27-contact-native-setup.log`, `-setup-2.log`, and `-tests.log`. Only Native selected behavior is qualified here; root owns canonical cumulative and original-profile qualification. No full OP-003 completion claim.
