# MechanicsMechanismsTests

## Purpose and Scope
Behavioral IM16 evidence; parent [module](../../Sources/SwiftMechanics/Physics/Mechanisms/DESIGN.md); no children.

## Responsibilities and Boundaries
Independent physical oracles for constrained mass dynamics, affine invariant evolution, engagement and connected wake. Root owns registration/profile execution.

## Related Designs
[ConstrainedDynamics](../../Sources/SwiftMechanics/Physics/Mechanisms/ConstrainedDynamics/DESIGN.md), [AffineEvolution](../../Sources/SwiftMechanics/Physics/Mechanisms/AffineEvolution/DESIGN.md), [AcceptedTransitions](../../Sources/SwiftMechanics/Physics/Mechanisms/AcceptedTransitions/DESIGN.md), [ConnectedSleep](../../Sources/SwiftMechanics/Physics/Mechanisms/ConnectedSleep/DESIGN.md) own contracts.

## Architecture
```text
real compiled tree + mass + original rows -> actual services -> independent physical oracle
```

## Contracts and Invariants
No supplier fake mass, scalar animation, hidden projection or topology-disable success. Nonunit scale, redundancy, invalid input and accepted prefix remain observable.

## Verification and Change Impact
Tests are unexecuted until root registers frozen source and executes the actual Native/profile graph. Scope remains admitted affine scalar mechanisms and one direct-root spatial leaf break. General loops/subtree release/free-manifold evolution remain outside the admitted subset. Required Runtime topology replacement is qualified separately; these mechanics conservation and combined tests remain unexecuted.

Actual unexecuted source fixtures now contain 16 tests: ConstrainedDynamicsTests(4), AffineEvolutionTests(3), AcceptedTransitionTests(2), ConnectedSleepTests(2), MechanismFailureTests(2), TransmissionReactionTests(1), DetachedLeafTests(2). They use real compiled spherical-inertia shaft bodies, nonunit S=[2,3], T=5, E=7, independent analytic gear acceleration/reaction and moving-lock momentum/energy, actual Integration rejection/replay, work-authority counterexample and true joint removal/free 7/6 target layout. Atomic threshold break, actual owner replacement, original RNG/global sequence, target checkpoint/replay and repeated-source rejection are implemented against root-qualified Runtime replacement 37b8816. None of these tests have run yet.

Root AF17 qualification: Sixteen actual Native cases pass in `.build/af17-integrated-native.log`. Public profile execution belongs to FoundationVerification and covers its selected operations, not this whole test target on WASM. Full requirement gaps remain with the parent module.
