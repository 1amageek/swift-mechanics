# MechanicsModelTests

## Purpose and Scope
Behavioral ownership of model identity/representation/body/layout records and analytic inertia (IM02). No graph compiler, dynamics or contact claims.

## Responsibilities and Boundaries
Independent closed-form oracles, invalid-input corpus, frame composition, representation replacement and q/v round-trip prove the corresponding component contracts.

## Related Designs
[Identity](../../Sources/MechanicsModel/Identity/DESIGN.md), [Representations](../../Sources/MechanicsModel/Representations/DESIGN.md), [Inertia](../../Sources/MechanicsModel/Inertia/DESIGN.md), [Bodies](../../Sources/MechanicsModel/Bodies/DESIGN.md), [Coordinates](../../Sources/MechanicsModel/Coordinates/DESIGN.md).

## Architecture
```text
explicit test policy -> production kernel/record -> independent expected physical quantity or typed rejection
```

## Contracts and Invariants
Each test owns local immutable fixtures. Analytic fixture precision uses a test policy, not an undocumented production default. No shared resource or state. Native test execution proves tested local paths only; WASM/Embedded execution belongs to the root verification program.

## Verification and Change Impact
Run timeout-wrapped swift test --build-path .build/model-records --filter MechanicsModelTests. Core numerical/frame assumptions and any changed component contract invalidate corresponding analytic/round-trip evidence.
