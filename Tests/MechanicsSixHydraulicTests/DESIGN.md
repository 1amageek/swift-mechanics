# Six hydraulic tests

## Purpose and Scope
Parent: [HydraulicElements](../../Sources/SwiftMechanics/Physics/Actuation/HydraulicElements/DESIGN.md). Children: none. Own six independent Native constitutive suites and actual bounded-work failure paths.

## Responsibilities and Boundaries
Independent physical fixtures, pressure/flow/storage gradients and original cylinder pressure-rate/power identities. No surrogate module, mock supplier or circuit/Runtime claim.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [HydraulicElements](../../Sources/SwiftMechanics/Physics/Actuation/HydraulicElements/DESIGN.md) | depends on | Six required witnesses | Physical response | Selected fidelity only |
| [Ports](../../Sources/SwiftMechanics/Physics/Actuation/Ports/DESIGN.md) | depends on | Actual work/budget/error | Refusal before output | Exclusive per-test ledger |

## Architecture
```text
six independent physical fixtures -> six parallel suites
 -> original formulas, gradient/refinement, conservation and typed failures
common limits -> actual cancelled/exhausted supplier + preserved model/result
```

## Contracts and Invariants
Numeric tolerance1e-10 absolute+1e-10 relative for original values/powers; gradient checks use h=1e-6 and5e-7 with1e-8 absolute+1e-6 relative. Derivatives/refinement compare physical formulas, not copied implementation outputs. All suites timeLimit1min; command outer timeout60s; cold build timeout240s (previous cache removed). Each test owns its ledger and immutable model; no shared resource or serialization.

## Failure, Concurrency, and Constraints
Invalid parameter/input, nonfinite overflow, pressure/flow/stroke approximation bounds, supplier budget and cancellation refuse via actual typed error. Re-query preserves previous immutable result.

## Verification and Change Impact
Canonical MechanicsSixHydraulicTests depends only on SwiftMechanics. Freeze actual source/tests and relevant unchanged work suppliers. Local formula changes rerun its suite; shared response/work changes rerun all. Native evidence scoped to exact release toolchain and host.
