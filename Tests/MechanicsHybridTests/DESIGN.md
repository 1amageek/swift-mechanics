# Hybrid Behavioral Proof

## Purpose and Scope
Own local evidence for [ImpactPorts](../../Sources/MechanicsHybrid/ImpactPorts/DESIGN.md), [NormalImpulse](../../Sources/MechanicsHybrid/NormalImpulse/DESIGN.md), [EventEvolution](../../Sources/MechanicsHybrid/EventEvolution/DESIGN.md) and [Continuation](../../Sources/MechanicsHybrid/Continuation/DESIGN.md). Parent: [Hybrid](../../Sources/MechanicsHybrid/DESIGN.md). No children.

## Responsibilities and Boundaries
Actual Dynamics/Joints mass/point paths, Collision witnesses, ContactLaws restitution, isolated Runtime/Integration queries and outer accepted transactions are tested against independently computed impulse/bounce values. Root owns accumulated graph and exact profiles.

## Related Designs
The four component designs above own the tested contracts; this owner stores only local evidence.

## Architecture
```text
actual identified mass/witness/law -> impulse residual/energy
actual Runtime state -> isolated reintegration/root -> accepted bounce -> real restart bytes
```

## Contracts and Invariants
Each fixture owns all state. No shared globals or expected values derived from the production jump algorithm. Rejection/failure checks actual complete accepted checkpoints.

## Failure, Concurrency, and Constraints
Timeout-wrapped Native proof follows root registration/stable cohort. Invalid geometry/mode/history, cancellation, root/event/query/resource and unavailable supplier-work failures remain explicit.

## Verification and Change Impact
Only admitted frictionless independent normal modes and pure prismatic sphere-plane flight are qualified. Coupled impact, friction, resting stacks, general rotational CCD, constraint/wake reconciliation and arbitrary provider domains remain IM24 obligations.

Actual sources: HybridFixtures, HybridImpulseTests (6 tests) and HybridEvolutionTests (6 tests). The proof executes required service witnesses, actual compiled model/analytic collision/mass/Runtime/Integration paths, independent normal impulse conservation/loss, sorted independent modes and coupled rejection, two-bounce restart, failed cascade prefix, corrupt/truncated continuation/checkpoint rollback, cancellation and physical/query budgets. Native and exact-profile results are pending root registration/cohort execution at this snapshot.

Root coherent review counterexamples add HybridContinuationTests (3 tests): exact final signature/schema/record capacity boundary; excessive scale count; fixed+text environment preflight and long UTF8 asset; foreign event ID/provider/geometry histories rejected by record generation itself; valid carry-forward remains accepted. These close admission/storage/history authority findings; source preflight establishes ordering, with no allocator measurement claim. Native total is now 15 tests / 3 suites, pending root execution.
