# SubtreeTransitions

## Purpose and Scope
Parent: [Mechanisms](../DESIGN.md). No children. Own accepted-boundary spatial subtree release mapping and explicit post-cut acceleration preparation. General loop cuts, prescribed Runtime checkpoint continuation and missing inertia are unsupported domains.

## Responsibilities and Boundaries
Reparent the released subtree root to the unchanged model root through an explicitly named sixDOF connector. Preserve every remaining joint ID/manifold/anchor/authority and raw q/v values by public source/target range mapping. Preserve root chart/authority/raw prefixes, body identity/frame/inertia/representations and incoming world motion. Compiler alone admits target topology/charts. Dynamics alone supplies actual mass/known-load equations. This owner proves conservation and target acceleration before continuation publication.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Joints](../../../Modeling/Joints/DESIGN.md) | depends on | Tree evaluation, FrameMotionComposing, sixDOF chart | Relative body motion and range mapping | q7/v6; linear in parent axes, angular in child axes |
| [Compiler](../../../Modeling/Compiler/DESIGN.md) | depends on | Required compile and makeState | Complete target admission | A disconnected forest is represented by unconstrained virtual joints |
| [Dynamics](../../Dynamics/DESIGN.md) | depends on | Actual assemble, energy, originalInertialForce and required forward | P/L/K and post-cut force acceptance | Incoming acceleration is not a post-cut force solution |
| [TopologyContinuation](../TopologyContinuation/DESIGN.md) | used by | Opaque reconciled transition and mapping | Catalog/history preparation | Caller chooses explicit known target loads |

## Architecture
```text
accepted compiled state -> actual world root/child motion
  -> inverse(root) composed with child -> relative sixDOF q/v/incoming a
  -> unchanged internal joints + root prefixes -> actual compiler
  -> every body pose/twist + independent P/L/K acceptance -> immutable release
release + explicit target loads/drive -> actual kernel + required forward
  -> original inertial force acceptance -> immutable reconciled target state
```

## Contracts and Invariants
Spatial fixed and spatial-floating roots are supported, including nonidentity fixed anchors and moving deep parents. Mutable prescribed anchors, prescribed-coordinate authority, model extensions and static/prescribed bodies inside the released component fail explicitly. All source bodies must provide physical spatial inertia for the complete conservation oracle. Body and surviving joint semantic IDs remain stable; numerical range starts may change through canonical BFS and are mapped by joint identity. New connector/frame IDs must be unique and compiler-admitted. New revision is exactly source+1 with overflow protection.

The incoming-limit acceleration maps full relative FrameMotion derivatives and raw surviving/root accelerations. No conservation claim is made for post-cut acceleration. Runtime publication requires the separate reconciled handle. Reconciliation accepts caller-declared target gravity/body/generalized loads and drive, evaluates the exact mapped target q/v, uses concrete original rigid equations and a required forward solver, then independently verifies original physical force residuals with the caller DynamicsSolvePolicy. Its q/v/time cannot change. Injected solver returned drive, dimensions, finite data, work and original residual are checked; its success is never authority by itself.

All result construction consumes immutable internal tokens with explicit fileprivate initializers in the actual issuing file. Tokens and raw constructors are absent from the public surface. No mutable shared state or unsafe conformance is introduced.

## Runtime Flows
Preparation remains outside Runtime locks. Cancellation and caller limits precede traversal/output allocation and supplier phases. No failed opaque supplier operation is retried.

## State, Ownership, and Lifecycle
Models, transitions and reconciliations are immutable Sendable owners. Arrays and NumericalWork/LoadWork are exclusive caller-owned values. Native/WASM/Embedded use identical storage and visibility contracts. All public operations use protocol requirements.

## Failure, Concurrency, and Constraints
Caller policy owns body/coordinate bounds, dimensional tolerances and cancellation. Compiler owns identifier/canonical topology capacities. NumericalWork owns allocation-equivalent and arithmetic bounds; supplier entry has a nonzero seed and monotonic budget/counter preservation is checked on success and failure. Unknown/replaced supplier ledgers are reported as unavailable and stop publication. Work consumed by a valid failed prefix remains consumed.

## Verification and Change Impact
[Test owner](../../../../../Tests/MechanicsTopologyReleaseTests/DESIGN.md) proves moving deep parent/nonidentity anchors/downstream joints, floating raw prefix and range remapping, independently summed body P/L/K, incoming derivative mapping and actual post-cut original force acceptance. Counterexamples include stale bindings, capacity/cancellation, wrong solver solution and replaced ledgers. Root alone registers the actual graph, executes Native tests and selected original Native/WASM/Embedded public paths, updates parent indexes and commits.

All nine dedicated Native cases passed after actual registration. [Public execution authority](../../../../../Verification/FoundationVerification/DESIGN.md#af22-selected-topology-public-execution) owns the selected original three-profile composition and scope limits; floating/nonidentity and independent body conservation evidence remains Native-local. No active-loop cut or unsupported authority is qualified.
