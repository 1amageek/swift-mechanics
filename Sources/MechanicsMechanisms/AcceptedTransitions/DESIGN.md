# AcceptedTransitions

## Purpose and Scope
Accepted-boundary lock engagement and physically validated detached-leaf topology replacement. Parent: [MechanicsMechanisms](../DESIGN.md). No children. Full IM16 requirements remain owned beyond this initial admitted subset.

## Responsibilities and Boundaries
Instantaneous real-mass lock engagement, momentum and energy accounting; publication through required Runtime trial. Direct-root spatial leaf separation constructs a genuinely different compiled tree/layout and publishes it through the qualified required Runtime model replacement operation. General subtree/loop cuts and further event/law migration remain unavailable.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Parent](../DESIGN.md) | parent | IM16 ownership | Module composition | Root registers and qualifies actual paths |
| [Compiler](../../MechanicsCompiler/DESIGN.md) | depends on | Required compile and model state | Real new tree revision | Canonical public layout must match |
| [Model](../../MechanicsModel/DESIGN.md) | depends on | Preserved body and identity records | Inertia/representation fidelity | New connector has explicit identity |
| [Joints](../../MechanicsJoints/DESIGN.md) | depends on | Public tree, pose, velocity layout | Free 7/6 representation | Restricted identity anchors |
| [Numerics](../../MechanicsNumerics/DESIGN.md) | depends on | Exclusive bounded ledger | Separate supplier work | No allocator claim |
| [Dynamics](../../MechanicsDynamics/DESIGN.md) | depends on | Rigid equations and solve | Real compiled physical mass | No diagonal proxy |
| [Constraints](../../MechanicsConstraints/DESIGN.md) | depends on | Required rank and evaluation | Original identified rows | Rank does not imply force or feasibility |
| [Runtime](../../MechanicsRuntime/DESIGN.md) | coordinates with | Accepted physical transactions | Immutable accepted prefix | Model replacement has separate admission authority |
| [Integration](../../MechanicsIntegration/DESIGN.md) | coordinates with | Equation and continuation witnesses | Actual stage/time acceptance | Exact chart readback |

## Architecture
```text
accepted source -> mass impulse reconciliation -> original momentum/rows -> contributor reset -> runtime accept or old prefix
```
Actual dependencies used: ConstrainedDynamics reconciliation; RuntimeSessionOperating.performTrial; Integration public continuation reset.

## Contracts and Invariants
Engagement occurs at source accepted time; it changes velocity and associated derivative/history together. RNG and unrelated contributors are preserved. Topology break must change actual tree/layout and physical mapping; row disable cannot qualify separation.
All values and public witnesses are Sendable on every target. Frames, model/layout revision, temporal force versus impulse interpretation and physical units stay explicit. Output is published only after original physical acceptance.

## State, Ownership, and Lifecycle
Source records are immutable; workspace and authoritative NumericalWork are caller-exclusive values. Required suppliers execute outside locks. No global cache or mutable shared producer state is introduced. Rich operation contexts may be immutable final Sendable owners to bound debug stack overlap. Structural scalar-slot budgets do not claim allocator or physical-copy measurements.

## Failure, Concurrency, and Constraints
Typed failures distinguish stale binding, shape/domain/physical residual, cancellation, overflow, capacity and supplier error. Caller maxima are checked before allocation; checked integer products bound workspaces. Supplier work is separate from orchestration work; unknown partial supplier failure stops without retry. Ledger replacement/reset is rejected. Unavailable callable paths carry FIXME(INCOMPLETE_IMPLEMENTATION) and typed failure.

## Verification and Change Impact
[Test owner](../../../Tests/MechanicsMechanismsTests/DESIGN.md). Unexecuted behavioral fixtures: Moving shaft lock energy/momentum, rejected transaction prefix, stale source, checkpoint/replay; actual removed joint/free sixDOF layout, independent body energy/momentum, threshold event and atomic target checkpoint/replay. Root owns Native and exact original WASM/Embedded qualification after source freeze; declarations alone grant no qualification. Changed mass/row/scaling/chart or lifecycle supplier contracts require affected composition requalification.

