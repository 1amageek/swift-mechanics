# Conforming Tet4 Red Refinement

## Purpose and Scope
Own AF35.10 selected FX-012 uniform conforming Tet4 red refinement, material/source/boundary metadata and explicit nodal interpolation/concentrated-load transfer. Parent: [Flexible](../DESIGN.md). No children. Assigned local behavioral qualification: [RefinementQualification](../../../../../Verification/RefinementQualification/DESIGN.md). Root retains graph registration, cumulative integration and Git; target proofs remain attributable to their executed receipts.

## Responsibilities and Boundaries
Own original physical Tet4 conformity admission, global original-edge midpoint indexing, eight-child connectivity, deterministic caller-declared ID allocation, original-face subdivision ledgers and prolongation/load proposals. Reuse the public qualified Mesh validator for generated reference-cell quality/gradients. This is mechanics mesh refinement, not CAD geometry authority, time evolution, constitutive stress recovery or a convergence proof.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Flexible](../DESIGN.md) | parent | FX-012 responsibility | Composition | Full convergence and general constraints remain separate |
| [Mesh](../Mesh/DESIGN.md) | depends on | ValidatedTetrahedralMesh, TetrahedralMeshValidating.validate, MeshAdmission | Original physical values and generated quality | Existing centroid refinement and validator do not certify inter-cell conformity |
| [Tetrahedra](../Tetrahedra/DESIGN.md) | depends on | Public NodalState and positive energy-gradient conventions | Cartesian nodal layout | No internal helper or field-output supplier |
| [Model](../../../Modeling/Model/DESIGN.md) | depends on | EntityID/SourceProvenance | Physical assignment | Boundary group is metadata, not an imposed constraint |
| [Core](../../../Mathematics/Core/Geometry/DESIGN.md) | depends on | Public Vector3/Matrix3 | Consumer-owned geometry | Finite checked arithmetic |
| [Numerics](../../../Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | NumericalWork | Bounded workspace and operations | No fabricated constitutive work |

## Architecture
```text
qualified physical Tet4 source/state owner
 -> original face incidence + pairwise convex intersection conformity admission
 -> immutable layout: sorted unique original-node-pair edges + original boundary faces
 -> caller boundary assignments + explicit diagonal / IDs / concentrated loads
 -> midpoint coordinates and prolongation -> eight oriented children per original cell
 -> actual public Mesh.validate -> reference/current volume and face subdivision acceptance
 -> exact original-node injection dual load mapping -> immutable proposal and ledgers
```

## Contracts and Invariants
Every original cell is refined, so no selective hanging face is introduced. Global edge keys are sorted pairs of original UInt64 node IDs; each unique key receives exactly one midpoint. Old nodes/order/IDs/reference coordinates/boundary groups remain exact. Sorted edge order assigns midpoint IDs as caller firstNodeID+edgeOrdinal. Source cell order and explicit child ordinal assign child IDs as caller firstCellID+8*parentOrdinal+childOrdinal. Checked UInt64 ranges/collision admission precede generated geometry. Mesh revision and geometry epoch strictly increase; frame, mesh source, material objects and each child material/source/parent identity are retained.

Four corner tetrahedra plus four tetrahedra partition the central octahedron. Caller selects lexicographic opposite-edge diagonal or shortest reference diagonal with lexicographic tie break. Positive orientation is determined from actual generated coordinates; each child has original volume/8 and all children sum to original volume within explicit tolerances. Generated geometry passes the actual public Mesh.validate minimum-volume/inverse-quality contract. Current coordinates/velocities use the same 0.5/0.5 original-edge prolongation; current child volumes satisfy the same partition relation.

Original face incidence permits one outward boundary face or two oppositely oriented shared faces. Bounded clipping of each original tetra edge against every other tetra's outward half-spaces yields intersection endpoints; all must lie in their identified shared simplex, otherwise overlap/nonconforming geometry fails. This includes hanging vertices/edges/faces and unshared coincident boundaries, within caller-selected length/barycentric tolerances. Every original boundary face maps to exactly four outward child faces; every original interior face maps to four paired child faces. Actual oriented child area vectors equal one quarter of the original and sum to the original, with positive normal alignment and separate square-meter area tolerance. Child face incidence and original material-face partition are accepted before publication.

Boundary assignments are explicit caller-owned arrays aligned with the issued layout: one optional group for every new midpoint and every original outward boundary face. Group absence is an explicit caller selection, never inferred from endpoint labels. Original node labels stay exact, and all four child boundary faces retain their supplied parent-face group and assignment owner. No physical constraint or traction is inferred from metadata.

The admitted load policy is concentrated loads remaining on exact original nodes. P=[I; edge midpoint rows] prolongs old Cartesian values; L=[I;0] maps concentrated old covectors, so P transpose L=I. New midpoint forces are explicitly zero under this selected injection-dual convention; they do not represent silently removed distributed loads. Original per-node covectors, total force/current moment and virtual power are accepted using retained old/current interpolated coordinates/velocities. Tractions, redistributed nodal loads and inferred constraints are callable explicit failures.

## Runtime Flows
Capacity/metadata/work preflight -> issue immutable conformity layout -> re-admit current bounds and identical topology tolerance -> explicit boundary/source/ID/load admission -> create midpoint and eight-child geometry -> supplier validation -> volume/face/material/source/quality acceptance -> concentrated-force dual/physical acceptance -> final cancellation -> immutable proposal. No retry or partial output escapes.

## State, Ownership, and Lifecycle
Immutable Sendable source/layout/results retain exact physical source owner, mesh/state/time/epoch, policies, assignment owner and mapping ledgers. Mutable edge insertion, face traversal, generated arrays and NumericalWork are exclusive operation-local/inout. No shared cache, unsafe pointer, platform branch or accepted-state mutation exists. COW at generated mesh/state output boundaries is intentional and included in storage reserves.

## Failure, Concurrency, and Constraints
Caller bounds original/output nodes/cells/edges/faces/metadata/scalars and selects geometry/volume/load tolerances. Checked count products, ID range addition and simultaneous original/generated/validator storage precede allocations. Topology is bounded quadratic cell/face work; each clipping/traversal/insertion block charges outer operations and checks cancellation. Supplier errors preserve their spent NumericalWork and remain typed; no supplier internal helper or mutable override is used. Invalid owner/revision/layout/frame/ID/assignment, topology/conformity/orientation/quality, unsupported mapping, overflow, nonfinite, exhaustion and cancellation fail explicitly.

## Verification and Change Impact
Assigned independent public fixtures fix shared-edge/two-cell conformity, all central diagonal choices, outward four-way boundary/material-interface subdivision, independent eight-child volume and inverse quality, affine/non-affine old Tet4 prolongation, concentrated dual force/moment/arbitrary virtual-power preservation, deterministic IDs/source/metadata, hanging/overlap/assignment/ID/budget/cancel failures and the same portable synchronous public path with separate Native actual Task cancellation. Target compile/link/runtime evidence remains separate and cannot follow from source preparation. Source-only work does not prove mesh convergence. New selective refinement, other cells, distributed traction/constraint transfer or nonlinear field recovery requires a separate contract and behavioral evidence.

Native registration preparation is parameterized by root's actual committed producer graph and its source/object/module receipt, not historical2363 or an assumed future source count. Add only unchanged20 Refinement primaries, emit the complete graph/module and verify original lower contracts. The unchanged qualification fixture helper requires macOS15; production remains13, with a separate literal15 support/test/public consumer of the exact current canonical module/allobjects. Root owns shared/canonical mutation, execution lease and registration; no production/fixture byte or oracle change is included. The qualification child owns detailed bindings and budgets. Portable parent remains incomplete.

### Actual committed1924 registration preparation
The actual base is commit c22ccf382442a552f55682b894e13f81555496b8 with the successful complete1924 source/object/module inventory. Preparation verifies each original source, object and metadata SHA before copying the20 unchanged production files and8 unchanged fixture files into an owner-private root stage. The existing private manifest41512ab307b3077a10c65b0fd073b96ea409b5a508b60737d3d939ba4253af13 remains the warm-cache authority; its known misplaced Support DESIGN exclusion has no Swift effect and is preserved separately from the corrected manifest. The committed shared manifest is exported exactly, then only the Refinement DESIGN exclusion is added. Root alone applies either candidate.

The original Articulated inventory stores absolute source paths and uses `object` for its original object path. Preparation normalizes those fields into relative source paths and `objectPath` only in a separate consumer record, preserving the original inventory bytes and SHA. This is metadata adaptation with no source or object substitution. Full1944 module and all20 added primaries must actually emit at macOS13 before the original macOS15 fixture consumer is compiled. Admission requires896MiB free before launch, the global floor remains768MiB, the allocated growth limit128MiB and local reaction margin16MiB. Jobs4,2s sampling and process-group deadlines remain unchanged. No compiler is authorized by preparation.

### Registered Native1944 evidence
Root executed the complete1944 canonical source graph composed from committed c22ccf382442a552f55682b894e13f81555496b8 base1924 and the unchanged Refinement20. The full module and all20 added primaries emitted at arm64-apple-macosx13.0; the original eight qualification sources compiled separately at arm64-apple-macosx15.0 and consumed one library linked from all1944 matching objects. The seven Native tests and same six public cases passed, preserving the independent topology, geometry, source, load, moment, virtual-work and failure oracles. Production and fixture bytes remained unchanged. Detailed source/module/object/link and resource attribution is owned by [RefinementQualification](../../../../../Verification/RefinementQualification/DESIGN.md#registered-native1944-execution-evidence). This evidence applies to the selected Native1944 path; ordinary/Embedded portability and general mesh convergence remain unproven.
