# Six nonlinear transmission tests

## Purpose and Scope
Test owner for [NonlinearKinematics](../../Sources/SwiftMechanics/Physics/Transmissions/NonlinearKinematics/DESIGN.md). Parent: that component; children: none. Six named independent Native suites cover real model/profile behavior and actual published actuator mapping.

## Responsibilities and Boundaries
Own independent geometric/profile values, original closure/sign/phase, first/second derivative refinement, acceleration chain rule, work reciprocity, local inverse singularity and failure/cancellation/resource evidence. No contact surface, constraint-row solver or accepted mechanical evolution qualification.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [NonlinearKinematics](../../Sources/SwiftMechanics/Physics/Transmissions/NonlinearKinematics/DESIGN.md) | depends on | NonlinearTransmissionEvaluating | Original model response | Selected ideal fidelity |
| [Actuation Ports](../../Sources/SwiftMechanics/Physics/Actuation/Ports/DESIGN.md) | depends on | Actual ActuationTransmitting affine witness, work/budget | No mock force mapping | Model/frame/rate association stays explicit |

## Architecture
```text
six immutable geometric fixtures -> six parallel model suites
    -> independent closed-form values and analytic branch/phase/endpoints
    -> two-step directional geometry/motion refinement
    -> original conjugate power -> actual lower affine mapping
common failures -> explicit typed refusal and preserved samples/work
```

## Contracts and Invariants
First/second derivative finite differences use h=1e-4,5e-5 and 1e-8 absolute +2e-6 relative tolerance. Nonlinear acceleration independently evaluates q(t)=q0+v*t+a*t^2/2 at t=1e-3,5e-4 with 3e-6 absolute+2e-5 relative tolerance. Original closed-form tolerance1e-12 absolute+1e-9 relative; tiny profile tests use1e-40 absolute and1e-7 relative. All suites have one-minute timeLimit, outer runtime timeout60s. Fixture thresholds are fixed from physical/numerical units before candidate execution. No I/O/static/reference mutable state exists; suites run concurrently.

## State, Ownership, and Lifecycle
Each case owns its model, sample, lower model/frame records and exclusive ActuationWork/NumericalWork. Lower cancellation closure captures a constant boolean. No shared resources or .serialized bypass.

## Failure, Concurrency, and Constraints
Tests refuse impossible/singular closure, lead reversal, shaft-angle limit, out-of-domain/nonfinite query, arithmetic overflow and local inverse threshold; lower zero-gradient/capacity/cancellation/stale model/frame retain original typed errors. A valid next call must produce the same immutable sample.

## Verification and Change Impact
Run the canonical MechanicsSixTransmissionTests product with the pinned release toolchain and wrapper. No copied source/module or surrogate fixture certifies behavior. Frozen source receipts bind public test product and unchanged selected supplier hashes to the source merge. Changed common operations invalidate all six suites; a model-specific formula change invalidates its named suite. Native/minimum-platform/portable/contact/Runtime/whole210 evidence remains distinct.
