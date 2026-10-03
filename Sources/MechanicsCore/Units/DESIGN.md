# Units
## Purpose and Scope
Parent: [MechanicsCore](../DESIGN.md). Children: none. Own explicit physical dimensions, unit definitions and finite SI conversion.
## Responsibilities and Boundaries
Dimensions track length, mass, time, angle, electric current, temperature, amount and luminous intensity. Angle remains an explicit semantic dimension at conversion boundaries. Torque/energy share SI dimensions; consuming physical types distinguish their meaning. No parser or CAD unit system is reimplemented.
## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Core](../DESIGN.md) | parent | Canonical SI input boundary | Shared dimensional conversion | Affine temperature is distinct from multiplicative material parameters |
| [Diagnostics](../Diagnostics/DESIGN.md) | depends on | CoreError | Explicit mismatch, scale and overflow failures | No automatic conversion of incompatible quantities |
## Architecture
```text
Dimension + finite positive scale + optional temperature offset -> UnitDefinition
source value -> canonical SI -> destination value
```
## Contracts and Invariants
Int8 exponents combine with checked addition. SI value = source value * scale + offset; destination = (SI value - destination offset) / destination scale. Offset is accepted only for pure temperature; dimensions must match. Input, intermediate and output are finite or conversion fails. Symbols are immutable descriptive metadata, not authoritative parsers. Affine temperature conversions are for absolute readings, not temperature-difference multiplication.
## Verification and Change Impact
Tests/MechanicsCoreTests/UnitsTests.swift owns mixed length/time/angle/electrical/temperature conversions, mismatches, overflow and exponent bounds. Sources/CoreVerification checks actual UnitConverting protocol calls on each runtime. Changes affect every mechanical parameter and exchange adapter.
