# Capstan mechanical law

## Purpose and Scope
Parent: [owner](../DESIGN.md). Children: none. Add one independent constitutive law inside the existing SwiftMechanics module. No new module, automatic evolution or broad requirement-family completion.

## Responsibilities and Boundaries
Stationary circular guide, caller wrap radians, static>=kinetic friction and positive cable tensions. Solid sticking accepts only |log(Tout/Tin)|<=muStatic*theta and returns caller tensions; sliding tension ratio exp(muKinetic*theta), signed tension difference opposes caller slip, heat=abs(Tout-Tin)*abs(speed). Guide geometry, cable compliance and moving pulley work belong to other owners.

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
Stationary circular guide, caller wrap radians, static>=kinetic friction and positive cable tensions. Solid sticking accepts only |log(Tout/Tin)|<=muStatic*theta and returns caller tensions; sliding tension ratio exp(muKinetic*theta), signed tension difference opposes caller slip, heat=abs(Tout-Tin)*abs(speed). Guide geometry, cable compliance and moving pulley work belong to other owners.
Failures use ActuationError. Exact selected equations, original energy and force derivatives are acceptance evidence; finite output alone is insufficient.

## State, Ownership, and Lifecycle
No arrays, dynamic loops, callbacks or shared mutable storage. Constant scalar/vector footprint. Constructors reject nonfinite parameters and invalid admitted laws; operation arithmetic has explicit numerical failures. Operations reject outside envelopes and nonfinite arithmetic before issuing a result. All public values are immutable Sendable; protocol operations are witness requirements. Native/WASM/Embedded use the same source and ownership. Target math uses formal platform imports, not a new C target. No unsupported callable API is added. Exclusive inout supplier work charges/reserves before evaluation, with cancellation and capacity propagated.

## Verification and Change Impact
Analytic equations, state composition, constitutive derivative, energy / power, frame covariance where applicable, invalid parameters, envelopes, nonfinite output, cancellation and work exhaustion are tested through the public protocol. Direct clients recheck after contract changes. No WASM, Embedded, minimum OS or performance claim follows from Native tests. Parent indexes reference this design without duplicating it.

### Units and ownership
Wrap in rad, tension in N, travel speed in m/s and dissipated power in W. Upstream/downstream are fixed by positive travel. Cable friction=upstream-downstream tension, so boundary tension plus guide friction vanishes; sliding friction times travel speed plus heat is zero. Static tensions are supplied independently, not determined by a friction law.

| Profile | Law/history/response storage | Mutation and release | Evidence |
|---|---|---|---|
| Native | Immutable Sendable values | Caller-owned values, exclusive inout work where present; no shared state | Public protocol tests passed |
| WASM | Same source/storage/conformance | Same ownership, no conditional isolation | Not executed in this task |
| Embedded | Same source/storage/conformance | Same ownership, no conditional isolation | Not executed in this task |

### Selected qualification (2026-10-05)
Swift 6.4.0 release, arm64 macOS 27.0.1: actual canonical SwiftMechanics module and test products compiled/linked; the selected public service suite passed within the six-suite, 20-test run (0.013 s test execution). Tests own analytic success, failure and original physical identities. No whole-runtime, minimum macOS 13, WASM/Embedded or performance qualification follows. Full parent requirement families remain open.
