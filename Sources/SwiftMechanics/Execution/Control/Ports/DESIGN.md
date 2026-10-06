# Dimensioned sampled control ports

## Purpose and Scope
Parent: [Control](../DESIGN.md). Children: none. Own the scalar port, immutable feedback/command records, direct-feedthrough graph admission and typed input/error vocabulary for the initial CO-001/002/007/008 implementation domain. DESIGN precedes source; implementation and behavioral/profile qualification are pending. Full assigned control requirements remain open.

## Responsibilities and Boundaries
A port identifies the compiled model, scalar joint and indices, coordinate/frame, position/rate/acceleration/effort dimensions and dynamic authority. A feedback record preserves source model/joint/frame, sourceTime, temporal meaning, measured values and units. A command identifies its controller/configuration, sampleTickTime and sequence and preserves the mode-dependent command units. Port admission owns compatibility; physical computation and Runtime publication belong to the linked children. Initial physical ports are spatial fixed-base single-prismatic translation. Additional graph nodes cannot imply available plant/controller implementations.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Control](../DESIGN.md) | parent | CO dispatch and full-family status | Root owns index/registration/evidence | No qualification from declarations |
| [SampledFeedback](../SampledFeedback/DESIGN.md) | used by | Bound sample/command records | Consumer owns clock and laws | Preserve true sourceTime |
| [MechanicalPlant](../MechanicalPlant/DESIGN.md) | used by | Effort and state-output ports | Consumer owns real mechanical meaning | No inferred reactions |
| [Observations](../../../Analysis/Observations/DESIGN.md) | depends on | JointEncoderObservation | Generic raw observation adapter | No pending sensor pipeline dependency |
| [Actuation Ports](../../../Physics/Actuation/Ports/DESIGN.md) | depends on | ActuatorBinding and scalar coordinate authority | Existing drive association | Same revision/frame/indices |
| [Tests](../../../../../Tests/MechanicsControlTests/DESIGN.md) | used by | Input and graph counterexamples | Test owner | Root owns platform composition |

## Architecture
```text
raw typed encoder / caller timestamped command
 -> immutable scalar feedback + command ports
 -> bounded unit/identity/temporal association and graph check
 -> sampled law -> conjugate effort -> state-output mechanical plant
```

## Contracts and Invariants
Planned required operation `ControlPortPreparing.prepare(encoder:port:policy:work:) throws(ControlFailure) -> ScalarControlFeedback` adapts actual public encoder values without erasing model, joint, parent-anchor convention, sourceTime or units. The admitted scalar translation uses q in m, v in m/s, acceleration in m/s² and conjugate effort in N. Effort command is N, velocity command m/s and position command m. Computed-torque targets carry position/rate/acceleration separately. Initial exact feedback must match the true bound trial's captured q/v/time; raw records are not session-commit certificates. Impulse/event records, delayed/noisy/interpolated values and incompatible manifold conventions are explicit unsupported input domains.

Each declared connection must preserve value dimension, cardinality, model/joint/frame and direction. The controller effort output directly depends on its current sampled input; the position/velocity plant output has no instantaneous effort feedthrough. A bounded graph admission walks only edges whose dependent output is marked directFeedthrough and rejects cycles, duplicate/missing ports and incompatible edges before numerical callbacks. This represents a sampled controller connected to a continuous state-output plant; it does not solve an algebraic loop. Same-instant acceleration feedback would create effort-to-acceleration direct feedthrough and is refused in this initial domain. Graph admission never certifies an unimplemented node as a working system.

## State, Ownership, and Lifecycle
Port/feedback/command/connection records are immutable Sendable and retain their owners. No shared mutable storage, hidden callback history or unsafe views. Generic measurement consumers depend on these public records; the future sensor pipeline can adapt its own released public measurements without sharing mutable buffers or imposing a producer dependency on this child.

## Failure, Concurrency, and Constraints
The integration/runtime cases of ControlFailure.Cause store their original immutable supplier payload indirectly. This preserves case-pattern matching, typed cause, accepted-prefix and work evidence while preventing the large accepted-state payload from being copied into every typed-throws temporary. The failure box has one immutable owner retained by the value and released when its last failure value is released; there is no mutation, lock or platform-specific storage. Allocation is bounded by the fixed supplier error record and existing retained immutable arrays, rather than traversal/copying of accepted mechanical history. Existing caller storage bounds reserve orchestration/failure records before callbacks; an exhausted work ledger does not prevent publishing the typed failure itself.

Caller bounds port/edge counts, metadata byte traversal and temporary graph slots. Checked count products precede allocation; bounded UTF8 traversal is charged before string comparisons. Invalid units/frame/model/indices, unknown connection, feedthrough cycle, nonfinite values, unsupported temporal meaning, stale input, capacity/work and cancellation are typed failures. Callback operations are protocol requirements on all targets; no extension-only existential operation or target-specific weaker isolation is admitted.

## Verification and Change Impact
The original ordinary-WASM frame/stack diagnostic identified a 67,136-byte prepareCandidate frame and a 452-byte inline Cause matching IntegrationFailure. Native layout and genuine underlying supplier-failure retention tests qualify the indirect carrier; exact original WASM/Embedded stack diagnostics remain owned by the parent. Actual encoder adaptation proves units/source association; wrong unit/frame/revision and direct-feedthrough cycles must fail before real servo/plant calls. Public physical tracking and contributor proofs belong to the linked test contract. Changing port or temporal meaning requires rechecking SampledFeedback, MechanicalPlant, Continuation and measurement adapters.
