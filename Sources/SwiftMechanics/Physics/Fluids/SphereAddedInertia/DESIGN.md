# AddedInertia mechanical component

## Purpose and Scope
Parent [owner](../DESIGN.md). Children: none. One additive public service within the existing SwiftMechanics module. Selected admitted model only; parent full requirement ownership stays open.

## Responsibilities and Boundaries
Own exact translational potential-flow inertia of one sphere in an unbounded, incompressible, inviscid medium with spatially uniform translation. md=rho*(4*pi*r^3/3), ma=md/2; Madded=ma*I, Fadded=ma*(aFluid-aBody), Fpressure=md*aFluid, total=Fadded+Fpressure. The pressure-gradient contribution must not be dropped for an accelerating medium. Krelative=ma*|vBody-vFluid|^2/2, Kdot=ma*(vBody-vFluid) dot (aBody-aFluid). Report body power and prescribed medium/pressure powers with original balance. Force and mass-matrix forms are two representations of the same inertia; the consumer chooses one and must not apply both. No CFD, drag, buoyancy, walls, rotating medium, multiple-body interaction or automatic equation augmentation.

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
Own exact translational potential-flow inertia of one sphere in an unbounded, incompressible, inviscid medium with spatially uniform translation. md=rho*(4*pi*r^3/3), ma=md/2; Madded=ma*I, Fadded=ma*(aFluid-aBody), Fpressure=md*aFluid, total=Fadded+Fpressure. The pressure-gradient contribution must not be dropped for an accelerating medium. Krelative=ma*|vBody-vFluid|^2/2, Kdot=ma*(vBody-vFluid) dot (aBody-aFluid). Report body power and prescribed medium/pressure powers with original balance. Force and mass-matrix forms are two representations of the same inertia; the consumer chooses one and must not apply both. No CFD, drag, buoyancy, walls, rotating medium, multiple-body interaction or automatic equation augmentation.
Failure contract: LoadError plus exclusive inout LoadWork, checked before arithmetic and before publication. Out-of-domain, nonfinite arithmetic and incompatible histories fail without replacing physical inputs. No dynamic array, unbounded iteration, hidden shared state, callback, unsafe pointer, target-dependent storage or synchronization bypass. Numerical resource counters may advance on failure; accepted physical history never mutates.

## State, Ownership, and Lifecycle
Parameters/history/results are immutable Sendable values. The caller owns all persistence and publication; evaluator retains no cache. Native, WASM and Embedded have identical stored values, protocol requirements and work isolation. Thermal material reads only public supplier contracts. Added inertia identifies all input vectors in one caller-supplied inertial coordinate system. Dahl time is seconds, deflection meters, force newtons, stiffness N/m, viscous coefficient Ns/m and work joules.

## Verification and Change Impact
Public service tests check analytic physical equations, numerical derivatives, energy/work/power, state composition, invalid laws/domains, nonfinite results and applicable cancellation/work/capacity failures. Suppliers and sibling components retain their own evidence; only changed contracts cause requalification. Native selected qualification is recorded after execution; WASM/Embedded/whole-runtime and performance remain unqualified.

### Physical reference
[MIT Marine Hydrodynamics: unsteady added mass](https://web.mit.edu/fluids-modules/www/potential_flows/LecturesHTML/lec12/node1.html) supplies the sphere coefficient ma=md/2; [accelerating-flow pressure gradient](https://web.mit.edu/fluids-modules/www/potential_flows/LecturesHTML/lec13/node2.html) supplies the distinct md*aFluid term. Accessed 2026-10-05. The relative kinetic-energy ledger is explicitly the selected uniform-medium disturbance energy, not the infinite medium's total kinetic energy.

### Selected Native qualification (2026-10-05)
Swift 6.4.0 release, arm64 macOS 27.0.1. The actual canonical SwiftMechanics module and MechanicsThreeAdditionalTests product compiled/linked, with 12 public behavioral tests in three concurrent suites passing (0.004 s test execution). Errors, calibrated envelopes, original derivatives/work/power and applicable state/budget/cancellation paths are exercised. Evidence belongs to Tests/MechanicsThreeAdditionalTests/DESIGN.md. Whole mechanism/Runtime, minimum macOS 13, WASM/Embedded and performance remain unqualified.

| Profile | Storage and isolation | Qualification |
|---|---|---|
| Native | Immutable Sendable values, no shared state; exclusive inout work where used | Selected public behavior passed |
| WASM | Identical source/value ownership and protocol requirements | Not compiled or executed in this task |
| Embedded | Identical source/value ownership and protocol requirements | Not compiled or executed in this task |
