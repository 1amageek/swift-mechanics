# MechanicsDerivativesTests

## Purpose and Scope
Parent: [package](../../DESIGN.md). Children: none. Behavioral owner for [ScalarCalculus](../../Sources/SwiftMechanics/Analysis/Derivatives/ScalarCalculus/DESIGN.md), [TreeTangents](../../Sources/SwiftMechanics/Analysis/Derivatives/TreeTangents/DESIGN.md), [ConstraintProducts](../../Sources/SwiftMechanics/Analysis/Derivatives/ConstraintProducts/DESIGN.md), and [MechanicalSensitivities](../../Sources/SwiftMechanics/Analysis/Derivatives/MechanicalSensitivities/DESIGN.md). Test/profile execution pending.

## Responsibilities and Boundaries
Real verified supplier trees and physical inputs; independent analytic oracles and centered differences only as test oracles. Root owns exact profile composition; tests do not infer general OP qualification.

## Related Designs
Component links above are used-by relations through public required operations. Frozen supplier tests retain their own proof; no repeated supplier audit.

## Architecture
```text
actual tree/model/constraint inputs -> public derivative protocol
                independent physics / centered oracle -> assertions and typed failures
```

## Contracts and Invariants
Serial two-link coupling, free asymmetric inertia, COM transport, quaternion conventions, force frame and prescribed drift must distinguish missing terms. Different coordinate/time scales distinguish physical from normalized products. Missing callback derivative and invalid output must fail. Shape/stale/domain/nonfinite/storage/work/supplier-call/cancel boundaries are actual invocation failures.

## State, Ownership, and Lifecycle
Each test owns immutable input and exclusive workspace/work. No shared mutable fixtures across tests; Swift Testing parallel execution is safe. The metadata/cancellation boundary provider owns one test-local Mutex<Bool>; Native/WASM/Embedded declarations all use that same type, withLock getter/setter, and owner release through normal lifetime. Its behavioral execution is pending Native tests and not claimed as a platform synchronization qualification.

## Failure, Concurrency, and Constraints
No test/build until root registration and stable graph. Root uses timeout-qualified selected Native and exact WASM/Embedded public probes. Compile success alone is not mathematical evidence.

## Verification and Change Impact
Local source review then one focused run at stable snapshot. Targeted repair only for concrete findings. Changes recheck affected component proof and root composition.

Root review regression resets the actual numerical ledger after real tree work inside a required force callback; rejection must retain known charges, mark failed supplier work unavailable and stop before its directional callback. No physical derivative result may be published.

AF16 actual root qualification: twenty-two Native tests pass in the final integrated 391-test/27-module run. Targeted ten-test mechanical recheck closed the two independent fixture expectation failures; stationary second-hinge body origin/geometric columns and changed child rotation match analytic geometry, and cumulative iterations include actual nested solves. Root callback ledger-reset regression rejects before directional/primal continuation, preserving known work and explicit unknown failed consumption. Required selected public pendulum products/Jacobian and scalar unavailable-domain probe exited 0 on Native/ordinary-WASM/Embedded using original profiles; full IM30 remains open.
