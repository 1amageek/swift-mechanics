# Actuation behavioral verification
## Purpose and Scope
Test owner for [Ports](../../Sources/SwiftMechanics/Physics/Actuation/Ports/DESIGN.md), [DriveLaws](../../Sources/SwiftMechanics/Physics/Actuation/DriveLaws/DESIGN.md), [LumpedLaws](../../Sources/SwiftMechanics/Physics/Actuation/LumpedLaws/DESIGN.md), [Continuation](../../Sources/SwiftMechanics/Physics/Actuation/Continuation/DESIGN.md). Children: none.
## Responsibilities and Boundaries
Independent controller equations and circuit/fluid/muscle balances, actual Loads routing and actual Runtime accepted/rejected/restored state. Numerical effort evaluation does not qualify mechanical dynamics or prescribed reactions.
## Related Designs
Runtime/Loads public contracts supply their verified owned state/port operations; actuator fixtures supply independent SI expected values.
## Architecture
```text
SI parameter fixture -> public law requirement -> independent discrete equation/power oracle
actuator contributor -> actual Runtime trial -> reject/checkpoint/restore -> same continuation
```
## Contracts and Invariants
Caller limits/tolerance are explicit. Success includes original energy/power balances; incorrect frame/revision/history/mode, nonfinite overflow, unsupported chart and exhausted ledgers must fail. Runtime metadata/budget separate from scalar numerical and control work.
## Verification and Change Impact
After root graph registration/stability, timeout180 private actuation build or root cohort runs actual suites. Exact Native/WASM/Embedded composition is root-owned. Mutable test state is local; no cross-suite shared resources.
