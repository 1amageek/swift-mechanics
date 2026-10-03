# CoreVerification
## Purpose and Scope
Parent: [root](../../DESIGN.md). Children: none. Headless runtime probe for actual Core production paths on native, WASM and Embedded WASM.
## Responsibilities and Boundaries
This executable verifies admitted mathematical paths and typed failures, including existential protocol dispatch. It does not claim physics, full platform support or replace native component tests.
## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Core](../MechanicsCore/DESIGN.md) | depends on | UnitConverting, SpatialTransforming, Matrix3Operating, RotationIntegrating | Actual linked foundation | All calls use protocol requirements supported in Embedded |
## Architecture
```text
Actual Core implementation -> analytic checks and expected failures -> explicit process success/failure
```
## Contracts and Invariants
Any wrong result or wrong/missing failure terminates with an error. Expected values are independent analytic fixtures. No simulated physics or synthesized data is reported as a success.
## Verification and Change Impact
Run on the exact SDK/runtime and record identifiers. A changed Core convention requires updating the independent expected fixture deliberately; passing compilation is not runtime evidence.
