# MechanicsPlanarTreeDerivativeTests

## Purpose and Scope
Parent: [package](../../DESIGN.md). Children: none. Own the new planar tree provider's independent physical and original-supplier directional oracles.

## Responsibilities and Boundaries
Exercise only `ExactPlanarTreeDifferentiator` through public `TreeDifferentiating`, public model constructors and the original `TreeKinematicsEvaluator`. These tests do not qualify planar dynamics, optimizer composition or full IM30.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Planar](../../Sources/SwiftMechanics/Analysis/Derivatives/TreeTangents/Planar/DESIGN.md) | depends on | TreeDifferentiating | Instantaneous world-frame derivatives | All admitted profiles require actual runtime evidence |

## Architecture
```text
public planar fixtures -> original primal central differences + exact hinge equations
                     -> public analytic direction -> independent comparison
```

## Contracts and Invariants
Compare every body translation, rotation matrix, actual motion, drift, nonzero-a bias, coordinate rate and geometric column. Fixed/floating branch fixtures contain revolute/prismatic/compound planar factors with nontrivial anchor offsets. Both prescribed anchors carry independent pose/motion directions. Exact hinge physics independently proves the nonzero-a bias subtraction. Failure tests assert typed refusal and charged work without primal state mutation. Scratch reuse must preserve prior immutable output.

## State, Ownership, and Lifecycle
Each test owns its fixtures, scratch and ledgers. No shared mutable state or serialized-suite assumption. Finite differences are test-only.

## Verification and Change Impact
Run the pinned Native focused target with a timeout after source freeze; root owns original public Native/WASM/Embedded/131072-byte qualification and target registration. Recheck these tests when the provider or admitted root/anchor/factor contract changes.

### Executed Native evidence
All 12 declarations in two suites passed on the pinned Swift 6.4.0 Native graph. The [provider design](../../Sources/SwiftMechanics/Analysis/Derivatives/TreeTangents/Planar/DESIGN.md#native-qualification) owns the exact receipt, source/object/link binding, timings and qualification limits. No unexecuted profile is inferred from these tests.
