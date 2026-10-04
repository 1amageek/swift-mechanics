# TopologyContinuation

## Purpose and Scope
Parent: [Mechanisms](../DESIGN.md). No children. Own bounded accepted subtree-release event history, exact target catalog migration, surviving scalar actuator history rebinding and atomic Runtime publication. Legacy one-event v1 remains a separate path; no v1 import API is declared.

## Responsibilities and Boundaries
Require a reconciled subtree transition and a source-bound explicit or supported scalar reaction observation. Own planned event rule catalog, monotonic event identity/time/global sequence/stamp chain and decodable bounded payload. Account for every source contributor exactly once and every target required schema exactly once. Runtime owns ticket/cancel/lifecycle gates, complete source comparison, RNG preservation and atomic model/configuration/handler/workspace publication. Integration/Actuation suppliers own their concrete payload semantics.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [SubtreeTransitions](../SubtreeTransitions/DESIGN.md) | depends on | Opaque release/reconciled state and joint range mapping | Actual physical target authority | Mapped incoming a cannot authorize publication |
| [Runtime](../../../Execution/Runtime/DESIGN.md) | depends on | Required replacement/checkpoint/contributor witnesses | Atomic accepted prefix and replay | Same owner capacities/build/backend/determinism |
| [Actuation](../../Actuation/DESIGN.md) | depends on | Fixed codec, binding/state, required registry validation | Actual scalar law history continuation | Removed joint or non-scalar law is unsupported |
| [Integration](../../../Execution/Integration/DESIGN.md) | depends on | Target initialRecord/associatedHistory | Explicit integrator reinitialization | Old integrator retirement is declared, not inferred |
| [AcceptedTransitions](../AcceptedTransitions/DESIGN.md) | coordinates with | Legacy v1 format only | Separate deprecated candidate path | Bytes cannot be reused as a multi-event certificate |

## Architecture
```text
source checkpoint + history + rule catalog + reconciled physical target
  -> source-bound observation + ordered history append
  -> per-source disposition: preserve / scalar actuator rebind / explicit integrator retirement+initialization / owned history append
  -> exact required target catalog + contextual target handler admission
  -> opaque prepared token -> RuntimeModelReplacement -> atomic publish
checkpoint bytes + explicit same catalog/target model -> bounded decode + complete history/catalog/physical-time/sequence validation -> fresh owner restart
```

## Contracts and Invariants
Fresh final owners may use an explicit immutable restore-only bootstrap: its empty history has the exact final model as initial stamp and sequence zero, and the handler binds the exact caller-declared compiled physical state. Only accepted sequence zero and the exact bootstrap record qualify. The saved-history branch decodes bounded bytes against the original catalog and final target, then validates the complete final supplier registry. Ordinary trials cannot advance bootstrap or replace saved history with an empty later prefix. Publication handlers never carry bootstrap authority.
Rule IDs are unique increasing caller IDs with explicit removed joint, connector/frame IDs, released root and metric/threshold. Explicit release has no inferred bearing reaction. Scalar force/impulse criteria bind the actual ConstrainedMotion source snapshot/time/velocity/layout and one-DOF original joint; force/torque and linear/angular impulse temporal meanings stay distinct. General bearing-wrench criteria are not declared by this owner.

History retains ordered events: unique increasing IDs, nondecreasing accepted time, strictly increasing global accepted sequence, exact source→target stamp chain and source+1 revisions. Same-time cuts differ by global sequence. Every historical removed joint is absent and retained virtual connector is present with the declared root/child/frames/sixDOF meaning. Payload binds the exact rule catalog and initial stamp/time/sequence, with bounded strict UTF8, lengths, counts, finite values and no trailing data. Contextual admission checks history is not ahead of physical time/global sequence and binds the exact target descriptor and configured complete provider catalog.

Surviving actuator migration decodes actual fixed-codec source state, proves unchanged joint ID/manifold/anchors/authority and source/target range mapping, creates new model/index binding with identical lawRevision/continuationKey/domain/frame/kind, encodes and decodes the target state exactly and requires ActuatorRuntimeContributors validation. Time/primary/secondary/mode/sequence are preserved. Callbacks keep original ActuationWork bounds and monotonic counters with a nonzero seed; unavailable failed work remains explicit. Removed-joint actuators, unsupported Hybrid/Sleep or other law migration are typed failures. Preserve requires target required validation; generic supplier declarations are not physical migration certificates.

Explicit integration initialization names the retired source integrator and exact target provider/equation, generates initialRecord for reconciled physical q/v/time and checks associatedHistory. Integration sequence reset is explicit. No source record is omitted, duplicated or silently replaced. A target schema/record omission fails before publication. Prepared construction uses an immutable admission token issued only after full source/generation/history/catalog/physical admission, with fileprivate issuance authority.

## Runtime Flows
Preparation and all supplier validation run outside Runtime locks. Publication uses the required RuntimeModelReplacing.snapshot witness to check the retained accepted state, then passes its complete checkpoint as expectedSource to the required replaceModel witness. Runtime replacement rechecks the exact source under its operation lease and owns invariant capacity/continuation/determinism, accepted time, newer model revision, RNG and accepted sequence. The preparer retains topology-specific source/history/catalog/physical proof; its sourceConfiguration is preparation metadata, not a configuration introspection requirement on the Runtime protocol. A changed source, duplicate event, stale history/catalog, unknown law, over-capacity input or cancellation preserves the entire accepted prefix and RNG. Replay from an earlier revision uses a fresh owner of that revision and deterministic reapplication; final-target restart uses an explicit final model/catalog/provider.

## State, Ownership, and Lifecycle
Catalogs/providers/histories/prepared values are immutable Sendable owners. Byte parsing, trial law state and all work ledgers are exclusive operation-local values. No global state, raw pointer view, unsafe isolation or target-conditioned storage is added.

## Failure, Concurrency, and Constraints
Caller policy owns maximum events, bytes, metadata and validation work/scratch. All counts/lengths and arithmetic overflow are checked before allocation. Required supplier validation receives explicit remaining budgets and its evidence is bounded. Unknown/replaced opaque ledgers stop without retry. Legacy v1 import, general loops, prescribed Runtime checkpoints and unsupported supplier topology migration remain explicit gaps.

## Verification and Change Impact
[Test owner](../../../../../Tests/MechanicsTopologyReleaseTests/DESIGN.md) proves two cuts including same-time distinct sequences, source-revision reexecution replay/fresh final restart, actual actuator codec/rebind/continued law step, explicit integration reset, duplicate/stale/catalog/capacity/cancellation/unknown-law whole-prefix rejection, source-bound scalar metrics and prepared authority. Root owns actual graph registration, frozen Native tests and original three-profile public execution. No completeness claim follows from compile or declared interfaces alone.

All nine dedicated Native cases passed, including the actual required Runtime capacity/profile rejection after removal of nonexistent configuration introspection. [Public execution authority](../../../../../Verification/FoundationVerification/DESIGN.md#af22-selected-topology-public-execution) owns selected source-revision replay, two ordered cuts, real servo migration and cold final-owner restart on the original three profiles. Broader supplier migration and concurrency limitations remain.
