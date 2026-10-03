# MaterialGeometry

## Purpose and Scope
Own actual oriented Tet4 boundary extraction and current nodal surface/material-coordinate updates. Parent: [MechanicsDeformingContact](../DESIGN.md). No children. Full FX009 remains owned after the selected initial handoff.

## Responsibilities and Boundaries
Flexible owns validated volume topology/material assignments; this child owns only derived boundary faces and current surface admission. Cloth/cable topology and continuous swept collision remain full FX009 obligations.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Parent](../DESIGN.md) | parent | IM23 dispatch | Composition owner | Initial selected domain only |
| [Flexible](../../MechanicsFlexible/DESIGN.md) | depends on | ValidatedTetrahedralMesh/NodalState | Actual nodes/material coordinates | Not cloth/cable |
| [Collision](../../MechanicsCollision/DESIGN.md) | depends on | Required analytic point query | Plane geometry | No triangle producer assumption |
| [ContactLaws](../../MechanicsContactLaws/DESIGN.md) | depends on | Required initialHistory/evaluate | Law/friction authority | Root owns material-site identity extension |
| [Tests](../../../Tests/MechanicsDeformingContactTests/DESIGN.md) | verified by | Physical and invalid-input fixtures | Local evidence | Profiles root-owned |

## Architecture
```text
validated Tet4 -> oriented boundary topology -> actual NodalState -> identified current triangles
```

## Contracts and Invariants
Positive Tet4 orientation uses outward local faces; paired identified interior faces cancel, nonmanifold or inconsistent orientation fails. Material sites retain cell/opposite-face and barycentric coordinates through current deformation. Current frame/mesh/node order, positive volume and nondegenerate triangle admission are checked before publication. Geometry epoch is explicit; changing physical positions or velocities without increasing epoch fails against supplied previous snapshot. Immutable snapshots retain source topology and node arrays.
All positions/gaps use meters, nodal velocities m/s, force N, moment N m, power W and times seconds in the identified mesh/query frame. Policy supplies physical residual/volume/area/interior tolerances; there is no guessed global epsilon.

## Runtime Flows
Count and checked resource preflight -> original input/epoch validation -> bounded non-inline local phases -> physical acceptance -> immutable output or typed failure. No retry follows unknown supplier work.

## State, Ownership, and Lifecycle
Immutable Sendable topology/snapshots/records/providers; mutable numerical/output workspace is exclusive operation-local inout. No shared cache, lock-held callback, target storage/conformance branch, unsafe memory or speculative publication exists. Input arrays retain COW backing; slices never outlive an owning record. Sources remain untouched.

## Failure, Concurrency, and Constraints
Caller-owned node/cell/face/contact/metadata bounds are checked before internal allocation. NumericalWork owns outer arithmetic/storage, CollisionWork and ContactWork separately own supplier work. Checked counts precede traversal/materialization. Failed supplier work is reported as unavailable when a witness fails without a trustworthy ledger; operation stops. Structural bounds do not claim measured allocator/COW/wall-time performance. Callable absent cloth/cable/general surface/impact/resistance paths have explicit incomplete markers and typed failure.

## Verification and Change Impact
Direct material-point queries reuse current-policy bounded snapshot admission before feature lookup. Every geometry result has a final cancellation gate; prior extraction policy cannot bypass a smaller current query cell/face/metadata limit.
Independent outward normals/interior-face elimination, affine material interpolation, rotated/deformed geometry, refinement boundary equivalence, stale epochs/layout/inversion/capacity/cancellation. Geometry/material-site identity changes invalidate witness/history consumers; force/Jacobian changes invalidate flexible coupling/evolution. Root registers actual files then owns exact selected Native/WASM/Embedded execution.

Current surface authority is an immutable final Sendable MaterialSurface owner. Previous/current witnesses and transaction states must share that exact owner; constructing another validated mesh under reused revisions cannot inherit authority. Independent states may share one owner. Current-operation policy re-admits node/cell/face counts and bounded metadata before any lookup or semantic comparison; lookup bounds are charged before the borrowed traversal. No persistent global identity cache is used.
