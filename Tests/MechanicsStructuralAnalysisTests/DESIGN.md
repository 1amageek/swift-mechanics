# Structural analysis tests

## Purpose and Scope
Parent [module](../../Sources/MechanicsStructuralAnalysis/DESIGN.md). Own local ST-005..007 physical success/failure evidence; no children. Execution qualification pending.

## Responsibilities and Boundaries
Tests invoke actual public protocols with beam/truss physical models and actual Flexible/Equilibrium producers. Root owns shared graph and profile probes.

## Related Designs
PhysicalModels, Pencils, HarmonicResponse and Buckling child DESIGNs own equations and budgets. This test owner consumes them without repeating contracts.

## Architecture
```text
physical fixture -> actual public operation -> independent analytical/original residual assertion
```

## Contracts and Invariants
Euler beam frequency/load mesh convergence, free modes, prestress classification, real mass normalization, oscillator complex phase, nonlinear truss energy/force/tangent and critical load are evidence targets. Invalid domains and exhausted budgets must fail. No fake numerical responses.

## State, Ownership, and Lifecycle
Each test owns immutable inputs and local work. Cancellation contexts use immutable closures unless a same-target Mutex owner is explicitly required. No shared files/static mutable state. The cancellation fixture owns a macOS15/iOS18/tvOS18/watchOS11-available Mutex<Bool> instance and delegates the actual linear solve before setting cancellation; all accesses use the same lock, lifetime is the test call and no callback runs inside the lock.

| Logical state | Native / WASM / Embedded storage | Isolation | Read | Mutation | Release |
|---|---|---|---|---|---|
| Test cancellation flag | Mutex<Bool> | Same withLock | cancelled | cancel | Instance owner end |

## Verification and Change Impact
Root registers frozen actual source/tests then runs timeout-wrapped focused Native and selected exact-profile public operations. No build is executed while the graph is mutable.
