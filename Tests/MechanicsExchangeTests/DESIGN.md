# Exchange behavioral verification
## Purpose and Scope
Test owner of [Schema](../../Sources/MechanicsExchange/Schema/DESIGN.md), [BinaryCodec](../../Sources/MechanicsExchange/BinaryCodec/DESIGN.md), [Admission](../../Sources/MechanicsExchange/Admission/DESIGN.md). Children: none.
## Responsibilities and Boundaries
Round-trip is checked through real Compiler compilation and actual kinematic snapshots/layout/sparsity, with a real bounded spring descriptor validator. Opaque asset equality proves data admission only. No Runtime continuation or external I/O success is implied.
## Related Designs
Compiler public records/tests provide verified assumptions; these fixtures compute expected counts/motion/units and preserve source provenance without copying Compiler internals.
## Architecture
```text
explicit SI model -> public codec -> public loader/Compiler -> independent q-v/motion/manifest oracle
malformed bytes/policy/required assets -> explicit failure -> unchanged caller input/previous model
```
## Contracts and Invariants
Native tests freeze meter/radian/SI input, Float64 bit checks for arrays/parameters, 1e-10 absolute+1e-11 relative geometric tolerance, unit component correction1e-11 (strict case0). Work limits explicitly selected per fixture, no host global mutation. Header and offset fixtures follow Schema field order. Counts are guarded before allocation, malformed UTF8 never repaired, unsupported tags/features/references and missing/stale/duplicate assets fail. Semantic Unicode IDs include canonical-equivalent duplicate rejection.
## Verification and Change Impact
After target registration: python3 Scripts/run_with_timeout.py 180 swift test --build-path .build/exchange-kernels --filter MechanicsExchangeTests. Schema/producer changes recheck exact-profile loading; Native/WASM/Embedded combined proof belongs to root.
