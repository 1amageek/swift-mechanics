# Compilation Records

## Purpose and Scope
Own immutable mechanical compile input, body/joint records, layout, report, structural sparsity and compiled model (MD-004/008 initial tree domain). Parent: [MechanicsCompiler](../DESIGN.md). No children.

## Responsibilities and Boundaries
Retain complete BodyRecord2D/3D and JointRecord data, explicit coordinate authority, initial state and capability requirements. Publish the actual canonical tree/layout and selected kinematic equations. Runtime state evolution, native serialization and physical dynamics remain consumers.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Model](../../MechanicsModel/DESIGN.md) | depends on | Immutable body/inertia/representation values | Preserve all source semantics | Compiler does not derive inertia from display geometry |
| [Joints](../../MechanicsJoints/DESIGN.md) | depends on | Tree q/v/layout and motion | Actual topology and initial-chart proof | Single-root tree only |
| [Validation](../Validation/DESIGN.md) | used by | Descriptor ownership | Transactional publication | Compiled model initializer is internal |
| [Revisions](../Revisions/DESIGN.md) | used by | Public reconstructable descriptor/layout | Change/migration proof | Model identity plus revision identifies state |

## Architecture
```text
MechanicalDescriptor -> complete body/joint records + authority + initial KinematicState
validated tree -> stable layout + six-world-component structural CSR pattern
validated descriptor + report + manifest + cache dependencies -> CompiledMechanicalModel
```

## Contracts and Invariants
Bodies are homogeneous planar or spatial; records retain modes, body/world initial poses, all independent representations and inertia/provenance. Free root/joint coordinates declare dynamicState or prescribedMotion; fixed coordinates declare fixed. Input q/v use canonical breadth-first tree order with sibling joint IDs ordered by Swift String comparison, consistent with canonical-equivalent ID equality; joints and bodies supplied in arbitrary array order compile deterministically. Quaternion sign reversal denotes the same rotation. Initial body poses must match evaluated tree poses within explicit SI translation/radian rotation policy; source transforms are preserved, never overwritten.

Report counts body/frame/joint/q/v/extension records and structural joint/root tree constraint rank (excluding prescribed-coordinate, body-mode, closure, force and actuation equations). Rank is ambient body velocity dimension (3 planar/6 spatial) minus validated tree v count, certified by regular local subspaces and unique child ownership at the admitted initial configuration. Quaternion normalization constraints are chart invariants, not counted as mechanical velocity constraints. Closed loops fail before report creation. Selected equations are qdot=N(q)v, velocity=J*v+prescribedDrift and acceleration=J*vdot+bias; no mass matrix, force/contact or integrator claim is made.

Structural sparsity uses six world geometric rows per body (angular xyz, linear xyz) and stable generalized velocity columns. Each body row conservatively includes root and ancestor-joint columns; declared entries may numerically vanish. Zero-column fixed trees have valid empty patterns, not fabricated numeric matrices. Pattern values/rank/force results are not invented. All public output data is reconstructable through public input contracts. Compiled model/state handles own immutable Sendable values and no mutable singleton registry.

## State, Ownership, and Lifecycle
Compiled values own source descriptor, validated KinematicTree, initial snapshot and array storage via Swift value/COW lifetime. State handles retain model identity/revision and immutable KinematicState; sharing compiled values never shares mutable rollout arrays. Numeric/state mutation and shutdown belong to runtime IM08.

## Verification and Change Impact
[Test owner](../../../Tests/MechanicsCompilerTests/DESIGN.md) checks canonical order/count/rank/pattern against independent tree counts and actual Jacobian columns, source preservation/reconstruction and independent state handles. Layout/chart changes invalidate runtime/exchange/CAD consumers.
