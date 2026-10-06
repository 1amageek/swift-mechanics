# Collision component

## Purpose and Scope
Parent: [responsibility owner](../DESIGN.md). Own IM10 geometric collision/proximity witnesses, conservative pair discovery, query/event identity and admitted CCD. [SPEC](../../../../SPEC.md) CL-001..010 owns full requirements. Children: [Shapes](Shapes/DESIGN.md), [Geometry](Geometry/DESIGN.md), [Discovery](Discovery/DESIGN.md), [Persistence](Persistence/DESIGN.md), [Sweep](Sweep/DESIGN.md). Component designs precede source and are indexed at handoff.

## Responsibilities and Boundaries
Own framed geometry queries and declared shape/motion/representation domains. Contact constitutive law, forces/impulses, dynamics, CAD shape construction and accepted runtime event scheduling remain external. A numerical shape query never implies mechanical response.

## Related Designs
| Design | Relationship | Contract used | Summary | Cautions |
|---|---|---|---|---|
| [TriangleMeshes](TriangleMeshes/DESIGN.md) | child | Identified feature/BVH/refit closest/ray/sphere-CCD | Original Native8/public7 on frozen2270 | General signed volume, tangency, rotating CCD and portable remain open |
| [CompoundQueries](CompoundQueries/DESIGN.md) | child | Identified analytic child proxy, transform, filter and bounded aggregation | Selected Native8/public7 on frozen2270 | Custom-filter failure accounting, union surfaces, manifolds and portable remain open |
| [Responsibility owner](../DESIGN.md) | parent | Scope and prerequisite DAG | Single-writer registration/integration | Full closure remains IM48 |
| [Core](../../Mathematics/Core/DESIGN.md) | depends on | Finite vectors/transforms, explicit SI | Geometry algebra | Degenerate normals fail or have explicit deterministic convention |
| [Model](../../Modeling/Model/DESIGN.md) | depends on | IDs/revisions/representations/provenance | Immutable geometric identity | Display and inertia never silently substitute collision geometry |

## Architecture
```text
immutable shape/proxy/revision + pose/filter + caller policy
 -> conservative candidates -> admitted geometric query -> framed witnesses/manifold/TOI
```

## Contracts and Invariants
Public service operations are protocol requirements. Original shape geometry, margins, normal direction, signed separation, feature identities and inside/tie behavior are explicit. Capacity/work/iteration limits bound operations; invalid geometry, unsupported pair/sweep, stale source and nonconvergence are typed failures. Unavailable geometry is never reported as empty/no-hit success. Broad-phase proofs compare against exhaustive independent fixtures; TOI assumptions match the admitted actual motion interpolation.

## State, Ownership, and Lifecycle
Immutable Sendable shape/scene/output values and caller-owned continuation/manifold/event records. Operation-owned workspace only. Any shared reference state must use the same Mutex/actor and callback contracts on every target. Actual accepted-step event lifecycle is an IM08/24 composition responsibility.

## Failure, Concurrency, and Constraints
Source revision, frame identity and declared approximation errors remain traceable. Query/contact representation resolution is independent of display LOD. Explicit caller capacities and domain policies own allocation/work limits; failed operations return no fabricated witness or partial success. Exact profile evidence follows root FoundationVerification; Native does not imply browser/Embedded physics.

## Verification and Change Impact
Tests/MechanicsCollisionTests owns analytic pair/query/CCD/transform/degeneracy/filter/capacity proofs. Root owns package registration, composed runtime probes and local commits. Changed witness conventions or IDs invalidate contact response, planning, sensing and CAD-derivation consumers. Full CL feature closure remains distinguishable from an initial admitted producer handoff.

### Verified initial producer handoff (2026-10-03)
Native Swift 6.4.0 release passed 14 tests in four suites covering admitted analytic geometry, conservative discovery, filter failure/order, current-pose/stale manifold and sampled trigger identity, original translating TOI brackets, cancellation and resources. Tangent-edge classification uses the child-owned numerical boundary-equivalence band; an independently observed 1e-12 s tangency bracket that excluded the true time was rejected by typed unresolvedMinimum after the targeted correction. Root selected sphere/box/plane witnesses, pair discovery, sliding feature-ID continuation, moving-plane translation CCD and unsupported pair rejection compiled/linked and actually ran with exit 0 on Native, ordinary WASM and Embedded WASM. Node.js 24.19.0 WASI Preview 1 and exact matching Swift 6.4.0 SDKs were used; Embedded selected --traits EmbeddedUnicode. A missing explicit Model import in Discovery was corrected uniformly, and its affected three Native tests passed again. General shapes/pairs/rotation/refit/continuous-trigger/source-geometry fidelity domains remain unqualified under IM10/IM48.

### Consolidation contract
This directory is a component inside the SwiftMechanics module, not a separate SwiftPM target. Its existing public behavior and exact-profile evidence remain its contract authority. Cross-component access uses the documented contracts; internal visibility alone does not grant admission or publication authority. Source relocation requires integrated behavioral requalification.

| [ConvexQueries](ConvexQueries/DESIGN.md) | child | Convex support-map weighted witnesses | Selected exact-source Native/WASM/Embedded and canonical qualification; proof domain owned by child |
