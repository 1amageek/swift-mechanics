# Identity

## Purpose and Scope
Own immutable mechanical entity IDs and model revision references (MD-001 records). Parent: [MechanicsModel](../DESIGN.md). No children.

## Responsibilities and Boundaries
IDs distinguish body instances, frames, joints, colliders, materials, loads, actuators and sensors. An external CAD part identity never substitutes for a body instance ID. Global uniqueness, dangling-reference checks and compiler transactions belong to IM07.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Model](../DESIGN.md) | parent | Module composition | Registers this owner | Graph validation is downstream |
| [Representations](../Representations/DESIGN.md) | used by | Entity and revision values | Independent occurrence and source identities | Source IDs are not mechanical IDs |

## Architecture
```text
EntityKind + nonempty key -> EntityID -> ModelReference(revision)
```

## Contracts and Invariants
EntityID equality includes kind and key. Empty keys fail with ModelError. Revision references are immutable and reject a caller-supplied mismatched revision. Keys have no SI unit or frame. Values own their strings for their entire lifetime; no allocation of globally unique IDs or mutable registry is implied.

## Verification and Change Impact
Test owner: [MechanicsModelTests](../../../../../Tests/MechanicsModelTests/DESIGN.md).

RecordTests proves kind/key distinction, repeated-source instance separation, invalid keys and revision mismatch. Compiler and representations must recheck any key/revision contract change. No global graph validity is claimed.
