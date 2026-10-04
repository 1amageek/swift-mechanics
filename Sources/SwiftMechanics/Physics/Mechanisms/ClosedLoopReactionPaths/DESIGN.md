# ClosedLoopReactionPaths

## Purpose and Scope
Parent: [Mechanisms](../DESIGN.md). No children. Own source-bound instantaneous continuous spatial geometric-loop reactions and the remaining tree-edge/root-support balance for selected JT007/TR013. This AF24 component does not close the full requirements. Planar physical reactions, impulses, unrepresented connections, prescribed supports, and bearing/tooth distribution remain explicit unavailable domains.

## Responsibilities and Boundaries
Consume sealed original geometry and legacy ConstrainedMotion, prove original source/rows/rank/force agreement, convert energy multipliers to identified endpoint loads, then compose unchanged TreeReactionRecovery. No inertia tensor, Newton/Euler algorithm, tree-cut algorithm, dynamic solve, rank algorithm, accepted state, or constitutive bearing allocation is implemented here. Caller declares original generalized drive and physical completeness; these declarations are assumptions, not library certificates. Original body loads must inventory all known applied interactions and must not already contain the unknown declared loop reactions.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [Mechanisms](../DESIGN.md) | parent | AF24 dispatch/domain | Root owns registration, execution, progress and commits |
| [GeometricRelations](../../Constraints/GeometricRelations/DESIGN.md) | depends on | GeometricPhysicalRowAcceptance, GeometricOriginalAcceptance | Sealed covectors prove derivative/source, not feasibility or uniqueness |
| [AssemblyProjection](../../Constraints/AssemblyProjection/DESIGN.md) | depends on | WeightedConstraintAssembler.rank | Builtin rank is recomputed on all original rows |
| [ConstrainedDynamics](../ConstrainedDynamics/DESIGN.md) | depends on | Legacy ConstrainedMotion | Original drive/rows are not retained; declarations and physical proof are required |
| [RigidEquations](../../Dynamics/RigidEquations/DESIGN.md) | depends on | RigidEquationComputing.assemble, original immutable spatial input | No access to internal admission or arithmetic |
| [ReactionPaths](../ReactionPaths/DESIGN.md) | depends on | Unchanged TreeReactionRecovery | Its original per-body/generalized balance is the final physical acceptance |
| [Tests](../../../../../Tests/MechanicsClosedLoopReactionTests/DESIGN.md) | used by | Public recovery protocol | Root executes frozen source |

## Architecture
```text
spatial dynamics + source state + canonical geometry + sealed rows + constrained motion
 -> original source/layout/time and continuous-force admission
 -> original all-row rank and g/v/a, multiplier/generalized agreement
 -> identified world endpoint loads and common-reference action/reaction
 -> augmented original input -> bounded equation assembly
 -> sealed builtin TreeReactionRecovery -> immutable loop/tree/support report
```

## Contracts and Invariants
The public non-generic requirement is `ClosedLoopReactionRecovering.recover(_:outputFrame:policy:loadWork:work:)`. `ClosedLoopReactionInput` owns immutable Dynamics system, GeometricConstraintSystem, source KinematicState, sealed GeometricPhysicalRowWitness, legacy ConstrainedMotion, explicit originalDrive, and ClosedLoopReactionTopology. Construction is not acceptance. `completeTreeAndDeclaredRows` means every unknown interaction is a tree edge/fixed-root support or one of the complete original declared geometric rows. Other connections fail. This assumption never establishes unseen mesh/bearing completeness.

`ClosedLoopReactionPolicy` owns row limit, geometry original/projection policy, original rank policy (allowRedundancy), dimensionless position/velocity/acceleration tolerances, physical generalized agreement through TreeReactionPolicy scales/tolerance, explicit DynamicsAdmission for augmented input, and cancellation through tree/geometry/rank/admission policies. Positive original rank nullity fails with `ambiguousAllocation`; representative retained multipliers never become unique row reactions. All rank evidence is compared with the motion and all original rows remain present.

Only spatial continuous accelerationForce motion is admitted. Geometry motion programs/prescribed samples, nonstationary or nonzero-offset coincidence targets, and static/prescribed endpoints are unsupported. Planar geometry is refused explicitly. Nonzero originalDrive or original input.generalizedForces values fail as unallocatable. A zero declaration does not prove producer-drive provenance: final original physical balance proves that the declared known body loads suffice. Motion snapshot and Dynamics snapshot are each independently checked by public builtin GeometricOriginalAcceptance against canonical source geometry, including every public original column. Exact layout, tree basis, source velocity, frame, time and row identity must agree. Original g, normalized velocity residual, normalized acceleration residual, full alignment cross residual, and sum(A/S*mu) versus motion.generalizedReaction are recomputed; stored diagnostic residuals do not authorize output.

