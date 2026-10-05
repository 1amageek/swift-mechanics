# RegularizedYieldDamper

## Purpose and Scope
Parent [owner](../DESIGN.md); children none. Own one selected constitutive service within SwiftMechanics. Requirement portion FL-002/FL-008, not full family closure.

## Responsibilities and Boundaries
Own original physical constitutive evaluation and its domain, derivatives and energy/power. Caller owns placement, calibration, mechanical port coupling and accepted Runtime publication; this task does not register a Runtime contributor.

## Related Designs
- Parent [owner](../DESIGN.md): child composition; no broader capability inherited.
- Depends on [ForcePorts](../ForcePorts/DESIGN.md) LoadError/LoadWork and [PassiveLaws](../PassiveLaws/DESIGN.md) public scalar quantities; suppliers remain read-only.
- Used by [public tests](../../../../../Tests/MechanicsNineAdditionalTests/DESIGN.md): actual protocol behavior and failure evidence.

## Architecture
```text
immutable law + caller sample + exclusive work where required
 -> public protocol requirement -> checked constitutive operation
 -> immutable response, original energy/power and explicit derivatives
```

## Contracts and Invariants
Papanastasiou-type scalar mechanical regularization of a Bingham yield dashpot: F=-yield*(1-exp(-abs(v)/regularizationSpeed))*sign(v)-c*v; dF/dv=-yield/regularizationSpeed*exp(-abs(v)/regularizationSpeed)-c. expm1 avoids near-zero loss; zero force at rest and finite rest tangent. Passivity by -F*v>=0. This is a calibrated scalar damper, not a CFD rheology or exact static yield constraint.

Scalar coordinates use ScalarCoordinateKind (m/N or rad/conjugate torque); rates use coordinate/s. Rest/regularization/envelopes use the same coordinate units. Rate coefficient units are chosen to produce conjugate effort. Material stress is Pa, energy J/m^3, rate 1/s, power W/m^3. All arithmetic results must be representable; underflow in transcendental asymptotes is ordinary floating point behavior, nonfinite outputs are typed failure. LoadError with caller-owned exclusive inout LoadWork; resource counters may advance on failure. Success must never replace input/calibration with defaults.

## State, Ownership, and Lifecycle
Immutable Sendable laws/results; evaluators retain no cache. Only caller-exclusive value work counters mutate. No target-dependent shared storage, locks, Sendable refinement, unsafe pointer or isolation bypass. Input arrays, where used, remain immutable COW-backed ownership; no view escapes or intermediate evaluation arrays.

## Failure, Concurrency, and Constraints
Explicit invalid law/input, outside domain, arithmetic overflow, cancellation/work/capacity where applicable. No asynchronous I/O or callback except caller cancellation check before publication. Operations preserve laws and physical inputs on failure. Native/WASM/Embedded have identical value ownership/protocol contracts; only Native is qualified by this task.

## Verification and Change Impact
RegularizedYieldDamperTests independently verifies analytic success, derivative/one-sided behavior, potential gradient or original power, zero/boundary cases and invalid/domain/arithmetic/resource refusal as applicable. Changed service affects its direct consumers only; whole Runtime, flexible assembler, minimum deployment target, WASM/Embedded and performance remain unqualified. [COMSOL non-Newtonian model reference](https://doc.comsol.com/6.4/doc/com.comsol.help.cfd/cfd_ug_fluidflow_single.06.085.html); scalar mechanical adaptation is explicitly defined here.

### Selected Native qualification (2026-10-05)
Pinned Swift 6.4.0 release on arm64 macOS27.0.1, canonical SwiftMechanics module and MechanicsNineAdditionalTests product compiled/linked. Final 50 public tests in nine concurrent suites passed, including near-zero signed table calibration regression. Forty-one source/test hashes match the frozen inventory. Build and test commands use Scripts/run_with_timeout.py (300s/60s); logs and frozen hashes live in `.build/nine-evidence`. Supplier Swift files are unchanged in the parent working snapshot. Native evidence applies to these selected constitutive services; whole Runtime/element acceptance, minimum macOS13, WASM/Embedded, performance and complete210 closure remain unqualified.

| Profile | Storage/isolation | Read/mutation/release | Evidence |
|---|---|---|---|
| Native | Immutable Sendable laws/results; caller-exclusive LoadWork value | Public protocol witnesses; only local workspace/value counters mutate; value/COW release by caller | Selected compile/link and behavioral runtime passed |
| WASM | Same source storage, Sendable and work isolation | Same requirements and value ownership; math adapters depend on WASILibc | Not compiled/executed by this task |
| Embedded | Same source storage, Sendable and work isolation | Same requirements and value ownership; no omitted lock/reference owner | Not compiled/executed by this task |
