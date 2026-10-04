# MechanicsGranularTests

## Purpose and Scope
Parent [module](../../Sources/SwiftMechanics/Physics/Granular/DESIGN.md). Behavioral qualification pending; root owns all executions.

## Responsibilities and Boundaries
Own independent physical equations and failure/replay evidence for the admitted sphere/plane CPU domain.

## Related Designs
[ParticleState](../../Sources/SwiftMechanics/Physics/Granular/ParticleState/DESIGN.md), [NeighborContacts](../../Sources/SwiftMechanics/Physics/Granular/NeighborContacts/DESIGN.md), [ParticleEvolution](../../Sources/SwiftMechanics/Physics/Granular/ParticleEvolution/DESIGN.md), [Replay](../../Sources/SwiftMechanics/Physics/Granular/Replay/DESIGN.md).

## Architecture
```text
real public services -> accepted state/evidence -> independent impulse/work/replay assertions
```

## Contracts and Invariants
Collision/settling/shear use actual analytic geometry and compliant material law. Replay compares all used history/RNG state, not particle positions alone. No test shared state or mock successful solver.

## Failure, Concurrency, and Constraints
Local buffers/ledgers; tests cover capacity before publication, cancellation, stale checkpoint, incomplete shape/loss/transport and supplier domain/work failure. Root timeout-qualified Native/WASM/Embedded checks own platform evidence.

## Verification and Change Impact
FD/time refinement is independent evidence only; no numerical FD production. Test success scope does not qualify full EX-004, exact Coulomb, dynamic rigid coupling or Runtime wire serialization.

Root AF17 qualification: Nineteen actual Native cases pass in `.build/af17-integrated-native.log`. Public profile execution belongs to FoundationVerification and covers its selected operations, not this whole test target on WASM. Full requirement gaps remain with the parent module.
