# Thermal mechanical component

## Purpose and Scope
Parent [owner](../DESIGN.md). Children: none. One additive public service within the existing SwiftMechanics module. Selected admitted model only; parent full requirement ownership stays open.

## Responsibilities and Boundaries
Own small-strain isotropic thermal eigenstrain and elastic free-energy density. epsilonElastic=epsilonTotal-alpha*(T-Tref)*I; stress=C:epsilonElastic, psi=0.5*epsilonElastic:C:epsilonElastic, dStress/dT=-3*K*alpha*I. Input strains are infinitesimal material-frame tensors, T in kelvin. Mechanical power=stress:epsilonDot, prescribed thermal power=-alpha*trace(stress)*TDot and psiDot is their sum. No heat capacity, conduction, total thermal internal energy, finite thermal multiplicative deformation or element/Runtime admission is inferred. Consume only public IsotropicElasticity.evaluate/tangent, SymmetricTensor and StrainDomain operations; elastic and total strain domains are both checked.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [Owner](../DESIGN.md) | parent | SI, explicit domain and authority | No parent Runtime capability inferred |
| [Core](../../../Mathematics/Core/DESIGN.md) | depends on | Checked finite vector/matrix algebra | Explicit typed failure translation |
| [Tests](../../../../../Tests/MechanicsThreeAdditionalTests/DESIGN.md) | used by | Public operation behavioral evidence | Profile-specific scope |

## Architecture
```text
immutable law + explicit physical sample / accepted history
    -> required protocol witness -> checked finite equation
    -> immutable response + original derivative / power / energy
```

## Contracts and Invariants
Own small-strain isotropic thermal eigenstrain and elastic free-energy density. epsilonElastic=epsilonTotal-alpha*(T-Tref)*I; stress=C:epsilonElastic, psi=0.5*epsilonElastic:C:epsilonElastic, dStress/dT=-3*K*alpha*I. Input strains are infinitesimal material-frame tensors, T in kelvin. Mechanical power=stress:epsilonDot, prescribed thermal power=-alpha*trace(stress)*TDot and psiDot is their sum. No heat capacity, conduction, total thermal internal energy, finite thermal multiplicative deformation or element/Runtime admission is inferred. Consume only public IsotropicElasticity.evaluate/tangent, SymmetricTensor and StrainDomain operations; elastic and total strain domains are both checked.
Failure contract: MaterialError; constant scalar/tensor work and no callbacks. Out-of-domain, nonfinite arithmetic and incompatible histories fail without replacing physical inputs. No dynamic array, unbounded iteration, hidden shared state, callback, unsafe pointer, target-dependent storage or synchronization bypass. Numerical resource counters may advance on failure; accepted physical history never mutates.

## State, Ownership, and Lifecycle
Parameters/history/results are immutable Sendable values. The caller owns all persistence and publication; evaluator retains no cache. Native, WASM and Embedded have identical stored values, protocol requirements and work isolation. Thermal material reads only public supplier contracts. Added inertia identifies all input vectors in one caller-supplied inertial coordinate system. Dahl time is seconds, deflection meters, force newtons, stiffness N/m, viscous coefficient Ns/m and work joules.

## Verification and Change Impact
Public service tests check analytic physical equations, numerical derivatives, energy/work/power, state composition, invalid laws/domains, nonfinite results and applicable cancellation/work/capacity failures. Suppliers and sibling components retain their own evidence; only changed contracts cause requalification. Native selected qualification is recorded after execution; WASM/Embedded/whole-runtime and performance remain unqualified.

### Selected Native qualification (2026-10-05)
Swift 6.4.0 release, arm64 macOS 27.0.1. The actual canonical SwiftMechanics module and MechanicsThreeAdditionalTests product compiled/linked, with 12 public behavioral tests in three concurrent suites passing (0.004 s test execution). Errors, calibrated envelopes, original derivatives/work/power and applicable state/budget/cancellation paths are exercised. Evidence belongs to Tests/MechanicsThreeAdditionalTests/DESIGN.md. Whole mechanism/Runtime, minimum macOS 13, WASM/Embedded and performance remain unqualified.

| Profile | Storage and isolation | Qualification |
|---|---|---|
| Native | Immutable Sendable values, no shared state; exclusive inout work where used | Selected public behavior passed |
| WASM | Identical source/value ownership and protocol requirements | Not compiled or executed in this task |
| Embedded | Identical source/value ownership and protocol requirements | Not compiled or executed in this task |