Trial derivative work is returned through an attempt-local `Mutex<NumericalWork>` evidence owner; callback computation occurs outside the lock. Native/WASM/Embedded use the identical storage and read/store entry points. No ordering/FIFO behavior is promised. The lock holds only the small numerical ledger, never physical arrays or external callbacks. Engagement can initialize a selected stationary lock before the configured constrained equation starts evolution; changing an already active constraint catalog requires a separate admitted provider transition and is not qualified by this operation.

A pure detached-leaf builder removes the original direct-root spatial leaf joint and creates explicitly identified virtual sixDOF connector/anchor records. It admits an identity fixed root and fixed identity anchors; no private compiler internals or geometric loop cut inference are used. Caller joint/connector/anchor UTF8 is charged and bounded by the source compiler identifier capacity before identity comparisons or target construction. Public KinematicTree constructs the proposed bounded layout, actual compiler reconstruction must return the identical layout, and unchanged joint ranges map by identity. Source current body poses/velocities, original inertias/representations, total kinetic energy and world linear/angular momentum are preserved within separate caller dimensional tolerances. The target descriptor initial pose is the actual accepted pose. General subtree release and active force/law migration remain explicit unavailable domains. Atomic Runtime replacement consumes the root-qualified required operation; mechanics conservation and combined behavioral qualification remain this component’s separate evidence obligation.

| Logical state | Native | Ordinary WASM | Embedded WASM | Entry/lifetime |
|---|---|---|---|---|
| Trial supplier ledger evidence | `Mutex<NumericalWork>` | same | same | `read/store`, attempt-local reference; external derivative outside lock; release after operation |
| Physical accepted state | required Runtime owner | same | same | `performTrial/replaceModel`; Runtime owns admission/publication/shutdown |
| Pure detached transition | immutable final Sendable | same | same | operation-local build; caller retains source/target |

No target branch, raw shared mutable state, unchecked conformance or I/O callback under a lock exists in this component. Profile execution is pending root qualification.

A break criterion is the absolute original computed generalized reaction of the selected scalar joint coordinate, in N translational force or N m torque (or N s/N m s for instantaneous impulse), explicitly distinguished by manifold and temporal meaning. The immutable reaction source pose/velocity/basis/time is checked against the accepted source. This does not grant unavailable bearing radial loads. The break event contributor has a bounded exact source/target/joint/connector/time/criterion payload; validation binds the actual target descriptor and schema, and checkpoint replay preserves the actual free topology. Full force/law contributor mapping stays caller-authorized and must be complete under the target Runtime handler.

Root-qualified Runtime producer commit `37b8816` provides required `RuntimeModelReplacing.replaceModel` and immutable `RuntimeModelReplacement`. Mechanisms prepare a threshold event from the retained original reaction/source and the physically validated detached transition. Publication constructs the target request from that exact transition. Target configuration, handler and complete contributor catalog are explicit caller inputs: the old integrator contributor is invalidated for the unavailable free-manifold integration chart, every unrelated source contributor is preserved, and the exact break event record is required. Runtime owns atomic model/context/workspace admission, source RNG preservation and one global accepted-sequence increment. Lock supplier ledger replacement reports unavailable work through the Runtime failure bridge. This first domain admits one break event; multi-event topology/law history requires further explicit authority. A detached target can be checkpointed/restarted but is not qualified for general free-manifold evolution here.

### Selected AF17 execution evidence

Native stationary lock and direct-root leaf-break acceptance/replay/failure tests passed. Original Native/WASM/Embedded public leaf mapping/atomic break/checkpoint replay executes; lock execution on WASM was not separately exercised by the public probe. Exact profile identity and root logs are indexed by the [parent design](../DESIGN.md); the corresponding test owner retains the independent physical oracles. Private stack diagnostics are not qualification.
