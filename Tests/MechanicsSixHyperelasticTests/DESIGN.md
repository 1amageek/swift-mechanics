# Six invariant material tests

## Purpose and Scope
Parent/test consumer: [InvariantHyperelasticity](../../Sources/SwiftMechanics/Physics/Materials/InvariantHyperelasticity/DESIGN.md). Six named suites own selected Native constitutive behavior; children: none.

## Responsibilities and Boundaries
Tests call the existing public HyperelasticResponding witness through an existential, independently compare closed-form shear/volume responses, and verify first/second Piola and Cauchy analytic tangents plus potential gradients. No Runtime or element pairing assertion.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Material](../../Sources/SwiftMechanics/Physics/Materials/InvariantHyperelasticity/DESIGN.md) | depends on | Six public models | Independent energies and derivatives | Exact selected equations only |
| [Constitutive](../../Sources/SwiftMechanics/Physics/Materials/Constitutive/DESIGN.md) | depends on | Public finite response/tangent factories | Mapping and failure evidence | Existing client regression is separate |

## Architecture
```text
six immutable calibrated fixtures -> six parallel suites -> independent original physics assertions
shared immutable matrix fixtures -> finite differences at two refinements -> all analytic stress tangents
```

## Contracts and Invariants
Scalar tolerances are 1e-10 absolute plus 1e-7 relative; tiny energy uses 1e-50 absolute. Tangent tolerance 1e-7 absolute plus 2e-6 relative at independent h=1e-4,5e-5. Two-step refinement must retain agreement; fixtures do not relax tolerance based on candidate results. Objectivity compares QF to independent stress transforms. Hydrostatic energy and pure shear tangents derive from the declared original potential. Suite timeLimit one minute, outer test timeout60 seconds. Tests have no I/O, reference-owned shared state or serialization; six suites run concurrently.

## State, Ownership, and Lifecycle
Each test owns immutable material/matrix inputs. No files/static buffers or resource contention. Local loops and expected-value arithmetic do not cross concurrency boundaries.

## Failure, Concurrency, and Constraints
Fixtures reject invalid parameters, singular/negative J, strain calibration violation, locking and overflowing direction, preserving a recoverable valid next call. Outer timeout bounds tool execution independently of Swift Testing.

## Verification and Change Impact
The canonical MechanicsSixHyperelasticTests product verifies the real SwiftMechanics module, not copied source. Source hashes bind the product evidence. Additive supplier factories also require retained nine Materials tests; existing evidence is reused when sources are unchanged. Native success does not qualify minimum macOS13, WASM/Embedded, performance or flexible element execution.
