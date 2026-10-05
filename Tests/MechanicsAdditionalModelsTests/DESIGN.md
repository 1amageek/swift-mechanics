# Additional mechanical model verification

## Purpose and Scope
Public protocol behavioral verification of six independent selected laws. Parent: [package](../../DESIGN.md). Children: none.

## Responsibilities and Boundaries
Test equations, actual immutable state evolution, finite derivatives and independent energy identities; do not certify automatic Runtime integration or complete requirement families.

## Related Designs
Each model owns its source DESIGN.md under Materials/MaxwellRelaxation, Actuation/SealedLiquid, Actuation/PolytropicGas, Actuation/ExactMotor, Transmissions/CapstanFriction and Dynamics/GyroscopicRotors.

## Architecture
```text
six isolated model suites (parallel) -> public protocol -> original equation / failure evidence
```

## Contracts and Invariants
No shared mutable fixture or external resources. Throwing failures, cancellation, bounds and scalar/vector behavior tested directly. Laws retain their own authority.

## Verification and Change Impact
Swift 6.4.0 release Native qualification uses a timed build and timed Swift Testing run. Evidence under .build/six-evidence; target profile and counts recorded after execution. WASM/Embedded unqualified here.

### Native evidence (2026-10-05)
Canonical command: pinned Swift 6.4.0 release, `swift build --build-path .build/six-native --build-tests -j 2`, bounded at 1200 s. Corrected build exited 0 in 760.96 s; an earlier build rejected missing explicit typed-throws annotations in the rotor Core adapters. `swift test --build-path .build/six-native --skip-build --disable-xctest --enable-swift-testing --filter 'MaxwellRelaxationTests|SealedLiquidTests|PolytropicGasTests|ExactMotorTests|CapstanFrictionTests|GyroscopicRotorTests' -j 2`, bounded at 60 s, exited 0 with 20 tests in six suites (0.013 s). Suites run concurrently, use the public module, and retain no shared mutable fixture. All 33 Swift source/test hashes match `.build/six-evidence/source-freeze.json`.

The first test invocation exceeded its 60 s startup bound; its sample shows SwiftPM TestRunner waiting for a per-product child. A diagnostic second invocation completed. This is an observed runner startup limitation, not a claim that its root cause was fixed or that startup duration is part of the 0.013 s test-execution time. Future focused invocations can select the supported hidden `--test-product MechanicsAdditionalModelsTests` option to avoid unrelated product startup. Evidence: `native-build-repair.log`, `native-tests.log`, `native-test-startup-sample.txt`, `native-tests-diagnostic.log` under `.build/six-evidence`.
