# CMechanicsMath
## Purpose and Scope
Parent: [root design](../../DESIGN.md). Children: none. Platform adapter for scalar system libm only.
## Responsibilities and Boundaries
Expose sin, cos, atan2 and hypot without Foundation. Physics algorithms remain in Swift; this adapter is neither a solver nor a simulation backend. No pointers, heap state or device resources cross this boundary.
## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Root](../../DESIGN.md) | parent | Native/WASM platform boundary | System scalar mathematics | Linux libm linkage is explicit |
| [Core](../MechanicsCore/DESIGN.md) | used by | Scalar operations | Quaternion and norm operations | Caller validates domains/results |
## Architecture
```text
Swift finite scalar -> inline C wrapper -> target libm -> Swift checked result
```
## Contracts and Invariants
There is no hidden approximate backend selection or mutable state. Supported semantics are those of the linked target libm and floating-point environment. Determinism across different libm implementations is numerical, not unconditionally bitwise.
## Verification and Change Impact
The Core tests/executable exercise each required operation through actual linked code on native/WASM/Embedded. Target-specific linkage changes require corresponding compile/link/runtime evidence.
