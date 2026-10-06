# Six energy transducer tests

## Purpose and Scope
Parent: [EnergyTransducers](../../Sources/SwiftMechanics/Physics/Actuation/EnergyTransducers/DESIGN.md). Children: none. Native public API proof for six selected constitutive laws and original supplier/energy boundaries.

## Responsibilities and Boundaries
Independent original values, energy gradients, all reciprocal tangents, signed power accounting and actual published affine actuator witness. No mock source or Runtime/circuit qualification.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [EnergyTransducers](../../Sources/SwiftMechanics/Physics/Actuation/EnergyTransducers/DESIGN.md) | depends on | Required EnergyTransducerEvaluating | Analytic physical values | Selected calibrated models |
| [Ports](../../Sources/SwiftMechanics/Physics/Actuation/Ports/DESIGN.md) | depends on | Real work/error/affine mapping | Resource and force authority | Separate exclusive per-case ledgers |

## Architecture
```text
six independent SI fixtures -> six concurrent named suites
 -> original energy -> independent first derivatives -> analytic tangent check
 -> signed rates and source power -> actual lower affine port
common limits -> typed failures, preserved immutable samples and actual work ledger
```

## Contracts and Invariants
Original numeric tolerance1e-10abs+1e-9rel; derivative h1e-5/5e-6 and1e-7abs+2e-5rel. Tests timeLimit1min; command test timeout60s/build120s. No shared mutable/static/I/O resources or serialized bypass.

## Failure, Concurrency, and Constraints
Malformed law, invalid state/rate, gap/capacitance admission, arithmetic overflow and actual work/cancel failure are observed through public calls. Prior immutable sample remains valid.

## Verification and Change Impact
Canonical MechanicsSixTransducerTests depends only on actual SwiftMechanics. Match frozen production/test hashes and unchanged supplier hashes after merge. Common sample changes require all suites; model-local change needs its suite. Native/portable/Runtime/field fidelity remain separate.
