# Revisions, Invalidation and State Compatibility

## Purpose and Scope
Own model stamps, explicit change/invalidation diagnostics and compatible parameter-state migration (MD-007 initial immutable tree domain). Parent: [MechanicsCompiler](../DESIGN.md). No children.

## Responsibilities and Boundaries
Compare complete compiled descriptors, require monotonic revisions for updates, classify topology/parameter edits, invalidate only known cache dependencies, and preserve state only under explicit identical-kinematics migration. Planned runtime owns mutable caches and accepted-state transactions; no hidden automatic reset/remap.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Records](../CompilationRecords/DESIGN.md) | depends on | Immutable descriptor/layout/model | Compare source authority | Equal q/v counts alone do not imply compatible semantics |
| [Validation](../Validation/DESIGN.md) | depends on | Complete compiled validity | Recheck actual migrated state | New chart/state failures remain failures |
| [Implementation plan](../../../../../IMPLEMENTATION_PLAN.md) | used by | Model identity/revision and migration | Future runtime cache/state adoption | Runtime may add its own registered cache dependencies |

## Architecture
```text
old/new compiled models + explicit migration policy -> monotonic revision + classified edits
 -> dependency invalidation -> compatible preserve or explicit reset requirement
old state handle + target model + transition -> revalidated new stamped immutable state
```

## Contracts and Invariants
CompiledKinematicState construction consumes the immutable `_CompiledStateAdmission` issued only by CompiledMechanicalModel.makeState after actual target-tree validation. An explicit fileprivate token initializer seals generation across unrelated components of the shared SwiftMechanics module. Revision migration continues to use target.makeState rather than raw construction.

State stamp includes model identity and UInt64 revision; wrong identity/stale revision/counts fail. Each update uses a strictly newer revision, even if no parameter changed. Source-array reordering and canonical-equivalent Unicode spelling are canonicalized without changing coordinate meaning. Preservation also compares actual body/joint/range layout equality; equal total counts cannot hide a permutation. Topology includes body/frame/joint/anchor IDs/endpoints, root/world frame, body dimension and coordinate counts/authority. Geometry/chart changes (axes/pitch/anchor transforms/root pose), body mode changes and state schema changes prevent preserved-state migration; the policy reset explicitly requires construction from target initial state. Display/collision/inertia/source/material-extension parameter edits can preserve coordinates only when complete kinematic semantics/layout/authority match. Migration constructs a new stamp and runs the actual target tree at the old state's time/q/v/vdot/prescribed samples; old inputs remain unchanged.

Cache keys represent concrete compiled descriptor/motion/representation/layout/validation responsibilities. Dependency references own entity+parameter aspect; display changes invalidate display data only, inertia changes invalidate corresponding inertia data, joint parameter changes invalidate dependent descendant motion, and topology changes invalidate the entire known set. Future solver/runtime caches must register their own dependency contracts instead of relying on absent caches here. Returned invalidation is advisory immutable data; no cache is silently mutated.

## State, Ownership, and Lifecycle
All transition/state outputs are immutable Sendable values with COW-owned arrays. No global current revision, mutable shared registry or escaping borrow exists. Caller explicitly adopts a transition into its runtime/session owner.

## Failure, Concurrency, and Constraints
Unknown identity, nonmonotonic revision, mismatched transition, incompatible preserve request and failed target-state revalidation yield structured typed failure. Update comparisons run only over admitted bounded records/dependencies. External schema parameter edits with supplier-owned internal runtime state are not automatically state-compatible; runtime owns that additional migration obligation.

## Verification and Change Impact
[Test owner](../../../../../Tests/MechanicsCompilerTests/DESIGN.md) verifies stale/wrong model state rejection, topology reset requirement, preserved inertia/display edit, selective cache invalidation, incompatible axis/authority edit despite equal counts, monotonic revision and independent state values. Runtime/exchange/CAD consumers recheck stamp and migration rules.

### AR01 owner qualification
State handles receive only the makeState-issued token after actual tree evaluation; invalid coordinates cannot produce a handle. Integrated test, foreign-access refusal and public profile evidence are owned by [root integration](../../../../../DESIGN.md#ar01-integrated-qualification-2026-10-04) and [FoundationVerification](../../../../../Verification/FoundationVerification/DESIGN.md#ar01-public-profile-execution).
