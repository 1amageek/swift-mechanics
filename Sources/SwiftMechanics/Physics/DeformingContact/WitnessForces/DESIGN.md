# WitnessForces

## Purpose and Scope
Own exact selected triangle/plane and directed nonadjacent vertex/triangle witnesses and nodal law-force transport. Parent: [MechanicsDeformingContact](../DESIGN.md). No children. Full FX009 remains owned after the selected initial handoff.

## Responsibilities and Boundaries
Collision owns analytic plane point queries; ContactLaws owns compliant normal/friction response. Rigid ContactResponse cannot supply a nodal mass chart and is not used as an implicit flexible solver.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Parent](../DESIGN.md) | parent | IM23 dispatch | Composition owner | Initial selected domain only |
| [Flexible](../../Flexible/DESIGN.md) | depends on | ValidatedTetrahedralMesh/NodalState | Actual nodes/material coordinates | Not cloth/cable |
| [Collision](../../Collision/DESIGN.md) | depends on | Required analytic point query | Plane geometry | No triangle producer assumption |
| [ContactLaws](../../ContactLaws/DESIGN.md) | depends on | Required initialHistory/evaluate | Law/friction authority | Root owns material-site identity extension |
| [Tests](../../../../../Tests/MechanicsDeformingContactTests/DESIGN.md) | verified by | Physical and invalid-input fixtures | Local evidence | Profiles root-owned |

## Architecture
```text
current triangles -> exact selected witness -> actual ContactLaws -> transpose nodal forces + physical evidence
```

## Contracts and Invariants
Triangle/plane selects a unique deepest vertex; ties are explicit ambiguous-feature failure. Self contact is directed vertex against a nonadjacent face with strictly interior orthogonal projection; shared-node pairs, edge/grazing/degenerate sites fail. This is a selected feature query, not exhaustive surface intersection/CCD certification. Same-body identity uses actual upstream material-site authority, never synthetic bodies. Angular resistance/cohesion/hard impact are unavailable. For self friction the target material point is lifted along its normal to the first vertex; normal-rate Jacobian and its transpose retain common-point torque and exact virtual power. Original gap/direction/barycentric/current epoch and physical force/power checks precede output.
All positions/gaps use meters, nodal velocities m/s, force N, moment N m, power W and times seconds in the identified mesh/query frame. Policy supplies physical residual/volume/area/interior tolerances; there is no guessed global epsilon.

## Runtime Flows
Count and checked resource preflight -> original input/epoch validation -> bounded non-inline local phases -> physical acceptance -> immutable output or typed failure. No retry follows unknown supplier work.

## State, Ownership, and Lifecycle
Immutable Sendable topology/snapshots/records/providers; mutable numerical/output workspace is exclusive operation-local inout. No shared cache, lock-held callback, target storage/conformance branch, unsafe memory or speculative publication exists. Input arrays retain COW backing; slices never outlive an owning record. Sources remain untouched.

## Failure, Concurrency, and Constraints
Caller-owned node/cell/face/contact/metadata bounds are checked before internal allocation. NumericalWork owns outer arithmetic/storage, CollisionWork and ContactWork separately own supplier work. Checked counts precede traversal/materialization. Failed supplier work is reported as unavailable when a witness fails without a trustworthy ledger; operation stops. Structural bounds do not claim measured allocator/COW/wall-time performance. Callable absent cloth/cable/general surface/impact/resistance paths have explicit incomplete markers and typed failure.

## Verification and Change Impact
Independent gap/projection, directed self contact, actual normal force and friction traction, common-point force/torque and arbitrary virtual velocity power, stale witness/epoch/history, unsupported edges/law, supplier failure/ledger replacement. Geometry/material-site identity changes invalidate witness/history consumers; force/Jacobian changes invalidate flexible coupling/evolution. Root registers actual files then owns exact selected Native/WASM/Embedded execution.

Query admission rechecks the CURRENT caller node/cell/face policy and charges bounded lookup traversal before triangle selection. Body/frame/collider/representation metadata is UTF-8 bounded before semantic comparisons, including supplier-returned geometry. A surface built under a larger prior policy does not grant a larger query budget. Exact immutable surface owner association rejects foreign same-revision meshes.

For a target face with u=p1-p0, v=p2-p0, n=(u cross v)/A, the instantaneous lifted material point is sum(b_i p_i)+d*n, where d is the current directed separation held fixed in that contact's virtual transport. Normal rate is `(I-n*nT)*(uDot cross v+u cross vDot)/A`. The transpose correction for force F is `t=(d/A)*(I-n*nT)*F`, with node1 += v cross t, node2 += t cross u, node0 -= both. This transports translational friction at the common spatial point without adding an unrepresented nodal angular DOF or discarding penetrated-contact moment. Tests compare the actual nodal moment, rotated physical result and central derivative of this independently constructed lifted point. A stationary analytic plane receives the full common-point reaction wrench about the identified frame origin; moving obstacles are not represented by this entry point. Current obstacle equality and full nodal snapshot equality reject stale query outputs before law evaluation.
