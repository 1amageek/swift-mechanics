# ScalarFunctions

## Purpose and Scope
Parent: [Mathematics](../DESIGN.md). Children: none. This component owns the internal Float64 platform scalar boundary used by the consolidated SwiftMechanics module.

## Responsibilities and Boundaries
ScalarMath delegates sine, cosine, two-argument angle and two-argument norm to the selected platform libm. Consumers own physical domains, finite input/output admission and typed errors. The boundary does not alter values, clamp results, approximate functions or select a numerical fallback.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Mathematics](../DESIGN.md) | parent | Consolidated component composition | Internal scalar boundary | Source relocation requires integrated qualification |
| [Core](../Core/DESIGN.md) | used by | Float64 norm and orientation functions | Checked geometry and quaternion arithmetic | Consumers preserve their finite-result guards |
| [Constraints](../../Physics/Constraints/DESIGN.md) | used by | Sine and cosine | Knife-edge row and acceleration bias | Domain and work accounting remain consumer-owned |
| [Equilibrium](../../Analysis/Equilibrium/DESIGN.md) | used by | Sine and cosine | Pendulum force, tangent and energy | Scalar conversion and finite result checks remain consumer-owned |
| [Derivatives](../../Analysis/Derivatives/DESIGN.md) | used by | Sine and cosine | Exact directional scalar derivatives | DirectionalScalar owns finite result admission |
| [StructuralAnalysis](../../Analysis/StructuralAnalysis/DESIGN.md) | used by | Norm and two-argument angle | Truss lengths and complex amplitude/phase | Overflow and zero-phase semantics remain consumer-owned |
| [Core tests](../../../../Tests/MechanicsCoreTests/DESIGN.md) | verified by | Scalar boundary and checked public geometry | Direct platform oracles plus analytic cases | Native test evidence is scoped to the executed profile |

## Architecture
```text
Checked physics/geometry consumer
    -> internal ScalarMath
        -> Darwin, WASILibc or Glibc
            -> platform sin / cos / atan2 / hypot
```

## Contracts and Invariants
`sine` and `cosine` accept one Double; `angle(y:x:)` preserves atan2 argument order; `norm` accepts two Doubles. Each operation returns the platform result unchanged, including signed zero, quadrant selection, scaled extreme norms, NaN and infinity. The selected import is Darwin first, WASILibc second, Glibc third. A platform with none fails compilation explicitly. This internal boundary adds no public API or independent finite-value promise. The former C header delegated these same operations directly to libm; consumer validation, result semantics and operation charges stay unchanged.

## State, Ownership, and Lifecycle
The enum has no instances, stored state, buffers, owners, callbacks or resources. All inputs and outputs are values; calls are synchronous. Native, ordinary WASM and Embedded use identical operations and consumer Sendable contracts. Platform selection does not branch storage, isolation or conformance.

## Failure, Concurrency, and Constraints
libm exceptional values remain exceptional values. Consumer-specific typed validation determines whether they are admitted. No error is converted to a finite default. Concurrent calls share no Swift mutable state. Every operation invokes one platform function with fixed scalar arguments and no Swift allocation or copy buffer.

## Verification and Change Impact
`Tests/MechanicsCoreTests/ScalarMathTests.swift` compares the actual internal boundary with direct platform functions and analytic signed-zero, quadrant, extreme norm and nonfinite cases; public vector/quaternion/complex checks cover consumer admission. Existing Constraints, Equilibrium, Derivatives and StructuralAnalysis behavioral tests cover their actual consumer paths. Scalar-related fluid and constraint test fixtures call platform libm directly, independently of ScalarMath.

The separate `.build/scalar-math-design-probe` selected this direct Swift boundary with Swift 6.4.0 and matching Native, ordinary WASM and Embedded WASM profiles: its successful runtime logs cover trigonometry, atan2 quadrants/signed zero, large/tiny scaled hypot and NaN/infinity. This is boundary selection evidence from an isolated probe; it is not qualification of the changed production source. Root-owned frozen-source integrated tests and verification executables must qualify actual production callers. Glibc is an explicit compilation branch; Linux runtime is not qualified. Changing import selection, function mapping or consumer finite admission requires affected integrated consumer verification on the declared profiles.

AR01 production qualification: four new scalar tests and preserved checked geometry/phase callers passed within 477 consolidated Native tests. Original public Foundation execution passed matching Native/WASM/Embedded profiles using this Swift adapter. The own C target was removed; system libm remains the implementation. Independent prior signed-zero/quadrant/extreme-scale/nonfinite probes are valid for their pinned profiles. Linux runtime remains unverified.
