# Motor mechanical law

## Purpose and Scope
Parent: [owner](../DESIGN.md). Children: none. Add one independent constitutive law inside the existing SwiftMechanics module. No new module, automatic evolution or broad requirement-family completion.

## Responsibilities and Boundaries
Exact scalar DC electrical evolution L*iDot=U-K*w-R*i with voltage and shaft speed held throughout the interval. Report endpoint and mean current, mean torque K*meanCurrent-b*w, source work U*integral(i), copper loss R*integral(i^2), shaft work (K*w*integral(i)-b*w^2*dt), viscous loss and magnetic storage change. R=0 polynomial solution and stable small-R entire functions preserve the same equation. No clipping or unqualified joint integration.

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
Exact scalar DC electrical evolution L*iDot=U-K*w-R*i with voltage and shaft speed held throughout the interval. Report endpoint and mean current, mean torque K*meanCurrent-b*w, source work U*integral(i), copper loss R*integral(i^2), shaft work (K*w*integral(i)-b*w^2*dt), viscous loss and magnetic storage change. R=0 polynomial solution and stable small-R entire functions preserve the same equation. No clipping or unqualified joint integration.
Failures use ActuationError. Exact selected equations, original energy and force derivatives are acceptance evidence; finite output alone is insufficient.

## State, Ownership, and Lifecycle
No arrays, dynamic loops, callbacks or shared mutable storage. Constant scalar/vector footprint. Constructors reject nonfinite parameters and invalid admitted laws; operation arithmetic has explicit numerical failures. Operations reject outside envelopes and nonfinite arithmetic before issuing a result. All public values are immutable Sendable; protocol operations are witness requirements. Native/WASM/Embedded use the same source and ownership. Target math uses formal platform imports, not a new C target. No unsupported callable API is added. A fixed 16-term series is used only for |z|<0.125; evaluation is bounded. Law-bound immutable history preserves the input on failure. Exclusive inout supplier work charges/reserves before evaluation, with cancellation and capacity propagated.

## Verification and Change Impact
Analytic equations, state composition, constitutive derivative, energy / power, frame covariance where applicable, invalid parameters, envelopes, nonfinite output, cancellation and work exhaustion are tested through the public protocol. Direct clients recheck after contract changes. No WASM, Embedded, minimum OS or performance claim follows from Native tests. Parent indexes reference this design without duplicating it.

### Units and ownership
Time in s, inductance in H, resistance in ohm, current in A, voltage in V, shaft speed in rad/s, reciprocal constant in Nm/A (=V s/rad), damping in Nm s/rad. Work and losses in J. The voltage/speed and exact law identity stay fixed over each step.

| Profile | Law/history/response storage | Mutation and release | Evidence |
|---|---|---|---|
| Native | Immutable Sendable values | Caller-owned values, exclusive inout work where present; no shared state | Public protocol tests passed |
| WASM | Same source/storage/conformance | Same ownership, no conditional isolation | Not executed in this task |
| Embedded | Same source/storage/conformance | Same ownership, no conditional isolation | Not executed in this task |

### Selected qualification (2026-10-05)
Swift 6.4.0 release, arm64 macOS 27.0.1: actual canonical SwiftMechanics module and test products compiled/linked; the selected public service suite passed within the six-suite, 20-test run (0.013 s test execution). Tests own analytic success, failure and original physical identities. No whole-runtime, minimum macOS 13, WASM/Embedded or performance qualification follows. Full parent requirement families remain open.