Each loop row multiplies original endpoint linear/angular covectors by mu in joules, producing N and N m. Known loop BodyWrenchContributions use actual world endpoint points, the constraint channel, and no invented potential. LoopRowReaction reports both endpoint bodies/points, row identity/kind/normalization/multiplier, output frame, a common torque reference (the first endpoint world point), time/revision and continuous-force meaning. `secondOnFirst` and `firstOnSecond` are shifted to that same world reference before frame rotation. Force and moment action/reaction are checked there. Torque shifts are `(oldPoint-newPoint) cross force` exactly once. Frame conversion rotates vectors; the point is separately transformed. Off-manifold geometry cannot fabricate coincident action/reaction.

The augmented input retains the complete original snapshot, velocity, original inertia/gravity/load inventory plus exactly two identified endpoint loads per original row. No original matrix/force-budget relabeling occurs. An injected RigidEquationComputing only assembles that input; its returned source is checked against the exact augmented input before composition. Final TreeReactionRecovery is builtin and unoverridable here, with builtin original equation/gravity services. Thus injected assembly output cannot override original physical acceptance or tree-cut authority. Existing tree algorithms, temporal/fidelity behavior, gravity root-versus-subtree ownership and original acceptance remain unchanged.

## Runtime Flows
Bounds/storage and irreversibly charged work precede any allocation or supplier callback. Original geometry acceptance and rank precede endpoint-load creation. One positive NumericalWork and LoadWork admission quantum precedes opaque augmented assembly. The supplier receives local ledger copies; both success and failure validate budget/counter preservation and merge known increments, preserving the caller LoadBudget cancellation closure. Reset restores the known numerical prefix and leaves the known load prefix; unknown supplier work raises supplierLedgerReplaced. Builtin TreeRecovery receives the cumulative caller ledgers. Cancellation is checked at admission, original rows/columns, load construction, after assembly and before publication. No retry or partial report.

If the retained caller cancellation closure becomes true after supplier work, LoadWork's public merge operations can refuse the increment. `loadLedgerMerge` preserves the caller admission prefix/closure and reports failed supplier work unavailable in that ledger; it never claims complete accounting or permits a safe retry from the prefix alone.

## State, Ownership, and Lifecycle
Inputs, dependencies and reports are immutable Sendable. Arrays and work ledgers are exclusive operation locals; retained COW backing is owned by results/input. Native/WASM/Embedded share identical declarations, isolation and synchronous lifetime. No shared mutable storage, unsafe code, conditional Sendable, or target-specific state exists. Phase storage includes retained original source/witness/motion, loop rows/body loads, augmented admitted system and lower geometry/rank/tree work. Checked conservative simultaneous storage bounds include these phases. Non-inlined phase boundaries preserve the original 128 KiB WASI stack contract; actual profiles remain root verification.

## Failure, Concurrency, and Constraints
ClosedLoopReactionError retains geometry, constraint, dynamics, tree, Core, Loads and numerical failures; exposes unavailable supplier work. Shape/source/temporal/domain/rank/generalized/geometry/action-reaction failures are explicit. Unsupported callable branches carry INCOMPLETE_IMPLEMENTATION markers. Caller limits bound rows, bodies, joints, body loads, metadata (lower), scalar storage and arithmetic. Frozen source is not behavioral qualification.

## Verification and Change Impact
Independent two-slider oracle: spatial masses 2/3, world X separation/target 2, distance normalization 4, identified first-body force 10, original zero generalized drive. Expected acceleration [2,2], multiplier 48 J, endpoint forces -6/+6. Normalization changes preserve physical forces. Independent transverse offset applied loads prove tree/support moments, frame rotation and common-reference action/reaction. Duplicate original distance proves typed ambiguity, despite a valid constrained representative. Changed geometry/source/time/layout/rows/velocity/drive, impulse, planar/support domains, wrong physical input, storage/arithmetic/cancellation and success/failure ledger reset must refuse publication. Lower contracts and source lifetime changes invalidate this composition evidence. Root alone executes focused Native and original three profiles after freeze.
