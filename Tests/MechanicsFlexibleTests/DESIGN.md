# MechanicsFlexibleTests

## Purpose and Scope
Native behavioral proof for initial tetrahedral IM19 producer. Parent [package](../../DESIGN.md); no children.

## Responsibilities and Boundaries
Own analytical element, conservation, objectivity, refinement and typed failure fixtures. Root owns exact-profile composition and commits.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Mesh](../../Sources/MechanicsFlexible/Mesh/DESIGN.md) | depends on | Validation/refinement | Identity/geometry | Closed tetra domain |
| [Tetrahedra](../../Sources/MechanicsFlexible/Tetrahedra/DESIGN.md) | depends on | Force/energy/tangent/mass | Physical evidence | No general family qualification |

## Architecture
```text
independent continuum/linear tetra equations -> expected nodal response
public protocol calls -> assembled evidence -> analytic and boundary comparison
```

## Contracts and Invariants
Fixtures use actual Model provenance and Materials polynomial law, with original energy/force directional differences and exact reference mass. No superficial existence tests.

## Failure, Concurrency, and Constraints
Operation-local inputs/work, no shared mutable test storage. Timeout180 / private .build/flexible-kernels.

## Verification and Change Impact
Patch/objectivity/energy-gradient/tangent/null modes/mass/damping/refinement and geometry/material/layout/resource/cancellation failures. Evidence is specific to this element profile.

Native completion evidence: timeout180 `swift test --build-path .build/flexible-kernels --filter 'TetrahedronPhysicsTests|FlexibleFailureTests'` exited 0 with nine tests passing. After final-publication cancellation and frame-mismatch coverage were added, the four affected FlexibleFailureTests passed in one targeted timeout180 run. The late cancellation fixture uses Mutex on the actual macOS 27 host and carries its required macOS 15 availability annotation. Root owns separate exact-profile composition. No broader element-family or target claim follows from these results.

Metadata-budget repair evidence: the five affected FlexibleFailureTests passed in the timeout180 targeted run recorded in `.build/flexible-kernels-metadata.log`. A 10,000-byte common-prefix material-key input with a 200-unit arithmetic budget fails during admission for both material lookup and duplicate checks. Borrowed UTF-8 iteration is charged before each advance; the late publication-cancellation fixture also remains green after these additional checkpoints. Physical equations and the five prior physics-test proof subjects are unchanged.
