# Complex spectrum evidence

## Purpose and Scope
Focused tests of [ComplexSpectrum](../../Sources/SwiftMechanics/Mathematics/Numerics/ComplexSpectrum/DESIGN.md); no children.
## Responsibilities and Boundaries
Independent original equations and resource/failure evidence; root owns profile integration.
## Related Designs
Production child owns spectrum contract; LinearAlgebra owns work.
## Architecture
```text
known matrix/roots -> actual protocol -> independent original residual
```
## Contracts and Invariants
Expected roots never come from solver output; test complete complex modes and nonzero work.
## Verification and Change Impact
Focused exact-release Native, not unexecuted profiles.
