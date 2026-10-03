# Diagnostics
## Purpose and Scope
Parent: [MechanicsCore](../DESIGN.md). Children: none. Own finite-value mathematical errors and explicit absolute/relative tolerance semantics.
## Responsibilities and Boundaries
CoreError concerns foundational numerical input/domain/result failures, not model references, physics convergence or platform capability failures. NumericalTolerance accepts nonnegative finite components and compares absolute error with absolute + relative * nonnegative reference scale.
## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Core](../DESIGN.md) | parent / used by | CoreError and NumericalTolerance | Common failure/tolerance values | Consumers do not convert errors to success |
## Architecture
```text
Finite input validation -> CoreError
Caller tolerance + error + scale -> accepted comparison or CoreError
```
## Contracts and Invariants
No nonfinite/negative tolerance is admitted. Overflow computing an error threshold is a failure, not infinite automatic acceptance. Scale is dimensionally chosen by the caller/fixture. Errors are typed, Sendable values.
## Verification and Change Impact
Tests/MechanicsCoreTests/DiagnosticsTests.swift owns invalid/overflow tolerance checks. Changes affect every Core component and numerical consumer.
