# ContactTransactions

## Purpose and Scope
Own immutable bounded accepted contact-history state and trial/accept/reject value transactions for downstream flexible evolution. Parent: [MechanicsDeformingContact](../DESIGN.md). No children. Full FX009 remains owned after the selected initial handoff.

## Responsibilities and Boundaries
Physical integration, hard impacts and Runtime publication belong to downstream owners. Accepting these records alone never certifies dynamics or an accepted nodal evolution.

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
accepted law state + current geometry -> trial forces/history -> explicit accept OR unchanged reject
```

## Contracts and Invariants
State binds physical body/frame, topology/material sites, accepted time and required contact history. Trial reads accepted records only; no hidden cache. Acceptance requires exact source association and explicit current snapshot binding; rejecting returns the original accepted state. Geometry epochs validate witnesses separately from material/topology law identity, so genuine nodal deformation preserves material friction history without treating stale witnesses as current. Unknown/missing required histories fail; initial registration is explicit. No externally published events or shared mutable state.
All positions/gaps use meters, nodal velocities m/s, force N, moment N m, power W and times seconds in the identified mesh/query frame. Policy supplies physical residual/volume/area/interior tolerances; there is no guessed global epsilon.

## Runtime Flows
Count and checked resource preflight -> original input/epoch validation -> bounded non-inline local phases -> physical acceptance -> immutable output or typed failure. No retry follows unknown supplier work.

## State, Ownership, and Lifecycle
Immutable Sendable topology/snapshots/records/providers; mutable numerical/output workspace is exclusive operation-local inout. No shared cache, lock-held callback, target storage/conformance branch, unsafe memory or speculative publication exists. Input arrays retain COW backing; slices never outlive an owning record. Sources remain untouched.

## Failure, Concurrency, and Constraints
Caller-owned node/cell/face/contact/metadata bounds are checked before internal allocation. NumericalWork owns outer arithmetic/storage, CollisionWork and ContactWork separately own supplier work. Checked counts precede traversal/materialization. Failed supplier work is reported as unavailable when a witness fails without a trustworthy ledger; operation stops. Structural bounds do not claim measured allocator/COW/wall-time performance. Callable absent cloth/cable/general surface/impact/resistance paths have explicit incomplete markers and typed failure.

## Verification and Change Impact
Root qualification checks cancellation after actual external initial-history evaluation, before publishing history/state. Supplier work remains observable; no accepted record is produced by that cancelled path.
Two independent states, trial rejection/history immutability, continuation through deformed geometry, stale trial/source/cancel/capacity and terminal failed supplier behavior. Geometry/material-site identity changes invalidate witness/history consumers; force/Jacobian changes invalidate flexible coupling/evolution. Root registers actual files then owns exact selected Native/WASM/Embedded execution.

ContactIdentity uses the proven optional ordered ContactMaterialSite payload. Site identity is topology-scoped (`node:<node ID>` and `face:<cell ID>:<opposite local node>`), not a changing current-position epoch; static obstacle sites are collider-scoped. Bodies retain genuine physical references, including identical body references for self contact. State/trial accept/reject uses exact immutable surface/source-state owner authority; different reconstructed surface/state owners are explicit incompatibilities even if revisions match. No binary checkpoint reconstruction or model migration API is declared.

Bindings are complete, nonempty and bounded before sorting; Swift String ordering is equality-consistent for canonical-equivalent identity keys. Every required contact is evaluated; missing/foreign/duplicate registration fails. Output retains at most c per-contact nodal force arrays plus one accumulated array; numerical reservation uses `3*n*(c+2)+512*c` scalar-equivalent slots, with supplier Collision/Contact storage separate. The 512/contact record allowance is a declared structural reservation, not measured allocation/COW bytes. Caller/Task cancellation is checked at each contact and charged node block. Failed supplier work stops without history publication/retry. Initial and final required mapper outputs are checked against the exact binding/history/source before constructing accepted records.
