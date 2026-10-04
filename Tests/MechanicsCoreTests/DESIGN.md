# MechanicsCoreTests
## Purpose and Scope
Parent: [root](../../DESIGN.md). Children: none. Behavioral test owner for Core Diagnostics, Units, Geometry, Spatial and the internal ScalarFunctions boundary.
## Responsibilities and Boundaries
Analytic and invalid-input tests target actual implementations. Fixtures freeze dimensional absolute/relative tolerances before evaluation. No shared mutable static state or shared files are used.
## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Core](../../Sources/SwiftMechanics/Mathematics/Core/DESIGN.md) | verifies | MD-002/003 and RB-003/005 foundation contracts | Analytic frame, units, orientation and inertia paths | Native evidence is not generalized to WASM |
| [ScalarFunctions](../../Sources/SwiftMechanics/Mathematics/ScalarFunctions/DESIGN.md) | verifies | Unchanged platform libm results and consumer validation | Direct libm oracles, signed zero, quadrants, extremes and nonfinite outcomes | Boundary probe evidence is separate from integrated production qualification |
## Architecture
```text
Independent local fixtures -> actual production Core -> analytic invariance and explicit error assertions
```
## Contracts and Invariants
Parallel tests use local immutable objects; loops use only test-local variables. Suite time limits are minutes; commands additionally use an external process deadline.
## Verification and Change Impact
swift test on the native baseline verifies this target. CoreVerification owns the cross-target runtime probe. Change corresponding analytic/domain assertions only when their owner contract actually changes.
