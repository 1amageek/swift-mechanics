# Gyro mechanical law

## Purpose and Scope
Parent: [owner](../DESIGN.md). Children: none. Add one independent constitutive law inside the existing SwiftMechanics module. No new module, automatic evolution or broad requirement-family completion.

## Responsibilities and Boundaries
Axisymmetric rotor in world coordinates with unit carrier-fixed axis a, moments It>0, 0<Jp<=2It. I*v=It*v+(Jp-It)*(a dot v)*a. Torque=I*alpha+Omega cross I*Omega+Jp*spinAcceleration*a+Jp*spinSpeed*(Omega cross a). Split motor torque along a and transverse bearing torque; report reaction torques, kinetic energy and independent energy rate/power. No additional mass or persistent dynamics state is injected.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [Owner](../DESIGN.md) | parent | Mechanical responsibility and SI conventions | Existing models remain independent |
| [Core](../../../Mathematics/Core/DESIGN.md) | depends on | Checked finite vectors, SI | Own failure translated explicitly |
| [Tests](../../../../../Tests/MechanicsAdditionalModelsTests/DESIGN.md) | used by | Public service behavioral evidence | Qualification is profile-specific |

## Architecture
```text
immutable law + caller state / physical sample
    -> protocol witness -> checked bounded equation
    -> immutable issued response + physical energy / power
```

## Contracts and Invariants
Axisymmetric rotor in world coordinates with unit carrier-fixed axis a, moments It>0, 0<Jp<=2It. I*v=It*v+(Jp-It)*(a dot v)*a. Torque=I*alpha+Omega cross I*Omega+Jp*spinAcceleration*a+Jp*spinSpeed*(Omega cross a). Split motor torque along a and transverse bearing torque; report reaction torques, kinetic energy and independent energy rate/power. No additional mass or persistent dynamics state is injected.
Failures use LoadError. Exact selected equations, original energy and force derivatives are acceptance evidence; finite output alone is insufficient.

## State, Ownership, and Lifecycle
No arrays, dynamic loops, callbacks or shared mutable storage. Constant scalar/vector footprint. Constructors reject nonfinite parameters and invalid admitted laws; operation arithmetic has explicit numerical failures. Operations reject outside envelopes and nonfinite arithmetic before issuing a result. All public values are immutable Sendable; protocol operations are witness requirements. Native/WASM/Embedded use the same source and ownership. Target math uses formal platform imports, not a new C target. No unsupported callable API is added. Exclusive inout supplier work charges/reserves before evaluation, with cancellation and capacity propagated.

## Verification and Change Impact
Analytic equations, state composition, constitutive derivative, energy / power, frame covariance where applicable, invalid parameters, envelopes, nonfinite output, cancellation and work exhaustion are tested through the public protocol. Direct clients recheck after contract changes. No WASM, Embedded, minimum OS or performance claim follows from Native tests. Parent indexes reference this design without duplicating it.

### Units and ownership
World-frame axis norm must differ from one by at most 1e-12; zero/nonunit axes fail, rather than being silently normalized. Carrier and relative spin speed/acceleration are bounded separately. Inertias in kg m^2, torques in Nm, angular speed/acceleration in rad/s and rad/s^2, energy in J, power in W. Carrier power is requiredTorque dot carrierSpeed; relative motor power is axis motor effort times relative spin speed.

| Profile | Law/history/response storage | Mutation and release | Evidence |
|---|---|---|---|
| Native | Immutable Sendable values | Caller-owned values, exclusive inout work where present; no shared state | Public protocol tests passed |
| WASM | Same source/storage/conformance | Same ownership, no conditional isolation | Not executed in this task |
| Embedded | Same source/storage/conformance | Same ownership, no conditional isolation | Not executed in this task |

### Selected qualification (2026-10-05)
Swift 6.4.0 release, arm64 macOS 27.0.1: actual canonical SwiftMechanics module and test products compiled/linked; the selected public service suite passed within the six-suite, 20-test run (0.013 s test execution). Tests own analytic success, failure and original physical identities. No whole-runtime, minimum macOS 13, WASM/Embedded or performance qualification follows. Full parent requirement families remain open.
